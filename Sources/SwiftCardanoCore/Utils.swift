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

struct ProtocolVersion: Codable {
    var major: Int?
    var minor: Int?
}

struct NonNegativeInterval {
    var uint: UInt
    var positiveInt: UInt64
    
    init(uint: UInt, positiveInt: UInt64) {
        self.uint = uint
        self.positiveInt = positiveInt
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
}

struct Url {
    let value: URL
    
    init?(_ value: URL) throws {
        guard value.absoluteString.count <= 128 else {
            throw CardanoCoreError.valueError("URL exceeds the maximum length of 128 characters.")
        }
        self.value = value
    }
}

struct Anchor: ArrayCBORSerializable {
    let anchorUrl: Url
    let anchorDataHash: AnchorDataHash
    
    static func fromPrimitive<T>(_ value: Any) throws -> T {
        <#code#>
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

class IndefiniteList<T> {
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
}

func hasAttribute(_ object: Any, propertyName: String) -> Bool {
    let mirror = Mirror(reflecting: object)
    return mirror.children.contains { $0.label == propertyName }
}

func getAttribute(_ object: Any, propertyName: String) -> Any? {
    let mirror = Mirror(reflecting: object)
    for child in mirror.children {
        if child.label == propertyName {
            return child.value
        }
    }
    return nil
}
func setAttribute(_ object: Any, propertyName: String, value: Any) -> Any? {
    let mirror = Mirror(reflecting: object)
    for child in mirror.children {
        if child.label == propertyName {
            if let object = object as? NSObject {
                object.setValue(value, forKey: propertyName)
                return true
            }
        }
    }
    return false
}

//func setAttribute(_ object: AnyObject, propertyName: String, value: Any) -> Bool {
//    var mirror: Mirror? = Mirror(reflecting: object)
//    
//    while let currentMirror = mirror {
//        for child in currentMirror.children {
//            if child.label == propertyName {
//                if let object = object as? NSObject {
//                    // Use Key-Value Coding if possible
//                    object.setValue(value, forKey: propertyName)
//                    return true
//                }
//            }
//        }
//        mirror = currentMirror.superclassMirror
//    }
//    return false
//}
