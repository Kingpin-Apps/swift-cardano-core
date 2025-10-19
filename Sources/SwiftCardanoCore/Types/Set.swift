import Foundation
import PotentCBOR
import PotentCodables


// Generic wrapper for CBOR-tagged sets (tag 258)
public protocol SetTaggable<Element>: CBORTaggable {
    associatedtype Element: CBORSerializable & Hashable

    var elements: Set<Element> { get set }
}

extension SetTaggable {
    public var tag: UInt64 { 258 }
    public var value: Primitive {
        get {
            return .list(
                elements.map {
                    try! Primitive.fromAny($0)
                }
            )
        }
        set(newValue) {
            guard case .list(_) = newValue else {
                fatalError("SetWrapper must contain an array")
            }
        }
    }

    public static var TAG: UInt64 { 258 }

    public var count: Int { return elements.count }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let cborData = try container.decode(CBOR.self)

        if case let .tagged(tag, value) = cborData {
            guard tag.rawValue == Self.TAG else {
                throw CardanoCoreError.valueError(
                    "Invalid CBOR tag: expected \(Self.TAG ) but found \(tag.rawValue)")
            }

            guard case let .array(arrayData) = value else {
                throw CardanoCoreError.valueError("SetWrapper must contain an array")
            }

            let decodedElements = try arrayData.map {
                let data = try CBORSerialization.data(from: $0)
                let element = try CBORDecoder().decode(
                    Element.self,
                    from: data
                )
                return element
            }
            let elements = Set(decodedElements)
            try self.init(
                tag: tag.rawValue,
                value: .list(
                    elements.map {
                        try Primitive.fromAny($0)
                    }
                )
            )
            self.elements = elements
        } else if case let .array(arrayData) = cborData {
            let decodedElements = try arrayData.map {
                try CBOR.Decoder.default.decode(Element.self, from: $0.unwrapped as! Data)
            }
            let elements = Set(decodedElements)
            try self.init(
                tag: Self.TAG,
                value: .list(elements.map { try Primitive.fromAny($0)     })
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
            CBOR.Tag(rawValue: Self.TAG),
            try .array(elements.map { try $0.toPrimitive().toCBOR() })
        )
    }
}

public struct OrderedSet<T: CBORSerializable & Hashable>: SetTaggable {
    public typealias Element = T
    public var elements: Set<Element> = Set()
    public var elementsOrdered: [Element] {
        Array(Set(elements))
    }

    public init(tag: UInt64 = 258, value: Primitive) throws {
        guard tag == Self.TAG else {
            fatalError("Invalid CBOR tag: expected \(Self.TAG) but found \(tag)")
        }
        self.value = value
        self.elements = Set(
            try value.listValue!.map {
                try T.init(from: $0.toPrimitive())
            }
        )
    }

    public init(_ elements: Set<Element>) throws {
        try self.init(
            tag: Self.TAG,
            value: .list(
                elements.map {
                    try! $0.toPrimitive()
                })
        )
        self.elements = elements
    }
    
    public init(_ elements: [Element]) throws {
        try self.init(Set(elements))
    }
    
    // MARK: - Convenience Methods
    
    /// Adds an element to the set if it's not already present
    /// - Parameter element: The element to add
    /// - Returns: A tuple containing a boolean indicating whether the element was inserted,
    ///            and the element itself
    @discardableResult
    public mutating func append(_ element: Element) -> (inserted: Bool, memberAfterInsert: Element) {
        let result = elements.insert(element)
        // Update the value to reflect the new elements
        self.value = .list(
            elements.map {
                try! Primitive.fromAny($0)
            }
        )
        return result
    }
    
    /// Adds an element to the set if it's not already present (alias for append)
    /// - Parameter element: The element to add
    /// - Returns: A tuple containing a boolean indicating whether the element was inserted,
    ///            and the element itself
    @discardableResult
    public mutating func insert(_ element: Element) -> (inserted: Bool, memberAfterInsert: Element) {
        return append(element)
    }
    
    /// Removes an element from the set
    /// - Parameter element: The element to remove
    /// - Returns: The removed element if it was in the set, nil otherwise
    @discardableResult
    public mutating func remove(_ element: Element) -> Element? {
        let removed = elements.remove(element)
        // Update the value to reflect the new elements
        self.value = .list(
            elements.map {
                try! Primitive.fromAny($0)
            }
        )
        return removed
    }
    
    /// Removes all elements from the set
    public mutating func removeAll() {
        elements.removeAll()
        self.value = .list([])
    }
    
    /// Returns true if the set is empty
    public var isEmpty: Bool {
        return elements.isEmpty
    }
    
    /// Adds multiple elements to the set
    /// - Parameter elements: The elements to add
    public mutating func append<S: Sequence>(contentsOf newElements: S) where S.Element == Element {
        for element in newElements {
            elements.insert(element)
        }
        // Update the value to reflect the new elements
        self.value = .list(
            elements.map {
                try! Primitive.fromAny($0)
            }
        )
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
    
    /// Returns an arbitrary element from the set, or nil if the set is empty
    public var first: Element? {
        return elements.first
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
            let decodedElements = try array.map { try Element(from: $0) }
            try self.init(Set(decodedElements))
            
        case .indefiniteList(let indefiniteArray):
            let decodedElements = try indefiniteArray.map { try Element(from: $0) }
            try self.init(Set(decodedElements))
            
        case .orderedSet(let orderedSet):
            let decodedElements = try orderedSet.elements.map { try Element(from: $0) }
            try self.init(Set(decodedElements))
            
        case .frozenSet(let frozenSet):
            let decodedElements = try frozenSet.map { try Element(from: $0) }
            try self.init(Set(decodedElements))
            
        default:
            throw CardanoCoreError.deserializeError(
                "Cannot convert Primitive.\(primitive) to OrderedSet"
            )
        }
    }
    
    /// Converts OrderedSet to a Primitive representation
    /// - Returns: A Primitive representation of this OrderedSet
    public func toPrimitive() throws -> Primitive {
        let primitiveElements = try elements.map { try $0.toPrimitive() }
        return .orderedSet(
            try OrderedSet<Primitive>(primitiveElements)
        )
    }
}

public struct NonEmptyOrderedSet<T: CBORSerializable & Hashable>: SetTaggable {
    public typealias Element = T
    public var elements: Set<Element> = Set()
    public var elementsOrdered: [Element] {
        Array(Set(elements))
    }

    public init(tag: UInt64 = Self.TAG, value: Primitive) throws {
        guard case let .list(list) = value else {
            fatalError("NonEmptySet must contain an array")
        }
        precondition(
            list.isEmpty == false,
            "NonEmptySet must contain at least one element"
        )
        guard tag == Self.TAG else {
            fatalError("Invalid CBOR tag: expected \(Self.TAG) but found \(tag)")
        }
        self.value = value
        self.elements = Set(
            try value.listValue!.map {
                try T.init(from: $0.toPrimitive())
            })
    }

    public init(_ elements: [Element]) {
        precondition(!elements.isEmpty, "NonEmptyOrderedSet must contain at least one element")
        self.elements = Set(elements)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let cborData = try container.decode(CBOR.self)

        if case let .tagged(tag, value) = cborData {
            guard tag.rawValue == Self.TAG else {
                throw CardanoCoreError.valueError(
                    "Invalid CBOR tag: expected \(Self.TAG) but found \(tag.rawValue)")
            }

            guard case let .array(arrayData) = value, !arrayData.isEmpty else {
                throw CardanoCoreError.valueError(
                    "NonEmptyOrderedSet must contain at least one element")
            }

            let decodedElements = arrayData.map {
                $0.unwrapped
            }

            try self.init(
                tag: Self.TAG,
                value:
                        .list(
                            decodedElements
                                .map { try! Primitive.fromAny($0 as Any) }
                        )
            )
        } else if case let .array(arrayData) = cborData, !arrayData.isEmpty {
            let decodedElements = arrayData.map {
                $0.unwrapped as! Element
            }
            let elements = Array(Set(decodedElements))
            try self.init(
                tag: Self.TAG,
                value: .list(elements.map { try! Primitive.fromAny($0) })
            )
        } else {
            throw CardanoCoreError.valueError("Invalid CBOR format for NonEmptyOrderedSet")
        }
    }
    
    // MARK: - Convenience Methods
    
    /// Adds an element to the set if it's not already present
    /// - Parameter element: The element to add
    /// - Returns: A tuple containing a boolean indicating whether the element was inserted,
    ///            and the element itself
    @discardableResult
    public mutating func append(_ element: Element) -> (inserted: Bool, memberAfterInsert: Element) {
        let result = elements.insert(element)
        // Update the value to reflect the new elements
        self.value = .list(
            elements.map {
                try! Primitive.fromAny($0)
            }
        )
        return result
    }
    
    /// Adds an element to the set if it's not already present (alias for append)
    /// - Parameter element: The element to add
    /// - Returns: A tuple containing a boolean indicating whether the element was inserted,
    ///            and the element itself
    @discardableResult
    public mutating func insert(_ element: Element) -> (inserted: Bool, memberAfterInsert: Element) {
        return append(element)
    }
    
    /// Removes an element from the set if it exists and the set would not become empty
    /// - Parameter element: The element to remove
    /// - Returns: The removed element if it was in the set and could be safely removed, nil otherwise
    /// - Note: This method will not remove an element if it would result in an empty set
    @discardableResult
    public mutating func remove(_ element: Element) -> Element? {
        // Prevent removing the last element to maintain non-empty constraint
        guard elements.count > 1 else {
            return nil
        }
        
        let removed = elements.remove(element)
        // Update the value to reflect the new elements
        self.value = .list(
            elements.map {
                try! Primitive.fromAny($0)
            }
        )
        return removed
    }
    
    /// Attempts to remove an element, throwing an error if it would result in an empty set
    /// - Parameter element: The element to remove
    /// - Returns: The removed element
    /// - Throws: CardanoCoreError if removing the element would make the set empty
    @discardableResult
    public mutating func safeRemove(_ element: Element) throws -> Element {
        guard elements.count > 1 else {
            throw CardanoCoreError.valueError("Cannot remove element: NonEmptyOrderedSet must contain at least one element")
        }
        
        guard let removed = elements.remove(element) else {
            throw CardanoCoreError.valueError("Element not found in set")
        }
        
        // Update the value to reflect the new elements
        self.value = .list(
            elements.map {
                try! Primitive.fromAny($0)
            }
        )
        return removed
    }
    
    /// Returns true if the set contains only one element (minimum size)
    public var isMinimal: Bool {
        return elements.count == 1
    }
    
    /// Returns the number of elements that can be safely removed (total count - 1)
    public var removableCount: Int {
        return max(0, elements.count - 1)
    }
    
    /// Adds multiple elements to the set
    /// - Parameter elements: The elements to add
    public mutating func append<S: Sequence>(contentsOf newElements: S) where S.Element == Element {
        for element in newElements {
            elements.insert(element)
        }
        // Update the value to reflect the new elements
        self.value = .list(
            elements.map {
                try! Primitive.fromAny($0)
            }
        )
    }
    
    /// Creates a new NonEmptyOrderedSet containing the union of this set and another set
    /// - Parameter other: The other set to union with
    /// - Returns: A new NonEmptyOrderedSet containing the union
    public func union(_ other: NonEmptyOrderedSet<Element>) -> NonEmptyOrderedSet<Element> {
        return NonEmptyOrderedSet(Array(elements.union(other.elements)))
    }
    
    /// Creates a new OrderedSet containing the union of this set and a regular OrderedSet
    /// - Parameter other: The OrderedSet to union with
    /// - Returns: A new NonEmptyOrderedSet containing the union
    public func union(_ other: OrderedSet<Element>) -> NonEmptyOrderedSet<Element> {
        return NonEmptyOrderedSet(Array(elements.union(other.elements)))
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
    
    /// Gets the first element (any element since sets are unordered)
    public var first: Element {
        return elements.first!
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
        guard elements.contains(oldElement) else {
            return false
        }
        
        // If newElement already exists and is different from oldElement, don't allow replacement
        if elements.contains(newElement) && oldElement != newElement {
            return false
        }
        
        elements.remove(oldElement)
        elements.insert(newElement)
        
        // Update the value to reflect the new elements
        self.value = .list(
            elements.map {
                try! Primitive.fromAny($0)
            }
        )
        
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
            let decodedElements = try orderedSet.elements.map { try Element(from: $0) }
            self.init(Array(decodedElements))
            
        case .nonEmptyOrderedSet(let nonEmptyOrderedSet):
            let decodedElements = try nonEmptyOrderedSet.elements.map { try Element(from: $0) }
            self.init(Array(decodedElements))
            
        case .frozenSet(let frozenSet):
            guard !frozenSet.isEmpty else {
                throw CardanoCoreError.deserializeError(
                    "Cannot create NonEmptyOrderedSet from empty frozen set"
                )
            }
            let decodedElements = try frozenSet.map { try Element(from: $0) }
            self.init(decodedElements)
            
        default:
            throw CardanoCoreError.deserializeError(
                "Cannot convert Primitive.\(primitive) to NonEmptyOrderedSet"
            )
        }
    }
    
    /// Converts NonEmptyOrderedSet to a Primitive representation
    /// - Returns: A Primitive representation of this NonEmptyOrderedSet
    public func toPrimitive() throws -> Primitive {
        let primitiveElements = try elements.map { try $0.toPrimitive() }
        return .list(primitiveElements)
    }
}
