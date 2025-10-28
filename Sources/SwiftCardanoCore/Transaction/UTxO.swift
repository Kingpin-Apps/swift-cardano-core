import Foundation
import OrderedCollections
import SwiftNcal

public struct UTxO: Serializable {
    public var input: TransactionInput
    public var output: TransactionOutput
    
//    public var debugDescription: String { self.description }
//    
//    public var description: String {
//        let jsonString = """
//        {
//            "input": \(input.description),
//            "output": \(output.description)
//        }
//        """
//        guard let data = jsonString.data(using: .utf8) else {
//            return jsonString
//        }
//        
//        guard let jsonObject = try? JSONSerialization.jsonObject(with: data) else {
//            return jsonString
//        }
//        
//        guard let prettyData = try? JSONSerialization.data(
//            withJSONObject: jsonObject,
//            options: [
//                .prettyPrinted,
//                .sortedKeys,
//                .withoutEscapingSlashes
//            ]
//        ) else {
//            return jsonString
//        }
//        
//        return String(data: prettyData, encoding: .utf8) ?? jsonString
//    }
    
    public init(input: TransactionInput, output: TransactionOutput) {
        self.input = input
        self.output = output
    }
    
    public init(from
                inputPrimitives: (String, UInt16),
                outputPrimitives: (String, Int, DatumOption?, ScriptType?, Bool?)) throws {
        input = try TransactionInput(from: inputPrimitives.0, index: inputPrimitives.1)
        output = try TransactionOutput(from: outputPrimitives.0,
                                   amount: outputPrimitives.1,
                                   datumOption: outputPrimitives.2,
                                   script: outputPrimitives.3,
                                   postAlonzo: outputPrimitives.4 ?? true)
    }
    
//    public init(from decoder: Decoder) throws {
//        var container = try decoder.unkeyedContainer()
//        input = try container.decode(TransactionInput.self)
//        output = try container.decode(TransactionOutput.self)
//    }
//
//    public func encode(to encoder: Swift.Encoder) throws {
//        var container = encoder.unkeyedContainer()
//        try container.encode(input)
//        try container.encode(output)
//    }
    
    // MARK: - CBORSerializable
    
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
    
    // MARK: - JSONSerializable
    
    public static func fromDict(_ dict: Primitive) throws -> UTxO {
        guard case let .orderedDict(dictValue) = dict,
              let inputPrimitive = dictValue[.string("input")] else {
            throw CardanoCoreError.deserializeError("Missing 'input' key in UTxO dictionary")
        }
        
        guard let outputPrimitive = dictValue[.string("output")] else {
            throw CardanoCoreError.deserializeError("Missing 'output' key in UTxO dictionary")
        }
        
        let input = try TransactionInput.fromDict(inputPrimitive)
        let output = try TransactionOutput.fromDict(outputPrimitive)
        
        return UTxO(input: input, output: output)
    }
    
    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        dict[.string("input")] = try input.toDict()
        dict[.string("output")] = try output.toDict()
        return .orderedDict(dict)
    }

    // MARK: - Equatable
    
    public static func == (lhs: UTxO, rhs: UTxO) -> Bool {
        return lhs.input == rhs.input && lhs.output == rhs.output
    }
    
    // MARK: - Hashable
    
    public func hash() throws -> String {
        let hash =  try SwiftNcal.Hash().blake2b(
            data: input.toCBORData() + output.toCBORData(),
            digestSize: UTXO_HASH_SIZE,
            encoder: RawEncoder.self
        )
        
        return hash.toHex
    }
}
