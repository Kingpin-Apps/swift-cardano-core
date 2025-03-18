import Foundation
import PotentCBOR

public struct ExecutionUnits: Codable, Equatable, Hashable {

    public var mem: Int
    public var steps: Int

    public init(mem: Int, steps: Int) {
        self.mem = mem
        self.steps = steps
    }
    
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        mem = try container.decode(Int.self)
        steps = try container.decode(Int.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(mem)
        try container.encode(steps)
    }

    public static func + (lhs: ExecutionUnits, rhs: ExecutionUnits) -> ExecutionUnits {
        return ExecutionUnits(mem: lhs.mem + rhs.mem, steps: lhs.steps + rhs.steps)
    }

    public static func += (lhs: inout ExecutionUnits, rhs: ExecutionUnits) {
        lhs.mem += rhs.mem
        lhs.steps += rhs.steps
    }

    public func isEmpty() -> Bool {
        return mem == 0 && steps == 0
    }
}
