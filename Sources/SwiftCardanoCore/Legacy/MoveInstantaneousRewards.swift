import Foundation
import OrderedCollections
import CBORCodable

public enum MoveInstantaneousRewardSource: Int, Codable, Sendable {
    case reserves = 0
    case treasury = 1
}

public struct DeltaCoin: Codable, Hashable, Equatable, Sendable {
    public let deltaCoin: Int
}

public struct MoveInstantaneousReward: Serializable, Sendable {
    public let source: MoveInstantaneousRewardSource
    public let rewards: [String: DeltaCoin]?
    public let coin: UInt64?

    public init(
        source: MoveInstantaneousRewardSource,
        rewards: [String: DeltaCoin]?,
        coin: UInt64?
    ) {
        self.source = source
        self.rewards = rewards
        self.coin = coin
    }

    public enum CodingKeys: String, CodingKey {
        case source
        case rewards
        case coin
    }

    // MARK: - CBORSerializable

    public init(from primitive: Primitive) throws {
        guard case .list(let primitive) = primitive else {
            throw CardanoCoreError.deserializeError("Invalid MoveInstantaneousReward type")
        }
        guard primitive.count == 3 else {
            throw CardanoCoreError.deserializeError("Invalid MoveInstantaneousReward type")
        }
        let sourceInt: Int
        switch primitive[0] {
        case .int(let v): sourceInt = Int(v)
        case .uint(let v): sourceInt = Int(v)
        default:
            throw CardanoCoreError.deserializeError("Invalid MoveInstantaneousReward source type")
        }
        guard let rewardSource = MoveInstantaneousRewardSource(rawValue: sourceInt) else {
            throw CardanoCoreError.deserializeError("Invalid MoveInstantaneousReward source type")
        }
        self.source = rewardSource
        var rewardsPairs: [(Primitive, Primitive)]?
        switch primitive[1] {
        case .dict(let d): rewardsPairs = Array(d)
        case .orderedDict(let od): rewardsPairs = od.map { ($0.key, $0.value) }
        case .null: rewardsPairs = nil
        default:
            throw CardanoCoreError.deserializeError("Invalid MoveInstantaneousReward rewards type")
        }
        if let pairs = rewardsPairs {
            var rewardsDict: [String: DeltaCoin] = [:]
            for (key, value) in pairs {
                guard case .string(let keyStr) = key else {
                    throw CardanoCoreError.deserializeError(
                        "Invalid MoveInstantaneousReward rewards type")
                }
                let delta: Int
                switch value {
                case .int(let v): delta = Int(v)
                case .uint(let v): delta = Int(v)
                default:
                    throw CardanoCoreError.deserializeError(
                        "Invalid MoveInstantaneousReward rewards type")
                }
                rewardsDict[keyStr] = DeltaCoin(deltaCoin: delta)
            }
            self.rewards = rewardsDict
        } else {
            self.rewards = nil
        }

        switch primitive[2] {
        case .int(let v): self.coin = UInt64(v)
        case .uint(let v): self.coin = UInt64(v)
        case .null: self.coin = nil
        default:
            throw CardanoCoreError.deserializeError("Invalid MoveInstantaneousReward coin type")
        }
    }

    public func toPrimitive() throws -> Primitive {
        var elements: [Primitive] = []
        elements.append(.int(Int64(source.rawValue)))

        if let rewards = rewards {
            var rewardsMap: [Primitive: Primitive] = [:]
            for (key, value) in rewards {
                rewardsMap[.string(key)] = .int(Int64(value.deltaCoin))
            }
            elements.append(.dict(rewardsMap))
        } else {
            elements.append(.null)
        }
        if let coin = coin {
            elements.append(.int(Int64(coin)))
        } else {
            elements.append(.null)
        }
        return .list(elements)
    }

    // MARK: - JSONSerializable

    public static func fromDict(_ dict: Primitive) throws -> MoveInstantaneousReward {
        guard case .orderedDict(let orderedDict) = dict else {
            throw CardanoCoreError.deserializeError("Invalid MoveInstantaneousReward dict format")
        }
        guard let sourcePrimitive = orderedDict[.string(CodingKeys.source.rawValue)],
            case .int(let sourceValue) = sourcePrimitive
        else {
            throw CardanoCoreError.deserializeError(
                "Missing or invalid source in MoveInstantaneousReward")
        }

        guard let source = MoveInstantaneousRewardSource(rawValue: Int(sourceValue)) else {
            throw CardanoCoreError.deserializeError(
                "Invalid source value in MoveInstantaneousReward")
        }

        var rewards: [String: DeltaCoin]? = nil
        if let rewardsPrimitive = orderedDict[.string(CodingKeys.rewards.rawValue)] {
            if case .null = rewardsPrimitive {
                rewards = nil
            } else if case .orderedDict(let rewardsDict) = rewardsPrimitive {
                var rewardsMap: [String: DeltaCoin] = [:]
                for (key, value) in rewardsDict {
                    guard case .string(let keyStr) = key,
                        case .int(let delta) = value
                    else {
                        throw CardanoCoreError.deserializeError(
                            "Invalid rewards format in MoveInstantaneousReward")
                    }
                    rewardsMap[keyStr] = DeltaCoin(deltaCoin: Int(delta))
                }
                rewards = rewardsMap
            } else {
                throw CardanoCoreError.deserializeError(
                    "Invalid rewards type in MoveInstantaneousReward")
            }
        }

        var coin: UInt64? = nil
        if let coinPrimitive = orderedDict[.string(CodingKeys.coin.rawValue)] {
            if case .null = coinPrimitive {
                coin = nil
            } else if case .int(let coinValue) = coinPrimitive {
                coin = UInt64(coinValue)
            } else {
                throw CardanoCoreError.deserializeError(
                    "Invalid coin type in MoveInstantaneousReward")
            }
        }

        return MoveInstantaneousReward(source: source, rewards: rewards, coin: coin)
    }

    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()

        dict[.string(CodingKeys.source.rawValue)] = .int(Int64(source.rawValue))

        if let rewards = rewards {
            var rewardsDict = OrderedDictionary<Primitive, Primitive>()
            for (key, value) in rewards {
                rewardsDict[.string(key)] = .int(Int64(value.deltaCoin))
            }
            dict[.string(CodingKeys.rewards.rawValue)] = .orderedDict(rewardsDict)
        } else {
            dict[.string(CodingKeys.rewards.rawValue)] = .null
        }

        if let coin = coin {
            dict[.string(CodingKeys.coin.rawValue)] = .int(Int64(coin))
        } else {
            dict[.string(CodingKeys.coin.rawValue)] = .null
        }

        return .orderedDict(dict)
    }

    public static func == (lhs: MoveInstantaneousReward, rhs: MoveInstantaneousReward) -> Bool {
        return lhs.source == rhs.source && lhs.rewards == rhs.rewards && lhs.coin == rhs.coin
    }
}

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
    public init(moveInstantaneousRewards: MoveInstantaneousReward) {
        self.moveInstantaneousRewards = moveInstantaneousRewards

        self._payload = try! CBORSerialization.data(
            from:
                .array(
                    [
                        CBOR(Self.CODE.rawValue),
                        try! CBOREncoder().encode(moveInstantaneousRewards).toCBOR,
                    ]
                )
        )
        self._type = Self.TYPE
        self._description = Self.DESCRIPTION
    }

    /// Initialize a new `MoveInstantaneousRewards` certificate from its Text Envelope representation
    /// - Parameters:
    ///  - payload: The CBOR representation of the certificate
    ///  - type: The type of the certificate
    ///  - description: The description of the certificate
    public init(payload: Data, type: String?, description: String?) {
        self._payload = payload
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION

        let cbor = try! CBORDecoder().decode(MoveInstantaneousRewards.self, from: payload)

        self.moveInstantaneousRewards = cbor.moveInstantaneousRewards
    }

    // MARK: - CBORSerializable

    public init(from primitive: Primitive) throws {
        guard case .list(let primitive) = primitive,
            primitive.count == 2
        else {
            throw CardanoCoreError.deserializeError("Invalid MoveInstantaneousRewards type")
        }

        guard case .int(let code) = primitive[0],
            code == UInt64(Self.CODE.rawValue)
        else {
            throw CardanoCoreError.deserializeError(
                "Invalid MoveInstantaneousRewards type: \(primitive[0])")
        }

        let moveInstantaneousRewards = try MoveInstantaneousReward(from: primitive[1])
        self.init(moveInstantaneousRewards: moveInstantaneousRewards)
    }

    public func toPrimitive() throws -> Primitive {
        return .list([
            .int(Int64(Self.CODE.rawValue)),
            try moveInstantaneousRewards.toPrimitive(),
        ])
    }

    // MARK: - JSONSerializable

    public static func fromDict(_ dict: Primitive) throws -> MoveInstantaneousRewards {
        guard case .orderedDict(let orderedDict) = dict else {
            throw CardanoCoreError.deserializeError("Invalid MoveInstantaneousRewards dict format")
        }
        guard
            let moveInstantaneousRewardsPrimitive = orderedDict[
                .string(CodingKeys.moveInstantaneousRewards.rawValue)]
        else {
            throw CardanoCoreError.deserializeError(
                "Missing moveInstantaneousRewards in MoveInstantaneousRewards")
        }

        guard case .orderedDict(let rewardsDict) = moveInstantaneousRewardsPrimitive else {
            throw CardanoCoreError.deserializeError(
                "Invalid moveInstantaneousRewards format in MoveInstantaneousRewards")
        }

        let moveInstantaneousRewards = try MoveInstantaneousReward.fromDict(
            .orderedDict(rewardsDict))

        return MoveInstantaneousRewards(moveInstantaneousRewards: moveInstantaneousRewards)
    }

    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        dict[.string(CodingKeys.moveInstantaneousRewards.rawValue)] =
            try moveInstantaneousRewards.toDict()
        return .orderedDict(dict)
    }

}
