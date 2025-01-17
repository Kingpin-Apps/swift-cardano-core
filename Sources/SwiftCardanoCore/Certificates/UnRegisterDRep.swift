import Foundation
import PotentCBOR


struct UnRegisterDRep: CertificateSerializable, Codable {
    static var TYPE: String { "CertificateConway" }
    static var DESCRIPTION: String { "Retirement Certificate" }
    
    public var code: Int { get { return 17 } }
    
    let drepCredential: DRepCredential
    let coin: Coin
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)
        
        guard code == 17 else {
            throw CardanoCoreError.deserializeError("Invalid UnRegisterDRep type: \(code)")
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
