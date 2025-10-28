import Foundation
import OrderedCollections
import PotentCBOR

public struct UpdateDRep: CertificateSerializable {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public var type: String { return UpdateDRep.TYPE }
    public var description: String { return UpdateDRep.DESCRIPTION }

    public static var TYPE: String { CertificateType.conway.rawValue }
    public static var DESCRIPTION: String { CertificateDescription.updateDRep.rawValue }
    public static var CODE: CertificateCode { return .updateDRep }

    public let drepCredential: DRepCredential
    public let anchor: Anchor?

    public enum CodingKeys: String, CodingKey {
        case drepCredential
        case anchor
    }

    /// Initialize a new `UpdateDRep` certificate
    /// - Parameters:
    ///  - drepCredential: The DRep credential
    ///  - anchor: The anchor
    public init(drepCredential: DRepCredential, anchor: Anchor? = nil) {
        self.drepCredential = drepCredential
        self.anchor = anchor

        self._payload = try! CBORSerialization.data(
            from:
                .array(
                    [
                        CBOR(integerLiteral: Self.CODE.rawValue),
                        try! CBOREncoder().encode(drepCredential).toCBOR,
                        try! CBOREncoder().encode(anchor).toCBOR,
                    ]
                )
        )
        self._type = Self.TYPE
        self._description = Self.DESCRIPTION
    }

    /// Initialize a new `UpdateDRep` certificate from its Text Envelope representation
    /// - Parameters:
    ///  - payload: The CBOR representation of the certificate
    ///  - type: The type of the certificate
    ///  - description: The description of the certificate
    public init(payload: Data, type: String?, description: String?) {
        self._payload = payload
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION

        let cbor = try! CBORDecoder().decode(UpdateDRep.self, from: payload)

        self.drepCredential = cbor.drepCredential
        self.anchor = cbor.anchor
    }
    
    // MARK: - CBORSerializable

    public init(from primitive: Primitive) throws {
        guard case .list(let primitive) = primitive,
            primitive.count == 3,
            case .uint(let code) = primitive[0],
            code == Self.CODE.rawValue
        else {
            throw CardanoCoreError.deserializeError("Invalid UpdateDRep type")
        }

        let drepCredential = try DRepCredential(from: primitive[1])
        let anchor = try? Anchor(from: primitive[2])

        self.init(drepCredential: drepCredential, anchor: anchor)
    }

    public func toPrimitive() throws -> Primitive {
        return .list([
            .uint(UInt(Self.CODE.rawValue)),
            try drepCredential.toPrimitive(),
            try anchor?.toPrimitive() ?? .null,
        ])
    }

    // MARK: - JSONSerializable

    public static func fromDict(_ dict: Primitive) throws
        -> UpdateDRep
    {
        guard case let .orderedDict(dictValue) = dict,
              case .string(let drepCredentialId) = dictValue[.string(CodingKeys.drepCredential.rawValue)]
        else {
            throw CardanoCoreError.deserializeError(
                "Missing or invalid drepCredential in UpdateDRep")
        }

        let drepCredential = try DRepCredential(from: drepCredentialId)

        var anchor: Anchor? = nil
        if case .orderedDict(let anchorPrimitive) = dictValue[.string(CodingKeys.anchor.rawValue)] {
            anchor = try Anchor.fromDict(.orderedDict(anchorPrimitive))
        }

        return UpdateDRep(drepCredential: drepCredential, anchor: anchor)
    }

    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()

        dict[.string(CodingKeys.drepCredential.rawValue)] = .string(try drepCredential.id())

        if let anchor = anchor {
            dict[.string(CodingKeys.anchor.rawValue)] = try anchor.toDict()
        }

        return .orderedDict(dict)
    }
}
