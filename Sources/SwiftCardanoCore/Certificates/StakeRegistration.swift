import Foundation
import PotentCBOR


/// Stake Address Registration Certificate
struct StakeRegistration: CertificateSerializable, Codable, Hashable, Equatable {
    var type: String { get { return StakeRegistration.TYPE } }
    var description: String { get { return StakeRegistration.DESCRIPTION } }

    static var TYPE: String { CertificateType.shelley.rawValue }
    static var DESCRIPTION: String { "Stake Address Registration Certificate" }

    public var code: Int { get { return 0 } }
    let stakeCredential: StakeCredential
    
    init(stakeCredential: StakeCredential) {
        self.stakeCredential = stakeCredential
    }
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)
        
        guard code == 0 else {
            throw CardanoCoreError.deserializeError("Invalid StakeRegistration type: \(code)")
        }
        
        stakeCredential = try container.decode(StakeCredential.self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(code)
        try container.encode(stakeCredential)
    }
}
