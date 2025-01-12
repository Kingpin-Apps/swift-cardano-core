import Foundation
import PotentCBOR

class ExecutionUnits: ArrayCBORSerializable {

    var mem: Int
    var steps: Int

    init(mem: Int, steps: Int) {
        self.mem = mem
        self.steps = steps
    }

    static func fromPrimitive<T>(_ value: Any) throws -> T {
        guard let values = value as? [Any],
              values.count == 2,
                let mem = values[0] as? Int,
                let steps = values[1] as? Int else {
            throw CardanoCoreError.valueError("Invalid ExecutionUnits values")
        }
        return ExecutionUnits(mem: mem, steps: steps) as! T
    }
    
    func toCBOR() -> [Any] {
        return [mem, steps]
    }

    static func fromCBOR(_ values: [Any]) throws -> ExecutionUnits {
        guard values.count == 2, let mem = values[0] as? Int, let steps = values[1] as? Int else {
            throw CardanoCoreError.valueError("Invalid ExecutionUnits values")
        }
        return ExecutionUnits(mem: mem, steps: steps)
    }

    static func +(lhs: ExecutionUnits, rhs: ExecutionUnits) -> ExecutionUnits {
        return ExecutionUnits(mem: lhs.mem + rhs.mem, steps: lhs.steps + rhs.steps)
    }

    func isEmpty() -> Bool {
        return mem == 0 && steps == 0
    }
}
