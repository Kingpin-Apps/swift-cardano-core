import Foundation
import OrderedCollections

/// A type that can represent transaction inputs as either an array or an OrderedSet
public enum ListOrOrderedSet<T: Serializable>: Serializable {
    public typealias Element = T
    
    case list([Element])
    case orderedSet(OrderedSet<Element>)
    
    public var count: Int {
        switch self {
            case .list(let array):
                return array.count
            case .orderedSet(let set):
                return set.count
        }
    }
    
    public var asArray: [Element] {
        switch self {
            case .list(let array):
                return array
            case .orderedSet(let set):
                return set.elements.map { $0 }
        }
    }
    
    
    public func asOrderedSet() throws -> OrderedSet<Element> {
        switch self {
            case .list(let array):
                return try OrderedSet(array)
            case .orderedSet(let set):
                return set
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
            case .orderedSet(let set):
                self = .orderedSet(
                    try OrderedSet(
                        try set.elements.map { try T.init(from: $0) }
                    )
                )
            case .cborTag(let tag):
                if tag.tag == 258 {
                    self = .orderedSet(
                        try OrderedSet(
                            try tag.value.listValue!.map {
                                try T.init(from: $0.toPrimitive())
                            }
                        )
                    )
                } else {
                    throw CardanoCoreError.valueError("Invalid ListOrOrderedSet CBOR tag")
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
                let primitives = try set.elements.map { try $0.toPrimitive() }
                return .orderedSet(try OrderedSet(primitives))
        }
    }
    
    // MARK: - JSONSerializable
    
    public static func fromDict(_ primitive: Primitive) throws -> ListOrOrderedSet<T> {
        // For JSON, ListOrOrderedSet is represented as a list
        guard case let .list(elements) = primitive else {
            throw CardanoCoreError.deserializeError("Expected list primitive for ListOrOrderedSet")
        }
        
        let items = try elements.map { try T.init(from: $0) }
        return .list(items)
    }
    
    public func toDict() throws -> Primitive {
        // For JSON, serialize as a list (JSON doesn't have sets)
        let elements = self.asArray
        return .list(try elements.map { try $0.toDict() })
    }

    
    public func contains(_ element: Element) -> Bool {
        switch self {
            case .list(let array):
                return array.contains(element)
            case .orderedSet(let set):
                return set.contains(element)
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
        }
    }
}

/// A type that can represent transaction inputs as either an array or a NonEmptyOrderedSet
public enum ListOrNonEmptyOrderedSet<T: Serializable>: Serializable {
    public typealias Element = T
    
    case list([Element])
    case nonEmptyOrderedSet(NonEmptyOrderedSet<Element>)
    
    public var count: Int {
        switch self {
            case .list(let array):
                return array.count
            case .nonEmptyOrderedSet(let set):
                return set.count
        }
    }
    
    public var asList: [Element] {
        switch self {
            case .list(let array):
                return array
            case .nonEmptyOrderedSet(let set):
                return set.elements.map { $0 }
        }
    }
    
    // Make this a throwing function since NonEmptyOrderedSet initialization may throw
    public func asNonEmptyOrderedSet() throws -> NonEmptyOrderedSet<Element> {
        switch self {
            case .list(let array):
                return NonEmptyOrderedSet(array)
            case .nonEmptyOrderedSet(let set):
                return set
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
            case .nonEmptyOrderedSet(let elements):
                self = .nonEmptyOrderedSet(NonEmptyOrderedSet(
                    try elements.elements.map { try T.init(from: $0) }
                ))
            case .cborTag(let tag):
                if tag.tag == 258 {
                    self = .nonEmptyOrderedSet(
                        NonEmptyOrderedSet(
                            try tag.value.listValue!.map {
                                try T.init(from: $0.toPrimitive())
                            }
                        )
                    )
                } else {
                    throw CardanoCoreError.valueError("Invalid ListOrOrderedSet CBOR tag")
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
                let primitives = try set.elements.map { try $0.toPrimitive() }
                return .nonEmptyOrderedSet(NonEmptyOrderedSet(primitives))
        }
    }
    
    // MARK: - JSONSerializable
    
    public static func fromDict(_ primitive: Primitive) throws -> ListOrNonEmptyOrderedSet<T> {
        // For JSON, ListOrNonEmptyOrderedSet is represented as a list
        guard case let .list(elements) = primitive else {
            throw CardanoCoreError.deserializeError("Expected list primitive for ListOrNonEmptyOrderedSet")
        }
        
        let items = try elements.map { try T.init(from: $0) }
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
        }
    }
}
