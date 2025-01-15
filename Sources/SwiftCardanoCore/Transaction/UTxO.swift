import Foundation

struct UTxO: Codable, CustomStringConvertible, Hashable {

    var input: TransactionInput
    var output: TransactionOutput
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        input = try container.decode(TransactionInput.self)
        output = try container.decode(TransactionOutput.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(input)
        try container.encode(output)
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
