import Foundation
import CBORCodable
import OrderedCollections
import SwiftNaCl

// MARK: - Reading

/// A CBOR data item read in place, by its span within the bytes it came from.
///
/// Byron types decode from these rather than from ``Primitive`` so each part
/// can keep the exact bytes it was written as — block and transaction hashes
/// are taken over those bytes — and so the shape of every item is checked
/// against the Byron CDDL as it is read.
struct ByronCBORItem {
    let scanner: CBORItemScanner
    let span: Range<Int>

    /// The single item that `data` holds, with no bytes after it.
    init(root data: Data, _ what: String) throws {
        let scanner = CBORItemScanner(data)
        let end = try scanner.end(ofItemAt: 0)
        guard end == scanner.bytes.count else {
            throw CardanoCoreError.deserializeError(
                "\(what): \(scanner.bytes.count - end) trailing bytes after the item"
            )
        }
        self.init(scanner: scanner, span: 0..<end)
    }

    init(scanner: CBORItemScanner, span: Range<Int>) {
        self.scanner = scanner
        self.span = span
    }

    /// The bytes of the item, exactly as written.
    var bytes: Data { scanner.bytes.subdata(in: span) }

    func header() throws -> CBORItemScanner.Header {
        try scanner.header(at: span.lowerBound)
    }

    /// The elements of an array, definite or indefinite in length.
    func array(_ what: String) throws -> [ByronCBORItem] {
        guard try header().major == 4 else {
            throw CardanoCoreError.deserializeError("\(what): expected an array")
        }
        return try scanner.elements(ofArrayAt: span.lowerBound).map {
            ByronCBORItem(scanner: scanner, span: $0)
        }
    }

    /// The elements of an array that must hold exactly `count` of them.
    func array(_ what: String, count: Int) throws -> [ByronCBORItem] {
        let elements = try array(what)
        guard elements.count == count else {
            throw CardanoCoreError.deserializeError(
                "\(what): expected \(count) elements, got \(elements.count)"
            )
        }
        return elements
    }

    /// The keys and values of a map, in the order they were written.
    func map(_ what: String) throws -> [(key: ByronCBORItem, value: ByronCBORItem)] {
        guard try header().major == 5 else {
            throw CardanoCoreError.deserializeError("\(what): expected a map")
        }
        return try scanner.entries(ofMapAt: span.lowerBound).map {
            (ByronCBORItem(scanner: scanner, span: $0.key),
             ByronCBORItem(scanner: scanner, span: $0.value))
        }
    }

    func uint(_ what: String) throws -> UInt64 {
        let header = try header()
        guard header.major == 0, let value = header.argument else {
            throw CardanoCoreError.deserializeError("\(what): expected an unsigned integer")
        }
        return value
    }

    /// An unsigned integer that must fit `T`, such as a `u8`, `u16` or `u32`.
    func uint<T: FixedWidthInteger & UnsignedInteger>(_ what: String, as type: T.Type) throws -> T {
        let value = try uint(what)
        guard let narrowed = T(exactly: value) else {
            throw CardanoCoreError.deserializeError("\(what): \(value) does not fit \(T.self)")
        }
        return narrowed
    }

    /// A signed integer: major type 0 or 1, within `Int64`.
    func int(_ what: String) throws -> Int64 {
        let header = try header()
        guard let argument = header.argument, header.major <= 1,
            argument <= UInt64(Int64.max)
        else {
            throw CardanoCoreError.deserializeError("\(what): expected an integer within Int64")
        }
        return header.major == 0 ? Int64(argument) : -1 - Int64(argument)
    }

    /// A byte string. An indefinite-length one has its chunks joined.
    func byteString(_ what: String) throws -> Data {
        let header = try header()
        guard header.major == 2 else {
            throw CardanoCoreError.deserializeError("\(what): expected a byte string")
        }
        if header.argument != nil {
            return scanner.bytes.subdata(in: header.end..<span.upperBound)
        }
        var joined = Data()
        var position = header.end
        while position < span.upperBound - 1 {
            let chunk = try scanner.header(at: position)
            let end = try scanner.end(ofItemAt: position)
            joined.append(scanner.bytes.subdata(in: chunk.end..<end))
            position = end
        }
        return joined
    }

    /// A byte string of exactly `count` bytes, such as a hash.
    func byteString(_ what: String, count: Int) throws -> Data {
        let data = try byteString(what)
        guard data.count == count else {
            throw CardanoCoreError.deserializeError(
                "\(what): expected \(count) bytes, got \(data.count)"
            )
        }
        return data
    }

    func text(_ what: String) throws -> String {
        let header = try header()
        guard header.major == 3, let length = header.argument else {
            throw CardanoCoreError.deserializeError("\(what): expected a definite text string")
        }
        let start = header.end
        guard let string = String(
            data: scanner.bytes.subdata(in: start..<(start + Int(length))), encoding: .utf8)
        else {
            throw CardanoCoreError.deserializeError("\(what): text is not valid UTF-8")
        }
        return string
    }

    func bool(_ what: String) throws -> Bool {
        let header = try header()
        switch (header.major, header.argument) {
        case (7, 20): return false
        case (7, 21): return true
        default:
            throw CardanoCoreError.deserializeError("\(what): expected a boolean")
        }
    }

    /// The item inside tag `tag`.
    func tagged(_ tag: UInt64, _ what: String) throws -> ByronCBORItem {
        let header = try header()
        guard header.major == 6, header.argument == tag else {
            throw CardanoCoreError.deserializeError("\(what): expected tag \(tag)")
        }
        return ByronCBORItem(scanner: scanner, span: header.end..<span.upperBound)
    }

    /// The item encoded inside `#6.24(bytes)`.
    func embedded(_ what: String) throws -> ByronCBORItem {
        let bytes = try tagged(24, what).byteString(what)
        return try ByronCBORItem(root: bytes, what)
    }

    /// The item decoded as a ``Primitive``, for values the CDDL leaves open.
    func primitive() throws -> Primitive {
        try Primitive.from(cbor: CBORSerialization.cbor(from: bytes))
    }
}

// MARK: - Writing

/// Builds the CBOR of a Byron item that has no bytes to keep, in the form the
/// Byron node writes it: integers and lengths in their shortest form, and
/// Haskell lists (`[* x]` in the CDDL, other than witness lists) as
/// indefinite-length arrays.
struct ByronCBORWriter {
    private(set) var data = Data()

    mutating func head(_ major: UInt8, _ value: UInt64) {
        let initial = major << 5
        switch value {
        case 0..<24: data.append(initial | UInt8(value))
        case 24...0xFF: data.append(contentsOf: [initial | 24, UInt8(value)])
        case 0x100...0xFFFF:
            data.append(initial | 25)
            withUnsafeBytes(of: UInt16(value).bigEndian) { data.append(contentsOf: $0) }
        case 0x10000...0xFFFF_FFFF:
            data.append(initial | 26)
            withUnsafeBytes(of: UInt32(value).bigEndian) { data.append(contentsOf: $0) }
        default:
            data.append(initial | 27)
            withUnsafeBytes(of: value.bigEndian) { data.append(contentsOf: $0) }
        }
    }

    mutating func array(_ count: Int) { head(4, UInt64(count)) }
    mutating func map(_ count: Int) { head(5, UInt64(count)) }
    mutating func beginIndefiniteArray() { data.append(0x9F) }
    mutating func endIndefinite() { data.append(0xFF) }
    mutating func uint<T: BinaryInteger>(_ value: T) { head(0, UInt64(value)) }

    mutating func int(_ value: Int64) {
        if value >= 0 {
            head(0, UInt64(value))
        } else {
            head(1, UInt64(-1 - value))
        }
    }

    mutating func bytes(_ value: Data) {
        head(2, UInt64(value.count))
        data.append(value)
    }

    mutating func text(_ value: String) {
        let utf8 = Data(value.utf8)
        head(3, UInt64(utf8.count))
        data.append(utf8)
    }

    mutating func bool(_ value: Bool) { data.append(value ? 0xF5 : 0xF4) }
    mutating func tag(_ value: UInt64) { head(6, value) }

    /// Appends an item that is already encoded.
    mutating func raw(_ encoded: Data) { data.append(encoded) }

    /// Appends `#6.24(bytes)` around an encoded item.
    mutating func embedded(_ encoded: Data) {
        tag(24)
        bytes(encoded)
    }

    /// Appends `items` as an indefinite-length array.
    mutating func indefiniteArray<T>(_ items: [T], _ write: (inout ByronCBORWriter, T) throws -> Void) rethrows {
        beginIndefiniteArray()
        for item in items { try write(&self, item) }
        endIndefinite()
    }

    /// Appends `items` as a definite-length array.
    mutating func definiteArray<T>(_ items: [T], _ write: (inout ByronCBORWriter, T) throws -> Void) rethrows {
        array(items.count)
        for item in items { try write(&self, item) }
    }

    static func encode(_ write: (inout ByronCBORWriter) throws -> Void) rethrows -> Data {
        var writer = ByronCBORWriter()
        try write(&writer)
        return writer.data
    }
}

// MARK: - Kept bytes

/// The bytes a Byron item was decoded from.
///
/// Every value compares equal and hashes to nothing, so a type holding one
/// keeps its synthesized `==` and `hash(into:)` over its decoded fields.
struct ByronOriginalBytes: Hashable, Sendable {
    var data: Data?

    init(_ data: Data? = nil) {
        self.data = data
    }

    static func == (lhs: Self, rhs: Self) -> Bool { true }
    func hash(into hasher: inout Hasher) {}
}

// MARK: - Hashing

enum ByronHash {
    /// Blake2b-256 of `data`.
    static func blake2b256(_ data: Data) -> Data {
        try! Hash().blake2b(data: data, digestSize: 32, encoder: RawEncoder.self)
    }

    /// The hash of a Byron block header: Blake2b-256 of `[discriminant, header]`,
    /// where the discriminant is 0 for an epoch boundary block and 1 for a
    /// regular block. Both the block hash and a block's `prevBlock` use it.
    static func header(discriminant: UInt8, headerCBOR: Data) -> Data {
        blake2b256(Data([0x82, discriminant]) + headerCBOR)
    }
}

// MARK: - Attributes

/// Byron `attributes = {* any => any}`.
///
/// Every attributes map on mainnet is empty, but the CDDL leaves the keys and
/// values open, so they are kept as primitives together with their bytes.
public struct ByronAttributes: Sendable, Equatable, Hashable {
    /// The entries, in the order they were written.
    public let entries: OrderedDictionary<Primitive, Primitive>

    var _original = ByronOriginalBytes()

    /// The exact bytes these attributes were decoded from.
    public var originalCBOR: Data? { _original.data }

    public init(_ entries: OrderedDictionary<Primitive, Primitive> = [:]) {
        self.entries = entries
    }

    /// An empty attributes map, `{}`.
    public static let empty = ByronAttributes()

    public var isEmpty: Bool { entries.isEmpty }

    static func decode(_ item: ByronCBORItem, _ what: String) throws -> ByronAttributes {
        var entries = OrderedDictionary<Primitive, Primitive>()
        for (key, value) in try item.map(what) {
            entries[try key.primitive()] = try value.primitive()
        }
        var attributes = ByronAttributes(entries)
        attributes._original = ByronOriginalBytes(item.bytes)
        return attributes
    }

    /// The bytes these attributes were decoded from, otherwise a fresh
    /// definite-length map.
    public func toCBORData() throws -> Data {
        if let originalCBOR { return originalCBOR }
        var writer = ByronCBORWriter()
        writer.map(entries.count)
        for (key, value) in entries {
            writer.raw(try CBORSerialization.data(from: key.toCBOR()))
            writer.raw(try CBORSerialization.data(from: value.toCBOR()))
        }
        return writer.data
    }
}
