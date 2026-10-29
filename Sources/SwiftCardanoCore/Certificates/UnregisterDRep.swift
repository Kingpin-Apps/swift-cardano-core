import Foundation
import CBORCodable
import OrderedCollections

/// DRep retirement: `drep_unregistration_cert = (17, drep_credential, coin)`.
public struct UnregisterDRep: CertificateSerializable {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public var type: String { UnregisterDRep.TYPE }
    public var description: String { UnregisterDRep.DESCRIPTION }

    public static var TYPE: String { CertificateType.conway.rawValue }
    public static var DESCRIPTION: String { CertificateDescription.unRegisterDRep.rawValue }
    public static var CODE: CertificateCode { .unRegisterDRep }

    public let drepCredential: DRepCredential
    public let coin: Coin

    public enum CodingKeys: String, CodingKey {
        case drepCredential
        case coin
    }

    /// Creates the certificate.
    ///
    /// - Throws: When the certificate cannot be encoded for its payload.
    public init(drepCredential: DRepCredential, coin: Coin) throws {
        self.drepCredential = drepCredential
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
        let fields = try Self.certificateFields(primitive, count: 3)
        try self.init(
            drepCredential: try DRepCredential(from: fields[0]),
            coin: try fields[1].integer("UnregisterDRep coin", as: Coin.self)
        )
    }

    public func toPrimitive() throws -> Primitive {
        return .list([
            Self.codePrimitive,
            try drepCredential.toPrimitive(),
            .integer(coin)
        ])
    }

    // MARK: - JSONSerializable

    public static func fromDict(_ dict: Primitive) throws -> UnregisterDRep {
        return try UnregisterDRep(
            drepCredential: try DRepCredential(from: try dictString(dict, CodingKeys.drepCredential.rawValue, in: "UnregisterDRep")),
            coin: try dictField(dict, CodingKeys.coin.rawValue, in: "UnregisterDRep").integer("UnregisterDRep coin", as: Coin.self)
        )
    }

    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        dict[.string(CodingKeys.drepCredential.rawValue)] = .string(try drepCredential.id())
        dict[.string(CodingKeys.coin.rawValue)] = .integer(coin)
        return .orderedDict(dict)
    }
}
