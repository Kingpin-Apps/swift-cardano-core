import Foundation
import PotentCBOR


struct UnregisterDRep: CertificateSerializable, Codable {
    var type: String { get { return UnregisterDRep.TYPE } }
    var description: String {
        get {
            switch self.drepCredential.credential {
                case .verificationKeyHash(_):
                    return "DRep Key Retirement Certificate"
                case .scriptHash(_):
                    return "DRep Script Retirement Certificate"
            }
        }
    }

    static var TYPE: String { CertificateType.conway.rawValue }
    static var DESCRIPTION: String { "DRep Retirement Certificate" }
    
    public var code: Int { get { return 17 } }
    
    let drepCredential: DRepCredential
    let coin: Coin
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)
        
        guard code == 17 else {
            throw CardanoCoreError.deserializeError("Invalid UnregisterDRep type: \(code)")
        }
        
        drepCredential = try container.decode(DRepCredential.self)
        coin = try container.decode(Coin.self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(code)
        try container.encode(drepCredential)
        try container.encode(coin)
    }
}
