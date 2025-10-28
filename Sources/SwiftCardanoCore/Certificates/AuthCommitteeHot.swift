import Foundation
import PotentCBOR
import OrderedCollections


/// Auth Committee Hot Key Registration Certificate
public struct AuthCommitteeHot: CertificateSerializable {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public var type: String { get { return AuthCommitteeHot.TYPE } }
    public var description: String { get { return AuthCommitteeHot.DESCRIPTION } }

    public static var TYPE: String { CertificateType.conway.rawValue }
    public static var DESCRIPTION: String { CertificateDescription.authCommitteeHot.rawValue }
    public static var CODE: CertificateCode { get { return .authCommitteeHot } }
    
    public let committeeColdCredential: CommitteeColdCredential
    public let committeeHotCredential: CommitteeHotCredential
    
    public enum CodingKeys: String, CodingKey {
        case committeeColdCredential
        case committeeHotCredential
    }
    
    /// Initialize AuthCommitteeHot from committeeColdCredential and committeeHotCredential
    /// - Parameters:
    ///   - committeeColdCredential: The cold key credential of the committee
    ///   - committeeHotCredential: The hot key credential of the committee
    public init(committeeColdCredential: CommitteeColdCredential,
         committeeHotCredential: CommitteeHotCredential) {
        self.committeeColdCredential = committeeColdCredential
        self.committeeHotCredential = committeeHotCredential
        
        self._payload =  try! CBORSerialization.data(from:
                .array(
                    [
                        CBOR(integerLiteral: Self.CODE.rawValue),
                        try! CBOREncoder().encode(committeeColdCredential).toCBOR,
                        try! CBOREncoder().encode(committeeHotCredential).toCBOR
                    ]
                )
        )
        self._type = Self.TYPE
        self._description = Self.DESCRIPTION
    }
    
    /// Initialize AuthCommitteeHot certificate from payload, type, and description
    /// - Parameters:
    ///   - payload: The payload of the certificate
    ///   - type: The type of the certificate
    ///   - description: The description of the certificate
    public init(payload: Data, type: String?, description: String?) {
        self._payload = payload
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
        
        let cbor = try! CBORDecoder().decode(AuthCommitteeHot.self, from: payload)
        
        self.committeeColdCredential = cbor.committeeColdCredential
        self.committeeHotCredential = cbor.committeeHotCredential
    }
    
    // MARK: - CBORSerializable
    
    public init(from primitive: Primitive) throws {
        guard case let .list(primitive) = primitive,
                primitive.count == 3,
              case let .uint(code) = primitive[0],
              code == Self.CODE.rawValue else {
            throw CardanoCoreError.deserializeError("Invalid AuthCommitteeHot type")
        }
        let committeeColdCredential = try CommitteeColdCredential(from: primitive[1])
        let committeeHotCredential = try CommitteeHotCredential(from: primitive[2])
        self.init(
            committeeColdCredential: committeeColdCredential,
            committeeHotCredential: committeeHotCredential
        )
    }

    public func toPrimitive() throws -> Primitive {
        return .list([
            .uint(UInt(Self.CODE.rawValue)),
            try committeeColdCredential.toPrimitive(),
            try committeeHotCredential.toPrimitive()
        ])
    }
    
    // MARK: - JSONSerializable

    public static func fromDict(_ dict: Primitive) throws -> AuthCommitteeHot {
        guard case let .orderedDict(dictValue) = dict,
              let committeeColdCredentialPrimitive = dictValue[.string(CodingKeys.committeeColdCredential.rawValue)],
              let committeeHotCredentialPrimitive = dictValue[.string(CodingKeys.committeeHotCredential.rawValue)] else {
            throw CardanoCoreError.deserializeError("Missing keys in AuthCommitteeHot dictionary")
        }
        
        guard case let .string(committeeColdCredentialId) = committeeColdCredentialPrimitive,
              case let .string(committeeHotCredentialId) = committeeHotCredentialPrimitive else {
            throw CardanoCoreError.deserializeError("Invalid types for AuthCommitteeHot credentials")
        }
        
        return AuthCommitteeHot(
            committeeColdCredential: try CommitteeColdCredential(from: committeeColdCredentialId),
            committeeHotCredential: try CommitteeHotCredential(from: committeeHotCredentialId)
        )
    }
    
    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        dict[.string(CodingKeys.committeeColdCredential.rawValue)] =
            .string(try committeeColdCredential.id())
        dict[.string(CodingKeys.committeeHotCredential.rawValue)] =
            .string(try committeeHotCredential.id())
        return .orderedDict(dict)
    }

}
