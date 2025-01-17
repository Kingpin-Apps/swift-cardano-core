import Foundation
import PotentCBOR


struct AuthCommitteeHot: CertificateSerializable, Codable {
    static var TYPE: String { "CertificateShelley" }
    static var DESCRIPTION: String { "Constitutional Committee Hot Key Registration Certificate" }
    
    public var code: Int { get { return 14 } }
    
    let committeeColdCredential: CommitteeColdCredential
    let committeeHotCredential: CommitteeHotCredential
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)
        
        guard code == 14 else {
            throw CardanoCoreError.deserializeError("Invalid AuthCommitteeHot type: \(code)")
        }
        
        committeeColdCredential = try container.decode(CommitteeColdCredential.self)
        committeeHotCredential = try container.decode(CommitteeHotCredential.self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(code)
        try container.encode(committeeColdCredential)
        try container.encode(committeeHotCredential)
    }
}
