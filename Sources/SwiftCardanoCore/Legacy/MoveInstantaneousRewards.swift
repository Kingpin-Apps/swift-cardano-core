@preconcurrency import BigInt
import Foundation
import OrderedCollections
import CBORCodable

/// The accounting pot a move instantaneous reward draws from.
public enum MoveInstantaneousRewardSource: Int, Codable, Sendable {
    case reserves = 0
    case treasury = 1
}

/// A change to a reward account's balance: the CDDL's `delta_coin = int`,
/// which can be negative and ranges over -2^64 ... 2^64 - 1.
public typealias DeltaCoin = BigInt

/// Where a move instantaneous reward sends its funds.
public enum MoveInstantaneousRewardTarget: Hashable, Sendable {
    /// `{* stake_credential => delta_coin}`: changes to the reward accounts of
    /// these credentials, in the order they were written.
    case stakeCredentials(OrderedDictionary<StakeCredential, DeltaCoin>)
    /// `coin`: an amount moved to the other pot (from Alonzo).
    case otherPot(Coin)
}

/// `move_instantaneous_reward = [0 / 1, {* stake_credential => delta_coin} / coin]`
///
/// The first field is the pot the funds come from, 0 for the reserves and 1
/// for the treasury. A map sends them to stake credentials; a coin moves them
/// to the other pot.
public struct MoveInstantaneousReward: Serializable, Sendable {
    public let source: MoveInstantaneousRewardSource
    public let target: MoveInstantaneousRewardTarget
    /// Whether the credential map is written with an indefinite length, as
    /// the ledger itself wrote it in the Shelley era. Ignored when the funds
    /// go to the other pot.
    public let indefiniteLengthMap: Bool

    public init(
        source: MoveInstantaneousRewardSource,
        target: MoveInstantaneousRewardTarget,
        indefiniteLengthMap: Bool = false
    ) {
        self.source = source
        self.target = target
        self.indefiniteLengthMap = indefiniteLengthMap
    }

    /// Funds from `source` to the reward accounts of `rewards`' credentials.
    public init(
        source: MoveInstantaneousRewardSource,
        rewards: OrderedDictionary<StakeCredential, DeltaCoin>,
        indefiniteLengthMap: Bool = false
    ) {
        self.init(
            source: source, target: .stakeCredentials(rewards),
            indefiniteLengthMap: indefiniteLengthMap)
    }

    /// `coin` from `source` to the other pot.
    public init(source: MoveInstantaneousRewardSource, coin: Coin) {
        self.init(source: source, target: .otherPot(coin))
    }

    /// The credentials and their deltas, when the funds go to stake credentials.
    public var rewards: OrderedDictionary<StakeCredential, DeltaCoin>? {
        guard case let .stakeCredentials(rewards) = target else { return nil }
        return rewards
    }

    /// The amount moved to the other pot, when the funds go there.
    public var coin: Coin? {
        guard case let .otherPot(coin) = target else { return nil }
        return coin
    }

    public enum CodingKeys: String, CodingKey {
        case source
        case rewards
        case coin
        case stakeCredential
        case deltaCoin
        case indefiniteLengthMap
    }

    // MARK: - CBORSerializable

    public init(from primitive: Primitive) throws {
        let elements: [Primitive]
        switch primitive {
        case .list(let list): elements = list
        case .indefiniteList(let list): elements = list.map { $0 }
        default:
            throw CardanoCoreError.deserializeError("MoveInstantaneousReward: expected an array, got \(primitive)")
        }
        guard elements.count == 2 else {
            throw CardanoCoreError.deserializeError(
                "MoveInstantaneousReward: expected 2 elements, got \(elements.count)")
        }
        self.source = try Self.source(elements[0])

        // The ledger reads a map of any length encoding as credentials, and
        // anything else as a coin.
        let pairs: [(Primitive, Primitive)]
        switch elements[1] {
        case .orderedDict(let map):
            pairs = map.map { ($0.key, $0.value) }
            self.indefiniteLengthMap = false
        case .indefiniteDictionary(let map):
            pairs = try map.map { (try $0.key.normalized(), try $0.value.normalized()) }
            self.indefiniteLengthMap = true
        case .dict(let map):
            // An indefinite-length map read without its order. The ledger
            // writes a map in its key order, so that order gives back what
            // the ledger wrote.
            let credentials = try map.map { (try StakeCredential(from: $0.key), $0.value) }
            let sorted = credentials.sorted {
                CredentialType.ledgerOrder($0.0.credential, $1.0.credential)
            }
            pairs = try sorted.map { (try $0.0.toPrimitive(), $0.1) }
            self.indefiniteLengthMap = true
        default:
            self.target = .otherPot(
                try elements[1].integer("MoveInstantaneousReward coin", as: Coin.self))
            self.indefiniteLengthMap = false
            return
        }
        var rewards = OrderedDictionary<StakeCredential, DeltaCoin>()
        for (key, value) in pairs {
            let credential = try StakeCredential(from: key)
            guard rewards[credential] == nil else {
                throw CardanoCoreError.deserializeError(
                    "MoveInstantaneousReward: \(credential) appears twice")
            }
            rewards[credential] = try Self.deltaCoin(value)
        }
        self.target = .stakeCredentials(rewards)
    }

    public func toPrimitive() throws -> Primitive {
        let targetPrimitive: Primitive
        switch target {
        case .stakeCredentials(let rewards):
            var map = OrderedDictionary<Primitive, Primitive>()
            for (credential, delta) in rewards {
                map[try credential.toPrimitive()] = .integer(delta)
            }
            targetPrimitive = indefiniteLengthMap ? .indefiniteDictionary(map) : .orderedDict(map)
        case .otherPot(let coin):
            targetPrimitive = .integer(coin)
        }
        return .list([.uint(UInt64(source.rawValue)), targetPrimitive])
    }

    /// The pot: 0 for the reserves, 1 for the treasury.
    private static func source(_ primitive: Primitive) throws -> MoveInstantaneousRewardSource {
        let raw = try primitive.integer("MoveInstantaneousReward source", as: UInt64.self)
        guard let rawInt = Int(exactly: raw),
              let source = MoveInstantaneousRewardSource(rawValue: rawInt) else {
            throw CardanoCoreError.deserializeError("MoveInstantaneousReward: invalid source \(raw)")
        }
        return source
    }

    /// `delta_coin = int`: a CBOR integer, -2^64 ... 2^64 - 1.
    private static func deltaCoin(_ primitive: Primitive) throws -> DeltaCoin {
        guard let value = primitive.integerValue else {
            throw CardanoCoreError.deserializeError(
                "MoveInstantaneousReward delta coin: expected an integer, got \(primitive)")
        }
        guard value >= -(BigInt(1) << 64), value < (BigInt(1) << 64) else {
            throw CardanoCoreError.deserializeError(
                "MoveInstantaneousReward delta coin: \(value) is outside the CBOR int range")
        }
        return value
    }

    // MARK: - JSONSerializable

    /// Reads ``toDict()``'s form: `source` (0 or 1), and either `rewards`, a
    /// list of `{stakeCredential, deltaCoin}`, or `coin`.
    public static func fromDict(_ dict: Primitive) throws -> MoveInstantaneousReward {
        let type = "MoveInstantaneousReward"
        guard case let .orderedDict(entries) = dict else {
            throw CardanoCoreError.deserializeError("\(type): expected a dict, got \(dict)")
        }
        let source = try Self.source(try dictField(dict, CodingKeys.source.rawValue, in: type))

        let rewardsPrimitive = entries[.string(CodingKeys.rewards.rawValue)]
        let coinPrimitive = entries[.string(CodingKeys.coin.rawValue)]
        switch (rewardsPrimitive, coinPrimitive) {
        case (.some(.list(let list)), nil), (.some(.list(let list)), .some(.null)):
            var rewards = OrderedDictionary<StakeCredential, DeltaCoin>()
            for entry in list {
                let credential = try StakeCredential.fromCertificateDict(
                    try dictField(entry, CodingKeys.stakeCredential.rawValue, in: type))
                guard rewards[credential] == nil else {
                    throw CardanoCoreError.deserializeError("\(type): \(credential) appears twice")
                }
                rewards[credential] = try deltaCoin(
                    try dictField(entry, CodingKeys.deltaCoin.rawValue, in: type))
            }
            let indefinite: Bool
            switch entries[.string(CodingKeys.indefiniteLengthMap.rawValue)] {
            case nil, .some(.bool(false)): indefinite = false
            case .some(.bool(true)): indefinite = true
            case .some(let other):
                throw CardanoCoreError.deserializeError("\(type): invalid indefiniteLengthMap \(other)")
            }
            return MoveInstantaneousReward(
                source: source, rewards: rewards, indefiniteLengthMap: indefinite)
        case (nil, .some(let coin)), (.some(.null), .some(let coin)):
            return MoveInstantaneousReward(
                source: source, coin: try coin.integer("\(type) coin", as: Coin.self))
        default:
            throw CardanoCoreError.deserializeError(
                "\(type): expected exactly one of rewards (a list) and coin")
        }
    }

    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        dict[.string(CodingKeys.source.rawValue)] = .uint(UInt64(source.rawValue))
        switch target {
        case .stakeCredentials(let rewards):
            dict[.string(CodingKeys.rewards.rawValue)] = .list(rewards.map { credential, delta in
                .orderedDict([
                    .string(CodingKeys.stakeCredential.rawValue): credential.certificateDict(),
                    .string(CodingKeys.deltaCoin.rawValue): .integer(delta),
                ])
            })
            if indefiniteLengthMap {
                dict[.string(CodingKeys.indefiniteLengthMap.rawValue)] = .bool(true)
            }
        case .otherPot(let coin):
            dict[.string(CodingKeys.coin.rawValue)] = .integer(coin)
        }
        return .orderedDict(dict)
    }
}

/// `move_instantaneous_rewards_cert = (6, move_instantaneous_reward)`, valid
/// from Shelley to Babbage.
public struct MoveInstantaneousRewards: CertificateSerializable {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public var type: String { return MoveInstantaneousRewards.TYPE }
    public var description: String { return MoveInstantaneousRewards.DESCRIPTION }

    public static var TYPE: String { CertificateType.shelley.rawValue }
    public static var DESCRIPTION: String {
        CertificateDescription.moveInstantaneousRewards.rawValue
    }
    public static var CODE: CertificateCode { return .moveInstantaneousRewards }

    public let moveInstantaneousRewards: MoveInstantaneousReward

    public enum CodingKeys: String, CodingKey {
        case moveInstantaneousRewards
    }

    /// Initialize a new `MoveInstantaneousRewards` certificate
    /// - Parameter moveInstantaneousRewards: The move instantaneous rewards
    /// - Throws: When the certificate cannot be encoded for its payload.
    public init(moveInstantaneousRewards: MoveInstantaneousReward) throws {
        self.moveInstantaneousRewards = moveInstantaneousRewards
        self._payload = Data()
        self._type = Self.TYPE
        self._description = Self.DESCRIPTION
        self._payload = try encodedPayload()
    }

    /// Initialize a new `MoveInstantaneousRewards` certificate from its Text Envelope representation
    /// - Parameters:
    ///  - payload: The CBOR representation of the certificate
    ///  - type: The type of the certificate
    ///  - description: The description of the certificate
    public init(payload: Data, type: String?, description: String?) throws {
        let decoded = try CBORDecoder().decode(Self.self, from: payload)
        self = decoded
        self._payload = payload
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
    }

    // MARK: - CBORSerializable

    public init(from primitive: Primitive) throws {
        let fields = try Self.certificateFields(primitive, count: 2)
        try self.init(moveInstantaneousRewards: try MoveInstantaneousReward(from: fields[0]))
    }

    public func toPrimitive() throws -> Primitive {
        return .list([
            Self.codePrimitive,
            try moveInstantaneousRewards.toPrimitive(),
        ])
    }

    // MARK: - JSONSerializable

    public static func fromDict(_ dict: Primitive) throws -> MoveInstantaneousRewards {
        let rewards = try dictField(
            dict, CodingKeys.moveInstantaneousRewards.rawValue, in: "MoveInstantaneousRewards")
        return try MoveInstantaneousRewards(
            moveInstantaneousRewards: try MoveInstantaneousReward.fromDict(rewards))
    }

    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        dict[.string(CodingKeys.moveInstantaneousRewards.rawValue)] =
            try moveInstantaneousRewards.toDict()
        return .orderedDict(dict)
    }
}
