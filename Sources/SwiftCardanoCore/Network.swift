import Foundation

/// Network ID
enum Network: Int, CBORSerializable {
    case testnet = 0
    case mainnet = 1
    
    func toShallowPrimitive() -> Any {
        return self.rawValue as Int
    }
    
    static func fromPrimitive<T>(_ value: Any) throws -> T {
        let network: Network?
        if let value = value as? Int {
            network = Network(rawValue: value)
        } else if let value = value as? UInt64 {
            let value = Int(value)
            network = Network(rawValue: value)
        } else {
            throw CardanoCoreError.valueError("Invalid value type for Network: \(value)")
        }
        
        guard network != nil else {
            throw CardanoCoreError.valueError("Invalid network value: \(value)")
        }
        return network as! T
    }
}
