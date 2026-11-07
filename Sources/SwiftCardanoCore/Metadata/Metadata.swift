import Foundation
import OrderedCollections
import CBORCodable
import SwiftNaCl
@preconcurrency import BigInt

/// A label in transaction metadata: the unsigned integer key of a top-level metadata entry.
public typealias TransactionMetadatumLabel = UInt64

/// A value in transaction metadata.
///
/// Integers that fit `Int` are held as ``int(_:)``; the ledger allows any
/// integer CBOR can carry, and the rest are held as ``bigInt(_:)``. The two
/// compare and hash alike when they hold the same value.
public enum TransactionMetadatum: Serializable, Hashable, Equatable {
    /// A map, kept as its ordered list of pairs. See ``MapPairs``.
    case map(MapPairs<TransactionMetadatum, TransactionMetadatum>)
    /// A list. Its elements are kept in a ``NestedList``, which reads like an
    /// array and is freed without recursion however deep the metadata nests.
    case list(NestedList<TransactionMetadatum>)
    /// An integer that fits `Int`.
    case int(Int)
    /// An integer too large for `Int`.
    case bigInt(BigInt)
    /// A byte string.
    case bytes(Data)
    /// A text string.
    case text(String)

    /// A list of `elements`.
    public static func list(_ elements: [TransactionMetadatum]) -> TransactionMetadatum {
        .list(NestedList(elements))
    }

    /// An integer metadatum for `value`, held as ``int(_:)`` when it fits.
    public static func integer(_ value: BigInt) -> TransactionMetadatum {
        Int(exactly: value).map { .int($0) } ?? .bigInt(value)
    }

    /// The integer this holds, whichever case carries it, or `nil` when this
    /// is not an integer.
    public var integerValue: BigInt? {
        switch self {
        case .int(let value): return BigInt(value)
        case .bigInt(let value): return value
        default: return nil
        }
    }

    public var debugDescription: String {
        switch self {
        case .int(let i): return "int(\(i))"
        case .bigInt(let i): return "int(\(i))"
        case .bytes(let data): return "bytes(\(data.base64EncodedString()))"
        case .text(let str): return "text(\(str))"
        case .list(let arr): return "list(\(arr.count) items)"
        case .map(let dict): return "map(\(dict.count) items)"
        }
    }

    public var description: String {
        return debugDescription
    }

    // MARK: - CBORSerializable

    public static var preservesEncoding: Bool { true }

    /// Reads a metadatum, whether `primitive` keeps how it was written or not.
    public init(from primitive: Primitive) throws {
        switch primitive {
        case .cborSimpleValue(.encoded(let bytes)):
            // Carried as its bytes — as a decoder hands over deep metadata —
            // and read without recursing.
            self = try MetadatumReader.read(bytes)
        case _ where primitive.containsEncoded:
            // Deep metadata, cut part-way down by the decoder: read it whole.
            self = try MetadatumReader.read(primitive.encodedBytes())
        case .uint(let value):
            self = .integer(BigInt(value))
        case .int(let value):
            self = .integer(BigInt(value))
        case .bigInt(let value):
            self = .integer(value)
        case .bigUInt(let value):
            self = .integer(BigInt(value))
        case .cborTag(let tag) where tag.tag == 2 || tag.tag == 3:
            // The ledger reads a CBOR bignum as a metadata integer too.
            self = .integer(try BigInteger(from: primitive).value)
        case .bytes(let data):
            self = .bytes(data)
        case .byteArray(let bytes):
            self = .bytes(Data(bytes))
        case .byteString(let byteString):
            self = .bytes(byteString.bytes)
        case .string(let string):
            self = .text(string)
        case .cborSimpleValue(.indefiniteTextString(let chunks)):
            self = .text(chunks.joined())
        case .list(let array):
            self = .list(try array.map { try TransactionMetadatum(from: $0) })
        case .indefiniteList(let array):
            self = .list(try array.map { try TransactionMetadatum(from: $0) })
        case .dict, .orderedDict, .indefiniteDictionary:
            var map = MapPairs<TransactionMetadatum, TransactionMetadatum>()
            for (key, value) in try Metadata.entries(of: primitive) {
                map.append(key: try TransactionMetadatum(from: key), value: try TransactionMetadatum(from: value))
            }
            self = .map(map)
        default:
            throw CardanoCoreError.deserializeError(
                "Unsupported CBOR type for TransactionMetadatum")
        }
    }

    /// The metadatum as a primitive tree; one nested deeper than
    /// ``maxConversionDepth`` as its encoded bytes, which hold the same value.
    public func toPrimitive() throws -> Primitive {
        if nests(deeperThan: Self.maxConversionDepth) {
            return .cborSimpleValue(.encoded(try MetadatumWriter.encode(self)))
        }
        return try primitive()
    }

    func primitive() throws -> Primitive {
        switch self {
        case .int(let value):
            return value >= 0 ? .uint(UInt64(value)) : .int(Int64(value))
        case .bigInt(let value):
            // Beyond 64 bits the ledger writes a CBOR bignum, as for Plutus data.
            return try BigInteger(from: .bigInt(value)).toPrimitive()
        case .bytes(let data):
            return .bytes(data)
        case .text(let string):
            return .string(string)
        case .list(let array):
            let list = try array.map { try $0.primitive() }
            return .list(list)
        case .map(let map):
            return try map.primitive(
                indefinite: false, key: { try $0.primitive() }, value: { try $0.primitive() })
        }
    }

    // MARK: - JSONSerializable

    /// Reads a metadatum from JSON in cardano-cli's detailed schema —
    /// `{"int": 1}`, `{"bytes": "<hex>"}`, `{"string": "…"}`, `{"list": […]}`,
    /// `{"map": [{"k": …, "v": …}]}` — which keeps every value as it is. Plain
    /// JSON values are read too: a number as an integer, a string as text, an
    /// array as a list and an object as a map with text keys.
    ///
    /// - Throws: When the JSON is not a metadatum, or nests deeper than
    ///   ``maxConversionDepth``.
    public static func fromDict(_ primitive: Primitive) throws -> TransactionMetadatum {
        try fromDict(primitive, level: 1)
    }

    /// Reads the metadatum at depth `level` of the JSON, the outermost at 1.
    static func fromDict(_ primitive: Primitive, level: Int) throws -> TransactionMetadatum {
        // This recurses once per level, so containers are read in out-of-line
        // helpers that keep its frame small: 128 levels fit a 512 KB stack.
        try checkJSONDepth(level, limit: maxConversionDepth, "Metadata JSON")
        if case .orderedDict(let object) = primitive, object.count == 1,
            case .string(let key) = object.keys[0]
        {
            switch (key, object.values[0]) {
            case ("list", .list(let elements)):
                return try list(elements, level: level)
            case ("map", .list(let entries)):
                return try detailedMap(entries, level: level)
            case ("int", _), ("bytes", .string), ("string", .string):
                return try detailedScalar(key, object.values[0], level: level)
            default:
                break
            }
        }
        switch primitive {
        case .string(let string):
            return .text(string)
        case .list(let array):
            return try list(array, level: level)
        case .indefiniteList(let array):
            return try list(array.getAll(), level: level)
        case .dict, .orderedDict:
            return try map(Metadata.entries(of: primitive), level: level)
        default:
            if let integer = primitive.integerValue { return .integer(integer) }
            throw unsupportedJSON(primitive)
        }
    }

    /// A list whose elements are at `level + 1`.
    @inline(never)
    private static func list(_ elements: [Primitive], level: Int) throws -> TransactionMetadatum {
        var items: [TransactionMetadatum] = []
        items.reserveCapacity(elements.count)
        for element in elements {
            items.append(try fromDict(element, level: level + 1))
        }
        return .list(items)
    }

    /// A map whose keys and values are at `level + 1`.
    @inline(never)
    private static func map(
        _ entries: OrderedDictionary<Primitive, Primitive>, level: Int
    ) throws -> TransactionMetadatum {
        var pairs = MapPairs<TransactionMetadatum, TransactionMetadatum>()
        for (key, value) in entries {
            pairs.append(
                key: try fromDict(key, level: level + 1), value: try fromDict(value, level: level + 1))
        }
        return .map(pairs)
    }

    /// The detailed schema's `{"map": [{"k": …, "v": …}]}`.
    @inline(never)
    private static func detailedMap(_ entries: [Primitive], level: Int) throws -> TransactionMetadatum {
        var pairs = MapPairs<TransactionMetadatum, TransactionMetadatum>()
        for entry in entries {
            guard case .orderedDict(let pair) = entry, let k = pair[.string("k")],
                let v = pair[.string("v")]
            else {
                throw CardanoCoreError.deserializeError("Invalid metadata map entry: \(entry)")
            }
            pairs.append(key: try fromDict(k, level: level + 1), value: try fromDict(v, level: level + 1))
        }
        return .map(pairs)
    }

    /// The detailed schema's `{"int": …}`, `{"bytes": "<hex>"}` and
    /// `{"string": "…"}`.
    @inline(never)
    private static func detailedScalar(
        _ key: String, _ value: Primitive, level: Int
    ) throws -> TransactionMetadatum {
        switch (key, value) {
        case ("bytes", .string(let hex)):
            guard let data = Data(hexString: hex) else {
                throw CardanoCoreError.deserializeError("Invalid hex in metadata bytes: \(hex)")
            }
            return .bytes(data)
        case ("string", .string(let text)):
            return .text(text)
        case ("int", .orderedDict), ("int", .dict), ("int", .list), ("int", .indefiniteList):
            // A container in the integer's place counts as a level of its
            // own, so it cannot recurse without bound.
            return try fromDict(value, level: level + 1)
        default:
            // The integer is this level's value.
            return try fromDict(value, level: level)
        }
    }

    @inline(never)
    private static func unsupportedJSON(_ primitive: Primitive) -> CardanoCoreError {
        CardanoCoreError.deserializeError("Unsupported JSON for TransactionMetadatum: \(primitive)")
    }

    /// The metadatum as JSON in cardano-cli's detailed schema, which keeps
    /// bytes apart from text, keeps map keys of any type, and keeps every pair
    /// of a map that repeats a key.
    ///
    /// - Throws: When it nests deeper than ``maxConversionDepth``.
    public func toDict() throws -> Primitive {
        guard !nests(deeperThan: Self.maxConversionDepth) else {
            throw CardanoCoreError.valueError(
                "Metadata nests deeper than \(Self.maxConversionDepth) levels, too deep to convert to JSON")
        }
        return try dict()
    }

    func dict() throws -> Primitive {
        switch self {
        case .int(let value):
            return .orderedDict([.string("int"): .int(Int64(value))])
        case .bigInt(let value):
            return .orderedDict([.string("int"): .bigInt(value)])
        case .bytes(let data):
            return .orderedDict([.string("bytes"): .string(data.toHex)])
        case .text(let string):
            return .orderedDict([.string("string"): .string(string)])
        case .list(let array):
            return .orderedDict([.string("list"): .list(try array.map { try $0.dict() })])
        case .map(let map):
            let entries: [Primitive] = try map.map {
                .orderedDict([.string("k"): try $0.key.dict(), .string("v"): try $0.value.dict()])
            }
            return .orderedDict([.string("map"): .list(entries)])
        }
    }

}

// MARK: - MetadataType
/// The three forms the auxiliary data of a transaction can take.
///
/// Reading from CBOR picks the form from the shape of the value: a map is ``metadata(_:)``, an array is ``shelleyMaryMetadata(_:)``, and tag 259 is ``alonzoMetadata(_:)``. A ``metadata(_:)`` value equals an ``alonzoMetadata(_:)`` value that holds the same metadata and no scripts.
public enum MetadataType: Serializable, Equatable {
    /// The Shelley form: a bare metadata map.
    case metadata(Metadata)
    /// The Shelley-MA form: an array of metadata and, optionally, native scripts.
    case shelleyMaryMetadata(ShelleyMaryMetadata)
    /// The Alonzo form: a tag 259 map that can also hold native and Plutus scripts.
    case alonzoMetadata(AlonzoMetadata)

    // Custom Equatable to handle semantic comparison
    public static func == (lhs: MetadataType, rhs: MetadataType) -> Bool {
        switch (lhs, rhs) {
        case (.metadata(let lhsData), .metadata(let rhsData)):
            return lhsData == rhsData
        case (.shelleyMaryMetadata(let lhsData), .shelleyMaryMetadata(let rhsData)):
            return lhsData == rhsData
        case (.alonzoMetadata(let lhsData), .alonzoMetadata(let rhsData)):
            return lhsData == rhsData
        // Handle cross-variant comparison: plain Metadata vs AlonzoMetadata with only metadata
        case (.metadata(let plainMetadata), .alonzoMetadata(let alonzoMetadata)):
            // AlonzoMetadata with only metadata field set is semantically equivalent to plain Metadata
            return alonzoMetadata.nativeScripts == nil && alonzoMetadata.plutusV1Script == nil
                && alonzoMetadata.plutusV2Script == nil && alonzoMetadata.plutusV3Script == nil
                && alonzoMetadata.metadata == plainMetadata
        case (.alonzoMetadata(let alonzoMetadata), .metadata(let plainMetadata)):
            // Symmetric case
            return alonzoMetadata.nativeScripts == nil && alonzoMetadata.plutusV1Script == nil
                && alonzoMetadata.plutusV2Script == nil && alonzoMetadata.plutusV3Script == nil
                && alonzoMetadata.metadata == plainMetadata
        default:
            return false
        }
    }

    // MARK: - CBORSerializable

    public static var preservesEncoding: Bool { true }

    public init(from primitive: Primitive) throws {
        switch primitive {
        case .cborTag(let cborTag) where cborTag.tag == AlonzoMetadata.TAG:
            self = .alonzoMetadata(try AlonzoMetadata(from: primitive))
        case .dict, .orderedDict, .indefiniteDictionary:
            self = .metadata(try Metadata(from: primitive))
        case .list, .indefiniteList:
            self = .shelleyMaryMetadata(try ShelleyMaryMetadata(from: primitive))
        default:
            throw CardanoCoreError.deserializeError("Invalid MetadataType primitive: \(primitive)")
        }
    }

    public func toPrimitive() throws -> Primitive {
        switch self {
        case .metadata(let metadata):
            return try metadata.toPrimitive()
        case .shelleyMaryMetadata(let shelleyMaryMetadata):
            return try shelleyMaryMetadata.toPrimitive()
        case .alonzoMetadata(let alonzoMetadata):
            return try alonzoMetadata.toPrimitive()
        }
    }

    // MARK: - JSONSerializable

    public static func fromDict(_ primitive: Primitive) throws -> MetadataType {
        // Check if it's a wrapped format with type discriminator
        if case .orderedDict(let dict) = primitive,
            let metadataValue = dict[.string("metadata")]
        {
            // The wrapper just contains plain Metadata, but we need to check if there are other fields
            // that would indicate this is actually AlonzoMetadata
            if dict.count == 1 {
                // Only "metadata" key, so it's plain Metadata
                return .metadata(try Metadata.fromDict(metadataValue))
            } else {
                // Has other fields, could be AlonzoMetadata
                return .alonzoMetadata(try AlonzoMetadata.fromDict(primitive))
            }
        }

        // Try to detect the type based on structure
        // AlonzoMetadata is a dict with numeric keys
        if case .dict(let dict) = primitive,
            dict.keys.contains(where: {
                if case .uint(_) = $0 { return true }
                return false
            })
        {
            return .alonzoMetadata(try AlonzoMetadata.fromDict(primitive))
        }

        if case .orderedDict(let dict) = primitive,
            dict.keys.contains(where: {
                if case .uint(_) = $0 { return true }
                return false
            })
        {
            return .alonzoMetadata(try AlonzoMetadata.fromDict(primitive))
        }

        // ShelleyMaryMetadata is a list with at least 1 element
        if case .list(let elements) = primitive, elements.count >= 1 {
            return .shelleyMaryMetadata(try ShelleyMaryMetadata.fromDict(primitive))
        }

        // Otherwise try as plain Metadata (dict)
        if case .dict(_) = primitive {
            return .metadata(try Metadata.fromDict(primitive))
        }

        if case .orderedDict(_) = primitive {
            return .metadata(try Metadata.fromDict(primitive))
        }

        throw CardanoCoreError.deserializeError("Invalid MetadataType primitive: \(primitive)")
    }

    public func toDict() throws -> Primitive {
        switch self {
        case .metadata(let metadata):
            // Wrap with "metadata" key for JSON format
            var wrapper = OrderedDictionary<Primitive, Primitive>()
            wrapper[.string("metadata")] = try metadata.toDict()
            return .orderedDict(wrapper)
        case .shelleyMaryMetadata(let shelleyMaryMetadata):
            return try shelleyMaryMetadata.toDict()
        case .alonzoMetadata(let alonzoMetadata):
            return try alonzoMetadata.toDict()
        }
    }

}

// MARK: - Metadata
/// Transaction metadata: a map from labels to metadata values, `{ * transaction_metadatum_label => transaction_metadatum }`.
public struct Metadata: Serializable, Equatable {
    /// The type of a metadata label.
    public typealias KEY_TYPE = TransactionMetadatumLabel
    /// The type of a metadata value.
    public typealias VALUE_TYPE = TransactionMetadatum

    /// The most bytes a byte string or text string in metadata may hold, 64.
    public static let MAX_ITEM_SIZE = 64

    /// The metadata by label, in the order it is written.
    ///
    /// The auxiliary-data hash is taken over the encoded bytes, so the order
    /// is kept: decoded metadata keeps the order it was read in.
    public var data: OrderedDictionary<KEY_TYPE, VALUE_TYPE>

    /// Equal when they hold the same labels and values, in whatever order.
    public static func == (lhs: Metadata, rhs: Metadata) -> Bool {
        guard lhs.data.count == rhs.data.count else { return false }
        return lhs.data.allSatisfy { rhs.data[$0.key] == $0.value }
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(data.count)
        for key in data.keys.sorted() {
            hasher.combine(key)
            hasher.combine(data[key])
        }
    }

    /// The value under a label, or `nil` when there is none. Setting `nil` removes the label.
    ///
    /// - Parameter key: The metadata label.
    public subscript(key: KEY_TYPE) -> VALUE_TYPE? {
        get {
            return data[key]
        }
        set {
            data[key] = newValue
        }
    }

    /// Metadata written in ascending label order.
    ///
    /// - Throws: When a byte string or text string is longer than
    ///   ``MAX_ITEM_SIZE`` bytes, which the ledger rejects.
    public init(_ data: [KEY_TYPE: VALUE_TYPE]) throws {
        try self.init(entries: OrderedDictionary(uniqueKeysWithValues: data.sorted { $0.key < $1.key }))
    }

    /// Metadata written in the order of `entries`.
    ///
    /// - Throws: When a byte string or text string is longer than
    ///   ``MAX_ITEM_SIZE`` bytes, which the ledger rejects.
    public init(entries: OrderedDictionary<KEY_TYPE, VALUE_TYPE>) throws {
        for value in entries.values {
            try Self.validate(value)
        }
        self.data = entries
    }

    /// Metadata as decoded, not checked against ``MAX_ITEM_SIZE``.
    init(decoded entries: OrderedDictionary<KEY_TYPE, VALUE_TYPE>) {
        self.data = entries
    }

    // MARK: - CBORSerializable

    public static var preservesEncoding: Bool { true }

    /// Reads metadata as written. Its strings are not checked against
    /// ``MAX_ITEM_SIZE``: the ledger only began enforcing that limit after the
    /// first Shelley protocol version, so longer ones are on chain.
    public init(from primitive: Primitive) throws {
        self.data = [:]
        for (key, value) in try Self.entries(of: primitive) {
            guard case .uint(let label) = key else {
                throw CardanoCoreError.deserializeError("Invalid Metadata key type")
            }
            self.data[label] = try VALUE_TYPE(from: value)
        }
    }

    public func toPrimitive() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        for (key, value) in data {
            dict[.uint(UInt64(key))] = try value.toPrimitive()
        }
        return .orderedDict(dict)
    }

    /// The entries of a map, whichever form `primitive` holds it in.
    static func entries(of primitive: Primitive) throws -> OrderedDictionary<Primitive, Primitive> {
        switch primitive {
        case .orderedDict(let entries), .indefiniteDictionary(let entries):
            return entries
        case .dict(let dict):
            return OrderedDictionary(uniqueKeysWithValues: dict.map { ($0.key, $0.value) })
        default:
            throw CardanoCoreError.deserializeError("Invalid Metadata type: \(primitive)")
        }
    }

    // MARK: - JSONSerializable

    public static func fromDict(_ primitive: Primitive) throws -> Metadata {
        let dict: OrderedDictionary<Primitive, Primitive>
        switch primitive {
        case .dict(let d):
            dict = OrderedDictionary(uniqueKeysWithValues: d.map { ($0.key, $0.value) })
        case .orderedDict(let d):
            dict = d
        default:
            throw CardanoCoreError.deserializeError("Expected dictionary for Metadata")
        }

        var metadata = OrderedDictionary<KEY_TYPE, VALUE_TYPE>()

        for (key, value) in dict {
            let keyValue: UInt64
            switch key {
            case .string(let strValue):
                guard let uint = UInt64(strValue) else {
                    throw CardanoCoreError.deserializeError(
                        "Expected numeric string key in Metadata dictionary")
                }
                keyValue = uint
            case .uint(let uintValue):
                keyValue = UInt64(uintValue)
            case .int(let intValue):
                guard let uint = UInt64(exactly: intValue) else {
                    throw CardanoCoreError.deserializeError("Negative Metadata label: \(intValue)")
                }
                keyValue = uint
            default:
                throw CardanoCoreError.deserializeError(
                    "Expected string or uint key in Metadata dictionary, got: \(key)")
            }

            metadata[KEY_TYPE(keyValue)] = try VALUE_TYPE.fromDict(value)
        }

        // A JSON object has no order of its own, so an unordered one is
        // written in label order.
        if case .dict = primitive {
            metadata.sort { $0.key < $1.key }
        }
        return try Metadata(entries: metadata)
    }

    public func toDict() throws -> Primitive {
        var result = OrderedDictionary<Primitive, Primitive>()
        for (key, value) in data {
            result[.string(String(key))] = try value.toDict()
        }
        return .orderedDict(result)
    }

    /// Checks every byte and text string in `value`, in a loop.
    private static func validate(_ value: VALUE_TYPE) throws {
        var pending = [value]
        while let value = pending.popLast() {
            switch value {
            case .bytes(let data) where data.count > MAX_ITEM_SIZE:
                throw CardanoCoreError.invalidArgument("Data size exceeds \(MAX_ITEM_SIZE) bytes.")
            case .text(let string) where string.utf8.count > MAX_ITEM_SIZE:
                throw CardanoCoreError.invalidArgument("String size exceeds \(MAX_ITEM_SIZE) bytes.")
            default:
                pending.append(contentsOf: value.children)
            }
        }
    }
}

// MARK: - ShelleyMaryMetadata
/// Auxiliary data in the Shelley-MA form: `[metadata, [* native_script]]`.
///
/// Reading accepts a definite- or indefinite-length array of one or two elements. Writing gives a one-element array when ``nativeScripts`` is `nil`.
public struct ShelleyMaryMetadata: Serializable, Equatable {
    /// The metadata.
    public var metadata: Metadata
    /// The native scripts, or `nil` when there are none.
    public var nativeScripts: [NativeScript]?

    /// Creates Shelley-MA auxiliary data.
    ///
    /// - Parameters:
    ///   - metadata: The metadata.
    ///   - nativeScripts: The native scripts, or `nil` for none.
    public init(metadata: Metadata, nativeScripts: [NativeScript]?) {
        self.metadata = metadata
        self.nativeScripts = nativeScripts
    }

    // MARK: - CBORSerializable

    public static var preservesEncoding: Bool { true }

    public init(from primitive: Primitive) throws {
        guard let elements = Self.elements(of: primitive), elements.count >= 1 else {
            throw CardanoCoreError.deserializeError("Invalid ShelleyMaryMetadata type")
        }

        metadata = try Metadata(from: elements[0])

        if elements.count > 1, let scripts = Self.elements(of: try elements[1].normalized()) {
            nativeScripts = try scripts.map { try NativeScript(from: $0) }
        } else {
            nativeScripts = nil
        }
    }

    /// The elements of a list, whether it was written definite or indefinite.
    static func elements(of primitive: Primitive) -> [Primitive]? {
        switch primitive {
        case .list(let elements): return elements
        case .indefiniteList(let elements): return elements.getAll()
        default: return nil
        }
    }

    public func toPrimitive() throws -> Primitive {
        var array: [Primitive] = []
        array.append(try metadata.toPrimitive())

        if let nativeScripts = nativeScripts {
            let scriptsPrimitive = try nativeScripts.map { try $0.toPrimitive() }
            array.append(.list(scriptsPrimitive))
        }

        return .list(array)
    }

    // MARK: - JSONSerializable

    public static func fromDict(_ primitive: Primitive) throws -> ShelleyMaryMetadata {
        guard case .list(let elements) = primitive, elements.count >= 1 else {
            throw CardanoCoreError.deserializeError(
                "Expected list with at least 1 element for ShelleyMaryMetadata")
        }

        let metadata = try Metadata.fromDict(elements[0])

        var nativeScripts: [NativeScript]?
        if elements.count > 1, case .list(let scriptsList) = elements[1] {
            nativeScripts = try scriptsList.map { try NativeScript.fromDict($0) }
        }

        return ShelleyMaryMetadata(metadata: metadata, nativeScripts: nativeScripts)
    }

    public func toDict() throws -> Primitive {
        var array: [Primitive] = []
        array.append(try metadata.toDict())

        if let nativeScripts = nativeScripts {
            let scriptsPrimitive = try nativeScripts.map { try $0.toDict() }
            array.append(.list(scriptsPrimitive))
        }

        return .list(array)
    }

}

// MARK: - AlonzoMetadata
/// Auxiliary data in the Alonzo form: tag 259 around a map with optional fields.
///
/// The keys are `0` for metadata, `1` for native scripts, `2` for Plutus V1 scripts, `3` for Plutus V2 scripts and `4` for Plutus V3 scripts. Fields that are `nil` are left out when writing.
public struct AlonzoMetadata: Serializable, Equatable {
    /// The CBOR tag of Alonzo-form auxiliary data, 259.
    public static let TAG: UInt64 = 259

    /// The metadata, under key `0`.
    public var metadata: Metadata?
    /// The native scripts, under key `1`.
    public var nativeScripts: [NativeScript]?
    /// The Plutus V1 scripts, under key `2`.
    public var plutusV1Script: [PlutusV1Script]?
    /// The Plutus V2 scripts, under key `3`.
    public var plutusV2Script: [PlutusV2Script]?
    /// The Plutus V3 scripts, under key `4`.
    public var plutusV3Script: [PlutusV3Script]?

    enum CodingKeys: Int, CodingKey {
        case metadata = 0
        case nativeScripts = 1
        case plutusV1Script = 2
        case plutusV2Script = 3
        case plutusV3Script = 4
    }

    /// Creates Alonzo-form auxiliary data. Every field is optional.
    ///
    /// - Parameters:
    ///   - metadata: The metadata.
    ///   - nativeScripts: The native scripts.
    ///   - plutusV1Script: The Plutus V1 scripts.
    ///   - plutusV2Script: The Plutus V2 scripts.
    ///   - plutusV3Script: The Plutus V3 scripts.
    public init(
        metadata: Metadata? = nil,
        nativeScripts: [NativeScript]? = nil,
        plutusV1Script: [PlutusV1Script]? = nil,
        plutusV2Script: [PlutusV2Script]? = nil,
        plutusV3Script: [PlutusV3Script]? = nil
    ) {
        self.metadata = metadata
        self.nativeScripts = nativeScripts
        self.plutusV1Script = plutusV1Script
        self.plutusV2Script = plutusV2Script
        self.plutusV3Script = plutusV3Script
    }

    // MARK: - CBORSerializable

    public static var preservesEncoding: Bool { true }

    public init(from primitive: Primitive) throws {
        guard case .cborTag(let cborTag) = primitive,
            cborTag.tag == AlonzoMetadata.TAG
        else {
            throw CardanoCoreError.deserializeError(
                "Invalid AlonzoMetadata: Not CBOR tag \(AlonzoMetadata.TAG)")
        }

        // Handle the case where tag value is a dictionary/map structure
        var cborDict: OrderedDictionary<Primitive, Primitive> = OrderedDictionary<
            Primitive, Primitive
        >()

        switch cborTag.value {
        case .dict(let dict):
            cborDict.merge(dict) { (_, new) in new }
        case .orderedDict(let dict):
            cborDict = dict
        case .indefiniteDictionary(let dict):
            cborDict = dict
        default:
            // For any other value type (including maps converted to dictionaries),
            // we'll create an empty dictionary and proceed with no metadata
            // This handles edge cases where the tag exists but has no structured content
            break
        }

        if let metadataPrimitive = cborDict[.uint(0)] {
            self.metadata = try Metadata(from: metadataPrimitive)
        } else {
            self.metadata = nil
        }

        /// The scripts under `key`, read in the usual form.
        func scripts<T: CBORSerializable>(_ key: UInt64) throws -> [T]? {
            guard let primitive = cborDict[.uint(key)],
                let elements = ShelleyMaryMetadata.elements(of: try primitive.normalized())
            else { return nil }
            return try elements.map { try T(from: $0) }
        }
        self.nativeScripts = try scripts(1)
        self.plutusV1Script = try scripts(2)
        self.plutusV2Script = try scripts(3)
        self.plutusV3Script = try scripts(4)
    }

    public func toPrimitive() throws -> Primitive {
        var cborDict = OrderedDictionary<Primitive, Primitive>()

        if let metadata = metadata {
            cborDict[.uint(0)] = try metadata.toPrimitive()
        }

        if let nativeScripts = nativeScripts {
            let scriptsPrimitive = try nativeScripts.map { try $0.toPrimitive() }
            cborDict[.uint(1)] = .list(scriptsPrimitive)
        }

        if let plutusV1Script = plutusV1Script {
            let scriptsPrimitive = try plutusV1Script.map { try $0.toPrimitive() }
            cborDict[.uint(2)] = .list(scriptsPrimitive)
        }

        if let plutusV2Script = plutusV2Script {
            let scriptsPrimitive = try plutusV2Script.map { try $0.toPrimitive() }
            cborDict[.uint(3)] = .list(scriptsPrimitive)
        }

        if let plutusV3Script = plutusV3Script {
            let scriptsPrimitive = try plutusV3Script.map { try $0.toPrimitive() }
            cborDict[.uint(4)] = .list(scriptsPrimitive)
        }

        return .cborTag(
            CBORTag(
                tag: Self.TAG,
                value: .orderedDict(cborDict)
            )
        )
    }

    // MARK: - JSONSerializable

    public static func fromDict(_ primitive: Primitive) throws -> AlonzoMetadata {
        var dict: OrderedDictionary<Primitive, Primitive>

        switch primitive {
        case .dict(let d):
            dict = OrderedDictionary(uniqueKeysWithValues: d.map { ($0.key, $0.value) })
        case .orderedDict(let d):
            dict = d
        default:
            throw CardanoCoreError.deserializeError("Expected dictionary for AlonzoMetadata")
        }

        let metadata: Metadata?
        if let metadataPrimitive = dict[.string("metadata")] {
            metadata = try Metadata.fromDict(metadataPrimitive)
        } else {
            metadata = nil
        }

        let nativeScripts: [NativeScript]?
        if let nativeScriptsPrimitive = dict[.string("nativeScripts")],
            case .list(let scriptsList) = nativeScriptsPrimitive
        {
            nativeScripts = try scriptsList.map { try NativeScript.fromDict($0) }
        } else {
            nativeScripts = nil
        }

        let plutusV1Script: [PlutusV1Script]?
        if let plutusV1ScriptPrimitive = dict[.string("plutusV1Script")],
            case .list(let scriptsList) = plutusV1ScriptPrimitive
        {
            plutusV1Script = try scriptsList.map { try PlutusV1Script.fromDict($0) }
        } else {
            plutusV1Script = nil
        }

        let plutusV2Script: [PlutusV2Script]?
        if let plutusV2ScriptPrimitive = dict[.string("plutusV2Script")],
            case .list(let scriptsList) = plutusV2ScriptPrimitive
        {
            plutusV2Script = try scriptsList.map { try PlutusV2Script.fromDict($0) }
        } else {
            plutusV2Script = nil
        }

        let plutusV3Script: [PlutusV3Script]?
        if let plutusV3ScriptPrimitive = dict[.string("plutusV3Script")],
            case .list(let scriptsList) = plutusV3ScriptPrimitive
        {
            plutusV3Script = try scriptsList.map { try PlutusV3Script.fromDict($0) }
        } else {
            plutusV3Script = nil
        }

        return AlonzoMetadata(
            metadata: metadata,
            nativeScripts: nativeScripts,
            plutusV1Script: plutusV1Script,
            plutusV2Script: plutusV2Script,
            plutusV3Script: plutusV3Script
        )
    }

    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()

        if let metadata = metadata {
            dict[.string("metadata")] = try metadata.toDict()
        }

        if let nativeScripts = nativeScripts {
            let scriptsPrimitive = try nativeScripts.map { try $0.toDict() }
            dict[.string("nativeScripts")] = .list(scriptsPrimitive)
        }

        if let plutusV1Script = plutusV1Script {
            let scriptsPrimitive = try plutusV1Script.map { try $0.toDict() }
            dict[.string("plutusV1Script")] = .list(scriptsPrimitive)
        }

        if let plutusV2Script = plutusV2Script {
            let scriptsPrimitive = try plutusV2Script.map { try $0.toDict() }
            dict[.string("plutusV2Script")] = .list(scriptsPrimitive)
        }

        if let plutusV3Script = plutusV3Script {
            let scriptsPrimitive = try plutusV3Script.map { try $0.toDict() }
            dict[.string("plutusV3Script")] = .list(scriptsPrimitive)
        }

        return .orderedDict(dict)
    }

}

// MARK: - AuxiliaryData
/// The auxiliary data of a transaction, in any of the forms ``MetadataType`` covers.
///
/// A value decoded from CBOR keeps the bytes it was read from in ``originalCBOR`` until ``data`` changes, so writing it and hashing it give the same result as the original.
public struct AuxiliaryData: Serializable, Equatable {
    /// The auxiliary data. Setting it clears ``originalCBOR``.
    public var data: MetadataType { didSet { originalCBOR = nil } }

    /// The exact bytes this was decoded from, while it is unchanged.
    ///
    /// The body commits to the hash of the auxiliary data as written, and
    /// decoding cannot keep every detail of it — the width of an integer's
    /// header, for one — so while this is set ``toCBORData(deterministic:)``
    /// returns these bytes and ``hash()`` hashes them.
    public internal(set) var originalCBOR: Data? = nil

    /// Creates auxiliary data from one of its forms.
    ///
    /// - Parameter data: The auxiliary data.
    public init(data: MetadataType) {
        self.data = data
    }

    // Custom Equatable to handle semantic comparison
    public static func == (lhs: AuxiliaryData, rhs: AuxiliaryData) -> Bool {
        return lhs.data == rhs.data
    }

    /// Hashes the metadata alone, which every value `==` holds equal shares.
    public func hash(into hasher: inout Hasher) {
        switch data {
        case .metadata(let metadata): hasher.combine(metadata)
        case .shelleyMaryMetadata(let shelleyMary): hasher.combine(shelleyMary.metadata)
        case .alonzoMetadata(let alonzo): hasher.combine(alonzo.metadata)
        }
    }

    /// Compute a blake2b hash from the key
    /// - Returns: Hash output in bytes.
    public func hash() throws -> AuxiliaryDataHash {
        return AuxiliaryDataHash(
            payload: try SwiftNaCl.Hash().blake2b(
                data: self.toCBORData(),
                digestSize: AUXILIARY_DATA_HASH_SIZE,
                encoder: RawEncoder.self
            )
        )
    }

    /// Decodes auxiliary data as the current era's ledger reads it, keeping
    /// the bytes it was read from.
    public static func fromCBOR(data: Data) throws -> AuxiliaryData {
        try fromCBOR(data: data, era: .conway)
    }

    /// Decodes auxiliary data as the ledger of `era` reads it, keeping the
    /// bytes it was read from.
    public static func fromCBOR(data: Data, era: Era) throws -> AuxiliaryData {
        let scanner = CBORItemScanner(data)
        guard try scanner.end(ofItemAt: 0) == scanner.bytes.count else {
            throw CardanoCoreError.deserializeError("Trailing bytes after AuxiliaryData")
        }
        try LedgerDuplicateRules(scanner.bytes, era: era).checkAuxiliaryData(at: 0)
        var auxiliaryData = try Transaction.decoder().decode(AuxiliaryData.self, from: data)
        try auxiliaryData.keepBytes(scanner.bytes)
        return auxiliaryData
    }

    /// Records `bytes` as what this was decoded from, and reads its metadata
    /// again from them, so that a map that repeats a key keeps every pair.
    mutating func keepBytes(_ bytes: Data) throws {
        let scanner = CBORItemScanner(bytes)
        let reader = MetadatumReader(bytes)
        let header = try scanner.header(at: 0)
        var metadataOffset: Int?
        // The native scripts, read again from their bytes, which they keep.
        var nativeScripts: [NativeScript]?
        if header.major == 5 {
            metadataOffset = 0
        } else if header.major == 4 {
            let elements = try scanner.elements(ofArrayAt: 0)
            metadataOffset = elements.first?.lowerBound
            if elements.count > 1 {
                nativeScripts = try NativeScript.read(scanner, arrayAt: elements[1].lowerBound)
            }
        } else if header.major == 6 {
            for (key, value) in try scanner.entries(ofMapAt: scanner.untagged(at: 0)) {
                switch try scanner.unsignedInteger(at: key.lowerBound) {
                case 0: metadataOffset = value.lowerBound
                case 1: nativeScripts = try NativeScript.read(scanner, arrayAt: value.lowerBound)
                default: break
                }
            }
        }
        if let nativeScripts {
            switch data {
            case .shelleyMaryMetadata(var shelleyMary) where shelleyMary.nativeScripts != nil:
                shelleyMary.nativeScripts = nativeScripts
                data = .shelleyMaryMetadata(shelleyMary)
            case .alonzoMetadata(var alonzo) where alonzo.nativeScripts != nil:
                alonzo.nativeScripts = nativeScripts
                data = .alonzoMetadata(alonzo)
            default:
                break
            }
        }
        if let metadataOffset {
            let metadata = Metadata(decoded: try reader.metadata(at: metadataOffset).0)
            switch data {
            case .metadata: data = .metadata(metadata)
            case .shelleyMaryMetadata(var shelleyMary):
                shelleyMary.metadata = metadata
                data = .shelleyMaryMetadata(shelleyMary)
            case .alonzoMetadata(var alonzo):
                alonzo.metadata = metadata
                data = .alonzoMetadata(alonzo)
            }
        }
        // Set after the metadata above, whose setter clears it.
        originalCBOR = scanner.bytes
    }

    /// Decodes auxiliary data as the Conway ledger reads it, keeping the bytes it was read from.
    ///
    /// - Parameter cbor: The CBOR bytes of the auxiliary data, with nothing after them.
    /// - Throws: When the bytes are not valid auxiliary data, break the ledger's duplicate rules, or have trailing bytes.
    public init(from cbor: Data) throws {
        self = try Self.fromCBOR(data: cbor)
    }

    /// The bytes this was decoded from while it is unchanged, otherwise a
    /// fresh encoding.
    public func toCBORData(deterministic: Bool = false) throws -> Data {
        _ = deterministic
        return try originalCBOR ?? CBOREncoder().encode(self)
    }

    // MARK: - CBORSerializable

    public static var preservesEncoding: Bool { true }

    public init(from primitive: Primitive) throws {
        // Bytes kept as written, from this type's own `toPrimitive()`: read
        // them again, keeping them.
        if case .cborSimpleValue(.encoded(let bytes)) = primitive {
            self = try Self.fromCBOR(data: bytes)
            return
        }
        self.data = try MetadataType(from: primitive)
    }

    /// The bytes this was decoded from while it is unchanged — so that
    /// encoding it, alone or inside a transaction, gives what was written and
    /// keeps its hash — otherwise its metadata.
    public func toPrimitive() throws -> Primitive {
        if let originalCBOR {
            return .cborSimpleValue(.encoded(originalCBOR))
        }
        return try data.toPrimitive()
    }

    // MARK: - JSONSerializable

    public static func fromDict(_ primitive: Primitive) throws -> AuxiliaryData {
        let metadataType = try MetadataType.fromDict(primitive)
        return AuxiliaryData(data: metadataType)
    }

    public func toDict() throws -> Primitive {
        return try data.toDict()
    }

}
