import Foundation
import SwiftNaCl
import OrderedCollections
import CBORCodable

public enum DatumType: Serializable {
    case datumHash(DatumHash)
    case data(PlutusData)

    // MARK: - CBORSerializable

    public init(from primitive: Primitive) throws {
        if case .cborTag(let cborTag) = primitive {
            guard cborTag.tag == 24 else {
                throw CardanoCoreError.deserializeError(
                    "Invalid DatumType type. Tag must be 24, but found \(cborTag.tag)")
            }

            // Handle CBOR-encoded data inside the tag. An inline datum is
            // only ever read from an output, which the ledger accepted with
            // any repeated map key, so one is not rejected here (see
            // ``Transaction/decoder()``).
            if case .bytes(let cborData) = cborTag.value {
                let plutusData = try PlutusDataReader.read(cborData)
                self = .data(plutusData)
            } else {
                throw CardanoCoreError.deserializeError("Invalid DatumType type")
            }
        } else if case .bytes(_) = primitive {
            self = .datumHash(try DatumHash(from: primitive))
        } else {
            throw CardanoCoreError.deserializeError("Invalid DatumType type")
        }
    }

    public func toPrimitive() throws -> Primitive {
        switch self {
        case .datumHash(let datumHash):
            return datumHash.toPrimitive()
        case .data(let data):
            return .cborTag(
                CBORTag(tag: 24, value: .bytes(try data.toCBORData()))
            )
        }
    }

    // MARK: - JSONSerializable

    public static func fromDict(_ dict: Primitive) throws -> DatumType {
        guard case .orderedDict(let dictValue) = dict else {
            throw CardanoCoreError.deserializeError("Invalid DatumType dict")
        }
        if let datumHashPrimitive = dictValue[.string("datumHash")] {
            // When coming from JSON, the hash is base64-encoded
            let datumHash: DatumHash
            if case .string(let base64Str) = datumHashPrimitive {
                guard let data = Data(base64Encoded: base64Str) else {
                    throw CardanoCoreError.deserializeError(
                        "Invalid DatumHash base64: \(base64Str)")
                }
                datumHash = DatumHash(payload: data)
            } else {
                datumHash = try DatumHash(from: datumHashPrimitive)
            }
            return .datumHash(datumHash)
        } else if let dataPrimitive = dictValue[.string("data")] {
            let plutusData = try PlutusData.fromDict(dataPrimitive)
            return .data(plutusData)
        } else {
            throw CardanoCoreError.deserializeError("Invalid DatumType dict")
        }
    }

    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        switch self {
        case .datumHash(let datumHash):
            // Encode as base64 for JSON compatibility
            dict[.string("datumHash")] = .string(datumHash.payload.base64EncodedString())
        case .data(let plutusData):
            dict[.string("data")] = try plutusData.toDict()
        }
        return .orderedDict(dict)
    }

    // MARK: - Codable

    //    public init(from decoder: Decoder) throws {
    //        if String(describing: Swift.type(of: decoder)).contains("JSONDecoder") {
    //            let container = try decoder.singleValueContainer()
    //            if let datumHash = try? container.decode(DatumHash.self) {
    //                self = .datumHash(datumHash)
    //            } else {
    //                let plutusData = try container.decode(PlutusData.self)
    //                self = .data(plutusData)
    //            }
    //        } else {
    //            let container = try decoder.singleValueContainer()
    //            let primitive = try container.decode(Primitive.self)
    //            try self.init(from: primitive)
    //        }
    //    }
    //
    //    public func encode(to encoder: Swift.Encoder) throws {
    //        if String(describing: Swift.type(of: encoder)).contains("JSONEncoder") {
    //            var container = encoder.singleValueContainer()
    //            switch self {
    //                case .datumHash(let datumHash):
    //                    try container.encode(datumHash.payload.toHex)
    //                case .data(let plutusData):
    //                    try container.encode(plutusData.toJSON())
    //            }
    //        } else  {
    //            var container = encoder.singleValueContainer()
    //            try container.encode(try toPrimitive())
    //        }
    //    }
}

public struct DatumOption: Serializable {
    public var type: Int { didSet { originalCBOR = nil; datumCBOR = nil } }
    public var datum: DatumType { didSet { originalCBOR = nil; datumCBOR = nil } }

    /// The exact bytes this was decoded from, while it is unchanged.
    public internal(set) var originalCBOR: Data? = nil
    /// The inline datum as written — the bytes its hash is taken over — while
    /// it is unchanged; `nil` for a datum hash or a datum built in code.
    public internal(set) var datumCBOR: Data? = nil

    /// The hash of the inline datum, taken over its bytes as written while
    /// they are kept; `nil` for a datum hash.
    public func inlineDatumHash() throws -> DatumHash? {
        guard case .data(let data) = datum else { return nil }
        guard let datumCBOR else { return try data.hash() }
        return DatumHash(
            payload: try Hash().blake2b(data: datumCBOR, digestSize: DATUM_HASH_SIZE, encoder: RawEncoder.self))
    }

    public static func == (lhs: DatumOption, rhs: DatumOption) -> Bool {
        lhs.type == rhs.type && lhs.datum == rhs.datum
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(type)
        hasher.combine(datum)
    }

    /// Decodes a datum option, keeping the bytes of it and of its inline datum.
    public static func fromCBOR(data: Data) throws -> DatumOption {
        let scanner = CBORItemScanner(data)
        guard try scanner.end(ofItemAt: 0) == scanner.bytes.count else {
            throw CardanoCoreError.deserializeError("Trailing bytes after DatumOption")
        }
        var option = try CBORDecoder().decode(DatumOption.self, from: data)
        try option.keepBytes(scanner.bytes)
        return option
    }

    public init(from cbor: Data) throws {
        self = try Self.fromCBOR(data: cbor)
    }

    /// Records `bytes` as what this datum option was decoded from.
    mutating func keepBytes(_ bytes: Data) throws {
        let scanner = CBORItemScanner(bytes)
        let spans = try scanner.elements(ofArrayAt: 0)
        if spans.count == 2, case .data = datum {
            // [1, #6.24(bytes .cbor plutus_data)]
            let tag = try scanner.header(at: spans[1].lowerBound)
            let content = try scanner.header(at: tag.end)
            if tag.major == 6, tag.argument == 24, content.major == 2, content.argument != nil {
                datumCBOR = scanner.bytes.subdata(in: content.end..<spans[1].upperBound)
            }
        }
        originalCBOR = scanner.bytes
    }

    public func toCBORData(deterministic: Bool = false) throws -> Data {
        _ = deterministic
        return try originalCBOR ?? CBOREncoder().encode(self)
    }

    public init(datum: DatumType) {
        self.datum = datum
        switch datum {
        case .datumHash(_):
            self.type = 0
        case .data(_):
            self.type = 1
        }
    }

    public init(datum: DatumHash) {
        self.datum = .datumHash(datum)
        self.type = 0
    }

    public init(datum: PlutusData) {
        self.datum = .data(datum)
        self.type = 1
    }

    enum CodingKeys: String, CodingKey {
        case type = "_TYPE"
        case datum
    }

    // MARK: - CBORSerializable

    public init(from primitive: Primitive) throws {
        guard case .list(let primitive) = primitive else {
            throw CardanoCoreError.deserializeError("Invalid DatumOption type")
        }
        guard primitive.count == 2 else {
            throw CardanoCoreError.deserializeError(
                "Invalid DatumOption: expected 2 elements, got \(primitive.count)")
        }

        if primitive[0] == .uint(0) {
            type = 0
        } else if primitive[0] == .uint(1) {
            type = 1
        } else {
            throw CardanoCoreError.deserializeError("Invalid DatumOption type: \(primitive)")
        }
        datum = try DatumType(from: primitive[1])
    }

    public func toPrimitive() throws -> Primitive {
        if let originalCBOR {
            return .cborSimpleValue(.encoded(originalCBOR))
        }
        switch datum {
        case .datumHash(_):
            return .list([.int(0), try datum.toPrimitive()])
        case .data(_):
            return .list([.int(1), try datum.toPrimitive()])
        }
    }

    // MARK: - JSONSerializable

    public static func fromDict(_ dict: Primitive) throws -> DatumOption {
        guard case .orderedDict(let dictValue) = dict,
            let datumPrimitive = dictValue[.string("datum")]
        else {
            throw CardanoCoreError.deserializeError("Invalid DatumOption dict: \(dict)")
        }

        let datumType = try DatumType.fromDict(datumPrimitive)

        return DatumOption(datum: datumType)
    }

    public func toDict() throws -> Primitive {
        var dict = OrderedCollections.OrderedDictionary<Primitive, Primitive>()
        dict[.string("_TYPE")] = .integer(type)
        dict[.string("datum")] = try datum.toDict()
        return .orderedDict(dict)
    }

    // MARK: - Codable

    //    public init(from decoder: Decoder) throws {
    //        if String(describing: Swift.type(of: decoder)).contains("JSONDecoder") {
    //            let container = try decoder.container(keyedBy: CodingKeys.self)
    //            let _type = try container.decode(Int.self, forKey: .type)
    //            let datum = try container.decode(DatumType.self, forKey: .datum)
    //            self.init(datum: datum)
    //        } else {
    //            let container = try decoder.singleValueContainer()
    //            let primitive = try container.decode(Primitive.self)
    //            try self.init(from: primitive)
    //        }
    //    }
    //
    //    public func encode(to encoder: Swift.Encoder) throws {
    //        if String(describing: Swift.type(of: encoder)).contains("JSONEncoder") {
    //            var container = encoder.container(keyedBy: CodingKeys.self)
    //            try container.encode(type, forKey: .type)
    //            try container.encode(datum, forKey: .datum)
    //        } else  {
    //            var container = encoder.singleValueContainer()
    //            try container.encode(try toPrimitive())
    //        }
    //    }
}

// MARK: - RawDatum
public enum RawDatum: PlutusDataProtocol {
    case plutusData(PlutusData)
    case dict([AnyValue: AnyValue])
    case int(Int)
    case bytes(Data)
    case indefiniteList(IndefiniteList<AnyValue>)
    case cbor(CBOR)
    case cborTag(CBORTag)

    public init(from plutusData: PlutusData) throws {
        self = try RawDatum(from: plutusData.toPrimitive())
    }

    public func toPlutusData() throws -> PlutusData {
        switch self {
        case .plutusData(let data):
            return data
        case .dict(let dict):
            var resultDict = OrderedDictionary<PlutusData, PlutusData>()
            for (key, value) in dict {
                let keyPlutusData = try PlutusData(from: key.toPrimitive())
                let valuePlutusData = try PlutusData(from: value.toPrimitive())
                resultDict[keyPlutusData] = valuePlutusData
            }
            return .map(MapPairs(resultDict))
        case .int(let int):
            return .bigInt(.int(Int64(int)))
        case .bytes(let bytes):
            return .bytes(try Bytes(from: bytes))
        case .indefiniteList(let list):
            let plutusDataList = try list.getAll().map {
                try PlutusData(from: $0.toPrimitive())
            }
            return .array(plutusDataList)
        case .cbor(let cbor):
            return .bytes(
                try Bytes(from: try CBORSerialization.data(from: cbor))
            )
        case .cborTag(let cborTag):
            return try PlutusData(from: cborTag.toPrimitive())
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let plutusData = try? container.decode(PlutusData.self) {
            self = .plutusData(plutusData)
        } else if let dict = try? container.decode(Dictionary<AnyValue, AnyValue>.self) {
            self = .dict(dict)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let bytes = try? container.decode(Data.self) {
            self = .bytes(bytes)
        } else if let list = try? container.decode(IndefiniteList<AnyValue>.self) {
            self = .indefiniteList(list)
        } else if let cborData = try? container.decode(Data.self) {
            let cbor = try CBORSerialization.cbor(from: cborData)
            if case CBOR.tagged(let tag, let data) = cbor {
                self = .cborTag(
                    CBORTag(
                        tag: UInt64(tag),
                        value: try data.toPrimitive()
                    )
                )
            } else {
                self = .cbor(cbor)
            }
        } else {
            throw CardanoCoreError.deserializeError("Invalid RawDatum data")
        }
    }

    public func encode(to encoder: Swift.Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .plutusData(let plutusData):
            try container.encode(plutusData)
        case .dict(let dict):
            try container.encode(dict)
        case .int(let int):
            try container.encode(int)
        case .bytes(let bytes):
            try container.encode(bytes)
        case .indefiniteList(let list):
            try container.encode(list)
        case .cbor(let cbor):
            try container.encode(try CBORSerialization.data(from: cbor))
        case .cborTag(let tag):
            try container.encode(tag)
        }
    }

    public static func == (lhs: RawDatum, rhs: RawDatum) -> Bool {
        switch (lhs, rhs) {
        case (.plutusData(let lhs), .plutusData(let rhs)):
            return lhs == rhs
        case (.dict(let lhs), .dict(let rhs)):
            return lhs == rhs
        case (.int(let lhs), .int(let rhs)):
            return lhs == rhs
        case (.bytes(let lhs), .bytes(let rhs)):
            return lhs == rhs
        case (.indefiniteList(let lhs), .indefiniteList(let rhs)):
            return lhs == rhs
        case (.cbor(let lhs), .cbor(let rhs)):
            return lhs == rhs
        case (.cborTag(let lhs), .cborTag(let rhs)):
            return lhs == rhs
        default:
            return false
        }
    }

    public init(from primitive: Primitive) throws {
        switch primitive {
        case .plutusData(let data):
            self = .plutusData(data)
        case .dict(let dict):
            let convertedDict = dict.reduce(into: [:]) { result, entry in
                result[entry.key.toAnyValue()] = entry.value.toAnyValue()
            }
            self = .dict(convertedDict)
        case .orderedDict(let od):
            let convertedDict = od.reduce(into: [:] as [AnyValue: AnyValue]) { result, entry in
                result[entry.key.toAnyValue()] = entry.value.toAnyValue()
            }
            self = .dict(convertedDict)
        case .int(let int) where Int(exactly: int) != nil:
            self = .int(Int(int))
        case .uint(let uint) where Int(exactly: uint) != nil:
            self = .int(Int(uint))
        case .int, .uint, .bigInt, .bigUInt:
            // An integer too big for `Int` is still valid Plutus data.
            self = .plutusData(try PlutusData(from: primitive))
        case .bytes(let bytes):
            self = .bytes(bytes)
        case .indefiniteList(let list):
            self = .indefiniteList(IndefiniteList(list.map { $0.toAnyValue() }))
        case .cborSimpleValue(let cbor):
            self = .cbor(cbor)
        case .cborTag(let tag):
            self = .cborTag(tag)
        default:
            throw CardanoCoreError.deserializeError("Invalid RawDatum primitive")
        }
    }

    /// Long byte strings are written in 64-byte chunks, as Plutus data
    /// requires; see ``Primitive/chunkingLongBytes()``.
    public func toPrimitive() throws -> Primitive {
        try unchunkedPrimitive().chunkingLongBytes()
    }

    private func unchunkedPrimitive() throws -> Primitive {
        switch self {
        case .plutusData(let data):
            return try data.toPrimitive()
        case .dict(let dict):
            let convertedDict = dict.reduce(into: [:]) { result, entry in
                result[entry.key.toPrimitive()] = entry.value.toPrimitive()
            }
            return .dict(convertedDict)
        case .int(let int):
            return .int(Int64(int))
        case .bytes(let bytes):
            return .bytes(bytes)
        case .indefiniteList(let list):
            return .indefiniteList(
                IndefiniteList(list.map { $0.toPrimitive() })
            )
        case .cbor(let cbor):
            return .cborSimpleValue(cbor)
        case .cborTag(let tag):
            return .cborTag(tag)
        }
    }
}

// MARK: - Datum
/// Plutus Datum type. A Union type that contains all valid datum types.
public enum Datum: PlutusDataProtocol {
    case plutusData(PlutusData)
    case dict([AnyValue: AnyValue])
    case int(Int)
    case bytes(Data)
    case indefiniteList(IndefiniteList<AnyValue>)
    case cbor(CBOR)
    case rawPlutusData(RawPlutusData)

    public init(from plutusData: PlutusData) throws {
        self = try Datum(from: plutusData.toPrimitive())
    }

    public static var preservesEncoding: Bool { true }

    public func toPlutusData() throws -> PlutusData {
        switch self {
        case .plutusData(let data):
            return data
        case .dict(let dict):
            var resultDict = OrderedDictionary<PlutusData, PlutusData>()
            for (key, value) in dict {
                let keyPlutusData = try PlutusData(from: key.toPrimitive())
                let valuePlutusData = try PlutusData(from: value.toPrimitive())
                resultDict[keyPlutusData] = valuePlutusData
            }
            return .map(MapPairs(resultDict))
        case .int(let int):
            return .bigInt(.int(Int64(int)))
        case .bytes(let bytes):
            return .bytes(try Bytes(from: bytes))
        case .indefiniteList(let list):
            let plutusDataList = try list.getAll().map {
                try PlutusData(from: $0.toPrimitive())
            }
            return .array(plutusDataList)
        case .cbor(let cbor):
            return .bytes(
                try Bytes(from: try CBORSerialization.data(from: cbor))
            )
        case .rawPlutusData(let data):
            return try data.toPlutusData()
        }
    }

    public init(from primitive: Primitive) throws {
        switch primitive {
        case .plutusData(let data):
            self = .plutusData(data)
        case .dict(let dict):
            self = .dict(
                dict.reduce(into: [:]) { result, entry in
                    result[entry.key.toAnyValue()] = entry.value.toAnyValue()
                })
        case .int(let int) where Int(exactly: int) != nil:
            self = .int(Int(int))
        case .uint(let uint) where Int(exactly: uint) != nil:
            self = .int(Int(uint))
        case .bytes(let bytes):
            self = .bytes(bytes)
        case .cborSimpleValue(let cbor):
            self = .cbor(cbor)
        case .orderedDict, .indefiniteDictionary, .list, .indefiniteList, .cborTag, .byteString,
            .int, .uint, .bigInt, .bigUInt:
            // Read as Plutus data, which keeps a map's order, the constructors
            // in it and how each part was written, so the datum hashes as
            // written.
            self = .plutusData(try PlutusData(from: primitive))
        default:
            throw CardanoCoreError.deserializeError("Invalid Datum")
        }
    }

    /// Long byte strings are written in 64-byte chunks, as Plutus data
    /// requires; see ``Primitive/chunkingLongBytes()``.
    public func toPrimitive() throws -> Primitive {
        try unchunkedPrimitive().chunkingLongBytes()
    }

    private func unchunkedPrimitive() throws -> Primitive {
        switch self {
        case .plutusData(let data):
            return try data.toPrimitive()
        case .dict(let data):
            return .dict(
                data.reduce(into: [:]) { result, entry in
                    result[entry.key.toPrimitive()] = entry.value.toPrimitive()
                })
        case .int(let data):
            return .int(Int64(data))
        case .bytes(let data):
            return .bytes(data)
        case .indefiniteList(let data):
            return .indefiniteList(IndefiniteList(data.map { $0.toPrimitive() }))
        case .cbor(let data):
            return .cborSimpleValue(data)
        case .rawPlutusData(let data):
            return try data.toPrimitive()
        }

    }

    public func toRawDatum() throws -> RawDatum {
        switch self {
        case .plutusData(let data):
            return .plutusData(data)
        case .dict(let data):
            return .dict(data)
        case .int(let data):
            return .int(data)
        case .bytes(let data):
            return .bytes(data)
        case .indefiniteList(let data):
            return .indefiniteList(data)
        case .cbor(let data):
            return .cbor(data)
        case .rawPlutusData(let data):
            return data.data
        }
    }

    public static func == (lhs: Datum, rhs: Datum) -> Bool {
        switch (lhs, rhs) {
        case (.plutusData(let a), .plutusData(let b)):
            return a == b
        case (.dict(let a), .dict(let b)):
            guard a.count == b.count else { return false }
            for (key, value1) in a {
                guard let value2 = b[key], value1 == value2 else {
                    return false
                }
            }
            return true
        case (.int(let a), .int(let b)):
            return a == b
        case (.bytes(let a), .bytes(let b)):
            return a == b
        case (.indefiniteList(let a), .indefiniteList(let b)):
            return a == b
        case (.cbor(let a), .cbor(let b)):
            return a == b
        case (.rawPlutusData(let a), .rawPlutusData(let b)):
            return a == b
        default:
            return false
        }
    }
}
