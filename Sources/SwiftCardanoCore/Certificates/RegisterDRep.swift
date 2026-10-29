import Foundation
import CBORCodable
import OrderedCollections

/// DRep registration: `drep_registration_cert = (16, drep_credential, coin, anchor / nil)`.
public struct RegisterDRep: CertificateSerializable {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public var type: String { RegisterDRep.TYPE }
    public var description: String {
        switch drepCredential.credential {
            case .verificationKeyHash(_):
                return "DRep Key Registration Certificate"
            case .scriptHash(_):
                return "DRep Script Registration Certificate"
        }
    }

    public static var TYPE: String { CertificateType.conway.rawValue }
    public static var DESCRIPTION: String { CertificateDescription.registerDRep.rawValue }
    public static var CODE: CertificateCode { .registerDRep }

    public let drepCredential: DRepCredential
    public let coin: Coin
    public let anchor: Anchor?

    public enum CodingKeys: String, CodingKey {
        case drepCredential
        case coin
        case anchor
    }

    /// Creates the certificate.
    ///
    /// - Throws: When the certificate cannot be encoded for its payload.
    public init(drepCredential: DRepCredential, coin: Coin, anchor: Anchor? = nil) throws {
        self.drepCredential = drepCredential
        self.coin = coin
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
        let decoded = try CBORDecoder.ledger().decode(Self.self, from: payload)
        self = decoded
        self._payload = payload
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
    }

    // MARK: - CBORSerializable

    public init(from primitive: Primitive) throws {
        let fields = try Self.certificateFields(primitive, count: 4)
        try self.init(
            drepCredential: try DRepCredential(from: fields[0]),
            coin: try fields[1].integer("RegisterDRep coin", as: Coin.self),
            anchor: try optionalAnchor(fields[2])
        )
    }

    public func toPrimitive() throws -> Primitive {
        return .list([
            Self.codePrimitive,
            try drepCredential.toPrimitive(),
            .integer(coin),
            try anchor?.toPrimitive() ?? .null
        ])
    }

    // MARK: - JSONSerializable

    public static func fromDict(_ dict: Primitive) throws -> RegisterDRep {
        guard case let .orderedDict(entries) = dict else {
            throw CardanoCoreError.deserializeError("RegisterDRep: expected a dict, got \(dict)")
        }
        return try RegisterDRep(
            drepCredential: try DRepCredential(from: try dictString(dict, CodingKeys.drepCredential.rawValue, in: "RegisterDRep")),
            coin: try dictField(dict, CodingKeys.coin.rawValue, in: "RegisterDRep").integer("RegisterDRep coin", as: Coin.self),
            anchor: try optionalAnchor(fromDict: entries[.string(CodingKeys.anchor.rawValue)])
        )
    }

    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        dict[.string(CodingKeys.drepCredential.rawValue)] = .string(try drepCredential.id())
        dict[.string(CodingKeys.coin.rawValue)] = .integer(coin)
        dict[.string(CodingKeys.anchor.rawValue)] = try optionalAnchorDict(anchor)
        return .orderedDict(dict)
    }
}
