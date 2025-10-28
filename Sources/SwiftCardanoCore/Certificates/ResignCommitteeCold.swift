import Foundation
import PotentCBOR
import OrderedCollections

/// Resign Committee Cold certificate
public struct ResignCommitteeCold: CertificateSerializable {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public var type: String { get { return ResignCommitteeCold.TYPE } }
    public var description: String { get { return ResignCommitteeCold.DESCRIPTION } }

    public static var TYPE: String { CertificateType.conway.rawValue }
    public static var DESCRIPTION: String { CertificateDescription.resignCommitteeCold.rawValue }
    public static var CODE: CertificateCode { get { return .resignCommitteeCold } }
    
    public let committeeColdCredential: CommitteeColdCredential
    public let anchor: Anchor?
    
    public enum CodingKeys: String, CodingKey {
        case committeeColdCredential
        case anchor
    }
    
    /// Initialize a new `ResignCommitteeCold` certificate
    /// - Parameters:
    ///   - committeeColdCredential: The committee cold credential
    ///   - anchor: The anchor
    public init(committeeColdCredential: CommitteeColdCredential, anchor: Anchor? = nil) {
        self.committeeColdCredential = committeeColdCredential
        self.anchor = anchor
        
        self._payload =  try! CBORSerialization.data(from:
                .array(
                    [
                        CBOR(integerLiteral: Self.CODE.rawValue),
                        try! CBOREncoder().encode(committeeColdCredential).toCBOR,
                        try! CBOREncoder().encode(anchor).toCBOR
                    ]
                )
        )
        self._type = Self.TYPE
        self._description = Self.DESCRIPTION
    }
    
    /// Initialize ResignCommitteeCold certificate from payload, type, and description
    /// - Parameters:
    ///   - payload: The payload of the certificate
    ///   - type: The type of the certificate
    ///   - description: The description of the certificate
    public init(payload: Data, type: String?, description: String?) {
        self._payload = payload
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
        
        let cbor = try! CBORDecoder().decode(ResignCommitteeCold.self, from: payload)
        
        self.committeeColdCredential = cbor.committeeColdCredential
        self.anchor = cbor.anchor
    }
    
    // MARK: - CBORSerializable
    
    public init(from primitive: Primitive) throws {
        guard case let .list(primitive) = primitive,
              primitive.count == 3,
              case let .uint(code) = primitive[0],
              code == Self.CODE.rawValue else {
            throw CardanoCoreError.deserializeError("Invalid ResignCommitteeCold type")
        }
        
        let committeeColdCredential = try CommitteeColdCredential(from: primitive[1])
        let anchor = try? Anchor(from: primitive[2])
        
        self.init(committeeColdCredential: committeeColdCredential, anchor: anchor)
    }
    
    public func toPrimitive() throws -> Primitive {
        return .list([
            .uint(UInt(Self.CODE.rawValue)),
            try committeeColdCredential.toPrimitive(),
            try anchor?.toPrimitive() ?? .null
        ])
    }
    
    // MARK: - JSONSerializable
    
    public static func fromDict(_ dict: Primitive) throws -> ResignCommitteeCold {
        guard case let .orderedDict(dictValue) = dict,
              case let .string(committeeColdCredentialId) = dictValue[.string(CodingKeys.committeeColdCredential.rawValue)] else {
            throw CardanoCoreError.deserializeError("Missing or invalid committeeColdCredential in ResignCommitteeCold")
        }
        
        let committeeColdCredential = try CommitteeColdCredential(
            from: committeeColdCredentialId
        )
        
        var anchor: Anchor? = nil
        if case let .orderedDict(anchorPrimitive) = dictValue[.string(CodingKeys.anchor.rawValue)] {
            anchor = try Anchor.fromDict(.orderedDict(anchorPrimitive))
        }
        
        return ResignCommitteeCold(committeeColdCredential: committeeColdCredential, anchor: anchor)
    }
    
    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        
        dict[.string(CodingKeys.committeeColdCredential.rawValue)] = .string(try committeeColdCredential.id())
        
        if let anchor = anchor {
            dict[.string(CodingKeys.anchor.rawValue)] = try anchor.toDict()
        }
        
        return .orderedDict(dict)
    }

}

