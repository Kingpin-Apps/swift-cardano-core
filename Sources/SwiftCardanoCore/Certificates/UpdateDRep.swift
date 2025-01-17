import Foundation
import PotentCBOR

struct UpdateDRep: CertificateSerializable, Codable {
    static var TYPE: String { "CertificateConway" }
    static var DESCRIPTION: String { "Update Certificate" }
    
    public var code: Int { get { return 18 } }
    
    let drepCredential: DRepCredential
    let anchor: Anchor?
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)
        
        guard code == 18 else {
            throw CardanoCoreError.deserializeError("Invalid UpdateDRep type: \(code)")
        }
        
        drepCredential = try container.decode(DRepCredential.self)
        anchor = try container.decode(Anchor.self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(code)
        try container.encode(drepCredential)
        try container.encode(anchor)
    }
}
