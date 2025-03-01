import Foundation
import CryptoKit
import PotentCBOR

/// Redeemer tag, which indicates the type of redeemer.
enum RedeemerTag: Int, Codable {
    case spend = 0
    case mint = 1
    case cert = 2
    case reward = 3
    case voting = 4
    case proposing = 5
}


struct Redeemer: Codable {

    var tag: RedeemerTag?
    var index: Int = 0
    var data: PlutusData
    var exUnits: ExecutionUnits?

    init(data: PlutusData, exUnits: ExecutionUnits?) {
        self.data = data
        self.exUnits = exUnits
    }
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        tag = try container.decode(RedeemerTag.self)
        index = try container.decode(Int.self)
        data = try container.decode(PlutusData.self)
        exUnits = try container.decode(ExecutionUnits.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(tag)
        try container.encode(index)
        try container.encode(data)
        try container.encode(exUnits)
    }
}
