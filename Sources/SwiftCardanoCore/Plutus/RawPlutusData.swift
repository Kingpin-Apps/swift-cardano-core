import Foundation
import PotentCBOR
import PotentCodables

public struct RawPlutusData: CBORSerializable, Equatable, Hashable {
    public let data: RawDatum

    public init(data: RawDatum) {
        self.data = data
    }
    
    enum CodingKeys : String, CodingKey {
        case data
    }
    
    public init(from decoder: Decoder) throws {
        if String(describing: type(of: decoder)).contains("JSONDecoder") {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.data = try container.decode(RawDatum.self, forKey: .data)
        } else {
            let container = try decoder.singleValueContainer()
            self.data = try container.decode(RawDatum.self)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        if String(describing: type(of: encoder)).contains("JSONEncoder") {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(data, forKey: .data)
        } else {
            var container = encoder.singleValueContainer()
            try container.encode(data)
        }
    }
}
