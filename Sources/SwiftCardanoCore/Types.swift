import Foundation
import PotentCBOR
import PotentCodables

// MARK: - Types Aliases
typealias Coin = UInt64
typealias RewardAccount = Data
typealias SlotNumber = UInt64

// Represents a 4-byte unsigned integer
typealias EpochInterval = UInt32

// Represents an 8-byte unsigned integer
typealias EpochNumber = UInt64

// MARK: - PositiveCoin
struct PositiveCoin: Codable {
    let value: UInt
    
    init(_ value: UInt) {
        precondition(value > 0, "PositiveCoin must be greater than 0")
        self.value = value
    }
}

// MARK: - NonEmptySet
struct NonEmptySet<Element> {
    var elements: [Element]
    
    init(elements: [Element]) {
        precondition(!elements.isEmpty, "NonEmptySet must contain at least one element")
        self.elements = elements
    }
}

// MARK: - ExUnitPrices
struct ExUnitPrices: Codable {
    var memPrice: NonNegativeInterval
    var stepPrice: NonNegativeInterval
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        memPrice = try container.decode(NonNegativeInterval.self)
        stepPrice = try container.decode(NonNegativeInterval.self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(memPrice)
        try container.encode(stepPrice)
    }
}

// MARK: - ExUnits
struct ExUnits: Codable {
    var mem: UInt
    var steps: UInt
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        mem = try container.decode(UInt.self)
        steps = try container.decode(UInt.self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(mem)
        try container.encode(steps)
    }
}

// MARK: - ProtocolVersion
struct ProtocolVersion: Codable {
    var major: Int?
    var minor: Int?
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        major = try container.decode(Int.self)
        minor = try container.decode(Int.self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(major)
        try container.encode(minor)
    }
}

// MARK: - NonNegativeInterval
struct NonNegativeInterval: Codable {
    var lowerBound: UInt
    var upperBound: UInt64
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        lowerBound = try container.decode(UInt.self)
        upperBound = try container.decode(UInt64.self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(lowerBound)
        try container.encode(upperBound)
    }
}

// MARK: - UnitInterval
/// A unit interval is a number in the range between 0 and 1
struct UnitInterval: Codable {
    let numerator: UInt
    let denominator: UInt
    
    init(numerator: UInt, denominator: UInt) {
        precondition(numerator <= denominator, "Numerator must be less than or equal to denominator")
        precondition(denominator > 0, "Denominator must be greater than zero")
        self.numerator = numerator
        self.denominator = denominator
    }
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let numerator = try container.decode(UInt.self)
        let denominator = try container.decode(UInt.self)
        self.init(numerator: numerator, denominator: denominator)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(numerator)
        try container.encode(denominator)
    }
}

// MARK: - Url
struct Url {
    let value: URL
    
    init(_ value: String) throws {
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
struct Anchor: Codable {
    let anchorUrl: Url
    let anchorDataHash: AnchorDataHash
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let url = try container.decode(String.self)
        let dataHash = try container.decode(Data.self)
        
        self.anchorUrl = try Url(url)
        self.anchorDataHash = try AnchorDataHash(payload: dataHash)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(anchorUrl.value.absoluteString)
        try container.encode(anchorDataHash.payload)
    }
}

// MARK: - CBOR Tag
struct CBORTag: Codable, Equatable {
    let tag: UInt64
    let value: AnyHashable
    
    enum CodingKeys: CodingKey {
        case tag, value
    }
    
    init(tag: UInt64, value: AnyHashable) {
        self.tag = tag
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        
        // Decode the tag
        tag = try container.decode(UInt64.self)
        
        // Decode the value as a CBOR representation
        let cborData = try container.decode(Data.self)
        let cborObject = try CBORSerialization.cbor(from: cborData)
        value = cborObject.unwrapped as! AnyHashable
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        
//        let cborData = CBOR.tagged(
//            CBOR.Tag(rawValue: tag),
//            CBOR.fromAny(value)
//        )
        
        // Encode the tag
        try container.encode(tag)
        
        // Encode the value as CBOR data
        let cborData = try CBORSerialization.data(from: CBOR.fromAny(value))
        try container.encode(cborData)
    }
    
    static func == (lhs: CBORTag, rhs: CBORTag) -> Bool {
        return lhs.tag == rhs.tag && lhs.value == rhs.value
    }
}

// MARK: - ByteString
class ByteString: Hashable {
    let value: Data

    init(value: Data) {
        self.value = value
    }

    static func == (lhs: ByteString, rhs: ByteString) -> Bool {
        return lhs.value == rhs.value
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(value)
    }

    func isEqual(to other: Any) -> Bool {
        if let otherByteString = other as? ByteString {
            return self.value == otherByteString.value
        } else if let otherData = other as? Data {
            return self.value == otherData
        } else {
            return false
        }
    }
}

// MARK: - Unit
/// The default "Unit type" with a 0 constructor ID
class Unit: PlutusData {
    class override var CONSTR_ID: Any { return 0 }
}

// MARK: - IndefiniteList
class IndefiniteList<T>: Codable, Equatable where T: Hashable, T:Codable {
    private var items: [T]
    
    init(_ items: [T] = []) {
        self.items = items
    }
    
    // Adds an item to the list
    func add(_ item: T) {
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
    func remove(at index: Int) {
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
    
    static func == (lhs: IndefiniteList<T>, rhs: IndefiniteList<T>) -> Bool {
        return lhs.items == rhs.items
    }
}
