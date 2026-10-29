import Foundation
import CBORCodable
import OrderedCollections

/// DRep update: `drep_update_cert = (18, drep_credential, anchor / nil)`.
public struct UpdateDRep: CertificateSerializable {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public var type: String { UpdateDRep.TYPE }
    public var description: String { UpdateDRep.DESCRIPTION }

    public static var TYPE: String { CertificateType.conway.rawValue }
    public static var DESCRIPTION: String { CertificateDescription.updateDRep.rawValue }
    public static var CODE: CertificateCode { .updateDRep }

    public let drepCredential: DRepCredential
    public let anchor: Anchor?

    public enum CodingKeys: String, CodingKey {
        case drepCredential
        case anchor
    }

    /// Creates the certificate.
    ///
    /// - Throws: When the certificate cannot be encoded for its payload.
    public init(drepCredential: DRepCredential, anchor: Anchor? = nil) throws {
        self.drepCredential = drepCredential
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
            drepCredential: try DRepCredential(from: fields[0]),
            anchor: try optionalAnchor(fields[1])
        )
    }

    public func toPrimitive() throws -> Primitive {
        return .list([
            Self.codePrimitive,
            try drepCredential.toPrimitive(),
            try anchor?.toPrimitive() ?? .null
        ])
    }

    // MARK: - JSONSerializable

    public static func fromDict(_ dict: Primitive) throws -> UpdateDRep {
        guard case let .orderedDict(entries) = dict else {
            throw CardanoCoreError.deserializeError("UpdateDRep: expected a dict, got \(dict)")
        }
        return try UpdateDRep(
            drepCredential: try DRepCredential(from: try dictString(dict, CodingKeys.drepCredential.rawValue, in: "UpdateDRep")),
            anchor: try optionalAnchor(fromDict: entries[.string(CodingKeys.anchor.rawValue)])
        )
    }

    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        dict[.string(CodingKeys.drepCredential.rawValue)] = .string(try drepCredential.id())
        dict[.string(CodingKeys.anchor.rawValue)] = try optionalAnchorDict(anchor)
        return .orderedDict(dict)
    }
}
