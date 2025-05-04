import Foundation
import PotentASN1
import PotentCBOR
import PotentCodables
import OrderedCollections

// MARK: - Types Aliases
public typealias Coin = UInt64
public typealias RewardAccount = Data
public typealias SlotNumber = UInt64

// Represents a 4-byte unsigned integer
public typealias EpochInterval = UInt32

// Represents an 8-byte unsigned integer
public typealias EpochNumber = UInt64

// MARK: - PositiveCoin
public struct PositiveCoin: CBORSerializable, Equatable, Hashable {
    public let value: UInt

    public init(_ value: UInt) {
        precondition(value > 0, "PositiveCoin must be greater than 0")
        self.value = value
    }
}

// MARK: - ExUnitPrices
public struct ExUnitPrices: CBORSerializable, Hashable, Equatable {
    public var memPrice: NonNegativeInterval
    public var stepPrice: NonNegativeInterval

    public init(memPrice: NonNegativeInterval, stepPrice: NonNegativeInterval) {
        self.memPrice = memPrice
        self.stepPrice = stepPrice
    }

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        memPrice = try container.decode(NonNegativeInterval.self)
        stepPrice = try container.decode(NonNegativeInterval.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(memPrice)
        try container.encode(stepPrice)
    }
}

// MARK: - ExUnits
public struct ExUnits: CBORSerializable, Hashable, Equatable {
    public var mem: UInt
    public var steps: UInt

    public init(mem: UInt, steps: UInt) {
        self.mem = mem
        self.steps = steps
    }

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        mem = try container.decode(UInt.self)
        steps = try container.decode(UInt.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(mem)
        try container.encode(steps)
    }
}

// MARK: - ProtocolVersion
public struct ProtocolVersion: CBORSerializable, Hashable, Equatable {
    public var major: Int?
    public var minor: Int?

    public init(major: Int, minor: Int) {
        self.major = major
        self.minor = minor
    }

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        major = try container.decode(Int.self)
        minor = try container.decode(Int.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(major)
        try container.encode(minor)
    }
}

// MARK: - NonNegativeInterval
public struct NonNegativeInterval: CBORSerializable, Hashable, Equatable {
    public var lowerBound: UInt
    public var upperBound: UInt64

    public init(lowerBound: UInt, upperBound: UInt64) {
        precondition(
            lowerBound <= upperBound, "Lower bound must be less than or equal to upper bound")
        self.lowerBound = lowerBound
        self.upperBound = upperBound
    }

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        lowerBound = try container.decode(UInt.self)
        upperBound = try container.decode(UInt64.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(lowerBound)
        try container.encode(upperBound)
    }
}

// MARK: - Fraction
public struct Fraction: CBORSerializable, Equatable, Hashable {
    public let numerator: Int
    public let denominator: Int
    
    public static let tag = 30
    
    public var quotient: Double {
        return Double(numerator) / Double(denominator)
    }
    public init(numerator: Int, denominator: Int) {
        precondition(denominator != 0, "Denominator must not be zero")
        self.numerator = numerator
        self.denominator = denominator
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        let cborData = try container.decode(CBOR.self)

        if case let .tagged(tag, cborData) = cborData {
            guard tag.rawValue == UInt64(UnitInterval.tag) else {
                throw CardanoCoreError.valueError(
                    "UnitInterval must be tagged with tag \(UnitInterval.tag)")
            }

            switch cborData {
            case .array(let arrayData):
                guard arrayData.count == 2 else {
                    throw CardanoCoreError.valueError(
                        "UnitInterval must contain exactly 2 elements")
                }
                self.init(
                    numerator: arrayData[0].integerValue()!,
                    denominator: arrayData[1].integerValue()!
                )
            default:
                throw CardanoCoreError.valueError("UnitInterval must be an array")
            }
        } else {
            throw CardanoCoreError.valueError("UnitInterval must be tagged")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        let cborData: CBOR = .tagged(
            CBOR.Tag(rawValue: UInt64(UnitInterval.tag)),
            [
                .unsignedInt(UInt64(numerator)),
                .unsignedInt(UInt64(denominator)),
            ]
        )

        try container.encode(cborData)
    }
}

// MARK: - UnitInterval
/// A unit interval is a number in the range between 0 and 1
public struct UnitInterval: CBORSerializable, Equatable, Hashable {
    public let numerator: UInt
    public let denominator: UInt

    public static let tag = 30

    public init(numerator: UInt, denominator: UInt) {
        precondition(
            numerator <= denominator, "Numerator must be less than or equal to denominator")
        precondition(denominator > 0, "Denominator must be greater than zero")
        self.numerator = numerator
        self.denominator = denominator
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        let cborData = try container.decode(CBOR.self)

        if case let .tagged(tag, cborData) = cborData {
            guard tag.rawValue == UInt64(UnitInterval.tag) else {
                throw CardanoCoreError.valueError(
                    "UnitInterval must be tagged with tag \(UnitInterval.tag)")
            }

            switch cborData {
            case .array(let arrayData):
                guard arrayData.count == 2 else {
                    throw CardanoCoreError.valueError(
                        "UnitInterval must contain exactly 2 elements")
                }
                self.init(
                    numerator: arrayData[0].integerValue()!,
                    denominator: arrayData[1].integerValue()!
                )
            default:
                throw CardanoCoreError.valueError("UnitInterval must be an array")
            }
        } else {
            throw CardanoCoreError.valueError("UnitInterval must be tagged")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        let cborData: CBOR = .tagged(
            CBOR.Tag(rawValue: UInt64(UnitInterval.tag)),
            [
                .unsignedInt(UInt64(numerator)),
                .unsignedInt(UInt64(denominator)),
            ]
        )

        try container.encode(cborData)
    }
}

// MARK: - Url
public struct Url: CBORSerializable, Hashable {
    public let value: URL

    public var absoluteString: String {
        return value.absoluteString
    }

    public init(_ value: String) throws {
        guard value.count <= 128 else {
            throw CardanoCoreError.valueError("URL exceeds the maximum length of 128 characters.")
        }

        guard let url = URL(string: value) else {
            throw CardanoCoreError.valueError("Invalid URL format: \(value)")
        }

        self.value = url
    }
}

// MARK: - Anchor
public struct Anchor: CBORSerializable, Hashable {
    public let anchorUrl: Url
    public let anchorDataHash: AnchorDataHash

    public init(anchorUrl: Url, anchorDataHash: AnchorDataHash) {
        self.anchorUrl = anchorUrl
        self.anchorDataHash = anchorDataHash
    }

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let url = try container.decode(String.self)
        let dataHash = try container.decode(Data.self)

        self.anchorUrl = try Url(url)
        self.anchorDataHash = AnchorDataHash(payload: dataHash)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(anchorUrl.value.absoluteString)
        try container.encode(anchorDataHash.payload)
    }
}

// MARK: - CBOR Tag
public protocol CBORTaggable: CBORSerializable, Equatable, Hashable {
    var tag: UInt64 { get }
    var value: AnyValue { get set }

    init(tag: UInt64, value: AnyValue) throws
}

extension CBORTaggable {
    public func taggedCBOR() -> CBOR {
        let cborData = try! CBOREncoder().encode(value).toCBOR
        return .tagged(
            CBOR.Tag(rawValue: tag),
            cborData
        )
    }

    public func fromCBOR(_ cbor: CBOR) throws -> Self {
        guard case let .tagged(tag, value) = cbor else {
            throw CardanoCoreError.valueError("CBOR value is not tagged")
        }
        return try Self(
            tag: tag.rawValue,
            value: try AnyValue.wrapped(value.unwrapped)
        )
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let cborData = try container.decode(CBOR.self)

        if case let .tagged(tag, cborData) = cborData {
            let tag = tag.rawValue
            let value = try AnyValue.wrapped(cborData.unwrapped)
            try self.init(tag: tag, value: value)
        } else {
            throw CardanoCoreError.valueError("CBORTag must be tagged")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(taggedCBOR())
    }
    
    public init(from primitive: Primitive) throws {
        guard case let .cborTag(tagged) = primitive else {
            throw CardanoCoreError.valueError("Invalid CBORTag type")
        }
        
        try self.init(tag: tagged.tag, value: tagged.value)
    }
    
    public func toPrimitive() throws -> Primitive {
        return .cborTag(CBORTag(tag: tag, value: value))
    }

}

public struct CBORTag: CBORTaggable {
    public var tag: UInt64
    public var value: AnyValue

    public init(tag: UInt64, value: AnyValue) {
        self.tag = tag
        self.value = value
    }
}

// MARK: - ByteString
public struct ByteString: CBORSerializable, Hashable {
    public let value: Data

    public init(value: Data) {
        self.value = value
    }

    public static func == (lhs: ByteString, rhs: ByteString) -> Bool {
        return lhs.value == rhs.value
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(value)
    }

    public func isEqual(to other: Any) -> Bool {
        if let otherByteString = other as? ByteString {
            return self.value == otherByteString.value
        } else if let otherData = other as? Data {
            return self.value == otherData
        } else {
            return false
        }
    }
}

public struct RawBytesTransformer: ValueEncodingTransformer {
    public typealias Source = Data
    public typealias Target = Data
    
    public func encode(_ value: Data) throws -> Data {
        return value
    }

}

// MARK: - IndefiniteList
public struct IndefiniteList<T>: CBORSerializable, Hashable, Equatable where T: Hashable {
    private var items: [T]

    public init(_ items: [T] = []) {
        self.items = items
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let cborData = try container.decode(CBOR.self)

        switch cborData {
            case .array(let arrayData):
                self.items = arrayData.map { $0.unwrapped as! T }
            case .indefiniteArray(let arrayData):
                self.items = arrayData.map { $0.unwrapped as! T }
            default:
                throw CardanoCoreError.valueError("IndefiniteList must be an array")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        let indefiniteArray: CBOR = .indefiniteArray(items.map { CBOR.fromAny($0) })

        try container.encode(indefiniteArray)
    }

    public subscript(index: Int) -> T {
        get {
            return items[index]
        }
        set {
            items[index] = newValue
        }
    }

    // Adds an item to the list
    public mutating func add(_ item: T) {
        items.append(item)
    }

    // Returns the item at the specified index, or nil if out of bounds
    public func get(at index: Int) -> T? {
        guard index < items.count else { return nil }
        return items[index]
    }

    // Returns the entire list
    public func getAll() -> [T] {
        return items
    }

    // Removes the item at the specified index
    public mutating func remove(at index: Int) {
        guard index < items.count else { return }
        items.remove(at: index)
    }

    // Returns the count of items in the list
    public var count: Int {
        return items.count
    }

    // Checks if the list is empty
    public var isEmpty: Bool {
        return items.isEmpty
    }

    // Custom string description for easy debugging
    public var description: String {
        return "IndefiniteList: \(items)"
    }
    
    public func map<U>(_ transform: (T) throws -> U) rethrows -> [U] {
        return try items.map(transform)
    }

    public static func == (lhs: IndefiniteList<T>, rhs: IndefiniteList<T>) -> Bool {
        return lhs.items == rhs.items
    }
}

extension IndefiniteList: RandomAccessCollection, CustomReflectable {
    public typealias Index = Int
    public typealias Element = T

    public var startIndex: Index { items.startIndex }
    public var endIndex: Index { items.endIndex }

    public func index(after i: Index) -> Index {
        items.index(after: i)
    }

    public func index(before i: Index) -> Index {
        items.index(before: i)
    }

    public var customMirror: Mirror {
        Mirror(
                self,
                children: items.enumerated().map { (label: Optional("\($0.offset)"), value: $0.element as Any) },
                displayStyle: .collection
            )
    }
}

// Generic wrapper for CBOR-tagged sets (tag 258)
public protocol SetTaggable<Element>: CBORTaggable {
    associatedtype Element: CBORSerializable & Hashable

    var elements: Set<Element> { get set }
}

extension SetTaggable {
    public var tag: UInt64 { 258 }
    public var value: AnyValue {
        get {
            return .array(
                elements.map {
                    try! AnyValue.Encoder.default.encode($0)
                }
            )
        }
        set(newValue) {
            guard case .array(_) = newValue else {
                fatalError("SetWrapper must contain an array")
            }
        }
    }

    public static var TAG: UInt64 { 258 }

    public var count: Int { return elements.count }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let cborData = try container.decode(CBOR.self)

        if case let .tagged(tag, value) = cborData {
            guard tag.rawValue == Self.TAG else {
                throw CardanoCoreError.valueError(
                    "Invalid CBOR tag: expected \(Self.TAG ) but found \(tag.rawValue)")
            }

            guard case let .array(arrayData) = value else {
                throw CardanoCoreError.valueError("SetWrapper must contain an array")
            }

            let decodedElements = try arrayData.map {
                let data = try CBORSerialization.data(from: $0)
                let element = try CBORDecoder().decode(
                    Element.self,
                    from: data
                )
                return element
            }
            let elements = Set(decodedElements)
            try self.init(
                tag: tag.rawValue,
                value: AnyValue.array(
                    elements.map {
                        try! AnyValue.Encoder.default.encode($0)
                    }
                )
            )
            self.elements = elements
        } else if case let .array(arrayData) = cborData {
            let decodedElements = try arrayData.map {
                try CBOR.Decoder.default.decode(Element.self, from: $0.unwrapped as! Data)
            }
            let elements = Set(decodedElements)
            try self.init(
                tag: Self.TAG,
                value:
                    AnyValue
                    .array(elements.map { try! AnyValue.wrapped($0) })
            )
        } else {
            throw CardanoCoreError.valueError("Invalid CBOR format for SetWrapper")
        }
    }

    public func contains(_ element: Element) -> Bool {
        return elements.contains(element)
    }
}

public struct CBORSet<T: CBORSerializable & Hashable>: SetTaggable {
    public typealias Element = T
    public var elements: Set<Element> = Set()

    public init(tag: UInt64 = 258, value: AnyValue) {
        guard tag == Self.TAG else {
            fatalError("Invalid CBOR tag: expected \(Self.TAG) but found \(tag)")
        }
        self.value = value
        self.elements = Set(
            value.arrayValue!.map {
                try! AnyValue.Decoder.default.decode(Element.self, from: $0)
                //            try! CBOR.Decoder.default.decode(Element.self, from: $0)
            })
    }

    public init(_ elements: Set<Element>) {
        self.init(
            tag: Self.TAG,
            value:
                AnyValue
                .array(
                    elements.map {
                        try! AnyValue.Encoder.default.encode($0)
                    })
        )
        self.elements = elements
    }
}

public struct NonEmptyCBORSet<T: CBORSerializable & Hashable>: SetTaggable {
    public typealias Element = T
    public var elements: Set<Element> = Set()

    public init(_ elements: [Element]) {
        precondition(!elements.isEmpty, "NonEmptyCBORSet must contain at least one element")
        self.elements = Set(elements)
    }

    public init(tag: UInt64 = 258, value: AnyValue) {
        precondition(
            (value.isEmpty == nil) || (value.isEmpty == false),
            "NonEmptySet must contain at least one element"
        )
        guard tag == Self.TAG else {
            fatalError("Invalid CBOR tag: expected \(Self.TAG) but found \(tag)")
        }
        self.value = value
        self.elements = Set(
            value.arrayValue!.map {
                try! CBOR.Decoder.default.decode(Element.self, from: $0.unwrapped as! Data)
            })
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let cborData = try container.decode(CBOR.self)

        if case let .tagged(tag, value) = cborData {
            guard tag.rawValue == Self.TAG else {
                throw CardanoCoreError.valueError(
                    "Invalid CBOR tag: expected 258 but found \(tag.rawValue)")
            }

            guard case let .array(arrayData) = value, !arrayData.isEmpty else {
                throw CardanoCoreError.valueError("NonEmptySet must contain at least one element")
            }

            let decodedElements = arrayData.map {
                $0.unwrapped
            }

            self.init(
                tag: Self.TAG,
                value:
                    AnyValue
                    .array(decodedElements.map { try! AnyValue.wrapped($0) })
            )
        } else if case let .array(arrayData) = cborData, !arrayData.isEmpty {
            let decodedElements = try arrayData.map {
                try CBOR.Decoder.default.decode(Element.self, from: $0.unwrapped as! Data)
            }

            let elements = Set(decodedElements)
            self.init(
                tag: Self.TAG,
                value:
                    AnyValue
                    .array(elements.map { try! AnyValue.wrapped($0) })
            )
        } else {
            throw CardanoCoreError.valueError("Invalid CBOR format for NonEmptySet")
        }
    }
}

public struct NonEmptyOrderedCBORSet<T: CBORSerializable & Hashable>: SetTaggable {
    public typealias Element = T
    public var elements: Set<Element> = Set()
    public var elementsOrdered: [Element] {
        Array(Set(elements))
    }

    public init(tag: UInt64 = Self.TAG, value: AnyValue) {
        precondition(
            (value.isEmpty == nil) || (value.isEmpty == false),
            "NonEmptySet must contain at least one element"
        )
        guard tag == Self.TAG else {
            fatalError("Invalid CBOR tag: expected \(Self.TAG) but found \(tag)")
        }
        self.value = value
        self.elements = Set(
            value.arrayValue!.map {
                try! AnyValue.Decoder.default.decode(Element.self, from: $0)
            })
    }

    public init(_ elements: [Element]) {
        precondition(!elements.isEmpty, "NonEmptyOrderedSet must contain at least one element")
        self.elements = Set(elements)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let cborData = try container.decode(CBOR.self)

        if case let .tagged(tag, value) = cborData {
            guard tag.rawValue == Self.TAG else {
                throw CardanoCoreError.valueError(
                    "Invalid CBOR tag: expected \(Self.TAG) but found \(tag.rawValue)")
            }

            guard case let .array(arrayData) = value, !arrayData.isEmpty else {
                throw CardanoCoreError.valueError(
                    "NonEmptyOrderedSet must contain at least one element")
            }

            let decodedElements = arrayData.map {
                $0.unwrapped
            }

            self.init(
                tag: Self.TAG,
                value:
                    AnyValue
                    .array(decodedElements.map { try! AnyValue.wrapped($0) })
            )
        } else if case let .array(arrayData) = cborData, !arrayData.isEmpty {
            let decodedElements = arrayData.map {
                $0.unwrapped as! Element
            }
            let elements = Array(Set(decodedElements))
            self.init(
                tag: Self.TAG,
                value:
                    AnyValue
                    .array(elements.map { try! AnyValue.wrapped($0) })
            )
        } else {
            throw CardanoCoreError.valueError("Invalid CBOR format for NonEmptyOrderedSet")
        }
    }
}

// MARK: - Era Enum
public enum Era: String, CBORSerializable, Equatable {
    case byron
    case shelley
    case allegra
    case mary
    case alonzo
    case babbage
    case conway
}

// MARK: - HashableKey
public struct HashableKey<T: CBORSerializable & Hashable>: CBORSerializable, Equatable {
    public typealias Element = T
    public var value: Element

    public init(_ value: Element) {
        self.value = value
    }
}

// MARK: - Primitive Enum

public indirect enum Primitive: CBORSerializable, Equatable, Hashable {
    case bytes(Data)
    case byteArray([UInt8])
    case string(String)
    case int(Int)
    case float(Double)
    case decimal(Decimal)
    case bool(Bool)
    case none
    case tuple((Primitive, Primitive))
    case list([Primitive])
    case indefiniteList(IndefiniteList<Primitive>)
    case dict([Primitive: Primitive])
    case orderedDict(OrderedDictionary<Primitive, Primitive>)
    case datetime(Date)
    case regex(NSRegularExpression)
    case cborSimpleValue(CBOR)
    case cborTag(CBORTag)
    case set(CBORSet<Primitive>)
    case fraction(Fraction)
    case frozenSet(Set<Primitive>)
    case frozenDict([Primitive: Primitive])
    case frozenList([Primitive])
    case indefiniteFrozenList(IndefiniteList<Primitive>)
    case byteString(ByteString)
    case plutusData(PlutusData)
    case null
    
    /// Convert an arbitrary value to a Primitive.
    public static func fromAny(_ value: Any) throws -> Primitive {
        switch value {
        case let v as Primitive:
            return v
        case let v as Int:
            return .int(v)
        case let v as UInt8:
            return .int(Int(v))
        case let v as UInt:
            return .int(Int(v))
        case let v as Int8:
            return .int(Int(v))
        case let v as Int16:
            return .int(Int(v))
        case let v as Int32:
            return .int(Int(v))
        case let v as Int64:
            return .int(Int(v))
        case let v as UInt16:
            return .int(Int(v))
        case let v as UInt32:
            return .int(Int(v))
        case let v as UInt64:
            return .int(Int(v))
        case let v as Double:
            return .float(v)
        case let v as Float:
            return .float(Double(v))
        case let v as Decimal:
            return .decimal(v)
        case let v as Bool:
            return .bool(v)
        case let v as String:
            return .string(v)
        case let v as Data:
            return .bytes(v)
        case let v as [UInt8]:
            return .byteArray(v)
        case let v as [Any]:
            return .list(try v.map { try Primitive.fromAny($0) })
        case let v as [AnyHashable: Any]:
            var dict: [Primitive: Primitive] = [:]
            for (key, value) in v {
                let keyPrimitive = try Primitive.fromAny(key)
                let valuePrimitive = try Primitive.fromAny(value)
                dict[keyPrimitive] = valuePrimitive
            }
            return .dict(dict)
        case let v as Date:
            return .datetime(v)
        case let v as NSRegularExpression:
            return .regex(v)
        case let v as ByteString:
            return .byteString(v)
        case let v as Fraction:
            return .fraction(v)
        case let v as CBORTag:
            return .cborTag(v)
        case let v as CBOR:
            return .cborSimpleValue(v)
        case let v as PlutusData:
            return .plutusData(v)
        case Optional<Any>.none:
            return .none
        default:
            throw CardanoCoreError.typeError("Cannot convert type \(type(of: value)) to Primitive")
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let cbor = try container.decode(CBOR.self)
        self = try Primitive.from(cbor: cbor)
    }
    
    private static func from(cbor: CBOR) throws -> Primitive {
        switch cbor {
            case .byteString(let data):
                return .bytes(data)
            case .utf8String(let string):
                return .string(string)
            case .unsignedInt(let value):
                return .int(Int(value))
            case .negativeInt(let value):
                return .int(Int(bitPattern: ~UInt(value)))
            case .float(let value):
                return .float(Double(value))
            case .double(let value):
                return .float(value)
            case .boolean(let value):
                return .bool(value)
            case .null:
                return .none
            case .array(let array):
                let primitives = try array.map { try Primitive.from(cbor: $0) }
                return .list(primitives)
            case .indefiniteArray(let array):
                let primitives = try array.map { try Primitive.from(cbor: $0) }
                return .indefiniteList(IndefiniteList(primitives))
            case .map(let map):
                var dict: [Primitive: Primitive] = [:]
                for (key, value) in map {
                    dict[try Primitive.from(cbor: key)] = try Primitive.from(cbor: value)
                }
                return .dict(dict)
            case .indefiniteMap(let map):
                var dict: [Primitive: Primitive] = [:]
                for (key, value) in map {
                    dict[try Primitive.from(cbor: key)] = try Primitive.from(cbor: value)
                }
                return .dict(dict)
            case .simple(let simple):
                return .cborSimpleValue(.simple(simple))
            case .tagged(let tag, let value):
                if tag.rawValue == UInt64(Fraction.tag) {
                    let fraction = Fraction(
                        numerator: value.arrayValue![0].unwrapped as! Int,
                        denominator: value.arrayValue![1].unwrapped as! Int
                    )
                    return .fraction(fraction)
                } else if tag == CBOR.Tag.iso8601DateTime {
                    guard let date = value.unwrapped else {
                        throw CardanoCoreError.valueError("Invalid date format")
                    }
                    return .datetime(
                        Date(timeIntervalSince1970: date as! TimeInterval)
                    )
                } else if tag == CBOR.Tag.epochDateTime {
                    guard let date = value.unwrapped else {
                        throw CardanoCoreError.valueError("Invalid date format")
                    }
                    return .datetime(
                        Date(timeIntervalSince1970: date as! TimeInterval)
                    )
                }
                
                let wrapped = CBORTag(tag: tag.rawValue, value: try AnyValue.wrapped(value.unwrapped))
                return .cborTag(wrapped)
            case .indefiniteByteString(let string):
                return .bytes(string)
            case .indefiniteUtf8String(let string):
                return .string(string)
            case .undefined:
                return .none
            case .half(let value):
                return .float(Double(value))
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(try toCBOR())
    }
    
    private func toCBOR() throws -> CBOR {
        switch self {
            case .bytes(let data):
                return .byteString(data)
            case .byteArray(let array):
                return .byteString(Data(array))
            case .string(let string):
                return .utf8String(string)
            case .int(let value):
                return value >= 0 ? .unsignedInt(UInt64(value)) : .negativeInt(~UInt64(bitPattern: Int64(value)))
            case .float(let value):
                return .double(value)
            case .decimal(let decimal):
                return .utf8String(decimal.description)
            case .bool(let value):
                return .boolean(value)
            case .none:
                return .null
            case .tuple(let (a, b)):
                return .array([try a.toCBOR(), try b.toCBOR()])
            case .list(let list):
                return .array(try list.map { try $0.toCBOR() })
            case .indefiniteList(let list):
                return .indefiniteArray(try list.getAll().map { try $0.toCBOR() })
            case .dict(let dict):
                return .map(OrderedDictionary(uniqueKeysWithValues: try dict.map { (try $0.key.toCBOR(), try $0.value.toCBOR()) }))
            case .orderedDict(let dict):
                return .map(OrderedDictionary(uniqueKeysWithValues: try dict.map { (try $0.key.toCBOR(), try $0.value.toCBOR()) }))
            case .datetime(let date):
                return try CBOREncoder().encode(date).toCBOR
            case .regex(let regex):
                return .utf8String(regex.pattern)
            case .cborSimpleValue(let simple):
                return simple
            case .cborTag(let tag):
                return .tagged(CBOR.Tag(rawValue: tag.tag), try CBOREncoder().encode(tag.value).toCBOR)
            case .set(let set):
                return .array(try set.elements.map { try $0.toCBOR() })
            case .fraction(let fraction):
                return .tagged(CBOR.Tag(rawValue: UInt64(Fraction.tag)), .array([
                    .unsignedInt(UInt64(fraction.numerator)),
                    .unsignedInt(UInt64(fraction.denominator))
                ]))
            case .frozenSet(let set):
                return .array(try set.map { try $0.toCBOR() })
            case .frozenDict(let dict):
                return .map(OrderedDictionary(uniqueKeysWithValues: try dict.map { (try $0.key.toCBOR(), try $0.value.toCBOR()) }))
            case .frozenList(let list):
                return .array(try list.map { try $0.toCBOR() })
            case .indefiniteFrozenList(let list):
                return .indefiniteArray(try list.getAll().map { try $0.toCBOR() })
            case .byteString(let byteString):
                return .byteString(byteString.value)
            case .plutusData(let plutusData):
                return try plutusData.toCBOR().toCBOR
            case .null:
                return CBOR.null
        }
    }
    
    public static func == (lhs: Primitive, rhs: Primitive) -> Bool {
        switch (lhs, rhs) {
            case (.bytes(let a), .bytes(let b)):
                return a == b
            case (.byteArray(let a), .byteArray(let b)):
                return a == b
            case (.string(let a), .string(let b)):
                return a == b
            case (.int(let a), .int(let b)):
                return a == b
            case (.float(let a), .float(let b)):
                return a == b
            case (.decimal(let a), .decimal(let b)):
                return a == b
            case (.bool(let a), .bool(let b)):
                return a == b
            case (.none, .none):
                return true
            case (.tuple(let a), .tuple(let b)):
                return a == b
            case (.list(let a), .list(let b)):
                return a == b
            case (.indefiniteList(let a), .indefiniteList(let b)):
                return a == b
            case (.dict(let a), .dict(let b)):
                return a == b
            case (.orderedDict(let a), .orderedDict(let b)):
                return a == b
            case (.datetime(let a), .datetime(let b)):
                return a == b
            case (.regex(let a), .regex(let b)):
                return a.pattern == b.pattern // NSRegularExpression compare patterns
            case (.cborSimpleValue(let a), .cborSimpleValue(let b)):
                return a == b
            case (.cborTag(let a), .cborTag(let b)):
                return a == b
            case (.set(let a), .set(let b)):
                return a == b
            case (.fraction(let a), .fraction(let b)):
                return a == b
            case (.frozenSet(let a), .frozenSet(let b)):
                return a == b
            case (.frozenDict(let a), .frozenDict(let b)):
                return a == b
            case (.frozenList(let a), .frozenList(let b)):
                return a == b
            case (.indefiniteFrozenList(let a), .indefiniteFrozenList(let b)):
                return a == b
            case (.byteString(let a), .byteString(let b)):
                return a == b
            default:
                return false
        }
    }
    
    public func hash(into hasher: inout Hasher) {
        switch self {
            case .bytes(let data):
                hasher.combine(0)
                hasher.combine(data)
            case .byteArray(let array):
                hasher.combine(1)
                hasher.combine(array)
            case .string(let str):
                hasher.combine(2)
                hasher.combine(str)
            case .int(let intVal):
                hasher.combine(3)
                hasher.combine(intVal)
            case .float(let floatVal):
                hasher.combine(4)
                hasher.combine(floatVal)
            case .decimal(let decimalVal):
                hasher.combine(5)
                hasher.combine(decimalVal)
            case .bool(let boolVal):
                hasher.combine(6)
                hasher.combine(boolVal)
            case .none:
                hasher.combine(7)
            case .tuple(let tupleVal):
                hasher.combine(8)
                hasher.combine(tupleVal.0)
                hasher.combine(tupleVal.1)
            case .list(let listVal):
                hasher.combine(9)
                hasher.combine(listVal)
            case .indefiniteList(let listVal):
                hasher.combine(10)
                hasher.combine(listVal)
            case .dict(let dictVal):
                hasher.combine(11)
                hasher.combine(dictVal)
            case .orderedDict(let dictVal):
                hasher.combine(12)
                hasher.combine(dictVal)
            case .datetime(let dateVal):
                hasher.combine(13)
                hasher.combine(dateVal)
            case .regex(let regexVal):
                hasher.combine(14)
                hasher.combine(regexVal.pattern)
            case .cborSimpleValue(let cborVal):
                hasher.combine(15)
                hasher.combine(cborVal)
            case .cborTag(let tagVal):
                hasher.combine(16)
                hasher.combine(tagVal)
            case .set(let setVal):
                hasher.combine(17)
                hasher.combine(setVal)
            case .fraction(let fractionVal):
                hasher.combine(18)
                hasher.combine(fractionVal)
            case .frozenSet(let setVal):
                hasher.combine(19)
                hasher.combine(setVal)
            case .frozenDict(let dictVal):
                hasher.combine(20)
                hasher.combine(dictVal)
            case .frozenList(let listVal):
                hasher.combine(21)
                hasher.combine(listVal)
            case .indefiniteFrozenList(let listVal):
                hasher.combine(22)
                hasher.combine(listVal)
            case .byteString(let byteStringVal):
                hasher.combine(23)
                hasher.combine(byteStringVal)
            case .plutusData(let plutusData):
                hasher.combine(24)
                hasher.combine(plutusData)
            case .null:
                hasher.combine(25)
        }
    }
    
    /// Converts this Primitive back to AnyValue, reversing the toPrimitives() mapping.
    public func toAnyValue() -> AnyValue {
        switch self {
            case .null:
                return .nil
            case .bool(let bool):
                return .bool(bool)
            case .string(let string):
                return .string(string)
            case .int(let intVal):
                return .int64(Int64(intVal))
            case .float(let floatVal):
                return .double(floatVal)
            case .decimal(let decimalVal):
                return .decimal(decimalVal)
            case .bytes(let data):
                return .data(data)
            case .byteArray(let array):
                return .data(Data(array))
            case .datetime(let date):
                return .date(date)
            case .tuple(let (a, b)):
                return .array([a.toAnyValue(), b.toAnyValue()])
            case .list(let list):
                return .array(list.map { $0.toAnyValue() })
            case .indefiniteList(let list):
                return .indefiniteArray(list.map { $0.toAnyValue() })
            case .dict(let dict):
                return .dictionary(OrderedDictionary(uniqueKeysWithValues: dict.map { ($0.key.toAnyValue(), $0.value.toAnyValue()) }))
            case .orderedDict(let dict):
                return .dictionary(OrderedDictionary(uniqueKeysWithValues: dict.map { ($0.key.toAnyValue(), $0.value.toAnyValue()) }))
            case .regex(let regex):
                return .string(regex.pattern)
            case .cborSimpleValue(let cbor):
                return try! AnyValue.wrapped(cbor)
            case .cborTag(let tag):
                return tag.value
            case .set(let set):
                return .array(set.elements.map { $0.toAnyValue() })
            case .fraction(let fraction):
                return .array([.int(fraction.numerator), .int(fraction.denominator)])
            case .frozenSet(let set):
                return .array(set.map { $0.toAnyValue() })
            case .frozenDict(let dict):
                return .dictionary(OrderedDictionary(uniqueKeysWithValues: dict.map { ($0.key.toAnyValue(), $0.value.toAnyValue()) }))
            case .frozenList(let list):
                return .array(list.map { $0.toAnyValue() })
            case .indefiniteFrozenList(let list):
                return .indefiniteArray(list.map { $0.toAnyValue() })
            case .byteString(let byteString):
                return .data(byteString.value)
            case .plutusData(let plutus):
                return try! AnyValue.wrapped(plutus)
            case .none:
                return .nil
        }
    }
}
