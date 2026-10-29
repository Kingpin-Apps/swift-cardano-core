import Foundation

// Plutus data, metadata and native scripts nest without a limit: the ledger
// reads them with no depth check, so a transaction can hold one nested as deep
// as its size allows — about 16,000 levels. Swift frees a value by freeing
// what it holds, one call per level, so freeing such a value as plain nested
// arrays overflows a 512 KB thread's stack at about 2,000 levels, even in an
// optimised build.
//
// Every level of those trees keeps its children in a `NestedStorage`, whose
// `deinit` takes the subtree apart in a loop instead.

/// A tree node that can hand over the children it holds, so that a tree of
/// them is freed in a loop rather than by recursion.
protocol NestedTree {
    /// Moves the children this value alone holds onto `pending`, leaving it
    /// without them. Children it shares with another value stay put.
    mutating func moveChildren(into pending: inout [Self])
}

/// The children of a tree node. When it is freed, every node below it that
/// nothing else holds is freed with it, in a loop.
final class NestedStorage<Element>: @unchecked Sendable {
    var items: [Element]

    init(_ items: [Element]) {
        self.items = items
    }

    deinit {
        guard !items.isEmpty, let tree = Element.self as? any NestedTree.Type else { return }
        free(as: tree)
    }

    private func free<Node: NestedTree>(as _: Node.Type) {
        // Element is Node here; the cast only names it.
        var pending = unsafeBitCast(items, to: [Node].self)
        items = []
        while var node = pending.popLast() {
            node.moveChildren(into: &pending)
        }
    }

    /// Moves the items of `storage` onto `pending` when nothing else holds it.
    static func move(_ storage: inout NestedStorage, into pending: inout [Element]) {
        guard isKnownUniquelyReferenced(&storage) else { return }
        pending.append(contentsOf: storage.items)
        storage.items = []
    }
}

/// The key–value pairs of a map node, freed like ``NestedStorage``.
final class NestedPairStorage<Key, Value>: @unchecked Sendable {
    var pairs: [(key: Key, value: Value)]

    init(_ pairs: [(key: Key, value: Value)]) {
        self.pairs = pairs
    }

    deinit {
        guard !pairs.isEmpty, Key.self == Value.self,
              let tree = Key.self as? any NestedTree.Type else { return }
        free(as: tree)
    }

    private func free<Node: NestedTree>(as _: Node.Type) {
        var pending = flattened(as: Node.self)
        pairs = []
        while var node = pending.popLast() {
            node.moveChildren(into: &pending)
        }
    }

    /// The keys and values, in order, as `Node`s; Key and Value are `Node`.
    private func flattened<Node>(as _: Node.Type) -> [Node] {
        var nodes: [Node] = []
        nodes.reserveCapacity(pairs.count * 2)
        for (key, value) in pairs {
            nodes.append(unsafeBitCast(key, to: Node.self))
            nodes.append(unsafeBitCast(value, to: Node.self))
        }
        return nodes
    }

    /// Moves the keys and values of `storage` onto `pending` when nothing
    /// else holds it. Key and Value must be `Node`.
    static func move<Node>(_ storage: inout NestedPairStorage, into pending: inout [Node]) {
        guard isKnownUniquelyReferenced(&storage) else { return }
        pending.append(contentsOf: storage.flattened(as: Node.self))
        storage.pairs = []
    }
}

/// A list of tree nodes that is freed in a loop however deep it nests.
///
/// It reads and writes like an array — literal, indexing, iteration, append —
/// and copies on write.
public struct NestedList<Element> {
    var storage: NestedStorage<Element>

    public init() {
        storage = NestedStorage([])
    }

    public init<S: Sequence>(_ elements: S) where S.Element == Element {
        storage = NestedStorage(Array(elements))
    }

    /// The elements as an array.
    public var array: [Element] { storage.items }

    private mutating func makeUnique() {
        if !isKnownUniquelyReferenced(&storage) {
            storage = NestedStorage(storage.items)
        }
    }

    /// Moves the elements onto `pending` when nothing else holds them.
    mutating func moveElements(into pending: inout [Element]) {
        NestedStorage.move(&storage, into: &pending)
    }
}

extension NestedList: RandomAccessCollection, MutableCollection, RangeReplaceableCollection {
    public var startIndex: Int { 0 }
    public var endIndex: Int { storage.items.count }

    public subscript(position: Int) -> Element {
        get { storage.items[position] }
        set {
            makeUnique()
            storage.items[position] = newValue
        }
    }

    public mutating func replaceSubrange<C: Collection>(_ subrange: Range<Int>, with newElements: C)
    where C.Element == Element {
        makeUnique()
        storage.items.replaceSubrange(subrange, with: newElements)
    }

    public mutating func reserveCapacity(_ minimumCapacity: Int) {
        makeUnique()
        storage.items.reserveCapacity(minimumCapacity)
    }
}

extension NestedList: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: Element...) {
        self.init(elements)
    }
}

extension NestedList: Equatable where Element: Equatable {
    public static func == (lhs: NestedList, rhs: NestedList) -> Bool {
        lhs.storage === rhs.storage || lhs.array == rhs.array
    }

    public static func == (lhs: NestedList, rhs: [Element]) -> Bool {
        lhs.array == rhs
    }
}

extension NestedList: Hashable where Element: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(array)
    }
}

extension NestedList: Sendable where Element: Sendable {}

extension NestedList: CustomStringConvertible {
    public var description: String { array.description }
}
