import Foundation
import CBORCodable
import OrderedCollections

/// Constitutional committee hot key authorization: `committee_authorization_cert = (14, committee_cold_credential, committee_hot_credential)`.
public struct AuthCommitteeHot: CertificateSerializable {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public var type: String { AuthCommitteeHot.TYPE }
    public var description: String { AuthCommitteeHot.DESCRIPTION }

    public static var TYPE: String { CertificateType.conway.rawValue }
    public static var DESCRIPTION: String { CertificateDescription.authCommitteeHot.rawValue }
    public static var CODE: CertificateCode { .authCommitteeHot }

    public let committeeColdCredential: CommitteeColdCredential
    public let committeeHotCredential: CommitteeHotCredential

    public enum CodingKeys: String, CodingKey {
        case committeeColdCredential
        case committeeHotCredential
    }

    /// Creates the certificate.
    ///
    /// - Throws: When the certificate cannot be encoded for its payload.
    public init(committeeColdCredential: CommitteeColdCredential, committeeHotCredential: CommitteeHotCredential) throws {
        self.committeeColdCredential = committeeColdCredential
        self.committeeHotCredential = committeeHotCredential
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
        let fields = try Self.certificateFields(primitive, count: 3)
        try self.init(
            committeeColdCredential: try CommitteeColdCredential(from: fields[0]),
            committeeHotCredential: try CommitteeHotCredential(from: fields[1])
        )
    }

    public func toPrimitive() throws -> Primitive {
        return .list([
            Self.codePrimitive,
            try committeeColdCredential.toPrimitive(),
            try committeeHotCredential.toPrimitive()
        ])
    }

    // MARK: - JSONSerializable

    public static func fromDict(_ dict: Primitive) throws -> AuthCommitteeHot {
        return try AuthCommitteeHot(
            committeeColdCredential: try CommitteeColdCredential(from: try dictString(dict, CodingKeys.committeeColdCredential.rawValue, in: "AuthCommitteeHot")),
            committeeHotCredential: try CommitteeHotCredential(from: try dictString(dict, CodingKeys.committeeHotCredential.rawValue, in: "AuthCommitteeHot"))
        )
    }

    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        dict[.string(CodingKeys.committeeColdCredential.rawValue)] = .string(try committeeColdCredential.id())
        dict[.string(CodingKeys.committeeHotCredential.rawValue)] = .string(try committeeHotCredential.id())
        return .orderedDict(dict)
    }
}
