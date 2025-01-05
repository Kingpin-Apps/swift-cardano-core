import Foundation

/// Network ID
enum Network: Int, CBORSerializable {
    case testnet = 0
    case mainnet = 1
    
    func toPrimitive() -> Int {
        return self.rawValue
    }
    
    static func fromPrimitive(_ value: Int) throws -> Network {
        guard let network = Network(rawValue: value) else {
            throw CardanoException.valueError("Invalid network value")
        }
        return network
    }
}
