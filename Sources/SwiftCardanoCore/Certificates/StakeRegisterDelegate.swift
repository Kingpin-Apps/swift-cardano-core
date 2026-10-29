import Foundation
import CBORCodable
import OrderedCollections

/// Stake registration and pool delegation: `account_registration_delegation_to_stake_pool_cert = (11, stake_credential, pool_keyhash, coin)`.
public struct StakeRegisterDelegate: CertificateSerializable {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public var type: String { StakeRegisterDelegate.TYPE }
    public var description: String { StakeRegisterDelegate.DESCRIPTION }

    public static var TYPE: String { CertificateType.conway.rawValue }
    public static var DESCRIPTION: String { CertificateDescription.stakeRegisterDelegate.rawValue }
    public static var CODE: CertificateCode { .stakeRegisterDelegate }

    public let stakeCredential: StakeCredential
    public let poolKeyHash: PoolKeyHash
    public let coin: Coin

    public enum CodingKeys: String, CodingKey {
        case stakeCredential
        case poolKeyHash
        case coin
    }

    /// Creates the certificate.
    ///
    /// - Throws: When the certificate cannot be encoded for its payload.
    public init(stakeCredential: StakeCredential, poolKeyHash: PoolKeyHash, coin: Coin) throws {
        self.stakeCredential = stakeCredential
        self.poolKeyHash = poolKeyHash
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
        let fields = try Self.certificateFields(primitive, count: 4)
        try self.init(
            stakeCredential: try StakeCredential(from: fields[0]),
            poolKeyHash: try PoolKeyHash(from: fields[1]),
            coin: try fields[2].integer("StakeRegisterDelegate coin", as: Coin.self)
        )
    }

    public func toPrimitive() throws -> Primitive {
        return .list([
            Self.codePrimitive,
            try stakeCredential.toPrimitive(),
            poolKeyHash.toPrimitive(),
            .integer(coin)
        ])
    }

    // MARK: - JSONSerializable

    public static func fromDict(_ dict: Primitive) throws -> StakeRegisterDelegate {
        return try StakeRegisterDelegate(
            stakeCredential: try StakeCredential.fromCertificateDict(try dictField(dict, CodingKeys.stakeCredential.rawValue, in: "StakeRegisterDelegate")),
            poolKeyHash: try PoolOperator(from: try dictString(dict, CodingKeys.poolKeyHash.rawValue, in: "StakeRegisterDelegate")).poolKeyHash,
            coin: try dictField(dict, CodingKeys.coin.rawValue, in: "StakeRegisterDelegate").integer("StakeRegisterDelegate coin", as: Coin.self)
        )
    }

    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        dict[.string(CodingKeys.stakeCredential.rawValue)] = stakeCredential.certificateDict()
        dict[.string(CodingKeys.poolKeyHash.rawValue)] = .string(try PoolOperator(poolKeyHash: poolKeyHash).id())
        dict[.string(CodingKeys.coin.rawValue)] = .integer(coin)
        return .orderedDict(dict)
    }
}
