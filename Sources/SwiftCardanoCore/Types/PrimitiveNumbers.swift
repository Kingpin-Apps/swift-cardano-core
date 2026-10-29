@preconcurrency import BigInt
import Foundation

// Reading a number out of decoded input with `Int(x)`, `UInt64(x)` and the
// like traps when the value does not fit, and a trap is a crash: a value the
// ledger accepts, or one a hostile peer sends, would take the process down.
// These read and write integers without trapping — a value outside the type's
// range throws, as the ledger's own decoder fails.

extension Primitive {
    /// The integer this holds, whichever case holds it, or `nil` when it holds
    /// no integer.
    public var integerValue: BigInt? {
        switch self {
        case .uint(let value): return BigInt(value)
        case .int(let value): return BigInt(value)
        case .bigInt(let value): return value
        case .bigUInt(let value): return BigInt(value)
        default: return nil
        }
    }

    /// The integer this holds as a `T`.
    ///
    /// - Throws: When this holds no integer, or one outside `T`'s range.
    public func integer<T: FixedWidthInteger>(_ what: @autoclosure () -> String, as type: T.Type = T.self) throws -> T {
        guard let value = integerValue else {
            throw CardanoCoreError.deserializeError("\(what()): expected an integer, got \(self)")
        }
        guard let narrowed = T(exactly: value) else {
            throw CardanoCoreError.deserializeError("\(what()): \(value) is out of range for \(T.self)")
        }
        return narrowed
    }

    /// An integer as a primitive: `.uint` when it is not negative, `.int`
    /// when it fits `Int64`, and a big integer otherwise. Never traps.
    public static func integer<T: BinaryInteger>(_ value: T) -> Primitive {
        if value >= 0 {
            if let unsigned = UInt64(exactly: value) { return .uint(unsigned) }
        } else if let signed = Int64(exactly: value) {
            return .int(signed)
        }
        return .bigInt(BigInt(value))
    }
}

extension Primitive {
    /// The elements of an array, whether it was written with a definite or
    /// an indefinite length — the ledger reads a record either way
    /// (`decodeRecordNamed`) — or `nil` when this is not an array.
    public var arrayElements: [Primitive]? {
        switch self {
        case .list(let elements): return elements
        case .indefiniteList(let elements): return elements.getAll()
        default: return nil
        }
    }
}

extension Array {
    /// The element at `index`, or a decoding error naming `what` when the
    /// array is too short.
    func element(_ index: Int, _ what: @autoclosure () -> String) throws -> Element {
        guard indices.contains(index) else {
            throw CardanoCoreError.deserializeError(
                "\(what()): expected at least \(index + 1) elements, got \(count)")
        }
        return self[index]
    }
}
