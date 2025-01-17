import Foundation
import PotentCBOR

struct StakeDeregistration: CertificateSerializable, Codable {
    static var TYPE: String { "CertificateShelley" }
    static var DESCRIPTION: String { "Stake Address Deregistration Certificate" }
    
    public var code: Int { get { return 1 } }
    let stakeCredential: StakeCredential
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)
        
        guard code == 1 else {
            throw CardanoCoreError.deserializeError("Invalid StakeDeregistration type: \(code)")
        }
        
        stakeCredential = try container.decode(StakeCredential.self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(code)
        try container.encode(stakeCredential)
    }
}
