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

    /// Reads ``toDict()``'s form.
    public static func fromDict(_ primitive: Primitive) throws -> ListOrOrderedSet<T> {
        let (form, elements) = try jsonCollection(primitive, in: "ListOrOrderedSet")
        let items = try elements.map { try T.fromDict($0) }
        switch form {
            case .list: return .list(items)
            case .set: return .orderedSet(try OrderedSet(items))
            case .indefiniteList: return .indefiniteList(IndefiniteList(items))
            case .indefiniteSet: return .indefiniteOrderedSet(IndefiniteList(items))
        }
    }

    /// The elements as a JSON list, wrapped to say how they were written
    /// when that was not a plain list — `{"set": [...]}`,
    /// `{"indefiniteList": [...]}` or `{"indefiniteSet": [...]}` — so the value
    /// reads back as it was.
    public func toDict() throws -> Primitive {
        let form: JSONCollectionForm = switch self {
            case .list: .list
            case .orderedSet: .set
            case .indefiniteList: .indefiniteList
            case .indefiniteOrderedSet: .indefiniteSet
        }
        return form.wrap(.list(try asArray.map { try $0.toDict() }))
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

    /// Adds `element` at the end. A set, unlike a list, gains it only when
    /// it does not already hold it.
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
                // A set holds each element once.
                guard !indefiniteList.contains(element) else { return }
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
                return try NonEmptyOrderedSet(nonEmpty: array)
            case .nonEmptyOrderedSet(let set):
                return set
            case .indefiniteList(let indefiniteList), .indefiniteNonEmptyOrderedSet(let indefiniteList):
                return try NonEmptyOrderedSet(nonEmpty: indefiniteList.map { $0 })
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
                self = .nonEmptyOrderedSet(try NonEmptyOrderedSet(
                    nonEmpty: try elements.elementsOrdered.map { try T.init(from: $0) }
                ))
            case .cborTag(let tag):
                guard tag.tag == 258 else {
                    throw CardanoCoreError.valueError("Invalid ListOrNonEmptyOrderedSet CBOR tag")
                }
                switch tag.value {
                    case .list(let elements):
                        // nonempty_set: the ledger rejects an empty one.
                        self = .nonEmptyOrderedSet(
                            try NonEmptyOrderedSet(nonEmpty: try elements.map { try T.init(from: $0) })
                        )
                    case .indefiniteList(let elements):
                        // nonempty_set, however its length is written.
                        guard !elements.isEmpty else {
                            throw CardanoCoreError.deserializeError(
                                "A nonempty_set must hold at least one element")
                        }
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

    /// Reads ``toDict()``'s form.
    public static func fromDict(_ primitive: Primitive) throws -> ListOrNonEmptyOrderedSet<T> {
        let (form, elements) = try jsonCollection(primitive, in: "ListOrNonEmptyOrderedSet")
        let items = try elements.map { try T.fromDict($0) }
        switch form {
            case .list: return .list(items)
            case .set: return .nonEmptyOrderedSet(try NonEmptyOrderedSet(nonEmpty: items))
            case .indefiniteList: return .indefiniteList(IndefiniteList(items))
            case .indefiniteSet: return .indefiniteNonEmptyOrderedSet(IndefiniteList(items))
        }
    }

    /// The elements as a JSON list, wrapped to say how they were written
    /// when that was not a plain list — `{"set": [...]}`,
    /// `{"indefiniteList": [...]}` or `{"indefiniteSet": [...]}`.
    public func toDict() throws -> Primitive {
        let form: JSONCollectionForm = switch self {
            case .list: .list
            case .nonEmptyOrderedSet: .set
            case .indefiniteList: .indefiniteList
            case .indefiniteNonEmptyOrderedSet: .indefiniteSet
        }
        return form.wrap(.list(try asList.map { try $0.toDict() }))
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

    /// Adds `element` at the end. A set, unlike a list, gains it only when
    /// it does not already hold it.
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
                // A set holds each element once.
                guard !indefiniteList.contains(element) else { return }
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

/// How a list-or-set was written, which its JSON keeps: a plain list is a
/// JSON list, and the other forms wrap it, as `{"set": [...]}`,
/// `{"indefiniteList": [...]}` or `{"indefiniteSet": [...]}`.
enum JSONCollectionForm: String, CaseIterable {
    case list, set, indefiniteList, indefiniteSet

    func wrap(_ elements: Primitive) -> Primitive {
        self == .list ? elements : .orderedDict([.string(rawValue): elements])
    }
}

/// The form and elements of a list-or-set's JSON.
func jsonCollection(_ primitive: Primitive, in type: String) throws -> (JSONCollectionForm, [Primitive]) {
    if case .list(let elements) = primitive {
        return (.list, elements)
    }
    if case .orderedDict(let dict) = primitive, dict.count == 1,
       case .string(let name) = dict.keys[0], let form = JSONCollectionForm(rawValue: name),
       case .list(let elements) = dict.values[0] {
        return (form, elements)
    }
    throw CardanoCoreError.deserializeError("\(type): expected a JSON list or {\"set\": [...]}, got \(primitive)")
}
