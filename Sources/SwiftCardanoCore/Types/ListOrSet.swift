import Foundation
import OrderedCollections

/// A type that can represent transaction inputs as either an array or an OrderedSet
public enum ListOrOrderedSet<T: Serializable>: Serializable {
    public typealias Element = T

    case list([Element])
    case orderedSet(OrderedSet<Element>)
    case indefiniteList(IndefiniteList<Element>)
    /// A `#6.258` set whose payload was written as an *indefinite-length* array.
    ///
    /// Kept distinct from `.orderedSet` so the value re-encodes to the same bytes
    /// it was decoded from. Collapsing it into `.orderedSet` would emit a
    /// definite-length array and change the transaction hash.
    case indefiniteOrderedSet(IndefiniteList<Element>)

    public var count: Int {
        switch self {
            case .list(let array):
                return array.count
            case .orderedSet(let set):
                return set.count
            case .indefiniteList(let indefiniteList), .indefiniteOrderedSet(let indefiniteList):
                return indefiniteList.count
        }
    }

    public var asArray: [Element] {
        switch self {
            case .list(let array):
                return array
            case .orderedSet(let set):
                return set.elementsOrdered
            case .indefiniteList(let indefiniteList), .indefiniteOrderedSet(let indefiniteList):
                return indefiniteList.map { $0 }
        }
    }
    
    public func asIndefiniteList() throws -> IndefiniteList<Element> {
        switch self {
            case .list(let array):
                return IndefiniteList(array)
            case .orderedSet(let set):
                return IndefiniteList(set.elementsOrdered)
            case .indefiniteList(let indefiniteList), .indefiniteOrderedSet(let indefiniteList):
                return indefiniteList
        }
    }

    public func asOrderedSet() throws -> OrderedSet<Element> {
        switch self {
            case .list(let array):
                return try OrderedSet(array)
            case .orderedSet(let set):
                return set
            case .indefiniteList(let indefiniteList), .indefiniteOrderedSet(let indefiniteList):
                return try OrderedSet(indefiniteList.map { $0 })
        }
    }

    // Add a non-throwing version that returns nil on error for convenience
    public func asOrderedSetSafe() -> OrderedSet<Element>? {
        do {
            return try asOrderedSet()
        } catch {
            return nil
        }
    }

    // MARK: - CBORSerializable

    public init(from primitive: Primitive) throws {
        switch primitive {
            case .list(let elements):
                self = .list(try elements.map { try T.init(from: $0) })
            case .indefiniteList(let elements):
                self = .indefiniteList(IndefiniteList(try elements.map { try T.init(from: $0) }))
            case .orderedSet(let set):
                self = .orderedSet(
                    try OrderedSet(
                        try set.elementsOrdered.map { try T.init(from: $0) }
                    )
                )
            case .cborTag(let tag):
                guard tag.tag == 258 else {
                    throw CardanoCoreError.valueError("Invalid ListOrOrderedSet CBOR tag")
                }
                switch tag.value {
                    case .list(let elements):
                        self = .orderedSet(
                            try OrderedSet(try elements.map { try T.init(from: $0) })
                        )
                    case .indefiniteList(let elements):
                        self = .indefiniteOrderedSet(
                            IndefiniteList(try elements.getAll().map { try T.init(from: $0) })
                        )
                    default:
                        throw CardanoCoreError.deserializeError(
                            "A #6.258 set tag has to wrap a list, but this one wrapped \(tag.value)"
                        )
                }
            default:
                throw CardanoCoreError.valueError("Invalid ListOrOrderedSet type")
        }
    }

    public func toPrimitive() throws -> Primitive {
        switch self {
            case .list(let array):
                return .list(try array.map { try $0.toPrimitive() })
            case .orderedSet(let set):
                let primitives = try set.elementsOrdered.map { try $0.toPrimitive() }
                return .orderedSet(try OrderedSet(primitives))
            case .indefiniteList(let indefiniteList):
                return .indefiniteList(IndefiniteList(try indefiniteList.map { try $0.toPrimitive() }))
            case .indefiniteOrderedSet(let indefiniteList):
                // Re-emit `#6.258` around an indefinite-length array, byte-for-byte
                // as it was decoded.
                return .cborTag(
                    CBORTag(
                        tag: 258,
                        value: .indefiniteList(
                            IndefiniteList(try indefiniteList.map { try $0.toPrimitive() })
                        )
                    )
                )
        }
    }

    // MARK: - JSONSerializable

    public static func fromDict(_ primitive: Primitive) throws -> ListOrOrderedSet<T> {
        guard case let .list(elements) = primitive else {
            throw CardanoCoreError.deserializeError("Expected list primitive for ListOrOrderedSet")
        }

        let items = try elements.map { try T.fromDict($0) }
        return .list(items)
    }

    public func toDict() throws -> Primitive {
        let elements = self.asArray
        return .list(try elements.map { try $0.toDict() })
    }


    public func contains(_ element: Element) -> Bool {
        switch self {
            case .list(let array):
                return array.contains(element)
            case .orderedSet(let set):
                return set.contains(element)
            case .indefiniteList(let indefiniteList), .indefiniteOrderedSet(let indefiniteList):
                return indefiniteList.contains(element)
        }
    }

    public mutating func append(_ element: Element) throws {
        switch self {
            case .list(var array):
                array.append(element)
                self = .list(array)
            case .orderedSet(var set):
                set.append(element)
                self = .orderedSet(set)
            case .indefiniteList(var indefiniteList):
                indefiniteList.add(element)
                self = .indefiniteList(indefiniteList)
            case .indefiniteOrderedSet(var indefiniteList):
                indefiniteList.add(element)
                self = .indefiniteOrderedSet(indefiniteList)
        }
    }

    public subscript(_ index: Int) -> Element? {
        switch self {
            case .list(let array):
                guard index >= 0 && index < array.count else {
                    return nil
                }
                return array[index]
            case .orderedSet(let set):
                guard index >= 0 && index < set.count else {
                    return nil
                }
                return set.elementsOrdered[index]
            case .indefiniteList(let indefiniteList), .indefiniteOrderedSet(let indefiniteList):
                return indefiniteList.get(at: index)
        }
    }
}

/// A type that can represent transaction inputs as either an array or a NonEmptyOrderedSet
public enum ListOrNonEmptyOrderedSet<T: Serializable>: Serializable {
    public typealias Element = T

    case list([Element])
    case nonEmptyOrderedSet(NonEmptyOrderedSet<Element>)
    case indefiniteList(IndefiniteList<Element>)
    /// A `#6.258` set whose payload was written as an *indefinite-length* array.
    ///
    /// Kept distinct from `.nonEmptyOrderedSet` so the value re-encodes to the same
    /// bytes it was decoded from. Collapsing it into `.nonEmptyOrderedSet` would emit
    /// a definite-length array and change `script_data_hash`.
    case indefiniteNonEmptyOrderedSet(IndefiniteList<Element>)

    public var count: Int {
        switch self {
            case .list(let array):
                return array.count
            case .nonEmptyOrderedSet(let set):
                return set.count
            case .indefiniteList(let indefiniteList), .indefiniteNonEmptyOrderedSet(let indefiniteList):
                return indefiniteList.count
        }
    }

    public var asList: [Element] {
        switch self {
            case .list(let array):
                return array
            case .nonEmptyOrderedSet(let set):
                return set.elementsOrdered
            case .indefiniteList(let indefiniteList), .indefiniteNonEmptyOrderedSet(let indefiniteList):
                return indefiniteList.map { $0 }
        }
    }
    
    public func asIndefiniteList() throws -> IndefiniteList<Element> {
        switch self {
            case .list(let array):
                return IndefiniteList(array)
            case .nonEmptyOrderedSet(let set):
                return IndefiniteList(set.elementsOrdered)
            case .indefiniteList(let indefiniteList), .indefiniteNonEmptyOrderedSet(let indefiniteList):
                return indefiniteList
        }
    }

    // Make this a throwing function since NonEmptyOrderedSet initialization may throw
    public func asNonEmptyOrderedSet() throws -> NonEmptyOrderedSet<Element> {
        switch self {
            case .list(let array):
                return NonEmptyOrderedSet(array)
            case .nonEmptyOrderedSet(let set):
                return set
            case .indefiniteList(let indefiniteList), .indefiniteNonEmptyOrderedSet(let indefiniteList):
                return NonEmptyOrderedSet(indefiniteList.map { $0 })
        }
    }

    // Add a non-throwing version that returns nil on error for convenience
    public func asNonEmptyOrderedSetSafe() -> NonEmptyOrderedSet<Element>? {
        do {
            return try asNonEmptyOrderedSet()
        } catch {
            return nil
        }
    }

    // MARK: - CBORSerializable

    public init(from primitive: Primitive) throws {
        switch primitive {
            case .list(let elements):
                self = .list(try elements.map { try T.init(from: $0) })
            case .indefiniteList(let elements):
                self = .indefiniteList(IndefiniteList(try elements.map { try T.init(from: $0) }))
            case .nonEmptyOrderedSet(let elements):
                self = .nonEmptyOrderedSet(NonEmptyOrderedSet(
                    try elements.elementsOrdered.map { try T.init(from: $0) }
                ))
            case .cborTag(let tag):
                guard tag.tag == 258 else {
                    throw CardanoCoreError.valueError("Invalid ListOrNonEmptyOrderedSet CBOR tag")
                }
                switch tag.value {
                    case .list(let elements):
                        self = .nonEmptyOrderedSet(
                            NonEmptyOrderedSet(try elements.map { try T.init(from: $0) })
                        )
                    case .indefiniteList(let elements):
                        self = .indefiniteNonEmptyOrderedSet(
                            IndefiniteList(try elements.getAll().map { try T.init(from: $0) })
                        )
                    default:
                        throw CardanoCoreError.deserializeError(
                            "A #6.258 set tag has to wrap a list, but this one wrapped \(tag.value)"
                        )
                }
            default:
                throw CardanoCoreError.valueError("Invalid ListOrNonEmptyOrderedSet type: \(primitive)")
        }
    }

    public func toPrimitive() throws -> Primitive {
        switch self {
            case .list(let array):
                return .list(try array.map { try $0.toPrimitive() })
            case .nonEmptyOrderedSet(let set):
                let primitives = try set.elementsOrdered.map { try $0.toPrimitive() }
                return .nonEmptyOrderedSet(NonEmptyOrderedSet(primitives))
            case .indefiniteList(let indefiniteList):
                return .indefiniteList(IndefiniteList(try indefiniteList.map { try $0.toPrimitive() }))
            case .indefiniteNonEmptyOrderedSet(let indefiniteList):
                // Re-emit `#6.258` around an indefinite-length array, byte-for-byte
                // as it was decoded.
                return .cborTag(
                    CBORTag(
                        tag: 258,
                        value: .indefiniteList(
                            IndefiniteList(try indefiniteList.map { try $0.toPrimitive() })
                        )
                    )
                )
        }
    }

    // MARK: - JSONSerializable

    public static func fromDict(_ primitive: Primitive) throws -> ListOrNonEmptyOrderedSet<T> {
        // For JSON, ListOrNonEmptyOrderedSet is represented as a list
        guard case let .list(elements) = primitive else {
            throw CardanoCoreError.deserializeError("Expected list primitive for ListOrNonEmptyOrderedSet")
        }

        let items = try elements.map { try T.fromDict($0) }
        return .list(items)
    }

    public func toDict() throws -> Primitive {
        // For JSON, serialize as a list (JSON doesn't have sets)
        let elements = self.asList
        return .list(try elements.map { try $0.toDict() })
    }

    public func contains(_ element: Element) -> Bool {
        switch self {
            case .list(let array):
                return array.contains(element)
            case .nonEmptyOrderedSet(let set):
                return set.contains(element)
            case .indefiniteList(let indefiniteList), .indefiniteNonEmptyOrderedSet(let indefiniteList):
                return indefiniteList.contains(element)
        }
    }

    public mutating func append(_ element: Element) throws {
        switch self {
            case .list(var array):
                array.append(element)
                self = .list(array)
            case .nonEmptyOrderedSet(var set):
                set.append(element)
                self = .nonEmptyOrderedSet(set)
            case .indefiniteList(var indefiniteList):
                indefiniteList.add(element)
                self = .indefiniteList(indefiniteList)
            case .indefiniteNonEmptyOrderedSet(var indefiniteList):
                indefiniteList.add(element)
                self = .indefiniteNonEmptyOrderedSet(indefiniteList)
        }
    }

    public subscript(_ index: Int) -> Element? {
        switch self {
            case .list(let array):
                guard index >= 0 && index < array.count else {
                    return nil
                }
                return array[index]
            case .nonEmptyOrderedSet(let set):
                guard index >= 0 && index < set.count else {
                    return nil
                }
                return set.elementsOrdered[index]
            case .indefiniteList(let indefiniteList), .indefiniteNonEmptyOrderedSet(let indefiniteList):
                return indefiniteList.get(at: index)
        }
    }
}
