import Foundation
import OrderedCollections
import PotentCBOR

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
/// Serialized as a CBOR array with 4 elements on-chain.
///
/// When serialized as a `NodeOperationalCertificate` text envelope (matching `cardano-cli`),
/// the CBOR payload is a 2-element array: `[opcert_body, cold_vkey]`.
public struct OperationalCertificate: TextEnvelopable, JSONSerializable, Sendable {

    // MARK: - PayloadSerializable Properties

    public var _payload: Data
    public var _type: String
    public var _description: String

    public static var TYPE: String { "NodeOperationalCertificate" }
    public static var DESCRIPTION: String { "" }

    /// Custom description for display (resolves protocol conflict).
    public var description: String { _description }

    // MARK: - Properties

    /// KES hot verification key (32 bytes)
    public var hotVKey: KESVerificationKey
    /// Sequence number
    public var sequenceNumber: UInt64
    /// KES period
    public var kesPeriod: UInt64
    /// Ed25519 signature (64 bytes)
    public var sigma: Data
    /// The pool's cold verification key (present when loaded from a text envelope).
    public var coldVerificationKey: StakePoolVerificationKey?

    public static let SIGMA_SIZE = 64

    enum CodingKeys: String, CodingKey {
        case hotVKey
        case sequenceNumber
        case kesPeriod
        case sigma
    }

    // MARK: - Initialization

    public init(
        hotVKey: KESVerificationKey,
        sequenceNumber: UInt64,
        kesPeriod: UInt64,
        sigma: Data,
        coldVerificationKey: StakePoolVerificationKey? = nil
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
        self.coldVerificationKey = coldVerificationKey
        self._type = Self.TYPE
        self._description = Self.DESCRIPTION

        // Compute CBOR payload
        self._payload = try Self.computePayload(
            hotVKey: hotVKey,
            sequenceNumber: sequenceNumber,
            kesPeriod: kesPeriod,
            sigma: sigma,
            coldVerificationKey: coldVerificationKey
        )
    }

    /// Creates an `OperationalCertificate` from a CBOR payload (text envelope format).
    /// - Parameters:
    ///   - payload: The CBOR-encoded payload.
    ///   - type: Optional type string (defaults to `TYPE`).
    ///   - description: Optional description string.
    /// - Throws: `CardanoCoreError.deserializeError` if the payload is invalid.
    public init(payload: Data, type: String?, description: String?) throws {
        let primitive = try CBORDecoder().decode(Primitive.self, from: payload)

        guard case let .list(outerElements) = primitive, outerElements.count == 2 else {
            throw CardanoCoreError.deserializeError(
                "Invalid NodeOperationalCertificate CBOR: expected array of 2 elements"
            )
        }

        // Parse the 4-element opcert body
        guard case let .list(certElements) = outerElements[0], certElements.count == 4 else {
            throw CardanoCoreError.deserializeError(
                "Invalid operational_cert body: expected array of 4 elements"
            )
        }

        self.hotVKey = try KESVerificationKey(from: certElements[0])

        switch certElements[1] {
        case .uint(let val): self.sequenceNumber = UInt64(val)
        case .int(let val): self.sequenceNumber = UInt64(val)
        default:
            throw CardanoCoreError.deserializeError(
                "Invalid OperationalCertificate sequence_number type"
            )
        }

        switch certElements[2] {
        case .uint(let val): self.kesPeriod = UInt64(val)
        case .int(let val): self.kesPeriod = UInt64(val)
        default:
            throw CardanoCoreError.deserializeError(
                "Invalid OperationalCertificate kes_period type"
            )
        }

        guard case let .bytes(sigma) = certElements[3] else {
            throw CardanoCoreError.deserializeError(
                "Invalid OperationalCertificate sigma: expected bytes"
            )
        }
        guard sigma.count == Self.SIGMA_SIZE else {
            throw CardanoCoreError.invalidArgument(
                "OperationalCertificate sigma must be \(Self.SIGMA_SIZE) bytes, got \(sigma.count)"
            )
        }
        self.sigma = sigma

        // Parse the cold verification key
        guard case let .bytes(vkeyBytes) = outerElements[1] else {
            throw CardanoCoreError.deserializeError(
                "Invalid NodeOperationalCertificate: expected bytes for cold vkey"
            )
        }
        self.coldVerificationKey = try StakePoolVerificationKey(payload: vkeyBytes)

        self._payload = payload
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
    }

    // MARK: - CBORSerializable

    /// Deserialize from a Primitive.
    ///
    /// Supports both the on-chain 4-element format and the text envelope 2-element format.
    public init(from primitive: Primitive) throws {
        guard case let .list(elements) = primitive else {
            throw CardanoCoreError.deserializeError(
                "Invalid OperationalCertificate primitive: expected list"
            )
        }

        if elements.count == 2, case .list = elements[0], case .bytes = elements[1] {
            // Text envelope format: [opcert_body_4_array, cold_vkey_bytes]
            let cborData = try CBOREncoder().encode(primitive)
            try self.init(payload: cborData, type: nil, description: nil)
            return
        }

        guard elements.count == 4 else {
            throw CardanoCoreError.deserializeError(
                "OperationalCertificate requires exactly 4 elements, got \(elements.count)"
            )
        }

        let hotVKey = try KESVerificationKey(from: elements[0])

        let sequenceNumber: UInt64
        switch elements[1] {
        case .uint(let val): sequenceNumber = UInt64(val)
        case .int(let val): sequenceNumber = UInt64(val)
        default:
            throw CardanoCoreError.deserializeError(
                "Invalid OperationalCertificate sequence_number type"
            )
        }

        let kesPeriod: UInt64
        switch elements[2] {
        case .uint(let val): kesPeriod = UInt64(val)
        case .int(let val): kesPeriod = UInt64(val)
        default:
            throw CardanoCoreError.deserializeError(
                "Invalid OperationalCertificate kes_period type"
            )
        }

        guard case let .bytes(sigma) = elements[3] else {
            throw CardanoCoreError.deserializeError(
                "Invalid OperationalCertificate sigma: expected bytes"
            )
        }

        try self.init(
            hotVKey: hotVKey,
            sequenceNumber: sequenceNumber,
            kesPeriod: kesPeriod,
            sigma: sigma
        )
    }

    /// Serialize to the on-chain 4-element CBOR array.
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

    // MARK: - Issue Operational Certificate

    /// Issues a new operational certificate, mirroring `cardano-cli node issue-op-cert`.
    ///
    /// This constructs the certificate body `[kes_vkey, sequence_number, kes_period]`,
    /// signs it with the cold signing key to produce the Ed25519 sigma, and increments
    /// the issue counter.
    ///
    /// - Parameters:
    ///   - kesVerificationKey: The hot KES verification key for the node.
    ///   - coldSigningKey: The pool's cold signing key (Ed25519) used to sign the certificate body.
    ///   - operationalCertificateIssueCounter: The issue counter tracking the sequence number.
    ///     Will be incremented after successful issuance.
    ///   - kesPeriod: The KES period at which the certificate becomes valid.
    /// - Returns: The issued `OperationalCertificate` with the cold verification key set.
    /// - Throws: If CBOR encoding or signing fails.
    public static func issue(
        kesVerificationKey: KESVerificationKey,
        coldSigningKey: StakePoolSigningKey,
        operationalCertificateIssueCounter: inout OperationalCertificateIssueCounter,
        kesPeriod: UInt64
    ) throws -> OperationalCertificate {
        let sequenceNumber = UInt64(operationalCertificateIssueCounter.counterValue)

        // Construct the certificate body to sign: [kes_vkey, sequence_number, kes_period]
        let certBody: Primitive = .list([
            .bytes(kesVerificationKey.payload),
            .uint(UInt(sequenceNumber)),
            .uint(UInt(kesPeriod))
        ])
        let certBodyBytes = try CBOREncoder().encode(certBody)

        // Sign the CBOR-encoded body with the cold signing key
        let sigma = try coldSigningKey.sign(data: certBodyBytes)

        // Derive the cold verification key
        let coldVerificationKey: StakePoolVerificationKey = try coldSigningKey.toVerificationKey()

        // Build the operational certificate
        let cert = try OperationalCertificate(
            hotVKey: kesVerificationKey,
            sequenceNumber: sequenceNumber,
            kesPeriod: kesPeriod,
            sigma: sigma,
            coldVerificationKey: coldVerificationKey
        )

        // Increment the counter after successful issuance
        try operationalCertificateIssueCounter.increment()

        return cert
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

    // MARK: - Private Helpers

    /// Computes the CBOR payload for the text envelope format.
    private static func computePayload(
        hotVKey: KESVerificationKey,
        sequenceNumber: UInt64,
        kesPeriod: UInt64,
        sigma: Data,
        coldVerificationKey: StakePoolVerificationKey?
    ) throws -> Data {
        let opcertBody: Primitive = .list([
            .bytes(hotVKey.payload),
            .uint(UInt(sequenceNumber)),
            .uint(UInt(kesPeriod)),
            .bytes(sigma)
        ])

        let envelopePrimitive: Primitive
        if let coldVKey = coldVerificationKey {
            envelopePrimitive = .list([opcertBody, .bytes(coldVKey.payload)])
        } else {
            envelopePrimitive = opcertBody
        }

        return try CBOREncoder().encode(envelopePrimitive)
    }
}
