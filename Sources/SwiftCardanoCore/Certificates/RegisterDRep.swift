import Foundation
import PotentCBOR

/// DRep registration certificate
struct RegisterDRep: CertificateSerializable, Codable {
    var type: String { get { return RegisterDRep.TYPE } }
    var description: String {
        get {
            switch self.drepCredential.credential {
                case .verificationKeyHash(_):
                    return "DRep Key Registration Certificate"
                case .scriptHash(_):
                    return "DRep Script Registration Certificate"
            }
        }
    }

    static var TYPE: String { CertificateType.conway.rawValue }
    static var DESCRIPTION: String { CertificateDescription.registerDRep.rawValue }
    
    public var code: Int { get { return 16 } }
    
    let drepCredential: DRepCredential
    let coin: Coin
    let anchor: Anchor?
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)
        
        guard code == 16 else {
            throw CardanoCoreError.deserializeError("Invalid RegisterDRep type: \(code)")
        }
        
        drepCredential = try container.decode(DRepCredential.self)
        coin = try container.decode(Coin.self)
        anchor = try container.decodeIfPresent(Anchor.self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(code)
        try container.encode(drepCredential)
        try container.encode(coin)
        try container.encode(anchor)
    }
}
