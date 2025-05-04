import Foundation

public struct UTxO: Codable, CustomStringConvertible, Hashable {

    public var input: TransactionInput
    public var output: TransactionOutput
    
    public init(input: TransactionInput, output: TransactionOutput) {
        self.input = input
        self.output = output
    }
    
    public init(from
                inputPrimitives: (String, UInt16),
                outputPrimitives: (String, Int, Datum?, ScriptType?, Bool?)) throws {
        input = try TransactionInput(from: inputPrimitives.0, index: inputPrimitives.1)
        output = try TransactionOutput(from: outputPrimitives.0,
                                   amount: outputPrimitives.1,
                                   datum: outputPrimitives.2,
                                   script: outputPrimitives.3,
                                   postAlonzo: outputPrimitives.4 ?? true)
    }
    
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        input = try container.decode(TransactionInput.self)
        output = try container.decode(TransactionOutput.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(input)
        try container.encode(output)
    }
    
    public init(from primitive: Primitive) throws {
        guard case let .list(array) = primitive else {
            throw CardanoCoreError.deserializeError("Invalid UTxO type")
        }
        
        guard array.count == 2 else {
            throw CardanoCoreError.deserializeError("Invalid UTxO type")
        }
        
        input = try TransactionInput(from: array[0])
        output = try TransactionOutput(from: array[1])
    }
    
    public func toPrimitive() throws -> Primitive {
        return .list([
            try input.toPrimitive(),
            try output.toPrimitive()
        ])
    }

    public static func == (lhs: UTxO, rhs: UTxO) -> Bool {
        return lhs.input == rhs.input && lhs.output == rhs.output
    }

    public var description: String {
        return "\(input) -> \(output)"
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(input)
        hasher.combine(output)
    }
}
