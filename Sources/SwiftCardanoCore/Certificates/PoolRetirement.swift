import Foundation
import PotentCBOR

/// Stake Pool Retirement Certificate
struct PoolRetirement: CertificateSerializable, Codable {
    var type: String { get { return PoolRetirement.TYPE } }
    var description: String { get { return PoolRetirement.DESCRIPTION } }

    static var TYPE: String { CertificateType.shelley.rawValue }
    static var DESCRIPTION: String { "Stake Pool Retirement Certificate" }
    
    public var code: Int { get { return 4 } }
    
    let poolKeyHash: PoolKeyHash
    let epoch: Int
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)
        
        guard code == 4 else {
            throw CardanoCoreError.deserializeError("Invalid PoolRetirement type: \(code)")
        }
        
        let poolKeyHash = try container.decode(PoolKeyHash.self)
        let epoch = try container.decode(Int.self)
        
        self.poolKeyHash = poolKeyHash
        self.epoch = epoch
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(code)
        try container.encode(poolKeyHash)
        try container.encode(epoch)
    }
}
