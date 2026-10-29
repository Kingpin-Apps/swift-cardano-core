import Foundation
import CBORCodable
import OrderedCollections

/// Stake address deregistration certificate: `account_unregistration_cert = (1, stake_credential)`.
public struct StakeDeregistration: CertificateSerializable {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public var type: String { StakeDeregistration.TYPE }
    public var description: String { StakeDeregistration.DESCRIPTION }

    public static var TYPE: String { CertificateType.shelley.rawValue }
    public static var DESCRIPTION: String { CertificateDescription.stakeDeregistration.rawValue }
    public static var CODE: CertificateCode { .stakeDeregistration }

    public let stakeCredential: StakeCredential

    public enum CodingKeys: String, CodingKey {
        case stakeCredential
    }

    /// Creates the certificate.
    ///
    /// - Throws: When the certificate cannot be encoded for its payload.
    public init(stakeCredential: StakeCredential) throws {
        self.stakeCredential = stakeCredential
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
        let fields = try Self.certificateFields(primitive, count: 2)
        try self.init(
            stakeCredential: try StakeCredential(from: fields[0])
        )
    }

    public func toPrimitive() throws -> Primitive {
        return .list([
            Self.codePrimitive,
            try stakeCredential.toPrimitive()
        ])
    }

    // MARK: - JSONSerializable

    public static func fromDict(_ dict: Primitive) throws -> StakeDeregistration {
        return try StakeDeregistration(
            stakeCredential: try StakeCredential.fromCertificateDict(try dictField(dict, CodingKeys.stakeCredential.rawValue, in: "StakeDeregistration"))
        )
    }

    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        dict[.string(CodingKeys.stakeCredential.rawValue)] = stakeCredential.certificateDict()
        return .orderedDict(dict)
    }
}
