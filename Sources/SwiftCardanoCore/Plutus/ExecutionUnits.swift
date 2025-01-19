import Foundation
import PotentCBOR

struct ExecutionUnits: Codable {

    var mem: Int
    var steps: Int

    init(mem: Int, steps: Int) {
        self.mem = mem
        self.steps = steps
    }
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        mem = try container.decode(Int.self)
        steps = try container.decode(Int.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(mem)
        try container.encode(steps)
    }

    static func + (lhs: ExecutionUnits, rhs: ExecutionUnits) -> ExecutionUnits {
        return ExecutionUnits(mem: lhs.mem + rhs.mem, steps: lhs.steps + rhs.steps)
    }

    func isEmpty() -> Bool {
        return mem == 0 && steps == 0
    }
}
