import Foundation
import OrderedCollections
@preconcurrency import BigInt

// MARK: - Ledger rationals
//
// The ledger holds every rational parameter as a `BoundedRatio Word64`: a
// reduced fraction whose numerator and denominator are both `Word64`, within
// the bounds of its type (cardano-ledger-core, `Cardano.Ledger.BaseTypes`):
//
// - `UnitInterval`, `[0, 1]`;
// - `PositiveUnitInterval`, `[1/10^19, 1]`;
// - `NonNegativeInterval`, `[0, maxBound :: Word64]`.
//
// Fees and rewards are computed from these values exactly, so they are held
// here exactly too, never as a `Double`.

/// The range of a ledger `BoundedRatio Word64`.
public enum LedgerRationalBounds: Sendable {
    /// `UnitInterval`: `0 ... 1`.
    case unitInterval
    /// `PositiveUnitInterval`: `1/10^19 ... 1`.
    case positiveUnitInterval
    /// `NonNegativeInterval`: `0 ... UInt64.max`.
    case nonNegativeInterval
    /// `PositiveInterval`: `1/10^19 ... UInt64.max`.
    case positiveInterval
}

/// Reading and writing ledger rationals exactly, as the ledger does.
enum LedgerRational {
    /// The most decimals the ledger reads or writes (`maxDecimalsWord64`).
    static let maxDecimals = 19

    /// The most significant digits a value the ledger accepts can have: an
    /// integer up to `UInt64.max` has 20, and a fraction over `10^19`
    /// reduced to fit `Word64` at most 33. A `Decimal` holds 38 exactly, so
    /// every value the ledger accepts is read without rounding; a longer one
    /// may have been rounded by the JSON reader and is refused.
    static let maxSignificantDigits = 33

    // MARK: Bounds

    /// `numerator / denominator` reduced and checked against `bounds`, as the
    /// ledger's `boundRational` does: both parts must fit a `Word64` once
    /// reduced, and the value must lie in range.
    static func bound(
        _ numerator: BigInt, _ denominator: BigInt, _ bounds: LedgerRationalBounds, _ what: String
    ) throws -> (UInt64, UInt64) {
        guard denominator != 0 else {
            throw CardanoCoreError.deserializeError("\(what): the denominator is zero")
        }
        var n = numerator, d = denominator
        if d < 0 { n = -n; d = -d }
        let g = BigInt(n.magnitude.greatestCommonDivisor(with: d.magnitude))
        if g > 1 { n /= g; d /= g }
        guard n >= 0 else {
            throw CardanoCoreError.deserializeError("\(what): \(numerator)/\(denominator) is negative")
        }
        guard let num = UInt64(exactly: n), let den = UInt64(exactly: d) else {
            throw CardanoCoreError.deserializeError(
                "\(what): \(n)/\(d) does not fit a Word64 numerator and denominator")
        }
        try check(num, den, bounds, what)
        return (num, den)
    }

    /// Throws when the reduced `numerator / denominator` is outside `bounds`.
    static func check(_ numerator: UInt64, _ denominator: UInt64, _ bounds: LedgerRationalBounds, _ what: String) throws {
        guard denominator > 0 else {
            throw CardanoCoreError.deserializeError("\(what): the denominator is zero")
        }
        let atMostOne = bounds == .unitInterval || bounds == .positiveUnitInterval
        if atMostOne, numerator > denominator {
            throw CardanoCoreError.deserializeError("\(what): \(numerator)/\(denominator) is above one")
        }
        if bounds == .positiveUnitInterval || bounds == .positiveInterval {
            // At least 1/10^19, the smallest decimal that round-trips JSON.
            let scaled = BigUInt(numerator) * BigUInt(10).power(maxDecimals)
            guard scaled >= BigUInt(denominator) else {
                throw CardanoCoreError.deserializeError(
                    "\(what): \(numerator)/\(denominator) is below 1/10^\(maxDecimals)")
            }
        }
    }

    /// `(numerator, denominator)` reduced, without a range check.
    static func reduced(_ numerator: UInt64, _ denominator: UInt64) -> (UInt64, UInt64) {
        guard denominator > 0 else { return (numerator, denominator) }
        var a = numerator, b = denominator
        while b != 0 { (a, b) = (b, a % b) }
        let g = a == 0 ? 1 : a
        return (numerator / g, denominator / g)
    }

    // MARK: Decimal numbers

    /// A decimal number read exactly, as the ledger reads a JSON number into
    /// a `BoundedRatio Word64` (`fromScientificBoundedRatioWord64`).
    static func fromDecimal(_ value: Decimal, _ bounds: LedgerRationalBounds, _ what: String) throws -> (UInt64, UInt64) {
        guard !value.isNaN else {
            throw CardanoCoreError.deserializeError("\(what): not a number")
        }
        guard var coefficient = BigInt(value.significand.description) else {
            throw CardanoCoreError.deserializeError("\(what): \(value) is not a decimal number")
        }
        if value.sign == .minus { coefficient = -coefficient }
        var exponent = value.exponent
        // `normalize`: no trailing zeros in the coefficient.
        if coefficient == 0 {
            exponent = 0
        } else {
            while coefficient % 10 == 0 {
                coefficient /= 10
                exponent += 1
            }
        }
        guard coefficient.magnitude.description.count <= maxSignificantDigits else {
            throw CardanoCoreError.deserializeError("\(what): \(value) is too precise")
        }
        guard coefficient >= 0 else {
            throw CardanoCoreError.deserializeError("\(what): \(value) is negative")
        }
        if exponent <= 0 {
            guard exponent >= -maxDecimals else {
                throw CardanoCoreError.deserializeError("\(what): \(value) is too precise")
            }
            return try bound(coefficient, BigInt(10).power(-exponent), bounds, what)
        }
        guard exponent <= maxDecimals else {
            throw CardanoCoreError.deserializeError("\(what): \(value) is too big")
        }
        return try bound(coefficient * BigInt(10).power(exponent), 1, bounds, what)
    }

    /// The value as a decimal with at most 19 decimals, or `nil` when it has
    /// no such expansion. The ledger writes a rational as a JSON number when
    /// it has one (`fromRationalRepetendLimited 19`), and as
    /// `{"numerator": n, "denominator": d}` otherwise.
    static func decimal(_ numerator: UInt64, _ denominator: UInt64) -> Decimal? {
        let (n, d) = reduced(numerator, denominator)
        guard d > 0 else { return nil }
        var rest = d, twos = 0, fives = 0
        while rest % 2 == 0 { rest /= 2; twos += 1 }
        while rest % 5 == 0 { rest /= 5; fives += 1 }
        let places = max(twos, fives)
        guard rest == 1, places <= maxDecimals else { return nil }
        // n * 10^places / d is a whole number below 10^33: a Decimal holds it.
        let scaled = BigUInt(n) * BigUInt(10).power(places) / BigUInt(d)
        guard let significand = Decimal(string: scaled.description) else { return nil }
        return Decimal(sign: .plus, exponent: -places, significand: significand)
    }

    // MARK: JSON

    private enum FractionKeys: String, CodingKey {
        case numerator, denominator
    }

    /// Reads a JSON rational as the ledger does: a decimal number, or a
    /// `{"numerator": n, "denominator": d}` object.
    static func decodeJSON(from decoder: Decoder, _ bounds: LedgerRationalBounds, _ what: String) throws -> (UInt64, UInt64) {
        if let c = try? decoder.container(keyedBy: FractionKeys.self) {
            let n = try integer(c.decode(Decimal.self, forKey: .numerator), "\(what) numerator")
            let d = try integer(c.decode(Decimal.self, forKey: .denominator), "\(what) denominator")
            return try bound(n, d, bounds, what)
        }
        let value = try decoder.singleValueContainer().decode(Decimal.self)
        return try fromDecimal(value, bounds, what)
    }

    /// A whole decimal as an integer.
    private static func integer(_ value: Decimal, _ what: String) throws -> BigInt {
        var whole = Decimal()
        var copy = value
        NSDecimalRound(&whole, &copy, 0, .down)
        guard !value.isNaN, whole == value, let integer = BigInt(value.description) else {
            throw CardanoCoreError.deserializeError("\(what): \(value) is not a whole number")
        }
        return integer
    }

    /// Writes a rational as the ledger does: a JSON number when it has a
    /// decimal expansion of at most 19 places, an object otherwise.
    static func encodeJSON(_ numerator: UInt64, _ denominator: UInt64, to encoder: Encoder) throws {
        let (n, d) = reduced(numerator, denominator)
        if d == 1 {
            var c = encoder.singleValueContainer()
            try c.encode(n)
        } else if let value = decimal(n, d) {
            var c = encoder.singleValueContainer()
            try c.encode(value)
        } else {
            var c = encoder.container(keyedBy: FractionKeys.self)
            try c.encode(n, forKey: .numerator)
            try c.encode(d, forKey: .denominator)
        }
    }

    /// The rational as `toDict` holds it: an exact decimal, or a
    /// numerator-and-denominator map.
    static func jsonPrimitive(_ numerator: UInt64, _ denominator: UInt64) -> Primitive {
        let (n, d) = reduced(numerator, denominator)
        if d == 1 { return .uint(n) }
        if let value = decimal(n, d) { return .decimal(value) }
        return .orderedDict([.string("denominator"): .uint(d), .string("numerator"): .uint(n)])
    }

    // MARK: CBOR

    /// Reads a CBOR rational: `#6.30([n, d])` when `tagged`, the bare
    /// `[n, d]` otherwise. Each part is an integer, the denominator not zero,
    /// and the reduced value within `bounds`.
    static func fromPrimitive(
        _ primitive: Primitive, _ bounds: LedgerRationalBounds, _ what: String, tagged: Bool = true
    ) throws -> (UInt64, UInt64) {
        let parts: [Primitive]
        switch primitive {
        case .unitInterval(let interval) where tagged:
            // The CBOR reader turns every `#6.30` into this case, whatever
            // the ratio's range.
            parts = [.uint(interval.numerator), .uint(interval.denominator)]
        case .cborTag(let tag) where tagged && tag.tag == 30:
            switch tag.value {
            case .list(let items): parts = items
            case .indefiniteList(let items): parts = items.getAll()
            default:
                throw CardanoCoreError.deserializeError("\(what): a #6.30 rational must hold an array")
            }
        case .list(let items) where !tagged:
            parts = items
        case .indefiniteList(let items) where !tagged:
            parts = items.getAll()
        default:
            throw CardanoCoreError.deserializeError(
                "\(what): expected \(tagged ? "a #6.30 rational" : "an untagged [numerator, denominator]"), got \(primitive)")
        }
        guard parts.count == 2 else {
            throw CardanoCoreError.deserializeError("\(what): a rational has 2 parts, got \(parts.count)")
        }
        guard let n = parts[0].integerValue, let d = parts[1].integerValue else {
            throw CardanoCoreError.deserializeError("\(what): a rational's parts must be integers")
        }
        return try bound(n, d, bounds, what)
    }

    /// The reduced rational as the ledger writes it: `#6.30([n, d])`, or the
    /// bare `[n, d]` when not `tagged`.
    static func primitive(_ numerator: UInt64, _ denominator: UInt64, tagged: Bool = true) -> Primitive {
        let (n, d) = reduced(numerator, denominator)
        let pair: Primitive = .list([.uint(n), .uint(d)])
        return tagged ? .cborTag(CBORTag(tag: 30, value: pair)) : pair
    }
}

// MARK: - Exact values of the interval types

extension UnitInterval {
    /// A unit interval read from input, reduced and checked against `bounds`
    /// (`unitInterval` or `positiveUnitInterval`).
    init(exactNumerator numerator: UInt64, denominator: UInt64,
         bounds: LedgerRationalBounds = .unitInterval, _ what: String) throws {
        try LedgerRational.check(numerator, denominator, bounds, what)
        let (n, d) = LedgerRational.reduced(numerator, denominator)
        self.init(numerator: n, denominator: d)
    }

    /// Reads a unit interval from JSON as the ledger does: a decimal such as
    /// `0.0577` or `5.77e-2`, read exactly, or `{"numerator", "denominator"}`.
    public static func ledgerJSON(
        from decoder: Decoder, bounds: LedgerRationalBounds = .unitInterval, _ what: String = "UnitInterval"
    ) throws -> UnitInterval {
        let (n, d) = try LedgerRational.decodeJSON(from: decoder, bounds, what)
        return UnitInterval(numerator: n, denominator: d)
    }

    /// Writes the value to JSON as the ledger does.
    public func encodeLedgerJSON(to encoder: Encoder) throws {
        try LedgerRational.encodeJSON(numerator, denominator, to: encoder)
    }

    /// Reads a CBOR unit interval, reduced, as the ledger does.
    static func ledgerCBOR(
        _ primitive: Primitive, bounds: LedgerRationalBounds = .unitInterval, _ what: String, tagged: Bool = true
    ) throws -> UnitInterval {
        let (n, d) = try LedgerRational.fromPrimitive(primitive, bounds, what, tagged: tagged)
        return UnitInterval(numerator: n, denominator: d)
    }

    /// The reduced value as the ledger writes it in CBOR.
    func ledgerPrimitive(tagged: Bool = true) -> Primitive {
        LedgerRational.primitive(numerator, denominator, tagged: tagged)
    }

    /// The value as `toDict` holds it.
    var jsonPrimitive: Primitive { LedgerRational.jsonPrimitive(numerator, denominator) }

    /// Whether the two hold the same rational, however they are reduced.
    public func isEquivalent(to other: UnitInterval) -> Bool {
        BigUInt(numerator) * BigUInt(other.denominator) == BigUInt(other.numerator) * BigUInt(denominator)
    }
}

extension NonNegativeInterval {
    /// A non-negative interval read from input, reduced and checked against
    /// `bounds` (`nonNegativeInterval` or `positiveInterval`).
    init(exactNumerator numerator: UInt64, denominator: UInt64,
         bounds: LedgerRationalBounds = .nonNegativeInterval, _ what: String) throws {
        try LedgerRational.check(numerator, denominator, bounds, what)
        let (n, d) = LedgerRational.reduced(numerator, denominator)
        self.init(lowerBound: n, upperBound: d)
    }

    /// Reads a non-negative interval from JSON as the ledger does: a decimal,
    /// read exactly, or `{"numerator", "denominator"}`.
    public static func ledgerJSON(
        from decoder: Decoder, bounds: LedgerRationalBounds = .nonNegativeInterval,
        _ what: String = "NonNegativeInterval"
    ) throws -> NonNegativeInterval {
        let (n, d) = try LedgerRational.decodeJSON(from: decoder, bounds, what)
        return NonNegativeInterval(lowerBound: n, upperBound: d)
    }

    /// Writes the value to JSON as the ledger does.
    public func encodeLedgerJSON(to encoder: Encoder) throws {
        try LedgerRational.encodeJSON(numerator, denominator, to: encoder)
    }

    /// Reads a CBOR non-negative interval, reduced, as the ledger does.
    static func ledgerCBOR(
        _ primitive: Primitive, bounds: LedgerRationalBounds = .nonNegativeInterval, _ what: String
    ) throws -> NonNegativeInterval {
        let (n, d) = try LedgerRational.fromPrimitive(primitive, bounds, what)
        return NonNegativeInterval(lowerBound: n, upperBound: d)
    }

    /// The reduced value as the ledger writes it in CBOR.
    func ledgerPrimitive() -> Primitive {
        LedgerRational.primitive(numerator, denominator)
    }

    /// The value as `toDict` holds it.
    var jsonPrimitive: Primitive { LedgerRational.jsonPrimitive(numerator, denominator) }

    /// Whether the two hold the same rational, however they are reduced.
    public func isEquivalent(to other: NonNegativeInterval) -> Bool {
        BigUInt(numerator) * BigUInt(other.denominator) == BigUInt(other.numerator) * BigUInt(denominator)
    }
}

// MARK: - Keyed JSON containers

/// A ledger rational written to JSON on its own, for keyed containers.
private struct LedgerUnitIntervalJSON: Encodable {
    let value: UnitInterval
    init(_ value: UnitInterval) { self.value = value }
    func encode(to encoder: Encoder) throws { try value.encodeLedgerJSON(to: encoder) }
}

private struct LedgerNonNegativeIntervalJSON: Encodable {
    let value: NonNegativeInterval
    init(_ value: NonNegativeInterval) { self.value = value }
    func encode(to encoder: Encoder) throws { try value.encodeLedgerJSON(to: encoder) }
}

private extension Array where Element == CodingKey {
    var pathDescription: String {
        isEmpty ? "value" : map { $0.intValue.map(String.init) ?? $0.stringValue }.joined(separator: ".")
    }
}

extension KeyedDecodingContainer {
    /// A ledger `UnitInterval` (or, with `bounds`, `PositiveUnitInterval`)
    /// read exactly from a JSON number or fraction object.
    func decodeUnitInterval(forKey key: Key, bounds: LedgerRationalBounds = .unitInterval) throws -> UnitInterval {
        let decoder = try superDecoder(forKey: key)
        return try UnitInterval.ledgerJSON(from: decoder, bounds: bounds, decoder.codingPath.pathDescription)
    }

    func decodeUnitIntervalIfPresent(forKey key: Key, bounds: LedgerRationalBounds = .unitInterval) throws -> UnitInterval? {
        guard contains(key), try !decodeNil(forKey: key) else { return nil }
        return try decodeUnitInterval(forKey: key, bounds: bounds)
    }

    /// A ledger `NonNegativeInterval` (or, with `bounds`, `PositiveInterval`)
    /// read exactly from a JSON number or fraction object.
    func decodeNonNegativeInterval(
        forKey key: Key, bounds: LedgerRationalBounds = .nonNegativeInterval
    ) throws -> NonNegativeInterval {
        let decoder = try superDecoder(forKey: key)
        return try NonNegativeInterval.ledgerJSON(from: decoder, bounds: bounds, decoder.codingPath.pathDescription)
    }

    func decodeNonNegativeIntervalIfPresent(
        forKey key: Key, bounds: LedgerRationalBounds = .nonNegativeInterval
    ) throws -> NonNegativeInterval? {
        guard contains(key), try !decodeNil(forKey: key) else { return nil }
        return try decodeNonNegativeInterval(forKey: key, bounds: bounds)
    }
}

extension KeyedEncodingContainer {
    /// Writes a ledger rational as the ledger does.
    mutating func encodeLedgerRational(_ value: UnitInterval, forKey key: Key) throws {
        try encode(LedgerUnitIntervalJSON(value), forKey: key)
    }

    mutating func encodeLedgerRational(_ value: NonNegativeInterval, forKey key: Key) throws {
        try encode(LedgerNonNegativeIntervalJSON(value), forKey: key)
    }

    mutating func encodeLedgerRationalIfPresent(_ value: NonNegativeInterval?, forKey key: Key) throws {
        if let value { try encodeLedgerRational(value, forKey: key) }
    }

    mutating func encodeLedgerRationalIfPresent(_ value: UnitInterval?, forKey key: Key) throws {
        if let value { try encodeLedgerRational(value, forKey: key) }
    }
}
