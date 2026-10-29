import Foundation
import CBORCodable
import OrderedCollections

/// Stake registration with pool and vote delegation: `account_registration_delegation_to_stake_pool_and_drep_cert = (13, stake_credential, pool_keyhash, drep, coin)`.
public struct StakeVoteRegisterDelegate: CertificateSerializable {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public var type: String { StakeVoteRegisterDelegate.TYPE }
    public var description: String { StakeVoteRegisterDelegate.DESCRIPTION }

    public static var TYPE: String { CertificateType.conway.rawValue }
    public static var DESCRIPTION: String { CertificateDescription.voteRegisterDelegate.rawValue }
    public static var CODE: CertificateCode { .stakeVoteRegisterDelegate }

    public let stakeCredential: StakeCredential
    public let poolKeyHash: PoolKeyHash
    public let drep: DRep
    public let coin: Coin

    public enum CodingKeys: String, CodingKey {
        case stakeCredential
        case poolKeyHash
        case drep
        case coin
    }

    /// Creates the certificate.
    ///
    /// - Throws: When the certificate cannot be encoded for its payload.
    public init(stakeCredential: StakeCredential, poolKeyHash: PoolKeyHash, drep: DRep, coin: Coin) throws {
        self.stakeCredential = stakeCredential
        self.poolKeyHash = poolKeyHash
        self.drep = drep
        self.coin = coin
        self._payload = Data()
        self._type = Self.TYPE
        self._description = Self.DESCRIPTION
        self._payload = try encodedPayload()
    }

    /// Initialize the certificate from its text-envelope payload.
    /// - Parameters:
    ///   - payload: The CBOR of the certificate
    ///   - type: The text-envelope type
    ///   - description: The text-envelope description
    public init(payload: Data, type: String?, description: String?) throws {
        let decoded = try CBORDecoder().decode(Self.self, from: payload)
        self = decoded
        self._payload = payload
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
    }

    // MARK: - CBORSerializable

    public init(from primitive: Primitive) throws {
        let fields = try Self.certificateFields(primitive, count: 5)
        try self.init(
            stakeCredential: try StakeCredential(from: fields[0]),
            poolKeyHash: try PoolKeyHash(from: fields[1]),
            drep: try DRep(from: fields[2]),
            coin: try fields[3].integer("StakeVoteRegisterDelegate coin", as: Coin.self)
        )
    }

    public func toPrimitive() throws -> Primitive {
        return .list([
            Self.codePrimitive,
            try stakeCredential.toPrimitive(),
            poolKeyHash.toPrimitive(),
            try drep.toPrimitive(),
            .integer(coin)
        ])
    }

    // MARK: - JSONSerializable

    public static func fromDict(_ dict: Primitive) throws -> StakeVoteRegisterDelegate {
        return try StakeVoteRegisterDelegate(
            stakeCredential: try StakeCredential.fromCertificateDict(try dictField(dict, CodingKeys.stakeCredential.rawValue, in: "StakeVoteRegisterDelegate")),
            poolKeyHash: try PoolOperator(from: try dictString(dict, CodingKeys.poolKeyHash.rawValue, in: "StakeVoteRegisterDelegate")).poolKeyHash,
            drep: try DRep(from: try dictString(dict, CodingKeys.drep.rawValue, in: "StakeVoteRegisterDelegate")),
            coin: try dictField(dict, CodingKeys.coin.rawValue, in: "StakeVoteRegisterDelegate").integer("StakeVoteRegisterDelegate coin", as: Coin.self)
        )
    }

    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        dict[.string(CodingKeys.stakeCredential.rawValue)] = stakeCredential.certificateDict()
        dict[.string(CodingKeys.poolKeyHash.rawValue)] = .string(try PoolOperator(poolKeyHash: poolKeyHash).id())
        dict[.string(CodingKeys.drep.rawValue)] = .string(try drep.id((.bech32, .cip129)))
        dict[.string(CodingKeys.coin.rawValue)] = .integer(coin)
        return .orderedDict(dict)
    }
}
