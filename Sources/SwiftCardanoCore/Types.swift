import Foundation
import PotentASN1
import PotentCBOR
import PotentCodables

// MARK: - Types Aliases
public typealias Coin = UInt64
public typealias RewardAccount = Data
public typealias SlotNumber = UInt64

// Represents a 4-byte unsigned integer
public typealias EpochInterval = UInt32

// Represents an 8-byte unsigned integer
public typealias EpochNumber = UInt64

// MARK: - PositiveCoin
public struct PositiveCoin: Codable {
    let value: UInt
    
    init(_ value: UInt) {
        precondition(value > 0, "PositiveCoin must be greater than 0")
        self.value = value
    }
}

// MARK: - NonEmptySet
public struct NonEmptySet<Element> {
    var elements: [Element]
    
    init(elements: [Element]) {
        precondition(!elements.isEmpty, "NonEmptySet must contain at least one element")
        self.elements = elements
    }
}

// MARK: - ExUnitPrices
public struct ExUnitPrices: Codable, Hashable, Equatable {
    var memPrice: NonNegativeInterval
    var stepPrice: NonNegativeInterval
    
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
public struct ExUnits: Codable, Hashable, Equatable {
    var mem: UInt
    var steps: UInt
    
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
public struct ProtocolVersion: Codable, Hashable, Equatable {
    var major: Int?
    var minor: Int?
    
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
public struct NonNegativeInterval: Codable, Hashable, Equatable {
    var lowerBound: UInt
    var upperBound: UInt64
    
    public init(lowerBound: UInt, upperBound: UInt64) {
        precondition(lowerBound <= upperBound, "Lower bound must be less than or equal to upper bound")
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

// MARK: - UnitInterval
/// A unit interval is a number in the range between 0 and 1
public struct UnitInterval: Codable, Equatable, Hashable {
    let numerator: UInt
    let denominator: UInt
    
    static let tag = 30
    
    public init(numerator: UInt, denominator: UInt) {
        precondition(numerator <= denominator, "Numerator must be less than or equal to denominator")
        precondition(denominator > 0, "Denominator must be greater than zero")
        self.numerator = numerator
        self.denominator = denominator
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        let cborData = try container.decode(CBOR.self)
        
        if case let .tagged(tag, cborData) = cborData {
            guard tag.rawValue == UInt64(UnitInterval.tag) else {
                throw CardanoCoreError.valueError("UnitInterval must be tagged with tag \(UnitInterval.tag)")
            }
            
            switch cborData {
                case .array(let arrayData):
                    guard arrayData.count == 2 else {
                        throw CardanoCoreError.valueError("UnitInterval must contain exactly 2 elements")
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
                .unsignedInt(UInt64(denominator))
            ]
        )
        
        try container.encode(cborData)
    }
}

// MARK: - Url
public struct Url: Codable, Hashable {
    let value: URL
    
    var absoluteString: String {
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
public struct Anchor: Codable, Hashable {
    let anchorUrl: Url
    let anchorDataHash: AnchorDataHash
    
    public init(anchorUrl: Url, anchorDataHash: AnchorDataHash) {
        self.anchorUrl = anchorUrl
        self.anchorDataHash = anchorDataHash
    }
    
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let url = try container.decode(String.self)
        let dataHash = try container.decode(Data.self)
        
        self.anchorUrl = try Url(url)
        self.anchorDataHash =  AnchorDataHash(payload: dataHash)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(anchorUrl.value.absoluteString)
        try container.encode(anchorDataHash.payload)
    }
}

// MARK: - CBOR Tag
protocol CBORTaggable: Codable, Equatable, Hashable {
    var tag: UInt64 { get }
    var value: AnyValue { get set }
    
    init(tag: UInt64, value: AnyValue)
}

extension CBORTaggable {
    public func toCBOR() -> CBOR {
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
        return Self(
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
            self.init(tag: tag, value: value)
        } else {
            throw CardanoCoreError.valueError("CBORTag must be tagged")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(toCBOR())
    }
    
    public static func == (lhs: any CBORTaggable, rhs: any CBORTaggable) -> Bool {
        return lhs.tag == rhs.tag && lhs.value == rhs.value
    }
}

public struct CBORTag: CBORTaggable {
    var tag: UInt64
    var value: AnyValue
}

// MARK: - ByteString
public struct ByteString: Hashable {
    let value: Data

    init(value: Data) {
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

// MARK: - IndefiniteList
public struct IndefiniteList<T>: Codable, Hashable, Equatable where T: Hashable, T:Codable {
    private var items: [T]
    
    init(_ items: [T] = []) {
        self.items = items
    }
    
    // Adds an item to the list
    mutating func add(_ item: T) {
        items.append(item)
    }
    
    // Returns the item at the specified index, or nil if out of bounds
    func get(at index: Int) -> T? {
        guard index < items.count else { return nil }
        return items[index]
    }
    
    // Returns the entire list
    func getAll() -> [T] {
        return items
    }
    
    // Removes the item at the specified index
    mutating func remove(at index: Int) {
        guard index < items.count else { return }
        items.remove(at: index)
    }
    
    // Returns the count of items in the list
    var count: Int {
        return items.count
    }
    
    // Checks if the list is empty
    var isEmpty: Bool {
        return items.isEmpty
    }
    
    // Custom string description for easy debugging
    var description: String {
        return "IndefiniteList: \(items)"
    }
    
    public static func == (lhs: IndefiniteList<T>, rhs: IndefiniteList<T>) -> Bool {
        return lhs.items == rhs.items
    }
}


// Generic wrapper for CBOR-tagged sets (tag 258)
protocol SetTaggable<Element>: CBORTaggable {
    associatedtype Element: Codable & Hashable
    
    var elements: Set<Element> { get set }
}

extension SetTaggable {
    var tag: UInt64 { 258 }
    var value: AnyValue {
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
    
    var count: Int { return elements.count }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let cborData = try container.decode(CBOR.self)

        if case let .tagged(tag, value) = cborData {
            guard tag.rawValue == Self.TAG  else {
                throw CardanoCoreError.valueError("Invalid CBOR tag: expected \(Self.TAG ) but found \(tag.rawValue)")
            }

            guard case let .array(arrayData) = value else {
                throw CardanoCoreError.valueError("SetWrapper must contain an array")
            }

            let decodedElements = try arrayData.map {
                let data = try CBORSerialization.data(from: $0)
                let element =  try CBORDecoder().decode(
                    Element.self,
                    from: data
                )
                return element
            }
            let elements = Set(decodedElements)
            self.init(
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
            self.init(
                tag: Self.TAG,
                value: AnyValue
                    .array(elements.map { try! AnyValue.wrapped($0) })
            )
        }  else {
            throw CardanoCoreError.valueError("Invalid CBOR format for SetWrapper")
        }
    }
    
    public func contains(_ element: Element) -> Bool {
        return elements.contains(element)
    }
}

public struct CBORSet<T: Codable & Hashable>: SetTaggable {
    public typealias Element = T
    public var elements: Set<Element> = Set()
    
    public init(tag: UInt64 = 258, value: AnyValue) {
        guard tag == Self.TAG else {
            fatalError("Invalid CBOR tag: expected \(Self.TAG) but found \(tag)")
        }
        self.value = value
    }
    
    public init(_ elements: Set<Element>) {
        self.init(
            tag: Self.TAG,
            value: AnyValue
                .array(elements.map {
                    try! AnyValue.Encoder.default.encode($0)
                })
        )
        self.elements = elements
    }
}

public struct NonEmptyCBORSet<T: Codable & Hashable>: SetTaggable {
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
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let cborData = try container.decode(CBOR.self)

        if case let .tagged(tag, value) = cborData {
            guard tag.rawValue == Self.TAG else {
                throw CardanoCoreError.valueError("Invalid CBOR tag: expected 258 but found \(tag.rawValue)")
            }

            guard case let .array(arrayData) = value, !arrayData.isEmpty else {
                throw CardanoCoreError.valueError("NonEmptySet must contain at least one element")
            }
            
            let decodedElements = try arrayData.map {
                try CBOR.Decoder.default.decode(Element.self, from: $0.unwrapped as! Data)
            }
            
            let elements = Set(decodedElements)
            self.init(
                tag: Self.TAG,
                value: AnyValue
                    .array(elements.map { try! AnyValue.wrapped($0) })
            )
        } else if case let .array(arrayData) = cborData, !arrayData.isEmpty {
            let decodedElements = try arrayData.map {
                try CBOR.Decoder.default.decode(Element.self, from: $0.unwrapped as! Data)
            }
            
            let elements = Set(decodedElements)
            self.init(
                tag: Self.TAG,
                value: AnyValue
                    .array(elements.map { try! AnyValue.wrapped($0) })
            )
        } else {
            throw CardanoCoreError.valueError("Invalid CBOR format for NonEmptySet")
        }
    }
}

struct NonEmptyOrderedCBORSet<T: Codable & Hashable>: SetTaggable  {
    typealias Element = T
    var elements: Set<Element> = Set()
    var elementsOrdered: [Element] = []
    
    init(tag: UInt64 = Self.TAG, value: AnyValue) {
        precondition(
            (value.isEmpty == nil) || (value.isEmpty == false),
            "NonEmptySet must contain at least one element"
        )
        guard tag == Self.TAG else {
            fatalError("Invalid CBOR tag: expected \(Self.TAG) but found \(tag)")
        }
        self.value = value
    }

    init(_ elements: [Element]) {
        precondition(!elements.isEmpty, "NonEmptyOrderedSet must contain at least one element")
        self.elements = Set(elements)
        self.elementsOrdered = Array(Set(elements)) // Ensure uniqueness while preserving order
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let cborData = try container.decode(CBOR.self)

        if case let .tagged(tag, value) = cborData {
            guard tag.rawValue == Self.TAG else {
                throw CardanoCoreError.valueError("Invalid CBOR tag: expected \(Self.TAG) but found \(tag.rawValue)")
            }

            guard case let .array(arrayData) = value, !arrayData.isEmpty else {
                throw CardanoCoreError.valueError("NonEmptyOrderedSet must contain at least one element")
            }

            let decodedElements = arrayData.map {
                $0.unwrapped as! Element
            }
            
            let elements = Array(Set(decodedElements))
            self.init(
                tag: Self.TAG,
                value: AnyValue
                    .array(elements.map { try! AnyValue.wrapped($0) })
            )
        } else if case let .array(arrayData) = cborData, !arrayData.isEmpty {
            let decodedElements = arrayData.map {
                $0.unwrapped as! Element
            }
            let elements = Array(Set(decodedElements))
            self.init(
                tag: Self.TAG,
                value: AnyValue
                    .array(elements.map { try! AnyValue.wrapped($0) })
            )
        } else {
            throw CardanoCoreError.valueError("Invalid CBOR format for NonEmptyOrderedSet")
        }
    }
}


// MARK: - Era Enum
public enum Era: String, Codable, Equatable {
    case byron
    case shelley
    case allegra
    case mary
    case alonzo
    case babbage
    case conway
}
