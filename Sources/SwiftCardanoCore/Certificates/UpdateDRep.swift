import Foundation
import PotentCBOR

struct UpdateDRep: CertificateSerializable, Codable {
    var type: String { get { return UpdateDRep.TYPE } }
    var description: String {
        get {
            switch self.drepCredential.credential {
                case .verificationKeyHash(_):
                    return "DRep Key Update Certificate"
                case .scriptHash(_):
                    return "DRep Script Update Certificate"
            }
        }
    }

    static var TYPE: String { CertificateType.conway.rawValue }
    static var DESCRIPTION: String { CertificateDescription.updateDRep.rawValue }
    
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
