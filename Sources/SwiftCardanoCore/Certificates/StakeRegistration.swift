import Foundation
import PotentCBOR


/// Stake Address Registration Certificate
struct StakeRegistration: CertificateSerializable {
    var _payload: Data
    var _type: String
    var _description: String
    
    var type: String { get { return StakeRegistration.TYPE } }
    var description: String { get { return StakeRegistration.DESCRIPTION } }

    static var TYPE: String { CertificateType.shelley.rawValue }
    static var DESCRIPTION: String { CertificateDescription.stakeRegistration.rawValue }
    static var CODE: CertificateCode { get { return .stakeRegistration } }

    let stakeCredential: StakeCredential
    
    init(stakeCredential: StakeCredential) {
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
    init(payload: Data, type: String?, description: String?) {
        self._payload = payload
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
        
        let cbor = try! CBORDecoder().decode(Self.self, from: payload)
        
        self.stakeCredential = cbor.stakeCredential
    }

    /// Initialize StakeRegistration from CBOR
    /// - Parameter decoder: The decoder to use
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)
        
        guard case Self.CODE.rawValue = code else {
            throw CardanoCoreError.deserializeError("Invalid StakeRegistration type: \(code)")
        }
        
        let stakeCredential = try container.decode(StakeCredential.self)
        self.init(stakeCredential: stakeCredential)
    }
    
    /// Encode StakeRegistration to CBOR
    /// - Parameter encoder: The encoder to use
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(Self.CODE.rawValue)
        try container.encode(stakeCredential)
    }
}
