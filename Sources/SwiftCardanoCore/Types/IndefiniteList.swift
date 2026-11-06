import Foundation
import CBORCodable

/// A list that is written to CBOR as an indefinite-length array.
///
/// The ledger accepts arrays of either length encoding, and the encoding is part of what a hash covers, so a list read as indefinite-length has to be written back that way. This type reads a definite- or indefinite-length array and always writes an indefinite-length one.
public struct IndefiniteList<T: Sendable>: CBORSerializable, Sendable where T: Hashable {
    /// Kept in a ``NestedStorage``, so that a list of Plutus data nested
    /// however deep is freed without recursion.
    private var storage: NestedStorage<T>

    private var items: [T] {
        get { storage.items }
        set { storage = NestedStorage(newValue) }
    }

    /// Creates a list from an array.
    ///
    /// - Parameter items: The elements, in order.
    public init(_ items: [T] = []) {
        self.storage = NestedStorage(items)
    }

    private mutating func makeUnique() {
        if !isKnownUniquelyReferenced(&storage) {
            storage = NestedStorage(storage.items)
        }
    }

    /// Moves the items onto `pending` when nothing else holds them.
    mutating func moveItems(into pending: inout [T]) {
        NestedStorage.move(&storage, into: &pending)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let cborData = try container.decode(CBOR.self)

        switch cborData {
            case .array(let arrayData):
                self.storage = NestedStorage(try arrayData.map { try Self.cast($0.unwrapped as Any) })
            case .indefiniteArray(let arrayData):
                self.storage = NestedStorage(try arrayData.map { try Self.cast($0.unwrapped as Any) })
            default:
                throw CardanoCoreError.valueError("IndefiniteList must be an array")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        let indefiniteArray: CBOR = .indefiniteArray(items.map { CBOR.fromAnyCardano($0) })

        try container.encode(indefiniteArray)
    }
    
    public init(from primitive: Primitive) throws {
        switch primitive {
            case .list(let elements):
                self.storage = NestedStorage(try elements.map { try Self.cast($0) })
            case .indefiniteList(let elements):
                self.storage = NestedStorage(try elements.map { try Self.cast($0) })
            default:
                throw CardanoCoreError.valueError("IndefiniteList must be an array")
        }
    }

    /// An element as a `T`, or a decoding error when it is not one.
    private static func cast(_ element: Any) throws -> T {
        guard let item = element as? T else {
            throw CardanoCoreError.deserializeError(
                "IndefiniteList element \(element) is not a \(T.self)")
        }
        return item
    }
 
    public func toPrimitive() throws -> Primitive {
        return .indefiniteList(
            IndefiniteList<Primitive>(
                try items.map { try Primitive.fromAny($0 as Any) }
            )
        )
    }

    /// The element at a position. Traps when the index is out of range.
    ///
    /// - Parameter index: The zero-based position.
    public subscript(index: Int) -> T {
        get {
            return items[index]
        }
        set {
            makeUnique()
            storage.items[index] = newValue
        }
    }

    // Adds an item to the list
    /// Appends an element to the end of the list.
    ///
    /// - Parameter item: The element to append.
    public mutating func add(_ item: T) {
        makeUnique()
        storage.items.append(item)
    }

    // Returns the item at the specified index, or nil if out of bounds
    /// The element at a position, or `nil` when the index is past the end.
    ///
    /// - Parameter index: The zero-based position, which must not be negative.
    /// - Returns: The element, or `nil`.
    public func get(at index: Int) -> T? {
        guard index < items.count else { return nil }
        return items[index]
    }

    // Returns the entire list
    /// The elements as an array.
    ///
    /// - Returns: The elements, in order.
    public func getAll() -> [T] {
        return items
    }

    // Removes the item at the specified index
    /// Removes the element at a position. Does nothing when the index is past the end.
    ///
    /// - Parameter index: The zero-based position, which must not be negative.
    public mutating func remove(at index: Int) {
        guard index < items.count else { return }
        makeUnique()
        storage.items.remove(at: index)
    }

    // Returns the count of items in the list
    /// The number of elements.
    public var count: Int {
        return items.count
    }

    // Checks if the list is empty
    /// Whether the list has no elements.
    public var isEmpty: Bool {
        return items.isEmpty
    }

    // Custom string description for easy debugging
    public var description: String {
        return "IndefiniteList: \(items)"
    }
    
    /// The elements, transformed by a closure, as an array.
    ///
    /// - Parameter transform: The closure to apply to each element.
    /// - Returns: The transformed elements, in order.
    /// - Throws: Whatever `transform` throws.
    public func map<U>(_ transform: (T) throws -> U) rethrows -> [U] {
        return try items.map(transform)
    }

    public static func == (lhs: IndefiniteList<T>, rhs: IndefiniteList<T>) -> Bool {
        return lhs.items == rhs.items
    }

    /// Whether the list holds the same elements as an array, in the same order.
    ///
    /// - Parameters:
    ///   - lhs: The list.
    ///   - rhs: The array to compare with.
    /// - Returns: `true` when the elements are equal.
    public static func == (lhs: IndefiniteList<T>, rhs: [T]) -> Bool {
        return lhs.items == rhs
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(items)
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
