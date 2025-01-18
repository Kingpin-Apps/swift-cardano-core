import Foundation
import PotentCBOR


/// Auth Committee Hot Key Registration Certificate
struct AuthCommitteeHot: CertificateSerializable, Codable, Hashable, Equatable {
    var type: String { get { return AuthCommitteeHot.TYPE } }
    var description: String { get { return AuthCommitteeHot.DESCRIPTION } }

    static var TYPE: String { CertificateType.conway.rawValue }
    static var DESCRIPTION: String { CertificateDescription.authCommitteeHot.rawValue }
    
    public var code: Int { get { return 14 } }
    
    let committeeColdCredential: CommitteeColdCredential
    let committeeHotCredential: CommitteeHotCredential
    
    init (committeeColdCredential: CommitteeColdCredential, committeeHotCredential: CommitteeHotCredential) {
        self.committeeColdCredential = committeeColdCredential
        self.committeeHotCredential = committeeHotCredential
    }
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)
        
        guard code == 14 else {
            throw CardanoCoreError.deserializeError("Invalid AuthCommitteeHot type: \(code)")
        }
        
        self.committeeColdCredential = try container.decode(CommitteeColdCredential.self)
        self.committeeHotCredential = try container.decode(CommitteeHotCredential.self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(code)
        try container.encode(committeeColdCredential)
        try container.encode(committeeHotCredential)
    }
}
