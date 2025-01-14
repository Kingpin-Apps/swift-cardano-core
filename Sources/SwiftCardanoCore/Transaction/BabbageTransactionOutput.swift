import Foundation

struct BabbageTransactionOutput: MapCBORSerializable {
    var address: Address
    var amount: Value
    var datum: DatumOption?
    var scriptRef: ScriptRef?
    
    static func fromPrimitive<T>(_ value: Any) throws -> T {
        guard let dict = value as? [Int: Any] else {
            throw CardanoCoreError.valueError("Invalid BabbageTransactionOutput data: \(value)")
        }
        
        let address = try Address.fromPrimitive(data: dict[0] as! Data)
        let amount: Value = try Value.fromPrimitive(dict[1]!)
        let datum: DatumOption = try DatumOption.fromPrimitive(dict[2]!)
        let scriptRef: ScriptRef = try ScriptRef.fromPrimitive(dict[3]!)
        
        return BabbageTransactionOutput(
            address: address,
            amount: amount,
            datum: datum,
            scriptRef: scriptRef
        ) as! T
        
    }
    
    var script: ScriptType? {
        return scriptRef?.script.script
    }
}
