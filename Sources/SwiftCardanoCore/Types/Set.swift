import Foundation
import CBORCodable


// Generic wrapper for CBOR-tagged sets (tag 258)
public protocol SetTaggable<Element>: CBORTaggable {
    associatedtype Element: CBORSerializable & Hashable

    var elements: Set<Element> { get set }

    /// The elements in the order they were given. For a set read off the wire
    /// that is the order it was written in, which has to survive a round trip:
    /// the ledger keeps a transaction's certificates and proposals in the order
    /// the transaction lists them, both when it hashes the body and when it
    /// tells a script which certificate a redeemer is for.
    var elementsOrdered: [Element] { get set }
}

extension SetTaggable {
    public var tag: UInt64 { 258 }

    /// The same elements in the same order, with the later of any duplicates
    /// dropped — what makes an ordered set a set.
    static func deduplicated(_ elements: [Element]) -> [Element] {
        var seen = Set<Element>()
        return elements.filter { seen.insert($0).inserted }
    }

    /// The elements sorted by their CBOR encoding, bytewise.
    ///
    /// This is the order to put a set in when it was built from an unordered
    /// collection and so has no order of its own to keep. A Swift `Set` iterates
    /// differently from one process to the next, and encoding straight from one
    /// gives different bytes each run: the body hash a vkey witness signs then
    /// differs from the body that is finally submitted, and the ledger rejects
    /// the transaction with `InvalidWitnessesUTXOW`.
    public var canonicalElements: [Element] {
        Self.canonicallySorted(elements)
    }

    /// The elements, in order, as the list inside the `#6.258` tag.
    ///
    /// Setting it replaces the elements with those the list holds, in its
    /// order and without duplicates. A value that is not a list of elements
    /// is a programming error and traps, as the setter cannot throw.
    public var value: Primitive {
        get {
            return .list(
                elementsOrdered.map {
                    try! Primitive.fromAny($0)
                }
            )
        }
        set(newValue) {
            let list: [Primitive]
            switch newValue {
                case .list(let elements): list = elements
                case .indefiniteList(let elements): list = elements.getAll()
                default: preconditionFailure("A set's value must be a list, not \(newValue)")
            }
            do {
                elementsOrdered = try list.map { try Element(from: $0) }
            } catch {
                preconditionFailure("A set's value must be a list of its elements: \(error)")
            }
        }
    }

    /// `newElements` in order: those already in `current` keep their place,
    /// and the rest follow in canonical order, as a Swift `Set` has none.
    static func ordering(_ newElements: Set<Element>, keeping current: [Element]) -> [Element] {
        let kept = current.filter { newElements.contains($0) }
        return kept + canonicallySorted(newElements.subtracting(kept))
    }

    /// The elements sorted by their CBOR encoding, bytewise.
    static func canonicallySorted<S: Sequence>(_ elements: S) -> [Element] where S.Element == Element {
        let array = Array(elements)
        guard let sorted = try? array.sorted(by: {
            try $0.toCBORData().lexicographicallyPrecedes($1.toCBORData())
        }) else {
            return array
        }
        return sorted
    }

    public static var TAG: UInt64 { 258 }

    /// The elements inside a `#6.258` tag, in the order they were written.
    static func taggedElements(_ tag: CBORTag) throws -> [Primitive] {
        switch tag.value {
            case .list(let elements):
                return elements
            case .indefiniteList(let elements):
                return elements.getAll()
            default:
                throw CardanoCoreError.deserializeError(
                    "A set tag has to wrap a list, but this one wrapped \(tag.value)"
                )
        }
    }

    public var count: Int { return elements.count }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let cborData = try container.decode(CBOR.self)

        if case let .tagged(tag, value) = cborData {
            guard tag == Self.TAG else {
                throw CardanoCoreError.valueError(
                    "Invalid CBOR tag: expected \(Self.TAG ) but found \(tag)")
            }

            // `#6.258([* a])`, the array of definite or indefinite length.
            let arrayData: [CBOR]
            switch value {
            case .array(let items), .indefiniteArray(let items): arrayData = items
            default:
                throw CardanoCoreError.valueError("SetWrapper must contain an array")
            }

            let decodedElements = try arrayData.map {
                let data = try CBORSerialization.data(from: $0)
                let element = try CBORDecoder.ledger().decode(
                    Element.self,
                    from: data
                )
                return element
            }
            try self.init(
                tag: tag,
                value: .list(try decodedElements.map { try Primitive.fromAny($0) })
            )
        } else if case let .array(arrayData) = cborData.definiteOrIndefiniteArray {
            let decodedElements = try arrayData.map {
                try CBORDecoder.ledger().decode(Element.self, from: CBORSerialization.data(from: $0))
            }
            try self.init(
                tag: Self.TAG,
                value: .list(try decodedElements.map { try Primitive.fromAny($0) })
            )
        } else {
            throw CardanoCoreError.valueError("Invalid CBOR format for SetWrapper")
        }
    }

    public func contains(_ element: Element) -> Bool {
        return elements.contains(element)
    }
    
    public func toCBOR() throws -> CBOR {
        return .tagged(
            UInt64(Self.TAG),
            try .array(elementsOrdered.map { try $0.toPrimitive().toCBOR() })
        )
    }
}

public struct OrderedSet<T: CBORSerializable & Hashable & Sendable>: SetTaggable {
    public typealias Element = T

    /// The elements in order, each once: what is encoded.
    private var ordered: [Element] = []
    /// The same elements, for membership tests.
    private var members: Set<Element> = []

    /// The elements, unordered.
    ///
    /// Setting it keeps the place of every element that stays; elements that
    /// are new follow in canonical order.
    public var elements: Set<Element> {
        get { members }
        set { assign(Self.ordering(newValue, keeping: ordered)) }
    }

    /// The elements in order. Setting it drops the later of any duplicates.
    public var elementsOrdered: [Element] {
        get { ordered }
        set { assign(Self.deduplicated(newValue)) }
    }

    /// Replaces the elements with `unique`, which holds no duplicates.
    private mutating func assign(_ unique: [Element]) {
        ordered = unique
        members = Set(unique)
    }

    public init(tag: UInt64 = 258, value: Primitive) throws {
        guard tag == Self.TAG else {
            throw CardanoCoreError.valueError("Invalid CBOR tag: expected \(Self.TAG) but found \(tag)")
        }
        let list: [Primitive]
        switch value {
            case .list(let elements): list = elements
            case .indefiniteList(let elements): list = elements.getAll()
            default: throw CardanoCoreError.valueError("OrderedSet must contain an array, not \(value)")
        }
        assign(Self.deduplicated(try list.map { try T.init(from: $0.toPrimitive()) }))
    }

    /// A set has no order of its own, so the elements are put in canonical
    /// order — otherwise the bytes would change from run to run.
    public init(_ elements: Set<Element>) throws {
        try self.init(elements.sorted {
            try $0.toCBORData().lexicographicallyPrecedes($1.toCBORData())
        } as [Element])
    }

    /// Keeps the order the elements are given in, dropping later duplicates.
    public init(_ elements: [Element]) throws {
        assign(Self.deduplicated(elements))
    }
    
    // MARK: - Convenience Methods
    
    /// Adds an element at the end, unless it is already in the set.
    /// - Parameter element: The element to add
    /// - Returns: Whether the element was inserted, and the member equal to
    ///   it after the call
    @discardableResult
    public mutating func append(_ element: Element) -> (inserted: Bool, memberAfterInsert: Element) {
        let result = members.insert(element)
        if result.inserted {
            ordered.append(element)
        }
        return result
    }
    
    /// Adds an element at the end, unless it is already in the set (alias for append)
    /// - Parameter element: The element to add
    /// - Returns: Whether the element was inserted, and the member equal to
    ///   it after the call
    @discardableResult
    public mutating func insert(_ element: Element) -> (inserted: Bool, memberAfterInsert: Element) {
        return append(element)
    }
    
    /// Removes an element from the set
    /// - Parameter element: The element to remove
    /// - Returns: The removed element if it was in the set, nil otherwise
    @discardableResult
    public mutating func remove(_ element: Element) -> Element? {
        guard let removed = members.remove(element) else {
            return nil
        }
        ordered.removeAll { $0 == element }
        return removed
    }
    
    /// Removes all elements from the set
    public mutating func removeAll() {
        assign([])
    }
    
    /// Returns true if the set is empty
    public var isEmpty: Bool {
        return ordered.isEmpty
    }
    
    /// Adds the elements not already in the set at the end, in order
    /// - Parameter newElements: The elements to add
    public mutating func append<S: Sequence>(contentsOf newElements: S) where S.Element == Element {
        for element in newElements {
            append(element)
        }
    }
    
    /// Creates a new OrderedSet containing the union of this set and another set
    /// - Parameter other: The other set to union with
    /// - Returns: A new OrderedSet containing the union
    public func union(_ other: OrderedSet<Element>) throws -> OrderedSet<Element> {
        return try OrderedSet(elements.union(other.elements))
    }
    
    /// Creates a new OrderedSet containing the intersection of this set and another set
    /// - Parameter other: The other set to intersect with
    /// - Returns: A new OrderedSet containing the intersection
    public func intersection(_ other: OrderedSet<Element>) throws -> OrderedSet<Element> {
        return try OrderedSet(elements.intersection(other.elements))
    }
    
    /// Creates a new OrderedSet containing elements in this set but not in another set
    /// - Parameter other: The other set to subtract
    /// - Returns: A new OrderedSet containing the difference
    public func subtracting(_ other: OrderedSet<Element>) throws -> OrderedSet<Element> {
        return try OrderedSet(elements.subtracting(other.elements))
    }
    
    /// The first element in order, or nil if the set is empty.
    public var first: Element? {
        return elementsOrdered.first
    }
    
    /// Creates a new OrderedSet by filtering elements that satisfy the predicate
    /// - Parameter isIncluded: A closure that returns true for elements to include
    /// - Returns: A new OrderedSet containing only elements that satisfy the predicate
    public func filter(_ isIncluded: (Element) throws -> Bool) throws -> OrderedSet<Element> {
        let filteredElements = try elements.filter(isIncluded)
        return try OrderedSet(filteredElements)
    }
    
    /// Returns a new OrderedSet containing the results of mapping the given closure over the set's elements
    /// - Parameter transform: A closure that transforms elements
    /// - Returns: A new OrderedSet containing the transformed elements
    public func map<U: CBORSerializable & Hashable>(_ transform: (Element) throws -> U) throws -> OrderedSet<U> {
        let transformedElements = try elements.map(transform)
        return try OrderedSet<U>(Set(transformedElements))
    }
    
    /// Returns a new OrderedSet containing the non-nil results of mapping the given closure over the set's elements
    /// - Parameter transform: A closure that transforms elements to optionals
    /// - Returns: A new OrderedSet containing the non-nil transformed elements
    public func compactMap<U: CBORSerializable & Hashable>(_ transform: (Element) throws -> U?) throws -> OrderedSet<U> {
        let transformedElements = try elements.compactMap(transform)
        return try OrderedSet<U>(Set(transformedElements))
    }
    
    // MARK: - CBORSerializable Methods
    
    /// Initializes OrderedSet from a Primitive value
    /// - Parameter primitive: The Primitive to convert from
    /// - Throws: CardanoCoreError if the conversion fails
    public init(from primitive: Primitive) throws {
        switch primitive {
        case .list(let array):
            try self.init(try array.map { try Element(from: $0) })
            
        case .indefiniteList(let indefiniteArray):
            try self.init(try indefiniteArray.map { try Element(from: $0) })
            
        case .orderedSet(let orderedSet):
            try self.init(try orderedSet.elementsOrdered.map { try Element(from: $0) })
            
        case .nonEmptyOrderedSet(let set):
            try self.init(try set.elementsOrdered.map { try Element(from: $0) })
            
        case .cborTag(let tag) where tag.tag == Self.TAG:
            // A Conway `set` is a #6.258 tag around a list. The decoder hands
            // the tag through untouched, so unwrap it here — otherwise any
            // field held as a bare set, such as a transaction's proposal
            // procedures, cannot be decoded at all.
            try self.init(try Self.taggedElements(tag).map { try Element(from: $0) })
            
        case .frozenSet(let frozenSet):
            // A Swift `Set` has no order to keep, so this one is sorted.
            try self.init(Set(try frozenSet.map { try Element(from: $0) }))
            
        default:
            throw CardanoCoreError.deserializeError(
                "Cannot convert Primitive.\(primitive) to OrderedSet"
            )
        }
    }
    
    /// Converts OrderedSet to a Primitive representation
    /// - Returns: A Primitive representation of this OrderedSet
    public func toPrimitive() throws -> Primitive {
        let primitiveElements = try elementsOrdered.map { try $0.toPrimitive() }
        return .orderedSet(
            try OrderedSet<Primitive>(primitiveElements)
        )
    }
}

public struct NonEmptyOrderedSet<T: CBORSerializable & Hashable & Sendable>: SetTaggable {
    public typealias Element = T

    /// The elements in order, each once and never none: what is encoded.
    private var ordered: [Element] = []
    /// The same elements, for membership tests.
    private var members: Set<Element> = []

    /// The elements, unordered.
    ///
    /// Setting it keeps the place of every element that stays; elements that
    /// are new follow in canonical order.
    ///
    /// - Precondition: The new value is not empty.
    public var elements: Set<Element> {
        get { members }
        set { assign(Self.ordering(newValue, keeping: ordered)) }
    }

    /// The elements in order. Setting it drops the later of any duplicates.
    ///
    /// - Precondition: The new value is not empty.
    public var elementsOrdered: [Element] {
        get { ordered }
        set { assign(Self.deduplicated(newValue)) }
    }

    /// Replaces the elements with `unique`, which holds no duplicates.
    private mutating func assign(_ unique: [Element]) {
        precondition(!unique.isEmpty, "NonEmptyOrderedSet must contain at least one element")
        ordered = unique
        members = Set(unique)
    }

    public init(tag: UInt64 = Self.TAG, value: Primitive) throws {
        let list: [Primitive]
        switch value {
        case .list(let elements): list = elements
        case .indefiniteList(let elements): list = elements.getAll()
        default: throw CardanoCoreError.valueError("NonEmptyOrderedSet must contain an array")
        }
        guard !list.isEmpty else {
            throw CardanoCoreError.valueError("NonEmptyOrderedSet must contain at least one element")
        }
        guard tag == Self.TAG else {
            throw CardanoCoreError.valueError("Invalid CBOR tag: expected \(Self.TAG) but found \(tag)")
        }
        assign(Self.deduplicated(try list.map { try T.init(from: $0) }))
    }

    /// Keeps the order the elements are given in, dropping later duplicates.
    ///
    /// - Precondition: `elements` is not empty. Use ``init(nonEmpty:)`` for
    ///   elements that come from input.
    public init(_ elements: [Element]) {
        assign(Self.deduplicated(elements))
    }

    /// Keeps the order the elements are given in, dropping later duplicates.
    ///
    /// - Throws: When `elements` is empty.
    public init(nonEmpty elements: [Element]) throws {
        guard !elements.isEmpty else {
            throw CardanoCoreError.valueError("NonEmptyOrderedSet must contain at least one element")
        }
        self.init(elements)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        var cbor = try container.decode(CBOR.self)
        if case let .tagged(tag, value) = cbor {
            guard tag == Self.TAG else {
                throw CardanoCoreError.valueError(
                    "Invalid CBOR tag: expected \(Self.TAG) but found \(tag)")
            }
            cbor = value
        }
        let items: [CBOR]
        switch cbor {
        case .array(let elements), .indefiniteArray(let elements): items = elements
        default: throw CardanoCoreError.valueError("Invalid CBOR format for NonEmptyOrderedSet")
        }
        let elements = try items.map {
            try CBORDecoder.ledger().decode(Element.self, from: CBORSerialization.data(from: $0))
        }
        try self.init(nonEmpty: elements)
    }
    
    // MARK: - Convenience Methods
    
    /// Adds an element at the end, unless it is already in the set.
    /// - Parameter element: The element to add
    /// - Returns: Whether the element was inserted, and the member equal to
    ///   it after the call
    @discardableResult
    public mutating func append(_ element: Element) -> (inserted: Bool, memberAfterInsert: Element) {
        let result = members.insert(element)
        if result.inserted {
            ordered.append(element)
        }
        return result
    }
    
    /// Adds an element at the end, unless it is already in the set (alias for append)
    /// - Parameter element: The element to add
    /// - Returns: Whether the element was inserted, and the member equal to
    ///   it after the call
    @discardableResult
    public mutating func insert(_ element: Element) -> (inserted: Bool, memberAfterInsert: Element) {
        return append(element)
    }
    
    /// Removes an element, unless it is the last one left.
    /// - Parameter element: The element to remove
    /// - Returns: The removed element; nil when it is not in the set, or when
    ///   it is the only element, which stays — see ``safeRemove(_:)`` to tell
    ///   the two apart
    @discardableResult
    public mutating func remove(_ element: Element) -> Element? {
        // Never remove the last element: the set is never empty.
        guard members.count > 1, let removed = members.remove(element) else {
            return nil
        }
        ordered.removeAll { $0 == element }
        return removed
    }
    
    /// Removes an element, throwing when it is not in the set or is the last one left.
    /// - Parameter element: The element to remove
    /// - Returns: The removed element
    /// - Throws: CardanoCoreError when the element is not in the set, or when
    ///   removing it would make the set empty
    @discardableResult
    public mutating func safeRemove(_ element: Element) throws -> Element {
        guard members.contains(element) else {
            throw CardanoCoreError.valueError("Element not found in set")
        }
        guard members.count > 1 else {
            throw CardanoCoreError.valueError("Cannot remove element: NonEmptyOrderedSet must contain at least one element")
        }
        return remove(element)!
    }
    
    /// Returns true if the set contains only one element (minimum size)
    public var isMinimal: Bool {
        return members.count == 1
    }
    
    /// Returns the number of elements that can be safely removed (total count - 1)
    public var removableCount: Int {
        return max(0, members.count - 1)
    }
    
    /// Adds the elements not already in the set at the end, in order
    /// - Parameter newElements: The elements to add
    public mutating func append<S: Sequence>(contentsOf newElements: S) where S.Element == Element {
        for element in newElements {
            append(element)
        }
    }
    
    /// Creates a new NonEmptyOrderedSet containing the union of this set and another set
    /// - Parameter other: The other set to union with
    /// - Returns: This set's elements in order, then the other's that are new
    public func union(_ other: NonEmptyOrderedSet<Element>) -> NonEmptyOrderedSet<Element> {
        return NonEmptyOrderedSet(ordered + other.elementsOrdered)
    }
    
    /// Creates a new OrderedSet containing the union of this set and a regular OrderedSet
    /// - Parameter other: The OrderedSet to union with
    /// - Returns: This set's elements in order, then the other's that are new
    public func union(_ other: OrderedSet<Element>) -> NonEmptyOrderedSet<Element> {
        return NonEmptyOrderedSet(ordered + other.elementsOrdered)
    }
    
    /// Creates a new OrderedSet containing the intersection of this set and another set
    /// - Parameter other: The other set to intersect with
    /// - Returns: A new OrderedSet containing the intersection (may be empty)
    /// - Note: Returns a regular OrderedSet since intersection might result in empty set
    public func intersection(_ other: NonEmptyOrderedSet<Element>) throws -> OrderedSet<Element> {
        return try OrderedSet(elements.intersection(other.elements))
    }
    
    /// Creates a new OrderedSet containing elements in this set but not in another set
    /// - Parameter other: The other set to subtract
    /// - Returns: A new OrderedSet containing the difference (may be empty)
    /// - Note: Returns a regular OrderedSet since subtraction might result in empty set
    public func subtracting(_ other: NonEmptyOrderedSet<Element>) throws -> OrderedSet<Element> {
        return try OrderedSet(elements.subtracting(other.elements))
    }
    
    /// The first element in order.
    public var first: Element {
        return ordered[0]
    }
    
    /// Creates a new NonEmptyOrderedSet by filtering elements that satisfy the predicate
    /// - Parameter isIncluded: A closure that returns true for elements to include
    /// - Returns: A new OrderedSet containing only elements that satisfy the predicate (may be empty)
    /// - Note: Returns a regular OrderedSet since filtering might result in empty set
    public func filter(_ isIncluded: (Element) throws -> Bool) throws -> OrderedSet<Element> {
        let filteredElements = try elements.filter(isIncluded)
        return try OrderedSet(filteredElements)
    }
    
    /// Returns a new OrderedSet containing the results of mapping the given closure over the set's elements
    /// - Parameter transform: A closure that transforms elements
    /// - Returns: A new OrderedSet containing the transformed elements (may be empty)
    /// - Note: Returns a regular OrderedSet since mapping might result in empty set after deduplication
    public func map<U: CBORSerializable & Hashable>(_ transform: (Element) throws -> U) throws -> OrderedSet<U> {
        let transformedElements = try elements.map(transform)
        return try OrderedSet<U>(Set(transformedElements))
    }
    
    /// Returns a new OrderedSet containing the non-nil results of mapping the given closure over the set's elements
    /// - Parameter transform: A closure that transforms elements to optionals
    /// - Returns: A new OrderedSet containing the non-nil transformed elements (may be empty)
    /// - Note: Returns a regular OrderedSet since compact mapping might result in empty set
    public func compactMap<U: CBORSerializable & Hashable>(_ transform: (Element) throws -> U?) throws -> OrderedSet<U> {
        let transformedElements = try elements.compactMap(transform)
        return try OrderedSet<U>(Set(transformedElements))
    }
    
    /// Replaces an existing element with a new element
    /// - Parameters:
    ///   - oldElement: The element to replace
    ///   - newElement: The element to replace it with
    /// - Returns: True if the replacement was successful, false if oldElement was not found
    /// - Note: If newElement already exists and is different from oldElement, the set remains unchanged and returns false
    @discardableResult
    public mutating func replace(_ oldElement: Element, with newElement: Element) -> Bool {
        guard let index = ordered.firstIndex(of: oldElement) else {
            return false
        }
        if oldElement == newElement {
            return true
        }
        // If newElement already exists and is different from oldElement, don't allow replacement
        if members.contains(newElement) {
            return false
        }
        // In the old element's place.
        ordered[index] = newElement
        members.remove(oldElement)
        members.insert(newElement)
        return true
    }
    
    // MARK: - CBORSerializable Methods
    
    /// Initializes NonEmptyOrderedSet from a Primitive value
    /// - Parameter primitive: The Primitive to convert from
    /// - Throws: CardanoCoreError if the conversion fails or if the resulting set would be empty
    public init(from primitive: Primitive) throws {
        switch primitive {
        case .list(let array):
            guard !array.isEmpty else {
                throw CardanoCoreError.deserializeError(
                    "Cannot create NonEmptyOrderedSet from empty list"
                )
            }
            let decodedElements = try array.map { try Element(from: $0) }
            self.init(decodedElements)
            
        case .indefiniteList(let indefiniteArray):
            guard !indefiniteArray.isEmpty else {
                throw CardanoCoreError.deserializeError(
                    "Cannot create NonEmptyOrderedSet from empty indefinite list"
                )
            }
            let decodedElements = try indefiniteArray.map { try Element(from: $0) }
            self.init(decodedElements)
            
        case .orderedSet(let orderedSet):
            guard !orderedSet.elements.isEmpty else {
                throw CardanoCoreError.deserializeError(
                    "Cannot create NonEmptyOrderedSet from empty ordered set"
                )
            }
            self.init(try orderedSet.elementsOrdered.map { try Element(from: $0) })
            
        case .nonEmptyOrderedSet(let nonEmptyOrderedSet):
            self.init(try nonEmptyOrderedSet.elementsOrdered.map { try Element(from: $0) })
            
        case .frozenSet(let frozenSet):
            guard !frozenSet.isEmpty else {
                throw CardanoCoreError.deserializeError(
                    "Cannot create NonEmptyOrderedSet from empty frozen set"
                )
            }
            let decodedElements = try frozenSet.map { try Element(from: $0) }
            self.init(decodedElements)
            
        case .cborTag(let tag) where tag.tag == Self.TAG:
            // A Conway `nonempty_set` is a #6.258 tag around a list. The
            // decoder hands the tag through untouched, so unwrap it here —
            // otherwise any field held as a bare set, such as a transaction's
            // proposal procedures, cannot be decoded at all.
            let elements = try Self.taggedElements(tag)
            guard !elements.isEmpty else {
                throw CardanoCoreError.deserializeError(
                    "Cannot create NonEmptyOrderedSet from an empty set"
                )
            }
            self.init(try elements.map { try Element(from: $0) })
            
        default:
            throw CardanoCoreError.deserializeError(
                "Cannot convert Primitive.\(primitive) to NonEmptyOrderedSet"
            )
        }
    }
    
    /// Converts NonEmptyOrderedSet to a Primitive representation
    /// - Returns: A Primitive representation of this NonEmptyOrderedSet
    public func toPrimitive() throws -> Primitive {
        let primitiveElements = try elementsOrdered.map { try $0.toPrimitive() }
        // Keep the `#6.258` tag. Writing a plain list instead changes the bytes
        // of any body that holds one — the transaction's proposal procedures,
        // for instance — and so changes its hash, which is what a witness signs
        // and what a script sees as the transaction id.
        return .nonEmptyOrderedSet(NonEmptyOrderedSet<Primitive>(primitiveElements))
    }
}

private extension CBOR {
    /// An array of either length encoding as a definite array, so a set
    /// written as a plain array reads the same whichever length it uses.
    var definiteOrIndefiniteArray: CBOR {
        if case .indefiniteArray(let items) = self { return .array(items) }
        return self
    }
}

// MARK: - JSON

/// An element of a collection as JSON: its own JSON form, or the hex of its
/// CBOR when it has none.
func jsonElement<Element: CBORSerializable>(_ element: Element) throws -> Primitive {
    if let element = element as? any JSONSerializable {
        return try element.toDict()
    }
    return .string(try element.toCBORHex())
}

/// Reads ``jsonElement(_:)``'s form.
func elementFromJSON<Element: CBORSerializable>(_ primitive: Primitive, as type: Element.Type) throws -> Element {
    if let jsonType = Element.self as? any JSONSerializable.Type {
        guard let element = try jsonType.fromDict(primitive) as? Element else {
            throw CardanoCoreError.deserializeError("Expected \(Element.self) in JSON")
        }
        return element
    }
    guard case .string(let hex) = primitive else {
        throw CardanoCoreError.deserializeError("\(Element.self) in JSON is the hex of its CBOR, got \(primitive)")
    }
    return try Element.fromCBORHex(hex)
}

extension OrderedSet {
    /// The elements in order, each as its own JSON.
    public func toDict() throws -> Primitive {
        .list(try elementsOrdered.map(jsonElement))
    }

    /// Reads ``toDict()``'s form.
    public static func fromDict(_ primitive: Primitive) throws -> Self {
        guard case .list(let elements) = primitive else {
            throw CardanoCoreError.deserializeError("An ordered set in JSON is a list, got \(primitive)")
        }
        return try Self(try elements.map { try elementFromJSON($0, as: Element.self) })
    }
}

extension NonEmptyOrderedSet {
    /// The elements in order, each as its own JSON.
    public func toDict() throws -> Primitive {
        .list(try elementsOrdered.map(jsonElement))
    }

    /// Reads ``toDict()``'s form.
    public static func fromDict(_ primitive: Primitive) throws -> Self {
        guard case .list(let elements) = primitive else {
            throw CardanoCoreError.deserializeError("A non-empty ordered set in JSON is a list, got \(primitive)")
        }
        return try Self(nonEmpty: try elements.map { try elementFromJSON($0, as: Element.self) })
    }
}
