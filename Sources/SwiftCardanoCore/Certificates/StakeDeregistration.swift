import Foundation
import PotentCBOR

/// Stake Address Deregistration Certificate
struct StakeDeregistration: CertificateSerializable, Codable {
    var type: String { get { return StakeDeregistration.TYPE } }
    var description: String { get { return StakeDeregistration.DESCRIPTION } }

    static var TYPE: String { CertificateType.shelley.rawValue }
    static var DESCRIPTION: String { CertificateDescription.stakeDeregistration.rawValue }
    
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
