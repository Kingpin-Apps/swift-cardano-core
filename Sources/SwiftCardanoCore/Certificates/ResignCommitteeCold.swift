import Foundation
import CBORCodable
import OrderedCollections

/// Constitutional committee resignation: `committee_resignation_cert = (15, committee_cold_credential, anchor / nil)`.
public struct ResignCommitteeCold: CertificateSerializable {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public var type: String { ResignCommitteeCold.TYPE }
    public var description: String { ResignCommitteeCold.DESCRIPTION }

    public static var TYPE: String { CertificateType.conway.rawValue }
    public static var DESCRIPTION: String { CertificateDescription.resignCommitteeCold.rawValue }
    public static var CODE: CertificateCode { .resignCommitteeCold }

    public let committeeColdCredential: CommitteeColdCredential
    public let anchor: Anchor?

    public enum CodingKeys: String, CodingKey {
        case committeeColdCredential
        case anchor
    }

    /// Creates the certificate.
    ///
    /// - Throws: When the certificate cannot be encoded for its payload.
    public init(committeeColdCredential: CommitteeColdCredential, anchor: Anchor? = nil) throws {
        self.committeeColdCredential = committeeColdCredential
        self.anchor = anchor
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
            anchor: try optionalAnchor(fields[1])
        )
    }

    public func toPrimitive() throws -> Primitive {
        return .list([
            Self.codePrimitive,
            try committeeColdCredential.toPrimitive(),
            try anchor?.toPrimitive() ?? .null
        ])
    }

    // MARK: - JSONSerializable

    public static func fromDict(_ dict: Primitive) throws -> ResignCommitteeCold {
        guard case let .orderedDict(entries) = dict else {
            throw CardanoCoreError.deserializeError("ResignCommitteeCold: expected a dict, got \(dict)")
        }
        return try ResignCommitteeCold(
            committeeColdCredential: try CommitteeColdCredential(from: try dictString(dict, CodingKeys.committeeColdCredential.rawValue, in: "ResignCommitteeCold")),
            anchor: try optionalAnchor(fromDict: entries[.string(CodingKeys.anchor.rawValue)])
        )
    }

    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        dict[.string(CodingKeys.committeeColdCredential.rawValue)] = .string(try committeeColdCredential.id())
        dict[.string(CodingKeys.anchor.rawValue)] = try optionalAnchorDict(anchor)
        return .orderedDict(dict)
    }
}
