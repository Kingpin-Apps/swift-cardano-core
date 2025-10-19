import Foundation
import OrderedCollections
import PotentCBOR
import PotentCodables

public struct RawPlutusData: PlutusDataProtocol {
    public let data: RawDatum

    public init(data: RawDatum) {
        self.data = data
    }

    enum CodingKeys: String, CodingKey {
        case data
    }
    
    init(from plutusData: PlutusData) throws {
        switch plutusData {
            case .bigInt(let bigInt):
                self.data = .int(Int(bigInt.intValue))
            case .bytes(let bytes):
                self.data = .bytes(bytes.bytes)
            case .array(let array):
                let anyValueList = IndefiniteList<AnyValue>(
                    array.map { try! RawPlutusData(from: $0).toAnyValue() })
                self.data = .indefiniteList(anyValueList)
            case .indefiniteArray(let array):
                let anyValueList = IndefiniteList<AnyValue>(
                    array.map { try! RawPlutusData(from: $0).toAnyValue() })
                self.data = .indefiniteList(anyValueList)
            case .map(let dict):
                var resultDict = OrderedDictionary<AnyValue, AnyValue>()
                for (key, value) in dict {
                    let keyRawPlutusData = try RawPlutusData(from: key).toAnyValue()
                    let valueRawPlutusData = try RawPlutusData(from: value).toAnyValue()
                    resultDict[keyRawPlutusData] = valueRawPlutusData
                }
                self.data = .dict(resultDict.reduce(into: [:]) { result, entry in
                    result[entry.key] = entry.value
                })
            case .constructor(_):
                throw CardanoCoreError.typeError("Constructor PlutusData is not supported in RawPlutusData")
        }
    }
    
    func toPlutusData() throws -> PlutusData {
        switch data {
            case let .plutusData(plutusData):
                return plutusData
            case let .dict(dict):
                var resultDict = OrderedDictionary<PlutusData, PlutusData>()
                for (key, value) in dict {
                    let keyPlutusData = try PlutusData(from: key.toPrimitive())
                    let valuePlutusData = try PlutusData(from: value.toPrimitive())
                    resultDict[keyPlutusData] = valuePlutusData
                }
                return .map(OrderedDictionary(uniqueKeysWithValues: resultDict))
            case let .int(intValue):
                return .bigInt(.int(Int64(intValue)))
            case let .bytes(data):
                return .bytes(try BoundedBytes(bytes: data))
            case let .indefiniteList(list):
                let plutusDataList = try list.getAll().map {
                    try PlutusData(from: $0.toPrimitive())
                }
                return .array(plutusDataList)
            case let .cbor(cbor):
                return .bytes(
                    try BoundedBytes(
                        bytes: try CBORSerialization.data(from: cbor)
                    )
                )
            case let .cborTag(cborTag):
                return try PlutusData(from: cborTag.toPrimitive())
        }
    }

    public init(from decoder: Decoder) throws {
        if String(describing: type(of: decoder)).contains("JSONDecoder") {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.data = try container.decode(RawDatum.self, forKey: .data)
        } else {
            let container = try decoder.singleValueContainer()
            let primitive = try container.decode(Primitive.self)
            self = try RawPlutusData(from: primitive)
        }
    }

    public func encode(to encoder: Encoder) throws {
        if String(describing: type(of: encoder)).contains("JSONEncoder") {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(data, forKey: .data)
        } else {
            var container = encoder.singleValueContainer()
            try container.encode(try toPrimitive())
        }
    }
    
    public init(from primitive: Primitive) throws {
        if case let .plutusData(plutusData) = primitive {
            self.data = .plutusData(plutusData)
        } else if case let .dict(dictionary) = primitive {
            self.data = .dict(dictionary.reduce(into: [:]) { result, entry in
                result[entry.key.toAnyValue()] = entry.value.toAnyValue()
            })
        } else if case let .int(intValue) = primitive {
            self.data = .int(intValue)
        } else if case let .uint(uintValue) = primitive {
            self.data = .int(Int(uintValue))
        } else if case let .bytes(data) = primitive {
            self.data = .bytes(data)
        } else if case let .indefiniteList(list) = primitive {
            self.data =
                .indefiniteList(IndefiniteList(list.map { $0.toAnyValue() }))
        } else if case let .list(list) = primitive {
            self.data =
                .indefiniteList(IndefiniteList(list.map { $0.toAnyValue() }))
        } else if case let .cborSimpleValue(cbor) = primitive {
            self.data = .cbor(cbor)
        } else if case let .cborTag(tag) = primitive {
            self.data = .cborTag(tag)
        } else {
            throw CardanoCoreError.typeError("Unsupported primitive type: \(primitive))")
        }
    }

    // Convert to primitive CBOR format
    public func toPrimitive() throws -> Primitive {
//        func dfs(_ obj: Any) throws -> Primitive {
//            if let list = obj as? [Any] {
//                return .list(try list.map { try dfs($0) })
//            } else if let dict = obj as? [AnyValue: AnyValue] {
//                return .dict(
//                    Dictionary(uniqueKeysWithValues:
//                                try dict.map { (try dfs($0.key), try dfs($0.value)) }
//                              )
//                )
//            } else if let tag = obj as? CBORTag {
//                if tag.tag != 102 {
//                    let value = try tag.value.arrayValue!.map { try dfs($0) }
//                    return .cborTag(
//                        CBORTag(
//                            tag: tag.tag,
//                            value: AnyValue
//                                .indefiniteArray(
//                                    try! value.map { try AnyValue.wrapped($0)
//                                    })
//                        )
//                    )
//                } else {
//                    let value = try tag.value.arrayValue!.map { try dfs($0) }
//                    return .cborTag(
//                        CBORTag(
//                            tag: tag.tag,
//                            value: AnyValue
//                                .array(
//                                    try! value.map { try AnyValue.wrapped($0)
//                                    })
//                        )
//                    )
//                }
//            }
//            return try Primitive.fromAny(obj)
//        }

        return try self.data.toPrimitive()
    }
    
    public func toAnyValue() -> AnyValue {
        func dfs(_ obj: Any) -> AnyValue {
            if let list = obj as? [Any] {
                return .array(list.map { dfs($0) })
            } else if let dict = obj as? [AnyValue: AnyValue] {
                return .dictionary(
                    OrderedDictionary(
                        uniqueKeysWithValues: dict.map { (dfs($0.key), dfs($0.value)) }))
            } else if let tag = obj as? CBORTag {
                if tag.tag != 102 {
                    let value = tag.value.listValue!.map { dfs($0) }
                    return try! AnyValue.wrapped(
                        CBOR.tagged(
                            CBOR.Tag(rawValue: tag.tag),
                            CBOR.array(value.map { try! CBOREncoder().encode($0).toCBOR })))
                } else {
                    return try! AnyValue.wrapped(
                        CBOR.tagged(
                            CBOR.Tag(rawValue: tag.tag), try! CBOREncoder().encode(tag.value).toCBOR
                        ))
                }
            }
            return try! AnyValue.wrapped(obj)
        }

        return dfs(self.data)
    }

    // Convert to dictionary format
    public func toDict() throws -> [String: Any] {
        func dfs(_ obj: Any) throws -> [String: Any] {
            if let intValue = obj as? Int {
                return ["int": intValue]
            } else if let bytesValue = obj as? Data {
                return ["bytes": bytesValue.toHex]
            } else if let byteString = obj as? ByteString {
                return ["bytes": byteString.value.toHex]
            } else if let list = obj as? IndefiniteList<AnyValue> {
                return ["list": try list.getAll().map { try dfs($0) }]
            } else if let list = obj as? [Any] {
                return ["list": try list.map { try dfs($0) }]
            } else if let dict = obj as? [AnyValue: AnyValue] {
                return ["map": try dict.map { ["k": try dfs($0.key), "v": try dfs($0.value)] }]
            } else if let tag = obj as? CBORTag {
                let (constructor, fields) = try getConstructorIDAndFields(
                    value: CBOR.tagged(
                        CBOR.Tag(rawValue: tag.tag), try CBOREncoder().encode(tag.value).toCBOR))
                return [
                    "constructor": constructor,
                    "fields": try fields.map { try dfs($0) },
                ]
            } else if let rawCBOR = obj as? CBOR {
                return try RawPlutusData(data: .cbor(rawCBOR)).toDict()
            }
            throw CardanoCoreError.typeError("Unexpected type \(type(of: obj))")
        }

        return try dfs(self.toPrimitive())
    }

    // Convert to JSON string
    public func toJSON(prettyPrinted: Bool = false) throws -> String {
        let dict = try self.toDict()
        let jsonData = try JSONSerialization.data(
            withJSONObject: dict,
            options: prettyPrinted ? .prettyPrinted : []
        )
        return String(data: jsonData, encoding: .utf8)!
    }

    // Create from primitive value
    public static func fromPrimitive(_ value: Any) throws -> RawPlutusData {
        if let plutusData = value as? PlutusData {
            return RawPlutusData(data: .plutusData(plutusData))
        } else if let dict = value as? [AnyValue: AnyValue] {
            return RawPlutusData(data: .dict(dict))
        } else if let int = value as? Int {
            return RawPlutusData(data: .int(int))
        } else if let bytes = value as? Data {
            return RawPlutusData(data: .bytes(bytes))
        } else if let list = value as? IndefiniteList<AnyValue> {
            return RawPlutusData(data: .indefiniteList(list))
        } else if let cbor = value as? CBOR {
            return RawPlutusData(data: .cbor(cbor))
        } else if let tag = value as? CBORTag {
            return RawPlutusData(data: .cborTag(tag))
        }
        throw CardanoCoreError.typeError("Unsupported primitive type: \(type(of: value))")
    }

    // Create from dictionary
    public static func fromDict(_ data: [String: Any]) throws -> RawPlutusData {
        func dfs(_ obj: Any) throws -> Any {
            if let dict = obj as? [String: Any] {
                if let constructor = dict["constructor"] as? Int,
                    let fields = dict["fields"] as? [[String: Any]]
                {
                    let convertedFields = try fields.map { try dfs($0) }
                    if let tag = getTag(constrID: constructor) {
                        return CBORTag(
                            tag: UInt64(tag),
                            value: .list(try convertedFields.map { try Primitive.fromAny($0) })
                        )
                    } else {
                        return CBORTag(
                            tag: 102,
                            value: .list([
                                .int(constructor),
                                .list(try convertedFields.map { try Primitive.fromAny($0) }),
                            ])
                        )
                    }
                } else if let mapItems = dict["map"] as? [[String: Any]] {
                    var resultDict: [AnyValue: AnyValue] = [:]
                    for item in mapItems {
                        guard let key = item["k"], let value = item["v"] else {
                            throw CardanoCoreError.deserializeError("Invalid map item format")
                        }
                        resultDict[try AnyValue.wrapped(try dfs(key))] = try AnyValue.wrapped(
                            try dfs(value))
                    }
                    return resultDict
                } else if let intValue = dict["int"] as? Int {
                    return intValue
                } else if let bytesHex = dict["bytes"] as? String {
                    guard let bytes = Data(hexString: bytesHex) else {
                        throw CardanoCoreError.deserializeError("Invalid hex string")
                    }
                    return bytes.count > 64 ? ByteString(value: bytes) : bytes
                } else if let list = dict["list"] as? [Any] {
                    return try list.map { try dfs($0) }
                }
                throw CardanoCoreError.deserializeError("Unexpected data structure: \(dict)")
            }
            throw CardanoCoreError.typeError("Unexpected data type: \(type(of: obj))")
        }

        let value = try dfs(data)
        return try RawPlutusData.fromPrimitive(value)
    }

    // Create from JSON string
    public static func fromJSON(_ jsonString: String) throws -> RawPlutusData {
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw CardanoCoreError.deserializeError("Invalid JSON string")
        }

        let dict = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        guard let dict = dict else {
            throw CardanoCoreError.deserializeError("JSON must be a dictionary")
        }

        return try RawPlutusData.fromDict(dict)
    }

    // Deep copy support
    public func copy() throws -> RawPlutusData {
        return try Self.fromCBOR(data: try self.toCBORData())
    }
}
