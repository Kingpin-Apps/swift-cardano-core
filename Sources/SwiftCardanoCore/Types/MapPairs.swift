import CBORCodable
import Foundation
import OrderedCollections

/// A map held as the ordered list of key–value pairs it was written as.
///
/// The ledger reads a Plutus data map and a metadata map as a list of pairs,
/// not as a dictionary: the order of the pairs is part of the value, and a key
/// may appear more than once. A dictionary would keep one pair per key and so
/// change the value — and with it every hash taken over it. `MapPairs` keeps
/// every pair, in order.
///
/// Looking a key up returns the value of its first pair, as Plutus's own
/// `lookup` does.
public struct MapPairs<Key: Hashable, Value> {
    public typealias Element = (key: Key, value: Value)

    /// Kept in a ``NestedPairStorage``, so that a map of Plutus data or
    /// metadata nested however deep is freed without recursion.
    private var storage: NestedPairStorage<Key, Value>

    /// The pairs, in order.
    public var elements: [Element] {
        get { storage.pairs }
        set { storage = NestedPairStorage(newValue) }
    }

    public init() {
        storage = NestedPairStorage([])
    }

    /// A map of `pairs`, in order, repeated keys included.
    public init<S: Sequence>(_ pairs: S) where S.Element == (Key, Value) {
        storage = NestedPairStorage(pairs.map { (key: $0.0, value: $0.1) })
    }

    /// A map of the entries of `dictionary`, in its order.
    public init(_ dictionary: OrderedDictionary<Key, Value>) {
        storage = NestedPairStorage(dictionary.map { (key: $0.key, value: $0.value) })
    }

    private mutating func makeUnique() {
        if !isKnownUniquelyReferenced(&storage) {
            storage = NestedPairStorage(storage.pairs)
        }
    }

    /// Moves the keys and values onto `pending`, in order, when nothing else
    /// holds them. `Key` and `Value` must both be `Node`.
    mutating func moveKeysAndValues<Node>(into pending: inout [Node]) {
        NestedPairStorage.move(&storage, into: &pending)
    }

    public var count: Int { elements.count }
    public var isEmpty: Bool { elements.isEmpty }
    public var keys: [Key] { elements.map(\.key) }
    public var values: [Value] { elements.map(\.value) }

    /// Whether any key appears in more than one pair.
    public var hasDuplicateKeys: Bool {
        Set(keys).count != count
    }

    /// The value of the first pair with `key`. Setting a value replaces the
    /// first such pair's value, or appends a pair when there is none; setting
    /// `nil` removes every pair with `key`.
    public subscript(key: Key) -> Value? {
        get { elements.first { $0.key == key }?.value }
        set {
            if let newValue {
                makeUnique()
                if let index = storage.pairs.firstIndex(where: { $0.key == key }) {
                    storage.pairs[index].value = newValue
                } else {
                    storage.pairs.append((key, newValue))
                }
            } else {
                makeUnique()
                storage.pairs.removeAll { $0.key == key }
            }
        }
    }

    /// Every value paired with `key`, in order.
    public func values(forKey key: Key) -> [Value] {
        elements.filter { $0.key == key }.map(\.value)
    }

    /// The pairs as a dictionary, or `nil` when a key repeats.
    public var dictionary: OrderedDictionary<Key, Value>? {
        hasDuplicateKeys ? nil : OrderedDictionary(uniqueKeysWithValues: elements.map { ($0.key, $0.value) })
    }

    public mutating func append(key: Key, value: Value) {
        makeUnique()
        storage.pairs.append((key, value))
    }
}

extension MapPairs {
    /// The map as a primitive, its keys and values converted by `key` and
    /// `value`. A map that repeats a key cannot be held as a dictionary, so it
    /// is written out pair by pair and carried as those bytes.
    func primitive(
        indefinite: Bool,
        key: (Key) throws -> Primitive,
        value: (Value) throws -> Primitive
    ) throws -> Primitive {
        if !hasDuplicateKeys {
            var entries = OrderedDictionary<Primitive, Primitive>()
            for element in elements {
                entries[try key(element.key)] = try value(element.value)
            }
            // Distinct keys can still convert to one primitive; then the
            // dictionary has lost a pair and the map is written out instead.
            if entries.count == count {
                return indefinite ? .indefiniteDictionary(entries) : .orderedDict(entries)
            }
        }
        var bytes = indefinite ? Data([0xBF]) : CBORItemScanner.definiteHeader(major: 5, count: count)
        let encoder = CBOREncoder()
        for element in elements {
            bytes.append(try encoder.encode(key(element.key)))
            bytes.append(try encoder.encode(value(element.value)))
        }
        if indefinite { bytes.append(0xFF) }
        return .cborSimpleValue(.encoded(bytes))
    }
}

extension MapPairs: Sequence {
    public func makeIterator() -> IndexingIterator<[Element]> {
        elements.makeIterator()
    }
}

extension MapPairs: ExpressibleByDictionaryLiteral {
    /// A map of the literal's pairs, in order; a key may repeat.
    public init(dictionaryLiteral elements: (Key, Value)...) {
        self.init(elements)
    }
}

extension MapPairs: Equatable where Value: Equatable {
    /// Equal when they hold the same pairs in the same order.
    public static func == (lhs: MapPairs, rhs: MapPairs) -> Bool {
        lhs.count == rhs.count && zip(lhs, rhs).allSatisfy { $0.key == $1.key && $0.value == $1.value }
    }
}

extension MapPairs: Hashable where Value: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(count)
        for (key, value) in elements {
            hasher.combine(key)
            hasher.combine(value)
        }
    }
}

extension MapPairs: Sendable where Key: Sendable, Value: Sendable {}

extension MapPairs: CustomStringConvertible {
    public var description: String {
        "[" + elements.map { "\($0.key): \($0.value)" }.joined(separator: ", ") + "]"
    }
}
