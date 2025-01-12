import Foundation

struct UTxO: ArrayCBORSerializable, CustomStringConvertible, Hashable {

    var input: TransactionInput
    var output: TransactionOutput
    
    static func fromPrimitive<T>(_ value: Any) throws -> T {
        <#code#>
    }

    static func == (lhs: UTxO, rhs: UTxO) -> Bool {
        <#code#>
    }

    var description: String {
        return "\(input) -> \(output)"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(input)
        hasher.combine(output)
    }
}
