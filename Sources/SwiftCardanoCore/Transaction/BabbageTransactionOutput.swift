import Foundation

struct BabbageTransactionOutput: Codable {
    var address: Address
    var amount: Value
    var datum: DatumOption?
    var scriptRef: ScriptRef?
    
    enum CodingKeys: Int, CodingKey {
        case address = 0
        case amount = 1
        case datum = 2
        case scriptRef = 3
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        address = try container.decode(Address.self, forKey: .address)
        amount = try container.decode(Value.self, forKey: .amount)
        datum = try container.decode(DatumOption.self, forKey: .datum)
        scriptRef = try container.decode(ScriptRef.self, forKey: .scriptRef)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(address, forKey: .address)
        try container.encode(amount, forKey: .amount)
        try container.encode(datum, forKey: .datum)
        try container.encode(scriptRef, forKey: .scriptRef)
    }
    
    var script: ScriptType? {
        return scriptRef?.script.script
    }
}
