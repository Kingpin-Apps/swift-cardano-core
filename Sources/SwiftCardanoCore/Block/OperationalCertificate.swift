import Foundation
import OrderedCollections

/// Operational certificate as defined in the Conway CDDL:
/// ```
/// operational_cert =
///   ( hot_vkey        : kes_vkey
///   , sequence_number : uint
///   , kes_period      : uint
///   , sigma           : bytes .size 64
///   )
/// ```
///
/// Serialized as a CBOR array with 4 elements.
public struct OperationalCertificate: Serializable {
    /// KES hot verification key (32 bytes)
    public var hotVKey: KESVerificationKey
    /// Sequence number
    public var sequenceNumber: UInt64
    /// KES period
    public var kesPeriod: UInt64
    /// Ed25519 signature (64 bytes)
    public var sigma: Data

    public static let SIGMA_SIZE = 64

    enum CodingKeys: String, CodingKey {
        case hotVKey
        case sequenceNumber
        case kesPeriod
        case sigma
    }

    public init(
        hotVKey: KESVerificationKey,
        sequenceNumber: UInt64,
        kesPeriod: UInt64,
        sigma: Data
    ) throws {
        guard sigma.count == Self.SIGMA_SIZE else {
            throw CardanoCoreError.invalidArgument(
                "OperationalCertificate sigma must be \(Self.SIGMA_SIZE) bytes, got \(sigma.count)"
            )
        }
        self.hotVKey = hotVKey
        self.sequenceNumber = sequenceNumber
        self.kesPeriod = kesPeriod
        self.sigma = sigma
    }

    // MARK: - CBORSerializable

    public init(from primitive: Primitive) throws {
        guard case let .list(elements) = primitive else {
            throw CardanoCoreError.deserializeError(
                "Invalid OperationalCertificate primitive: expected list"
            )
        }

        guard elements.count == 4 else {
            throw CardanoCoreError.deserializeError(
                "OperationalCertificate requires exactly 4 elements, got \(elements.count)"
            )
        }

        let hotVKey = try KESVerificationKey(from: elements[0])

        let sequenceNumber: UInt64
        switch elements[1] {
        case .uint(let val):
            sequenceNumber = UInt64(val)
        case .int(let val):
            sequenceNumber = UInt64(val)
        default:
            throw CardanoCoreError.deserializeError(
                "Invalid OperationalCertificate sequence_number type"
            )
        }

        let kesPeriod: UInt64
        switch elements[2] {
            case .uint(let val):
                kesPeriod = UInt64(val)
            case .int(let val):
                kesPeriod = UInt64(val)
            default:
                throw CardanoCoreError.deserializeError("Invalid OperationalCertificate kes_period type")
        }

        guard case let .bytes(sigma) = elements[3] else {
            throw CardanoCoreError.deserializeError("Invalid OperationalCertificate sigma: expected bytes")
        }

        try self.init(
            hotVKey: hotVKey,
            sequenceNumber: sequenceNumber,
            kesPeriod: kesPeriod,
            sigma: sigma
        )
    }

    public func toPrimitive() throws -> Primitive {
        return .list([
            .bytes(hotVKey.payload),
            .uint(UInt(sequenceNumber)),
            .uint(UInt(kesPeriod)),
            .bytes(sigma)
        ])
    }

    // MARK: - JSONSerializable

    public static func fromDict(_ primitive: Primitive) throws -> OperationalCertificate {
        guard case let .orderedDict(dict) = primitive else {
            throw CardanoCoreError.deserializeError("Invalid OperationalCertificate dict")
        }

        guard let hotVKeyPrimitive = dict[.string(CodingKeys.hotVKey.rawValue)] else {
            throw CardanoCoreError.deserializeError("Missing hotVKey in OperationalCertificate")
        }
        let hotVKey = try KESVerificationKey(from: hotVKeyPrimitive)

        guard let seqPrimitive = dict[.string(CodingKeys.sequenceNumber.rawValue)] else {
            throw CardanoCoreError.deserializeError("Missing sequenceNumber in OperationalCert")
        }
        let sequenceNumber: UInt64
        switch seqPrimitive {
        case .uint(let val): sequenceNumber = UInt64(val)
        case .int(let val): sequenceNumber = UInt64(val)
        default:
            throw CardanoCoreError.deserializeError("Invalid sequenceNumber type in OperationalCert")
        }

        guard let kesPeriodPrimitive = dict[.string(CodingKeys.kesPeriod.rawValue)] else {
            throw CardanoCoreError.deserializeError("Missing kesPeriod in OperationalCert")
        }
        let kesPeriod: UInt64
        switch kesPeriodPrimitive {
        case .uint(let val): kesPeriod = UInt64(val)
        case .int(let val): kesPeriod = UInt64(val)
        default:
            throw CardanoCoreError.deserializeError("Invalid kesPeriod type in OperationalCert")
        }

        guard let sigmaPrimitive = dict[.string(CodingKeys.sigma.rawValue)],
              case let .bytes(sigma) = sigmaPrimitive else {
            throw CardanoCoreError.deserializeError("Missing or invalid sigma in OperationalCert")
        }

        return try OperationalCertificate(
            hotVKey: hotVKey,
            sequenceNumber: sequenceNumber,
            kesPeriod: kesPeriod,
            sigma: sigma
        )
    }

    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        dict[.string(CodingKeys.hotVKey.rawValue)] = .bytes(hotVKey.payload)
        dict[.string(CodingKeys.sequenceNumber.rawValue)] = .uint(UInt(sequenceNumber))
        dict[.string(CodingKeys.kesPeriod.rawValue)] = .uint(UInt(kesPeriod))
        dict[.string(CodingKeys.sigma.rawValue)] = .bytes(sigma)
        return .orderedDict(dict)
    }

    // MARK: - Equatable

    public static func == (lhs: OperationalCertificate, rhs: OperationalCertificate) -> Bool {
        return lhs.hotVKey == rhs.hotVKey &&
            lhs.sequenceNumber == rhs.sequenceNumber &&
            lhs.kesPeriod == rhs.kesPeriod &&
            lhs.sigma == rhs.sigma
    }

    // MARK: - Hashable

    public func hash(into hasher: inout Hasher) {
        hasher.combine(hotVKey)
        hasher.combine(sequenceNumber)
        hasher.combine(kesPeriod)
        hasher.combine(sigma)
    }
}
