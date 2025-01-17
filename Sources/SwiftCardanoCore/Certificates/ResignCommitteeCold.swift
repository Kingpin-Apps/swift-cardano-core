import Foundation
import PotentCBOR

struct ResignCommitteeCold: CertificateSerializable, Codable {
    static var TYPE: String { "CertificateConway" }
    static var DESCRIPTION: String { "Constitutional Committee Hot Key Retirement Certificate" }
    
    public var code: Int { get { return 15 } }
    
    let committeeColdCredential: CommitteeColdCredential
    let anchor: Anchor?
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)
        
        guard code == 15 else {
            throw CardanoCoreError.deserializeError("Invalid ResignCommitteeCold type: \(code)")
        }
        
        committeeColdCredential = try container.decode(CommitteeColdCredential.self)
        anchor = try container.decodeIfPresent(Anchor.self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(code)
        try container.encode(committeeColdCredential)
        try container.encode(anchor)
    }
}

