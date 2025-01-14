import Foundation

typealias Coin = UInt64
typealias RewardAccount = Data
typealias SlotNumber = UInt64

struct PositiveCoin {
    let value: UInt
    
    init(_ value: UInt) {
        precondition(value > 0, "PositiveCoin must be greater than 0")
        self.value = value
    }
}

struct NonEmptySet<Element> {
    var elements: [Element]
    
    init(elements: [Element]) {
        precondition(!elements.isEmpty, "NonEmptySet must contain at least one element")
        self.elements = elements
    }
}

// Represents a 4-byte unsigned integer
typealias EpochInterval = UInt32

// Represents an 8-byte unsigned integer
typealias EpochNumber = UInt64

struct ProtocolVersion: ArrayCBORSerializable {
    var major: Int?
    var minor: Int?
    
    static func fromPrimitive<T>(_ value: Any) throws -> T {
        var major: Int
        var minor: Int
        
        if let list = value as? [Any] {
            major = list[0] as! Int
            minor = list[1] as! Int
        } else if let tuple = value as? (Any, Any, Any, Any) {
            major = tuple.0 as! Int
            minor = tuple.1 as! Int
        } else {
            throw CardanoCoreError.deserializeError("Invalid ProtocolVersion data: \(value)")
        }
        
        return ProtocolVersion(
            major: major,
            minor: minor
        ) as! T
    }
}

struct NonNegativeInterval: ArrayCBORSerializable {
    var lowerBound: UInt
    var upperBound: UInt64
    
    init(lowerBound: UInt, upperBound: UInt64) {
        self.lowerBound = lowerBound
        self.upperBound = upperBound
    }
    
    static func fromPrimitive<T>(_ value: Any) throws -> T {
        guard let list = value as? [Int], list.count == 2 else {
            throw CardanoCoreError
                .decodingError(
                    "Invalid NonNegativeInterval data: \(value)"
                )
        }
        
        return NonNegativeInterval(
            lowerBound: UInt(list[0]),
            upperBound: UInt64(list[1])
        ) as! T
    }
}

/// A unit interval is a number in the range between 0 and 1
struct UnitInterval {
    let numerator: UInt
    let denominator: UInt
    
    init(numerator: UInt, denominator: UInt) {
        precondition(numerator <= denominator, "Numerator must be less than or equal to denominator")
        precondition(denominator > 0, "Denominator must be greater than zero")
        self.numerator = numerator
        self.denominator = denominator
    }
    
    static func fromPrimitive<T>(_ value: Any) throws -> T {
        guard let list = value as? [Int], list.count == 2 else {
            throw CardanoCoreError
                .decodingError(
                    "Invalid UnitInterval data: \(value)"
                )
        }
        
        return UnitInterval(
            numerator: UInt(list[0]),
            denominator: UInt(list[1])
        ) as! T
    }
}

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

struct Anchor: ArrayCBORSerializable {
    let anchorUrl: Url
    let anchorDataHash: AnchorDataHash
    
    static func fromPrimitive<T>(_ value: Any) throws -> T {
        var url: String
        var dataHash: Data
        
        if let list = value as? [Any] {
            url = list[0] as! String
            dataHash = list[1] as! Data
        } else if let tuple = value as? (Any, Any) {
            url = tuple.0 as! String
            dataHash = tuple.1 as! Data
        } else {
            throw CardanoCoreError.deserializeError("Invalid Anchor data: \(value)")
        }
        
        return Anchor(
            anchorUrl: try Url(url),
            anchorDataHash: try AnchorDataHash(payload: dataHash)
        ) as! T
    }

}

struct CBORTag {
    let tag: Int
    let value: Any
}

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

/// The default "Unit type" with a 0 constructor ID
class Unit: PlutusData {
    class override var CONSTR_ID: Any { return 0 }
}

class IndefiniteList<T>: Equatable where T: Hashable {
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
