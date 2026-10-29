import Foundation
import CBORCodable
import OrderedCollections

/// Stake pool retirement certificate: `pool_retirement_cert = (4, pool_keyhash, epoch)`.
public struct PoolRetirement: CertificateSerializable {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public var type: String { PoolRetirement.TYPE }
    public var description: String { PoolRetirement.DESCRIPTION }

    public static var TYPE: String { CertificateType.conway.rawValue }
    public static var DESCRIPTION: String { CertificateDescription.poolRetirement.rawValue }
    public static var CODE: CertificateCode { .poolRetirement }

    public let poolKeyHash: PoolKeyHash
    public let epoch: EpochNumber

    public enum CodingKeys: String, CodingKey {
        case poolKeyHash
        case epoch
    }

    /// Creates the certificate.
    ///
    /// - Throws: When the certificate cannot be encoded for its payload.
    public init(poolKeyHash: PoolKeyHash, epoch: EpochNumber) throws {
        self.poolKeyHash = poolKeyHash
        self.epoch = epoch
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
        let decoded = try CBORDecoder.ledger().decode(Self.self, from: payload)
        self = decoded
        self._payload = payload
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
    }

    // MARK: - CBORSerializable

    public init(from primitive: Primitive) throws {
        let fields = try Self.certificateFields(primitive, count: 3)
        try self.init(
            poolKeyHash: try PoolKeyHash(from: fields[0]),
            epoch: try fields[1].integer("PoolRetirement epoch", as: EpochNumber.self)
        )
    }

    public func toPrimitive() throws -> Primitive {
        return .list([
            Self.codePrimitive,
            poolKeyHash.toPrimitive(),
            .integer(epoch)
        ])
    }

    // MARK: - JSONSerializable

    public static func fromDict(_ dict: Primitive) throws -> PoolRetirement {
        return try PoolRetirement(
            poolKeyHash: try PoolOperator(from: try dictString(dict, CodingKeys.poolKeyHash.rawValue, in: "PoolRetirement")).poolKeyHash,
            epoch: try dictField(dict, CodingKeys.epoch.rawValue, in: "PoolRetirement").integer("PoolRetirement epoch", as: EpochNumber.self)
        )
    }

    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        dict[.string(CodingKeys.poolKeyHash.rawValue)] = .string(try PoolOperator(poolKeyHash: poolKeyHash).id())
        dict[.string(CodingKeys.epoch.rawValue)] = .integer(epoch)
        return .orderedDict(dict)
    }
}
