import Foundation
import CryptoKit
import PotentCBOR

/// Redeemer tag, which indicates the type of redeemer.
public enum RedeemerTag: Int, CBORSerializable {
    case spend = 0
    case mint = 1
    case cert = 2
    case reward = 3
    case voting = 4
    case proposing = 5
}


public struct Redeemer: CBORSerializable, Equatable, Hashable {

    public var tag: RedeemerTag?
    public var index: Int = 0
    public var data: PlutusData
    public var exUnits: ExecutionUnits?

    public init(data: PlutusData, exUnits: ExecutionUnits?) {
        self.data = data
        self.exUnits = exUnits
    }
    
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        tag = try container.decode(RedeemerTag.self)
        index = try container.decode(Int.self)
        data = try container.decode(PlutusData.self)
        exUnits = try container.decode(ExecutionUnits.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(tag)
        try container.encode(index)
        try container.encode(data)
        try container.encode(exUnits)
    }
}

/// Represents a unique key for a Redeemer.
public struct RedeemerKey: CBORSerializable, Equatable, Hashable {
    public var tag: RedeemerTag
    public var index: Int = 0

    public init(tag: RedeemerTag, index: Int = 0) {
        self.tag = tag
        self.index = index
    }

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        tag = try container.decode(RedeemerTag.self)
        index = try container.decode(Int.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(tag)
        try container.encode(index)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(tag)
        hasher.combine(index)
    }
}

/// Represents the value of a Redeemer, including data and execution units.
public struct RedeemerValue: CBORSerializable, Equatable, Hashable {
    public var data: PlutusData
    public var exUnits: ExecutionUnits

    public init(data: PlutusData, exUnits: ExecutionUnits) {
        self.data = data
        self.exUnits = exUnits
    }

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        data = try container.decode(PlutusData.self)
        exUnits = try container.decode(ExecutionUnits.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(data)
        try container.encode(exUnits)
    }
}

/// Represents a mapping of RedeemerKeys to RedeemerValues.
public typealias RedeemerMap = [RedeemerKey: RedeemerValue]

/// Redeemers can be a list of Redeemer objects or a map of Redeemer keys to values.
public enum Redeemers: CBORSerializable, Equatable, Hashable {
    case list([Redeemer])
    case map(RedeemerMap)
}
