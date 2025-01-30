import Foundation
import PotentCBOR

/// Stake Pool Registration Certificate
struct PoolRegistration: CertificateSerializable {
    var _payload: Data
    var _type: String
    var _description: String

    var type: String { get { return PoolRegistration.TYPE } }
    var description: String { get { return PoolRegistration.DESCRIPTION } }

    static var TYPE: String { CertificateType.shelley.rawValue }
    static var DESCRIPTION: String { CertificateDescription.poolRegistration.rawValue }
    static var CODE: CertificateCode { get { return .poolRegistration } }
    
    let poolParams: PoolParams
    
    /// Initialize a new PoolRegistration certificate
    /// - Parameter poolParams: The pool parameters
    init(poolParams: PoolParams) {
        self.poolParams = poolParams
        
        self._payload =  try! CBORSerialization.data(from:
                .array(
                    [
                        CBOR(integerLiteral: Self.CODE.rawValue),
                        try! CBOREncoder().encode(poolParams).toCBOR
                    ]
                )
        )
        self._type = Self.TYPE
        self._description = Self.DESCRIPTION
    }
    
    /// Initialize a new PoolRegistration certificate from a payload
    /// - Parameters:
    ///   - payload: The payload
    ///   - type: The type
    ///   - description: The description
    init(payload: Data, type: String?, description: String?) {
        self._payload = payload
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
        
        let cbor = try! CBORDecoder().decode(Self.self, from: payload)
        self.poolParams = cbor.poolParams
    }
    
    /// Initialize a new PoolRegistration certificate from CBOR
    /// - Parameter decoder: The decoder
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)
        
        guard case Self.CODE.rawValue = code else {
            throw CardanoCoreError.deserializeError("Invalid PoolRegistration type: \(code)")
        }
        
        let poolParams = try container.decode(PoolParams.self)
        
        self.init(poolParams: poolParams)
    }
    
    /// The encode function
    /// - Parameter encoder: The encoder
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(Self.CODE.rawValue)
        try container.encode(poolParams)
    }
}
