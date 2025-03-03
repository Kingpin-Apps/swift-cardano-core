import Foundation
import PotentCBOR

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
    
    /// Initialize a new `StakeDeregistration` certificate
    /// - Parameter decoder: The decoder
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)
        
        guard case Self.CODE.rawValue = code else {
            throw CardanoCoreError.deserializeError("Invalid StakeDeregistration type: \(code)")
        }
        
        let stakeCredential = try container.decode(StakeCredential.self)
        
        self.init(stakeCredential: stakeCredential)
    }
    
    /// Encode the StakeDeregistration certificate
    /// - Parameter encoder: The encoder
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(Self.CODE.rawValue)
        try container.encode(stakeCredential)
    }
}
