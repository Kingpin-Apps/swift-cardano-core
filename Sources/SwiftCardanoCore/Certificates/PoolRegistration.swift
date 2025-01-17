import Foundation
import PotentCBOR

struct PoolRegistration: CertificateSerializable, Codable {
    static var TYPE: String { "CertificateShelley" }
    static var DESCRIPTION: String { "Stake Pool Registration Certificate" }
    
    public var code: Int { get { return 3 } }
    let poolParams: PoolParams
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)
        
        guard code == 3 else {
            throw CardanoCoreError.deserializeError("Invalid PoolRegistration type: \(code)")
        }
        
        let poolParams = try container.decode(PoolParams.self)
        
        self.poolParams = poolParams
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(code)
        try container.encode(poolParams)
    }
}
