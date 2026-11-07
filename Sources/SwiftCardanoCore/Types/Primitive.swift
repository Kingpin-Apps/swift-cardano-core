@preconcurrency import BigInt
import Foundation
import OrderedCollections
import CBORCodable

/// CBORCodable's dynamically typed value, which ``Primitive/toAnyValue()`` and
/// a few other calls return, named here so callers need not import CBORCodable.
public typealias AnyValue = CBORCodable.AnyValue

/// A dynamically typed CBOR value, the intermediate form every serializable type in this module reads from and writes to.
///
/// Each case says how it is written to CBOR by ``toCBOR()``. Several cases exist only so that a value read from CBOR keeps how it was written (definite or indefinite length, map key order), so it encodes back to the same bytes.
public indirect enum Primitive: CBORSerializable, Sendable {
    /// A byte string.
    case bytes(Data)
    /// A byte string held as an array of bytes. Written as a CBOR byte string.
    case byteArray([UInt8])
    /// A text string.
    case string(String)
    /// A signed 64-bit integer. Written as a CBOR unsigned or negative integer.
    case int(Int64)
    /// An unsigned 64-bit integer.
    case uint(UInt64)
    /// An arbitrary-precision integer. Written as a plain CBOR integer when it fits in 64 bits, otherwise as a tag 2 or tag 3 bignum.
    case bigInt(BigInt)
    /// An arbitrary-precision unsigned integer. Written as for ``bigInt(_:)``.
    case bigUInt(BigUInt)
    /// A floating-point number. Written as a CBOR double.
    case float(Double)
    /// A decimal number. Written as a text string of its description.
    case decimal(Decimal)
    /// A Boolean.
    case bool(Bool)
    /// A tuple. Written as a definite-length array.
    case tuple(AnyTuple)
    /// A definite-length array.
    case list([Primitive])
    /// An indefinite-length array.
    case indefiniteList(IndefiniteList<Primitive>)
    /// An unordered map. Written with its entries sorted bytewise by their encoded keys; use ``orderedDict(_:)`` to keep insertion order.
    case dict([Primitive: Primitive])
    /// An indefinite-length map, in insertion order.
    case indefiniteDictionary(OrderedDictionary<Primitive, Primitive>)
    /// A definite-length map, in insertion order.
    case orderedDict(OrderedDictionary<Primitive, Primitive>)
    /// A date.
    case datetime(Date)
    /// A regular expression. Written as a text string of its pattern.
    case regex(NSRegularExpression)
    /// A raw CBOR value, written as is. It also carries values kept exactly as read, such as already-encoded bytes and chunked text strings.
    case cborSimpleValue(CBOR)
    /// A tagged value.
    case cborTag(CBORTag)
    /// An ordered set. Written as ``OrderedSet`` writes itself.
    case orderedSet(OrderedSet<Primitive>)
    /// A non-empty ordered set. Written as ``NonEmptyOrderedSet`` writes itself.
    case nonEmptyOrderedSet(NonEmptyOrderedSet<Primitive>)
    /// A unit interval. Written as tag 30 around `[numerator, denominator]`.
    case unitInterval(UnitInterval)
    /// An unordered set. Written as a definite-length array, without a set tag.
    case frozenSet(Set<Primitive>)
    /// A map. Written as a definite-length map in the dictionary's iteration order.
    case frozenDict([Primitive: Primitive])
    /// A definite-length array. Written as ``list(_:)``.
    case frozenList([Primitive])
    /// An indefinite-length array. Written as ``indefiniteList(_:)``.
    case indefiniteFrozenList(IndefiniteList<Primitive>)
    /// A byte string that keeps its definite or chunked encoding. See ``ByteString``.
    case byteString(ByteString)
    /// Plutus data. Written as its own CBOR encoding.
    case plutusData(PlutusData)
    /// CBOR null.
    case null

    /// Decodes a primitive that keeps how it was written: indefinite-length
    /// byte strings, text strings and maps come back as such, so it encodes
    /// back to the bytes it was read from.
    public init(from decoder: Decoder) throws {
        self = try Primitive.decode(from: decoder, preservingEncoding: true)
    }

    /// Decodes a primitive from `decoder`.
    ///
    /// With `preservingEncoding`, indefinite-length byte strings decode to
    /// ``byteString(_:)`` holding their chunk widths, text strings to
    /// ``cborSimpleValue(_:)`` holding their chunks, and maps to
    /// ``indefiniteDictionary(_:)``, so the value encodes back to its input.
    /// Without it they decode to ``bytes(_:)``, ``string(_:)`` and
    /// ``dict(_:)``, which is the form most types read.
    public static func decode(from decoder: Decoder, preservingEncoding: Bool) throws -> Primitive {
        let container = try decoder.singleValueContainer()
        if String(describing: type(of: decoder)).contains("JSONDecoder") {
            let jsonString = try container.decode(String.self)
            guard let data = jsonString.data(using: .utf8) else {
                throw CardanoCoreError.valueError("Invalid JSON string")
            }
            let json = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
            return try Primitive.from(json: json)
        }
        let cbor = try container.decode(CBOR.self)
        return try Primitive.from(cbor: cbor, preservingEncoding: preservingEncoding)
    }

    public func encode(to encoder: Encoder) throws {
        if String(describing: type(of: encoder)).contains("JSONEncoder") {
            var container = encoder.singleValueContainer()
            let json = try self.toJSON()
            let data = try JSONSerialization.data(withJSONObject: json, options: [.fragmentsAllowed])
            let jsonString = String(data: data, encoding: .utf8) ?? ""
            try container.encode(jsonString)
        } else {
            var container = encoder.singleValueContainer()
            try container.encode(try toCBOR())
        }
    }

    /// Reconstruct a Primitive from a Foundation JSON value (the output
    /// of `JSONSerialization.jsonObject(with:)`).
    ///
    /// - Throws: When the value holds a type JSON does not have, or nests
    ///   deeper than 128 levels.
    public static func from(json: Any) throws -> Primitive {
        try from(json: json, level: 1)
    }

    private static func from(json: Any, level: Int) throws -> Primitive {
        try checkJSONDepth(level, "A JSON value")
        if json is NSNull {
            return .null
        }
        // Order matters — NSNumber bridges from Bool, so check Bool first.
        // Use `objCType` (portable across Darwin and swift-corelibs-foundation)
        // instead of CoreFoundation helpers, which aren't public on Linux/WASM/Android.
        if let n = json as? NSNumber {
            let typeCode = String(cString: n.objCType)
            if typeCode == "c" {
                return .bool(n.boolValue)
            }
            if typeCode == "f" || typeCode == "d" {
                return .float(n.doubleValue)
            }
            return .int(n.int64Value)
        }
        if let s = json as? String {
            return .string(s)
        }
        if let arr = json as? [Any] {
            return .list(try arr.map { try from(json: $0, level: level + 1) })
        }
        if let dict = json as? [String: Any] {
            // Reconstruct cborTag: Primitive.toJSON() encodes .cborTag as
            // {"tag": N, "value": ...}.
            if dict.count == 2,
               let tagNum = dict["tag"] as? NSNumber,
               String(cString: tagNum.objCType) != "f",
               String(cString: tagNum.objCType) != "d",
               let valueAny = dict["value"]
            {
                guard let tagRaw = UInt64(exactly: tagNum.int64Value), tagNum.int64Value >= 0 else {
                    throw CardanoCoreError.valueError("Invalid CBOR tag in JSON: \(tagNum)")
                }
                let valuePrimitive = try from(json: valueAny, level: level + 1)
                return .cborTag(CBORTag(tag: tagRaw, value: valuePrimitive))
            }
            var result: OrderedDictionary<Primitive, Primitive> = [:]
            for (k, v) in dict { result[.string(k)] = try from(json: v, level: level + 1) }
            return .orderedDict(result)
        }
        throw CardanoCoreError.valueError("Cannot convert JSON value to Primitive: \(json)")
    }

    /// Converts `cbor` to a primitive. See
    /// ``decode(from:preservingEncoding:)`` for `preservingEncoding`.
    public static func from(cbor: CBOR, preservingEncoding: Bool = false) throws -> Primitive {
        switch cbor {
        case .encoded:
            // Already encoded, and kept so: it is written back as it is.
            return .cborSimpleValue(cbor)
        case .byteString(let data):
            return .bytes(data)
        case .textString(let string):
            return .string(string)
        case .unsignedInt(let value):
            return .uint(value)
        case .negativeInt(let value):
            // The wire value n stands for -1 - n, which below -2^63 no
            // longer fits Int64.
            return value <= UInt64(Int64.max)
                ? .int(Int64(bitPattern: ~value)) : .bigInt(-1 - BigInt(value))
        case .float(let value):
            return .float(Double(value))
        case .double(let value):
            return .float(value)
        case .boolean(let value):
            return .bool(value)
        case .null:
            return .null
        case .array(let array):
            let primitives = try array.map {
                try Primitive.from(cbor: $0, preservingEncoding: preservingEncoding)
            }
            return .list(primitives)
        case .indefiniteArray(let array):
            let primitives = try array.map {
                try Primitive.from(cbor: $0, preservingEncoding: preservingEncoding)
            }
            return .indefiniteList(IndefiniteList(primitives))
        case .map(let map):
            return .orderedDict(try fromEntries(map.elements, preservingEncoding))
        case .indefiniteMap(let map):
            return try fromIndefiniteMap(map, preservingEncoding)
        case .simple(let simple):
            return .cborSimpleValue(.simple(simple))
        case .tagged(let tag, let value):
            return try fromTagged(tag, value, preservingEncoding)
        case .indefiniteByteString(let chunks):
            let byteString = ByteString(chunks: chunks)
            return preservingEncoding ? .byteString(byteString) : .bytes(byteString.bytes)
        case .indefiniteTextString(let chunks):
            return preservingEncoding ? .cborSimpleValue(cbor) : .string(chunks.joined())
        case .undefined:
            return .null
        case .half(let value):
            return .float(Double(value))
        }
    }

    // The helpers below are kept out of line so `from(cbor:)`, which recurses
    // once per nesting level, keeps a small stack frame. Deeply nested
    // PlutusData has to fit in a cooperative thread's ~512 KB stack.
    @inline(never)
    private static func fromEntries(
        _ entries: OrderedDictionary<CBOR, CBOR>.Elements,
        _ preservingEncoding: Bool
    ) throws -> OrderedDictionary<Primitive, Primitive> {
        // Distinct CBOR keys can map to the same Primitive (null/undefined,
        // half/float/double, definite/indefinite strings). Such a map repeats
        // a key, so it throws; `uniqueKeysWithValues:` would trap instead.
        var dict = OrderedDictionary<Primitive, Primitive>()
        for (key, value) in entries {
            let primitiveKey = try Primitive.from(cbor: key, preservingEncoding: preservingEncoding)
            guard dict[primitiveKey] == nil else {
                throw CardanoCoreError.deserializeError(
                    "A CBOR map repeats the key \(primitiveKey) once its keys are read")
            }
            dict[primitiveKey] = try Primitive.from(cbor: value, preservingEncoding: preservingEncoding)
        }
        return dict
    }

    @inline(never)
    private static func fromIndefiniteMap(
        _ map: OrderedDictionary<CBOR, CBOR>,
        _ preservingEncoding: Bool
    ) throws -> Primitive {
        let entries = try fromEntries(map.elements, preservingEncoding)
        guard preservingEncoding else {
            // In the order written: a map's order can be part of its value.
            return .orderedDict(entries)
        }
        return .indefiniteDictionary(entries)
    }

    @inline(never)
    private static func fromTagged(
        _ tag: UInt64, _ value: CBOR, _ preservingEncoding: Bool
    ) throws -> Primitive {
        if tag == UInt64(UnitInterval.tag) {
            return try unitInterval(from: value)
        }
        // Date tags (0 and 1) stay tags: no Cardano structure uses them, and a
        // tag-1 integer or float read into a `Date` could not be written back
        // as it was.
        return .cborTag(
            CBORTag(tag: tag, value: try value.toPrimitive(preservingEncoding: preservingEncoding)))
    }

    /// `#6.30([numerator, denominator])`, both unsigned, the denominator
    /// above zero.
    @inline(never)
    private static func unitInterval(from value: CBOR) throws -> Primitive {
        let elements: [CBOR]
        switch value {
        case .array(let items), .indefiniteArray(let items): elements = items
        default: throw CardanoCoreError.valueError("A #6.30 interval must be an array: \(value)")
        }
        guard elements.count == 2,
            case .unsignedInt(let numerator) = elements[0],
            case .unsignedInt(let denominator) = elements[1],
            denominator > 0
        else {
            throw CardanoCoreError.valueError(
                "A #6.30 interval must be [numerator, denominator > 0]: \(value)")
        }
        return .unitInterval(UnitInterval(numerator: numerator, denominator: denominator))
    }

    /// This value as a CBOR value, as each case describes.
    ///
    /// - Returns: The CBOR value.
    /// - Throws: When a nested value cannot be converted.
    public func toCBOR() throws -> CBOR {
        // Containers recurse once per nesting level, so their bodies live in
        // out-of-line helpers. That keeps this frame small in unoptimized
        // builds, where every case binding gets its own stack slot.
        switch self {
        case .bytes(let data):
            return .byteString(data)
        case .string(let string):
            return .textString(string)
        case .int(let value):
            return value >= 0
                ? .unsignedInt(UInt64(value)) : .negativeInt(~UInt64(bitPattern: value))
        case .uint(let value):
            return .unsignedInt(value)
        case .float(let value):
            return .double(value)
        case .bool(let value):
            return .boolean(value)
        case .list(let list), .frozenList(let list):
            return .array(try Primitive.toCBOR(list))
        case .indefiniteList(let list), .indefiniteFrozenList(let list):
            return .indefiniteArray(try Primitive.toCBOR(list.getAll()))
        case .orderedDict(let dict):
            return .map(try Primitive.toCBOR(entries: dict.elements))
        case .cborTag(let tag):
            return try Primitive.toCBOR(tag: tag)
        case .null:
            return CBOR.null
        default:
            return try otherToCBOR()
        }
    }

    @inline(never)
    private static func toCBOR(_ list: [Primitive]) throws -> [CBOR] {
        try list.map { try $0.toCBOR() }
    }

    @inline(never)
    private static func toCBOR<S: Sequence>(
        entries: S
    ) throws -> OrderedDictionary<CBOR, CBOR> where S.Element == (key: Primitive, value: Primitive) {
        // Distinct primitives can be the same CBOR key (`.int(1)` and
        // `.uint(1)`, say), so assign and throw on a repeat rather than use
        // `uniqueKeysWithValues:`, which traps on one.
        var result = OrderedDictionary<CBOR, CBOR>()
        for entry in entries {
            try insert(try entry.key.toCBOR(), try entry.value.toCBOR(), into: &result)
        }
        return result
    }

    /// Adds a map entry, throwing when the map already has the key.
    private static func insert(
        _ key: CBOR, _ value: CBOR, into map: inout OrderedDictionary<CBOR, CBOR>
    ) throws {
        guard map[key] == nil else {
            throw CardanoCoreError.serializeError(
                "A map repeats the key \(key) once its keys are written as CBOR")
        }
        map[key] = value
    }

    @inline(never)
    private static func toCBOR(tag: CBORTag) throws -> CBOR {
        .tagged(UInt64(tag.tag), try tag.value.toCBOR())
    }

    @inline(never)
    private func otherToCBOR() throws -> CBOR {
        switch self {
        case .byteArray(let array):
            return .byteString(Data(array))
        case .decimal(let decimal):
            return .textString(decimal.description)
        case .tuple(let tup):
            return .array(try Primitive.toCBOR(tup.elements))
        case .dict(let dict):
            // Swift's Dictionary is unordered, so emit pairs in bytewise
            // lexicographic order of their encoded keys (matches
            // PotentCBOR's historical behavior and Cardano's expected
            // map-key ordering). Use `.orderedDict` for intentional
            // insertion-order preservation.
            let pairs = try dict.map { entry -> (CBOR, CBOR, Data) in
                let keyCBOR = try entry.key.toCBOR()
                let valueCBOR = try entry.value.toCBOR()
                var writer = CBORWriter()
                try writer.encode(keyCBOR)
                return (keyCBOR, valueCBOR, writer.data)
            }
            let sorted = pairs.sorted { $0.2.lexicographicallyPrecedes($1.2) }
            var map = OrderedDictionary<CBOR, CBOR>()
            for (key, value, _) in sorted {
                try Primitive.insert(key, value, into: &map)
            }
            return .map(map)
        case .indefiniteDictionary(let dict):
            return .indefiniteMap(try Primitive.toCBOR(entries: dict.elements))
        case .datetime(let date):
            return try CBOREncoder().encode(date).toCBOR
        case .regex(let regex):
            return .textString(regex.pattern)
        case .cborSimpleValue(let simple):
            return simple
        case .orderedSet(let set):
            return try set.toCBOR()
        case .nonEmptyOrderedSet(let set):
            return try set.toCBOR()
        case .unitInterval(let unitInterval):
            return .tagged(
                UInt64(UInt64(UnitInterval.tag)),
                .array([
                    .unsignedInt(UInt64(unitInterval.numerator)),
                    .unsignedInt(UInt64(unitInterval.denominator)),
                ]))
        case .frozenSet(let set):
            return .array(try set.map { try $0.toCBOR() })
        case .frozenDict(let dict):
            return .map(try Primitive.toCBOR(entries: dict))
        case .byteString(let byteString):
            return byteString.toCBOR()
        case .plutusData(let plutusData):
            return .encoded(try plutusData.toCBORData())
        case .bigInt(let bigInt):
            return Primitive.integerCBOR(bigInt)
        case .bigUInt(let bigUInt):
            return Primitive.integerCBOR(BigInt(bigUInt))
        case .bytes, .string, .int, .uint, .float, .bool, .list, .frozenList,
            .indefiniteList, .indefiniteFrozenList, .orderedDict, .cborTag, .null:
            return try toCBOR()
        }
    }

    /// Produce a Foundation JSON value (the kind `JSONSerialization`
    /// accepts as `withJSONObject:`). Top-level value can be NSNull,
    /// NSNumber, String, [Any], or [String: Any].
    public func toJSON() throws -> Any {
        switch self {
        case .bytes(let data):
            return data.toHex
        case .byteArray(let array):
            return Data(array).toHex
        case .string(let string):
            return string
        case .int(let value):
            return NSNumber(value: value)
        case .uint(let value):
            return NSNumber(value: value)
        case .float(let value):
            return NSNumber(value: value)
        case .decimal(let decimal):
            return decimal.description
        case .bool(let value):
            return NSNumber(value: value)
        case .tuple(let tup):
            return try tup.elements.map { try $0.toJSON() }
        case .list(let list):
            return try list.map { try $0.toJSON() }
        case .indefiniteList(let list):
            return try list.getAll().map { try $0.toJSON() }
        case .dict(let dict):
            var jsonDict: [String: Any] = [:]
            for (key, value) in dict {
                jsonDict[String(describing: key)] = try value.toJSON()
            }
            return jsonDict
        case .orderedDict(let dict):
            var jsonDict: [String: Any] = [:]
            for (key, value) in dict {
                // Use string value if available, otherwise fall back to description
                let keyStr: String
                if case .string(let s) = key {
                    keyStr = s
                } else {
                    keyStr = String(describing: key)
                }
                jsonDict[keyStr] = try value.toJSON()
            }
            return jsonDict
        case .indefiniteDictionary(let dict):
            var jsonDict: [String: Any] = [:]
            for (key, value) in dict {
                jsonDict[String(describing: key)] = try value.toJSON()
            }
            return jsonDict
        case .datetime(let date):
            return date.ISO8601Format()
        case .regex(let regex):
            return regex.pattern
        case .cborSimpleValue(let simple):
            return try simple.toPrimitive().toJSON()
        case .cborTag(let tag):
            return [
                "tag": NSNumber(value: tag.tag),
                "value": try tag.value.toJSON(),
            ] as [String: Any]
        case .null:
            return NSNull()
        default:
            throw CardanoCoreError.typeError(
                "Cannot convert Primitive type \(type(of: self)) to JSON")
        }
    }

    public static func == (lhs: Primitive, rhs: Primitive) -> Bool {
        switch (lhs, rhs) {
        case (.bytes(let a), .bytes(let b)):
            return a == b
        case (.byteArray(let a), .byteArray(let b)):
            return a == b
        case (.string(let a), .string(let b)):
            return a == b
        case (.int(let a), .int(let b)):
            return a == b
        case (.uint(let a), .uint(let b)):
            return a == b
        case (.float(let a), .float(let b)):
            // By bit pattern, as CBOR compares its floats: NaN equals itself,
            // so a map cannot hold two NaN keys that CBOR writes as one.
            return a.bitPattern == b.bitPattern
        case (.decimal(let a), .decimal(let b)):
            return a == b
        case (.bool(let a), .bool(let b)):
            return a == b
        case (.tuple(let a), .tuple(let b)):
            return a == b
        case (.list(let a), .list(let b)):
            return a == b
        case (.indefiniteList(let a), .indefiniteList(let b)):
            return a == b
        case (.dict(let a), .dict(let b)):
            return a == b
        case (.orderedDict(let a), .orderedDict(let b)):
            return a == b
        case (.indefiniteDictionary(let a), .indefiniteDictionary(let b)):
            return a == b
        case (.datetime(let a), .datetime(let b)):
            return a == b
        case (.regex(let a), .regex(let b)):
            return a.pattern == b.pattern  // NSRegularExpression compare patterns
        case (.cborSimpleValue(let a), .cborSimpleValue(let b)):
            return a == b
        case (.cborTag(let a), .cborTag(let b)):
            return a == b
        case (.orderedSet(let a), .orderedSet(let b)):
            return a == b
        case (.nonEmptyOrderedSet(let a), .nonEmptyOrderedSet(let b)):
            return a == b
        case (.unitInterval(let a), .unitInterval(let b)):
            return a == b
        case (.frozenSet(let a), .frozenSet(let b)):
            return a == b
        case (.frozenDict(let a), .frozenDict(let b)):
            return a == b
        case (.frozenList(let a), .frozenList(let b)):
            return a == b
        case (.indefiniteFrozenList(let a), .indefiniteFrozenList(let b)):
            return a == b
        case (.byteString(let a), .byteString(let b)):
            return a == b
        case (.bigInt(let a), .bigInt(let b)):
            return a == b
        case (.bigUInt(let a), .bigUInt(let b)):
            return a == b
        case (.null, .null):
            return true
        default:
            return false
        }
    }

    /// Hashes the case and its value, as ``==(_:_:)`` compares them: a float
    /// by its bit pattern and a regular expression by its pattern.
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .bytes(let value): hasher.combine(0); hasher.combine(value)
        case .byteArray(let value): hasher.combine(1); hasher.combine(value)
        case .string(let value): hasher.combine(2); hasher.combine(value)
        case .int(let value): hasher.combine(3); hasher.combine(value)
        case .uint(let value): hasher.combine(4); hasher.combine(value)
        case .bigInt(let value): hasher.combine(5); hasher.combine(value)
        case .bigUInt(let value): hasher.combine(6); hasher.combine(value)
        case .float(let value): hasher.combine(7); hasher.combine(value.bitPattern)
        case .decimal(let value): hasher.combine(8); hasher.combine(value)
        case .bool(let value): hasher.combine(9); hasher.combine(value)
        case .tuple(let value): hasher.combine(10); hasher.combine(value)
        case .list(let value): hasher.combine(11); hasher.combine(value)
        case .indefiniteList(let value): hasher.combine(12); hasher.combine(value)
        case .dict(let value): hasher.combine(13); hasher.combine(value)
        case .indefiniteDictionary(let value): hasher.combine(14); hasher.combine(value)
        case .orderedDict(let value): hasher.combine(15); hasher.combine(value)
        case .datetime(let value): hasher.combine(16); hasher.combine(value)
        case .regex(let value): hasher.combine(17); hasher.combine(value.pattern)
        case .cborSimpleValue(let value): hasher.combine(18); hasher.combine(value)
        case .cborTag(let value): hasher.combine(19); hasher.combine(value)
        case .orderedSet(let value): hasher.combine(20); hasher.combine(value)
        case .nonEmptyOrderedSet(let value): hasher.combine(21); hasher.combine(value)
        case .unitInterval(let value): hasher.combine(22); hasher.combine(value)
        case .frozenSet(let value): hasher.combine(23); hasher.combine(value)
        case .frozenDict(let value): hasher.combine(24); hasher.combine(value)
        case .frozenList(let value): hasher.combine(25); hasher.combine(value)
        case .indefiniteFrozenList(let value): hasher.combine(26); hasher.combine(value)
        case .byteString(let value): hasher.combine(27); hasher.combine(value)
        case .plutusData(let value): hasher.combine(28); hasher.combine(value)
        case .null: hasher.combine(29)
        }
    }

    /// Convert an arbitrary value to a Primitive.
    ///
    /// - Throws: When the value, or a value inside it, has no primitive form,
    ///   or arrays and dictionaries nest deeper than 128 levels.
    public static func fromAny(_ value: Any) throws -> Primitive {
        try fromAny(value, level: 1)
    }

    private static func fromAny(_ value: Any, level: Int) throws -> Primitive {
        try checkJSONDepth(level, "A value")
        switch value {
        case let v as Primitive:
            return v
        case let v as any CBORSerializable:
            // Its CBOR form, not its JSON one. `Serializable` is both, and
            // reaching for `toDict()` here put a value's *field names* into
            // CBOR: a tagged set of transaction inputs came out as a list of
            // `{"transactionId": …, "index": …}` maps rather than as inputs.
            return try v.toPrimitive()
        case let v as OrderedDictionary<Primitive, Primitive>:
            return .orderedDict(v)
        case let v as Int:
            return .int(Int64(v))
        case let v as UInt8:
            return .uint(UInt64(v))
        case let v as UInt:
            return .uint(UInt64(v))
        case let v as Int8:
            return .int(Int64(v))
        case let v as Int16:
            return .int(Int64(v))
        case let v as Int32:
            return .int(Int64(v))
        case let v as Int64:
            return .int(v)
        case let v as UInt16:
            return .uint(UInt64(v))
        case let v as UInt32:
            return .uint(UInt64(v))
        case let v as UInt64:
            return .uint(v)
        case let v as Double:
            return .float(v)
        case let v as Float:
            return .float(Double(v))
        case let v as Decimal:
            return .decimal(v)
        case let v as Bool:
            return .bool(v)
        case let v as String:
            return .string(v)
        case let v as Data:
            return .bytes(v)
        case let v as [UInt8]:
            return .byteArray(v)
        case let v as [Any]:
            return .list(try v.map { try Primitive.fromAny($0, level: level + 1) })
        case let v as OrderedDictionary<AnyHashable, Any>:
            var dict: OrderedDictionary<Primitive, Primitive> = [:]
            for (key, value) in v {
                let keyPrimitive = try Primitive.fromAny(key, level: level + 1)
                let valuePrimitive = try Primitive.fromAny(value, level: level + 1)
                dict[keyPrimitive] = valuePrimitive
            }
            return .orderedDict(dict)
        case let v as [AnyHashable: Any]:
            var dict: [Primitive: Primitive] = [:]
            for (key, value) in v {
                let keyPrimitive = try Primitive.fromAny(key, level: level + 1)
                let valuePrimitive = try Primitive.fromAny(value, level: level + 1)
                dict[keyPrimitive] = valuePrimitive
            }
            return .dict(dict)
        case let v as Date:
            return .datetime(v)
        case let v as NSRegularExpression:
            return .regex(v)
        case let v as ByteString:
            return .byteString(v)
        case let v as UnitInterval:
            return .unitInterval(v)
        case let v as CBORTag:
            return .cborTag(v)
        case let v as OrderedSet<Primitive>:
            return .orderedSet(v)
        case let v as NonEmptyOrderedSet<Primitive>:
            return .nonEmptyOrderedSet(v)
        case let v as CBOR:
            return .cborSimpleValue(v)
        case let v as PlutusData:
            return .plutusData(v)
        case Optional<Any>.none:
            return .null
        default:
            throw CardanoCoreError.typeError("Cannot convert type \(type(of: value)) to Primitive")
        }
    }

    /// Converts this Primitive back to AnyValue, reversing the toPrimitives() mapping.
    public func toAnyValue() -> AnyValue {
        switch self {
        case .null:
            return .nil
        case .bool(let bool):
            return .bool(bool)
        case .string(let string):
            return .string(string)
        case .int(let intVal):
            return .int64(Int64(intVal))
        case .uint(let intVal):
            return .uint64(UInt64(intVal))
        case .float(let floatVal):
            return .double(floatVal)
        case .decimal(let decimalVal):
            return .decimal(decimalVal)
        case .bytes(let data):
            return .data(data)
        case .byteArray(let array):
            return .data(Data(array))
        case .datetime(let date):
            return .date(date)
        case .tuple(let tup):
            // Explicitly cast each element to help with type inference
            let anyValues: [AnyValue] = tup.elements.map { element -> AnyValue in
                return element.toAnyValue()
            }
            return .array(anyValues)
        case .list(let list):
            return .array(list.map { $0.toAnyValue() })
        case .indefiniteList(let list):
            return .indefiniteArray(list.map { $0.toAnyValue() })
        case .dict(let dict):
            return .dictionary(
                dict.reduce(into: OrderedDictionary<AnyValue, AnyValue>()) { $0[$1.key.toAnyValue()] = $1.value.toAnyValue() }
            )
        case .orderedDict(let dict):
            return .dictionary(
                dict.reduce(into: OrderedDictionary<AnyValue, AnyValue>()) { $0[$1.key.toAnyValue()] = $1.value.toAnyValue() }
            )
        case .indefiniteDictionary(let dict):
            return .indefiniteDictionary(
                dict.reduce(into: OrderedDictionary<AnyValue, AnyValue>()) { $0[$1.key.toAnyValue()] = $1.value.toAnyValue() }
            )
        case .regex(let regex):
            return .string(regex.pattern)
        case .cborSimpleValue(let cbor):
            return (try? AnyValue.wrapped(cbor.unwrapped)) ?? .nil
        case .cborTag(let tag):
            return .array([.uint64(tag.tag), tag.value.toAnyValue()])
        case .orderedSet(let set):
            return .array(set.elementsOrdered.map { $0.toAnyValue() })
        case .nonEmptyOrderedSet(let set):
            return .array(set.elementsOrdered.map { $0.toAnyValue() })
        case .unitInterval(let unitInterval):
            return .array(
                [
                    .uint64(unitInterval.numerator),
                    .uint64(unitInterval.denominator),
                ]
            )
        case .frozenSet(let set):
            return .array(set.map { $0.toAnyValue() })
        case .frozenDict(let dict):
            return .dictionary(
                dict.reduce(into: OrderedDictionary<AnyValue, AnyValue>()) { $0[$1.key.toAnyValue()] = $1.value.toAnyValue() }
            )
        case .frozenList(let list):
            return .array(list.map { $0.toAnyValue() })
        case .indefiniteFrozenList(let list):
            return .indefiniteArray(list.map { $0.toAnyValue() })
        case .byteString(let byteString):
            return .data(byteString.bytes)
        case .plutusData(let plutus):
            return (try? plutus.toPrimitive().toAnyValue()) ?? .nil
        case .bigInt(let bigInt):
            return .integer(bigInt)
        case .bigUInt(let bigUInt):
            return .unsignedInteger(bigUInt)
        }
    }

    public init(from primitive: Primitive) throws {
        self = primitive
    }

    /// An integer as CBOR writes it: as a major type 0 or 1 integer whenever
    /// it fits one — the whole range down to -2^64 — and as a bignum
    /// (tag 2 or 3) otherwise.
    static func integerCBOR(_ value: BigInt) -> CBOR {
        if value.sign == .plus {
            if let unsigned = UInt64(exactly: value) { return .unsignedInt(unsigned) }
            return .tagged(2, .byteString(value.magnitude.serialize()))
        }
        let wire = -1 - value
        if let unsigned = UInt64(exactly: wire) { return .negativeInt(unsigned) }
        return .tagged(3, .byteString(wire.magnitude.serialize()))
    }

    /// This value as a decode without `preservingEncoding` would give it:
    /// indefinite-length byte strings as ``bytes(_:)``, text strings as
    /// ``string(_:)`` and maps as ``dict(_:)``, at every depth.
    ///
    /// A type that keeps how its value was written passes this to the parts
    /// of it that do not.
    public func normalized() throws -> Primitive {
        switch self {
        case .byteString(let byteString) where byteString.chunks != nil:
            return .bytes(byteString.bytes)
        case .cborSimpleValue(.indefiniteTextString(let chunks)):
            return .string(chunks.joined())
        case .indefiniteDictionary(let dict):
            // In the order written: a map's order can be part of its value.
            var result = OrderedDictionary<Primitive, Primitive>()
            for (key, value) in dict {
                result[try key.normalized()] = try value.normalized()
            }
            return .orderedDict(result)
        case .list(let list):
            return .list(try list.map { try $0.normalized() })
        case .indefiniteList(let list):
            return .indefiniteList(IndefiniteList(try list.map { try $0.normalized() }))
        case .orderedDict(let dict):
            var result = OrderedDictionary<Primitive, Primitive>()
            for (key, value) in dict {
                result[try key.normalized()] = try value.normalized()
            }
            return .orderedDict(result)
        case .dict(let dict):
            var result: [Primitive: Primitive] = [:]
            for (key, value) in dict {
                result[try key.normalized()] = try value.normalized()
            }
            return .dict(result)
        case .cborTag(let tag):
            return .cborTag(CBORTag(tag: tag.tag, value: try tag.value.normalized()))
        default:
            return self
        }
    }

    public func toPrimitive() throws -> Primitive {
        return self
    }

    /// The string, when this is ``string(_:)``; otherwise `nil`.
    public var stringValue: String? {
        guard case .string(let value) = self else { return nil }
        return value
    }

    /// The elements, when this is ``list(_:)``; otherwise `nil`.
    public var listValue: [Primitive]? {
        guard case .list(let value) = self else { return nil }
        return value
    }

    /// This primitive, with bytes kept as written —
    /// `.cborSimpleValue(.encoded(_:))`, as a type that keeps its bytes puts
    /// them in its `toPrimitive()` — read back into a primitive that keeps
    /// how they were written.
    func expandingEncoded() throws -> Primitive {
        guard case .cborSimpleValue(.encoded(let bytes)) = self else { return self }
        return try Primitive.from(cbor: CBORSerialization.cbor(from: bytes), preservingEncoding: true)
    }

    /// The list, when this is ``indefiniteList(_:)``; otherwise `nil`.
    public var indefiniteListValue: IndefiniteList<Primitive>? {
        guard case .indefiniteList(let value) = self else { return nil }
        return value
    }

    /// The dictionary, when this is ``orderedDict(_:)``; otherwise `nil`.
    public var orderedDictValue: OrderedDictionary<Primitive, Primitive>? {
        guard case .orderedDict(let value) = self else { return nil }
        return value
    }

    /// The value as an `Int`, when this is ``int(_:)`` or ``uint(_:)``; otherwise `nil`. Out-of-range values are clamped.
    public var intValue: Int? {
        switch self {
        case .int(let value):
            return Int(clamping: value)
        case .uint(let value):
            return Int(clamping: value)
        default:
            return nil
        }
    }

    /// The value as an `Int64`, when this is ``int(_:)`` or ``uint(_:)``; otherwise `nil`. Out-of-range values are clamped.
    public var int64Value: Int64? {
        switch self {
        case .int(let value):
            return value
        case .uint(let value):
            return Int64(clamping: value)
        default:
            return nil
        }
    }

    /// The value as a `UInt64`, when this is ``int(_:)`` or ``uint(_:)``; otherwise `nil`. Negative values are clamped to zero.
    public var uint64Value: UInt64? {
        switch self {
        case .int(let value):
            return UInt64(clamping: value)
        case .uint(let value):
            return value
        default:
            return nil
        }
    }
}
