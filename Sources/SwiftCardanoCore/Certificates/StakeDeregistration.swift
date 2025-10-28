import Foundation
import PotentCBOR
import OrderedCollections

/// Stake Address Deregistration Certificate
public struct StakeDeregistration: CertificateSerializable {
    public var _payload: Data
    public var _type: String
    public var _description: String
    
    public var type: String { get { return StakeDeregistration.TYPE } }
    public var description: String { get { return StakeDeregistration.DESCRIPTION } }

    public static var TYPE: String { CertificateType.shelley.rawValue }
    public static var DESCRIPTION: String { CertificateDescription.stakeDeregistration.rawValue }
    public static var CODE: CertificateCode { get { return .stakeDeregistration } }
    
    public let stakeCredential: StakeCredential
    
    public enum CodingKeys: String, CodingKey {
        case stakeCredential
    }
    
    /// Initialize StakeDeregistration from stake credential
    /// - Parameters:
    ///  - stakeCredential: The stake credential
    public init(stakeCredential: StakeCredential) {
        self.stakeCredential = stakeCredential
        
        self._payload =  try! CBORSerialization.data(from:
                .array(
                    [
                        CBOR(integerLiteral: Self.CODE.rawValue),
                        try! CBOREncoder().encode(stakeCredential).toCBOR
                    ]
                )
        )
        self._type = Self.TYPE
        self._description = Self.DESCRIPTION
    }
    
    /// Initialize StakeDelegation certificate from payload, type, and description
    /// - Parameters:
    ///   - payload: The payload of the certificate
    ///   - type: The type of the certificate
    ///   - description: The description of the certificate
    public init(payload: Data, type: String?, description: String?) {
        self._payload = payload
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
        
        let cbor = try! CBORDecoder().decode(StakeDeregistration.self, from: payload)
        
        self.stakeCredential = cbor.stakeCredential
    }
    
    // MARK: - CBORSerializable
    
    public init(from primitive: Primitive) throws {
        guard case let .list(primitive) = primitive,
              primitive.count == 2,
              case let .uint(code) = primitive[0],
              code == Self.CODE.rawValue else {
            throw CardanoCoreError.deserializeError("Invalid StakeDeregistration type")
        }
        
        let stakeCredential = try StakeCredential(from: primitive[1])
        self.init(stakeCredential: stakeCredential)
    }
    
    public func toPrimitive() throws -> Primitive {
        return .list([
            .uint(UInt(Self.CODE.rawValue)),
            try stakeCredential.toPrimitive()
        ])
    }
    
    // MARK: - JSONSerializable
    
    public static func fromDict(_ dict: Primitive) throws -> StakeDeregistration {
        guard case let .orderedDict(orderedDict) = dict else {
            throw CardanoCoreError.deserializeError("Invalid StakeDeregistration dict format")
        }
        guard let stakeCredentialPrimitive = orderedDict[.string(CodingKeys.stakeCredential.rawValue)],
              case let .string(stakeCredentialHex) = stakeCredentialPrimitive else {
            throw CardanoCoreError.deserializeError("Invalid stakeCredential in StakeDeregistration dict")
        }
        
        let stakeCredentialData = Data(hex: stakeCredentialHex)
        let stakeCredential = try StakeCredential(from: .bytes(stakeCredentialData))
        
        return StakeDeregistration(stakeCredential: stakeCredential)
    }

    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        dict[.string(CodingKeys.stakeCredential.rawValue)] = .string(stakeCredential.credential.payload.toHex)
        return .orderedDict(dict)
    }
}
