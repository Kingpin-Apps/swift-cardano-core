import Foundation
import PotentCBOR

struct GenesisKeyDelegation: Codable {
    public var code: Int { get { return 5 } }
    
    let genesisHash: GenesisHash
    let genesisDelegateHash: GenesisDelegateHash
    let vrfKeyHash: VrfKeyHash
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)
        
        guard code == 5 else {
            throw CardanoCoreError.deserializeError("Invalid GenesisKeyDelegation type: \(code)")
        }
        
        genesisHash = try container.decode(GenesisHash.self)
        genesisDelegateHash = try container.decode(GenesisDelegateHash.self)
        vrfKeyHash = try container.decode(VrfKeyHash.self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(code)
        try container.encode(genesisHash)
        try container.encode(genesisDelegateHash)
        try container.encode(vrfKeyHash)
    }
}
