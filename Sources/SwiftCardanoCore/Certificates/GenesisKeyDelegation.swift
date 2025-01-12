import Foundation
import PotentCBOR

struct GenesisKeyDelegation: ArrayCBORSerializable {
    public var code: Int { get { return 5 } }
    
    let genesisHash: GenesisHash
    let genesisDelegateHash: GenesisDelegateHash
    let vrfKeyHash: VrfKeyHash
    
    static func fromPrimitive<T>(_ value: Any) throws -> T {
        var code: Int
        var genesisHash: GenesisHash
        var genesisDelegateHash: GenesisDelegateHash
        var vrfKeyHash: VrfKeyHash
        
        if let list = value as? [Any] {
            code = list[0] as! Int
            genesisHash = try GenesisHash.fromPrimitive(list[1] as! Data)
            genesisDelegateHash = try GenesisDelegateHash.fromPrimitive(list[2] as! Data)
            vrfKeyHash = try VrfKeyHash.fromPrimitive(list[3] as! Data)
        } else if let tuple = value as? (Any, Any, Any, Any) {
            code = tuple.0 as! Int
            genesisHash = try GenesisHash.fromPrimitive(tuple.1 as! Data)
            genesisDelegateHash = try GenesisDelegateHash.fromPrimitive(tuple.2 as! Data)
            vrfKeyHash = try VrfKeyHash.fromPrimitive(tuple.3 as! Data)
        } else {
            throw CardanoCoreError.deserializeError("Invalid GenesisKeyDelegation data: \(value)")
        }
        
        guard code == 5 else {
            throw CardanoCoreError.deserializeError("Invalid GenesisKeyDelegation type: \(code)")
        }
        
        return GenesisKeyDelegation(
            genesisHash: genesisHash,
            genesisDelegateHash: genesisDelegateHash,
            vrfKeyHash: vrfKeyHash
        ) as! T
    }
}
