import Foundation
import CBORCodable

public struct IndefiniteList<T: Sendable>: CBORSerializable, Sendable where T: Hashable {
    /// Kept in a ``NestedStorage``, so that a list of Plutus data nested
    /// however deep is freed without recursion.
    private var storage: NestedStorage<T>

    private var items: [T] {
        get { storage.items }
        set { storage = NestedStorage(newValue) }
    }

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
    public mutating func add(_ item: T) {
        makeUnique()
        storage.items.append(item)
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
        makeUnique()
        storage.items.remove(at: index)
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
