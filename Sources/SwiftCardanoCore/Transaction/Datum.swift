import Foundation
import PotentCBOR
import PotentCodables
import OrderedCollections

public enum DatumType: CBORSerializable {
    case datumHash(DatumHash)
    case data(PlutusData)
    
    public init(from primitive: Primitive) throws {
        if case let .cborTag(cborTag) = primitive {
            guard cborTag.tag == 24 else {
                throw CardanoCoreError.deserializeError("Invalid DatumType type. Tag must be 24, but found \(cborTag.tag)")
            }
            
            // Handle CBOR-encoded data inside the tag
            if case .bytes(let cborData) = cborTag.value {
                let plutusData = try CBORDecoder().decode(
                    PlutusData.self,
                    from: cborData
                )
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
}

public struct DatumOption: CBORSerializable {
    public var type: Int
    public var datum: DatumType
    
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
    
    public init(from primitive: Primitive) throws {
        guard case let .list(primitive) = primitive else {
            throw CardanoCoreError.deserializeError("Invalid DatumOption type")
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
        switch datum {
            case .datumHash(_):
                return .list([.int(0), try datum.toPrimitive()])
            case .data(_):
                return .list([.int(1), try datum.toPrimitive()])
        }
    }
}


// MARK: - RawDatum
public enum RawDatum: PlutusDataProtocol {
    case plutusData(PlutusData)
    case dict(Dictionary<AnyValue, AnyValue>)
    case int(Int)
    case bytes(Data)
    case indefiniteList(IndefiniteList<AnyValue>)
    case cbor(CBOR)
    case cborTag(CBORTag)
    
    init(from plutusData: PlutusData) throws {
        self = try RawDatum(from: plutusData.toPrimitive())
    }
    
    func toPlutusData() throws -> PlutusData {
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
                return .map(OrderedDictionary(uniqueKeysWithValues: resultDict))
            case .int(let int):
                return .bigInt(.int(Int64(int)))
            case .bytes(let bytes):
                return .bytes(try BoundedBytes(bytes: bytes))
            case .indefiniteList(let list):
                let plutusDataList = try list.getAll().map {
                    try PlutusData(from: $0.toPrimitive())
                }
                return .array(plutusDataList)
            case .cbor(let cbor):
                return .bytes(
                    try BoundedBytes(
                        bytes: try CBORSerialization.data(from: cbor)
                    )
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
            if case let CBOR.tagged(tag, data) = cbor {
                self = .cborTag(
                    CBORTag(
                        tag: UInt64(tag.rawValue),
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
    
    public func encode(to encoder: Encoder) throws {
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
            case .int(let int):
                self = .int(int)
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
    
    public func toPrimitive() throws -> Primitive {
        switch self {
            case .plutusData(let data):
                return try data.toPrimitive()
            case .dict(let dict):
                let convertedDict = dict.reduce(into: [:]) { result, entry in
                    result[entry.key.toPrimitive()] = entry.value.toPrimitive()
                }
                return .dict(convertedDict)
            case .int(let int):
                return .int(int)
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
    case dict(Dictionary<AnyValue, AnyValue>)
    case int(Int)
    case bytes(Data)
    case indefiniteList(IndefiniteList<AnyValue>)
    case cbor(CBOR)
    case rawPlutusData(RawPlutusData)
    
    init(from plutusData: PlutusData) throws {
        self = try Datum(from: plutusData.toPrimitive())
    }
    
    func toPlutusData() throws -> PlutusData {
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
                return .map(OrderedDictionary(uniqueKeysWithValues: resultDict))
            case .int(let int):
                return .bigInt(.int(Int64(int)))
            case .bytes(let bytes):
                return .bytes(try BoundedBytes(bytes: bytes))
            case .indefiniteList(let list):
                let plutusDataList = try list.getAll().map {
                    try PlutusData(from: $0.toPrimitive())
                }
                return .array(plutusDataList)
            case .cbor(let cbor):
                return .bytes(
                    try BoundedBytes(
                        bytes: try CBORSerialization.data(from: cbor)
                    )
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
                self = .dict(dict.reduce(into: [:]) { result, entry in
                    result[entry.key.toAnyValue()] = entry.value.toAnyValue()
                })
            case .int(let int):
                self = .int(int)
            case .bytes(let bytes):
                self = .bytes(bytes)
            case .indefiniteList(let list):
                self = .indefiniteList(
                    IndefiniteList(list.map { $0.toAnyValue() })
                )
            case .cborSimpleValue(let cbor):
                self = .cbor(cbor)
            default:
                throw CardanoCoreError.deserializeError("Invalid Datum")
        }
    }
    
    public func toPrimitive() throws -> Primitive {
        switch self {
            case .plutusData(let data):
                return try data.toPrimitive()
            case .dict(let data):
                return .dict(data.reduce(into: [:]) { result, entry in
                    result[entry.key.toPrimitive()] = entry.value.toPrimitive()
                })
            case .int(let data):
                return .int(data)
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
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self)
    }
}
