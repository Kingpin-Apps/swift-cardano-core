import Foundation

struct UTxO: ArrayCBORSerializable, CustomStringConvertible, Hashable {

    var input: TransactionInput
    var output: TransactionOutput
    
    static func fromPrimitive<T>(_ value: Any) throws -> T {
        var input:  [Any]
        var output:  [Any]
        
        if let list = value as? [Any] {
            input = list[0] as! [Any]
            output = list[1] as! [Any]
        } else if let tuple = value as? (Any, Any, Any, Any) {
            input = tuple.0 as! [Any]
            output = tuple.1 as! [Any]
        } else {
            throw CardanoCoreError.deserializeError("Invalid UTxO data: \(value)")
        }
        
        return UTxO(
            input: try TransactionInput.fromPrimitive(input),
            output: try TransactionOutput.fromPrimitive(output)
        ) as! T
    }

    static func == (lhs: UTxO, rhs: UTxO) -> Bool {
        return lhs.input == rhs.input && lhs.output == rhs.output
    }

    var description: String {
        return "\(input) -> \(output)"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(input)
        hasher.combine(output)
    }
}
