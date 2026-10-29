import Foundation
import OrderedCollections

public struct CommitteeMember: CBORSerializable, CustomStringConvertible, CustomDebugStringConvertible, Sendable {
    public let coldCredential: CommitteeColdCredential
    public let epoch: EpochNumber
    
    public var description: String { "CommitteeMember(\(coldCredential), \(epoch))" }
    
    public var debugDescription: String { self.description }
    
    public init(from primitive: Primitive) throws {
        guard case let .orderedDict(dict) = primitive, dict.count == 1 else {
            throw CardanoCoreError.deserializeError("Expected a single-entry dictionary")
        }
        
        guard let credential = dict.keys.first else {
            throw CardanoCoreError.deserializeError("Expected a single-entry dictionary")
        }
        guard let epochPrimitive = dict[credential] else {
            throw CardanoCoreError.deserializeError("Expected a single-entry dictionary")
        }
        
        self.coldCredential = try CommitteeColdCredential(from: credential)
        self.epoch = try epochPrimitive.integer("CommitteeMember epoch", as: EpochNumber.self)
    }
    
    public func toPrimitive() throws -> Primitive {
        return .orderedDict(
            OrderedDictionary<Primitive, Primitive>(uniqueKeysWithValues: [
                try self.coldCredential.toPrimitive(): .integer(self.epoch)
            ])
        )
    }
}

/// The initial committee in Conway genesis: each member's expiry epoch
/// (`EpochNo`, a `Word64`) and the quorum (a `UnitInterval`).
public struct Committee: Codable, Equatable, Hashable, Sendable {
    public let members: [String: EpochNumber]
    public let threshold: Threshold

    public init(members: [String: EpochNumber], threshold: Threshold) {
        self.members = members
        self.threshold = threshold
    }
}

/// A `UnitInterval`: a `Word64` numerator at most its `Word64` denominator,
/// which is above zero.
public struct Threshold: Codable, Equatable, Hashable, Sendable {
    public let numerator: UInt64
    public let denominator: UInt64

    public init(numerator: UInt64, denominator: UInt64) throws {
        guard denominator > 0, numerator <= denominator else {
            throw CardanoCoreError.valueError("Threshold: \(numerator)/\(denominator) is not a unit interval")
        }
        self.numerator = numerator
        self.denominator = denominator
    }

    private enum CodingKeys: String, CodingKey {
        case numerator, denominator
    }

    /// Reads `{"numerator": n, "denominator": d}`, or a decimal number such
    /// as `0.67`, as the ledger's JSON reader does.
    public init(from decoder: Decoder) throws {
        let numerator: UInt64
        let denominator: UInt64
        if let c = try? decoder.container(keyedBy: CodingKeys.self) {
            numerator = try c.decode(UInt64.self, forKey: .numerator)
            denominator = try c.decode(UInt64.self, forKey: .denominator)
        } else {
            (numerator, denominator) = try Self.fraction(decoder.singleValueContainer().decode(Decimal.self))
        }
        guard denominator > 0, numerator <= denominator else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Threshold: \(numerator)/\(denominator) is not a unit interval"))
        }
        self.numerator = numerator
        self.denominator = denominator
    }

    /// A decimal as a fraction over a power of ten, both `Word64`.
    private static func fraction(_ value: Decimal) throws -> (UInt64, UInt64) {
        var scaled = value
        var denominator: UInt64 = 1
        for _ in 0 ... 19 {
            var whole = Decimal()
            NSDecimalRound(&whole, &scaled, 0, .plain)
            if whole == scaled, whole >= 0, whole <= Decimal(UInt64.max),
               let numerator = UInt64(whole.description) {
                return (numerator, denominator)
            }
            let (next, overflow) = denominator.multipliedReportingOverflow(by: 10)
            if overflow { break }
            denominator = next
            scaled *= 10
        }
        throw CardanoCoreError.deserializeError("Threshold: \(value) cannot be written as a Word64 fraction")
    }
}
