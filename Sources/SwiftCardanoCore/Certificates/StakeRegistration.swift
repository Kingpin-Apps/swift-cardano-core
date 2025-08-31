import Foundation
import PotentCBOR


/// Stake Address Registration Certificate
public struct StakeRegistration: CertificateSerializable {
    public var _payload: Data
    public var _type: String
    public var _description: String
    
    public var type: String { get { return StakeRegistration.TYPE } }
    public var description: String { get { return StakeRegistration.DESCRIPTION } }

    public static var TYPE: String { CertificateType.shelley.rawValue }
    public static var DESCRIPTION: String { CertificateDescription.stakeRegistration.rawValue }
    public static var CODE: CertificateCode { get { return .stakeRegistration } }

    public let stakeCredential: StakeCredential
    
    public init(stakeCredential: StakeCredential) {
        self.stakeCredential = stakeCredential
        
        self._payload =  try! CBORSerialization.data(from:
                .array(
                    [
                        CBOR(integerLiteral: Self.CODE.rawValue),
                        try! CBOREncoder().encode(stakeCredential).toCBOR,
                    ]
                )
        )
        self._type = Self.TYPE
        self._description = Self.DESCRIPTION
    }
    
    /// Initialize StakeRegistration from payload, type, and description
    /// - Parameters:
    ///   - payload: The payload of the certificate
    ///   - type: The type of the certificate
    ///   - description: The description of the certificate
    public init(payload: Data, type: String?, description: String?) {
        self._payload = payload
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
        
        let cbor = try! CBORDecoder().decode(Self.self, from: payload)
        
        self.stakeCredential = cbor.stakeCredential
    }
    
    public init(from primitive: Primitive) throws {
        guard case let .list(list) = primitive,
              list.count == 2 else {
            throw CardanoCoreError.deserializeError("Invalid StakeRegistration type")
        }
        
        guard case .int(let code) = list[0],
              code == Self.CODE.rawValue else {
            throw CardanoCoreError.deserializeError("Invalid StakeRegistration type")
        }
            
        let stakeCredential = try StakeCredential(from: list[1])
        self.init(stakeCredential: stakeCredential)

    }
    
    public func toPrimitive() throws -> Primitive {
        return .list([
            .int(Int(Self.CODE.rawValue)),
            try stakeCredential.toPrimitive()
        ])
    }
}
