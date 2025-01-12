import Foundation
import CryptoKit
import PotentCBOR

/// Redeemer tag, which indicates the type of redeemer.
enum RedeemerTag: Int, CBORSerializable {
    case spend = 0
    case mint = 1
    case cert = 2
    case withdrawal = 3
    
    func toShallowPrimitive() throws -> Any {
        return self.rawValue
    }

    static func fromPrimitive<T>(_ value: Any) throws -> T {
        guard let value = value as? Int, let tag = RedeemerTag(rawValue: value) else {
            throw CardanoCoreError.valueError("Invalid RedeemerTag value")
        }
        return tag as! T
    }
}


class Redeemer: ArrayCBORSerializable {

    var tag: RedeemerTag?
    var index: Int = 0
    var data: Any
    var exUnits: ExecutionUnits?

    init(data: Any, exUnits: ExecutionUnits?) {
        self.data = data
        self.exUnits = exUnits
    }
    
    static func fromPrimitive<T>(_ value: Any) throws -> T {
        guard var values = value as? [Any], values.count == 4 else {
            throw CardanoCoreError.valueError("Invalid Redeemer values")
        }
        
        if case CBOR.tagged(_, _) = values[2] {
            values[2] = try RawPlutusData.fromPrimitive(values[2])
        }
        
        let redeemer: Redeemer = try Redeemer.fromPrimitive([values[2], values[3]])
        
        let tag: RedeemerTag = try RedeemerTag.fromPrimitive(values[0])
        let index = values[1] as! Int
        redeemer.tag = tag
        redeemer.index = index
        return redeemer as! T
    }

    func toCBOR() -> [Any] {
        return [tag?.rawValue ?? 0, index, data, exUnits?.toCBOR() ?? []]
    }
}
