import Foundation
import FractionNumber
import Network
import OrderedCollections
import PotentCBOR
import PotentCodables
import BigInt

// MARK: - IPv4Address Extensions
extension IPv4Address: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let addressString = try container.decode(String.self)

        guard let address = IPv4Address(addressString) else {
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Invalid IPv4 address format")
        }

        self = address
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.debugDescription)
    }
}

// MARK: - IPv6Address Extensions
extension IPv6Address: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let addressString = try container.decode(String.self)

        guard let address = IPv6Address(addressString) else {
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Invalid IPv6 address format")
        }

        self = address
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.debugDescription)
    }
}

// MARK: - CBOR Extensions
extension CBOR: Codable {
    public init(from decoder: Swift.Decoder) throws {
        let container = try decoder.singleValueContainer()
        let cborData = try container.decode(Data.self)
        let cbor = try CBORSerialization.cbor(from: cborData)
        self = cbor
    }

    public func encode(to encoder: Swift.Encoder) throws {
        let cbor = try CBORSerialization.data(from: self)
        try cbor.encode(to: encoder)
    }
}

extension CBOR {
    public static func fromAny(_ value: Any) -> CBOR {
        if let anyValue = value as? AnyValue {
            let unwrapped = anyValue.unwrapped!
            return CBOR.fromAny(unwrapped)
        } else if let stringValue = value as? String {
            return .utf8String(stringValue)
        } else if let boolValue = value as? Bool {
            return .boolean(boolValue)
        }
        // Handle integers with proper hierarchy
        else if let intValue = value as? Int {
            if intValue >= 0 {
                return .unsignedInt(UInt64(intValue))
            } else {
                return .negativeInt(UInt64(-1 - intValue))
            }
        } else if let intValue = value as? Int64 {
            if intValue >= 0 {
                return .unsignedInt(UInt64(intValue))
            } else {
                return .negativeInt(UInt64(-1 - intValue))
            }
        } else if let intValue = value as? UInt64 {
            return .unsignedInt(intValue)
        } else if let intValue = value as? UInt8 {
            return .simple(intValue)
        } else if let intValue = value as? Int8 {
            return .simple(UInt8(intValue))
        }
        // Handle floating point values
        else if let floatValue = value as? Float {
            return .float(floatValue)
        } else if let doubleValue = value as? Double {
            return .double(doubleValue)
        }
        // Handle collections
        else if let arrayValue = value as? Array {
            return .array(arrayValue.map { CBOR.fromAny($0) })
        } else if let arrayValue = value as? [Any] {
            return .array(arrayValue.map { CBOR.fromAny($0) })
        } else if let indefiniteListValue = value as? IndefiniteList<AnyValue> {
            return .indefiniteArray(indefiniteListValue.map { CBOR.fromAny($0) })
        }
        // Handle tagged values
        else if let taggedValue = value as? (Tag, CBOR) {
            return .tagged(taggedValue.0, taggedValue.1)
        } else if let taggedValue = value as? CBORTag {
            return taggedValue.taggedCBOR()
        }
        // Handle binary and dictionary data
        else if let dataValue = value as? Data {
            return .byteString(dataValue)
        } else if let dictValue = value as? [AnyHashable: Any] {
            return .map(dictValue.mapKeysToCbor)
        } else if let dictValue = value as? OrderedDictionary<AnyHashable, AnyHashable> {
            return .map(dictValue.mapKeysToCbor)
        } else if let codable = value as? any Codable {
            return .byteString(try! CBOREncoder().encode(codable))
        } else if let hashable = value as? AnyHashable {
            return CBOR.fromAny(hashable.base)
        } else {
            return .null
        }
    }
    
    public func toPrimitive() throws -> Primitive {
        switch self {
        case .null:
            return .null
        case .boolean(let bool):
            return .bool(bool)
        case .utf8String(let string):
            return .string(string)
        case .byteString(let data):
            return .bytes(data)
        case .array(let array):
            let primitiveArray = try array.map { try $0.toPrimitive() }
            return .list(primitiveArray)
        case .map(let map):
            var resultDict: [Primitive: Primitive] = [:]
            for (key, value) in map {
                let keyPrimitive = try key.toPrimitive()
                let valuePrimitive = try value.toPrimitive()
                resultDict[keyPrimitive] = valuePrimitive
            }
            return .dict(resultDict)
        case .tagged(_, let value):
            let taggedValue = try AnyValue(from: value.toPrimitive())
            return taggedValue.toPrimitive()
        case .simple(let simpleValue):
                return .int(Int(simpleValue))
        case .float(let floatValue):
            return .float(Double(floatValue))
        case .double(let doubleValue):
            return .float(doubleValue)
        case .unsignedInt(let value):
            return .int(Int(value))
        case .negativeInt(let value):
            return .int(-Int(value) - 1) // CBOR negative integers are encoded as -1 - n
        case .indefiniteByteString(let data):
            return .bytes(data)
        case .indefiniteUtf8String(let string):
            return .string(string)
        case .indefiniteArray(let array):
            let primitiveArray = try array.map { try $0.toPrimitive() }
            return .indefiniteList(IndefiniteList(primitiveArray))
        case .indefiniteMap(let map):
            var resultDict: [Primitive: Primitive] = [:]
            for (key, value) in map {
                let keyPrimitive = try key.toPrimitive()
                let valuePrimitive = try value.toPrimitive()
                resultDict[keyPrimitive] = valuePrimitive
            }
            return .dict(resultDict)
        case .undefined:
            return .null
        case .half(let halfValue):
            return .float(Double(halfValue))
        }
        
    }
}


// MARK: - Data Extensions
extension Data {
    public var toBytes: [UInt8] {
        return [UInt8](self)
    }

    public var toHex: String {
        return map { String(format: "%02hhx", $0) }.joined()
    }

    public var toString: String {
        return String(data: self, encoding: .utf8)!
    }

    public var toCBOR: CBOR {
        return try! CBORSerialization.cbor(from: self)
    }

    public static func randomBytes(count: Int) -> Data {
        var data = Data(count: count)
        _ = data.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, count, $0.baseAddress!)
        }
        return data
    }

    public init?(hexString: String) {
        let length = hexString.count / 2
        var data = Data(capacity: length)
        var index = hexString.startIndex
        for _ in 0..<length {
            let nextIndex = hexString.index(index, offsetBy: 2)
            if let byte = UInt8(hexString[index..<nextIndex], radix: 16) {
                data.append(byte)
            } else {
                return nil
            }
            index = nextIndex
        }
        self = data
    }
}

// MARK: - Dictionary Extensions
extension Dictionary where Key == AnyHashable, Value == Any {
    public var mapKeysToCbor: OrderedDictionary<CBOR, CBOR> {
        return self.reduce(into: [:]) { result, element in
            result[CBOR.fromAny(element.key)] = CBOR.fromAny(element.value)
        }
    }
}

extension OrderedDictionary where Key == AnyHashable, Value == AnyHashable {
    public var mapKeysToCbor: OrderedDictionary<CBOR, CBOR> {
        return self.reduce(into: [:]) { result, element in
            result[CBOR.fromAny(element.key.base)] = CBOR.fromAny(element.value.base)
        }
    }
}

// MARK: - String Extensions
extension String {
    public var toData: Data {
        return Data(self.utf8)
    }

    public var hexStringToData: Data {
        var tempHex = self

        // Ensure string length is even
        if tempHex.count % 2 != 0 {
            tempHex = "0" + tempHex
        }

        let cleanHex = tempHex.replacingOccurrences(of: " ", with: "").replacingOccurrences(
            of: "\n", with: "")
        var bytes = [UInt8]()
        var currentIndex = cleanHex.startIndex

        while currentIndex < cleanHex.endIndex {
            let nextIndex =
                cleanHex.index(currentIndex, offsetBy: 2, limitedBy: cleanHex.endIndex)
                ?? cleanHex.endIndex
            let byteString = String(cleanHex[currentIndex..<nextIndex])
            if let byte = UInt8(byteString, radix: 16) {
                bytes.append(byte)
            }
            currentIndex = nextIndex
        }

        return Data(bytes)
    }
}

// MARK: - AnyValue Extensions

extension AnyValue: CBORSerializable {
    public init(from primitive: Primitive) throws {
        switch primitive {
        case .null:
            self = .nil
        case .bool(let value):
            self = .bool(value)
        case .int(let value):
            self = .integer(BigInt(value))
        case .float(let value):
            self = .double(value)
        case .decimal(let value):
            self = .decimal(value)
        case .string(let value):
            self = .string(value)
        case .bytes(let data):
            self = .data(data)
        case .byteArray(let array):
            self = .data(Data(array))
        case .datetime(let date):
            self = .date(date)
        case .list(let array):
            let anyValueArray = try array.map { try AnyValue(from: $0) }
            self = .array(anyValueArray)
        case .indefiniteList(let indefiniteArray):
            let anyValueArray = try indefiniteArray.map { try AnyValue(from: $0) }
            self = .indefiniteArray(anyValueArray)
        case .dict(let dictionary):
            var orderedDict = OrderedDictionary<AnyValue, AnyValue>()
            for (key, value) in dictionary {
                let anyKey = try AnyValue(from: key)
                let anyValue = try AnyValue(from: value)
                orderedDict[anyKey] = anyValue
            }
            self = .dictionary(orderedDict)
        case .orderedDict(let orderedDictionary):
            var orderedDict = OrderedDictionary<AnyValue, AnyValue>()
            for (key, value) in orderedDictionary {
                let anyKey = try AnyValue(from: key)
                let anyValue = try AnyValue(from: value)
                orderedDict[anyKey] = anyValue
            }
            self = .dictionary(orderedDict)
        case .tuple(let tuple):
            let anyValueArray = try tuple.elements.map { try AnyValue(from: $0) }
            self = .array(anyValueArray)
        case .regex(let regex):
            self = .string(regex.pattern)
        case .orderedSet(let set):
            let anyValueArray = try set.elements.map { try AnyValue(from: $0) }
            self = .array(anyValueArray)
        case .nonEmptyOrderedSet(let set):
            let anyValueArray = try set.elements.map { try AnyValue(from: $0) }
            self = .array(anyValueArray)
        case .unitInterval(let unitInterval):
            // Represent fraction as a 2-element array [numerator, denominator]
                self = .array(
                    [
                        .int(Int(unitInterval.numerator)),
                        .int(Int(unitInterval.denominator))
                    ]
                )
        case .frozenSet(let set):
            let anyValueArray = try set.map { try AnyValue(from: $0) }
            self = .array(anyValueArray)
        case .frozenDict(let dictionary):
            var orderedDict = OrderedDictionary<AnyValue, AnyValue>()
            for (key, value) in dictionary {
                let anyKey = try AnyValue(from: key)
                let anyValue = try AnyValue(from: value)
                orderedDict[anyKey] = anyValue
            }
            self = .dictionary(orderedDict)
        case .frozenList(let array):
            let anyValueArray = try array.map { try AnyValue(from: $0) }
            self = .array(anyValueArray)
        case .indefiniteFrozenList(let indefiniteArray):
            let anyValueArray = try indefiniteArray.map { try AnyValue(from: $0) }
            self = .indefiniteArray(anyValueArray)
        case .byteString(let byteString):
            self = .data(byteString.value)
        case .cborTag(let tag):
            // Handle CBOR tags by attempting to decode the tagged value
            let taggedValue = try AnyValue(from: tag.value.toPrimitive())
            self = taggedValue
        case .cborSimpleValue(let cbor):
            // Convert CBOR simple values to appropriate AnyValue
            switch cbor {
            case .null:
                self = .nil
            case .boolean(let bool):
                self = .bool(bool)
            case .utf8String(let string):
                self = .string(string)
            case .byteString(let data):
                self = .data(data)
            case .array(let array):
                let primitiveArray = try array.map { try $0.toPrimitive() }
                let anyValueArray = try primitiveArray.map { try AnyValue(from: $0) }
                self = .array(anyValueArray)
            case .map(let map):
                var orderedDict = OrderedDictionary<AnyValue, AnyValue>()
                for (key, value) in map {
                    let keyPrimitive = try key.toPrimitive()
                    let valuePrimitive = try value.toPrimitive()
                    let anyKey = try AnyValue(from: keyPrimitive)
                    let anyValue = try AnyValue(from: valuePrimitive)
                    orderedDict[anyKey] = anyValue
                }
                self = .dictionary(orderedDict)
            case .tagged(_, let value):
                let taggedValue = try AnyValue(from: value.toPrimitive())
                self = taggedValue
            case .simple(let simpleValue):
                self = .uint8(simpleValue)
            case .float(let floatValue):
                self = .float(floatValue)
            case .double(let doubleValue):
                self = .double(doubleValue)
            default:
                // For other CBOR types, attempt to get their raw value
                if let intValue: Int64 = cbor.integerValue() {
                    self = .integer(BigInt(intValue))
                } else if let stringValue = cbor.utf8StringValue {
                    self = .string(stringValue)
                } else if let dataValue = cbor.bytesStringValue {
                    self = .data(dataValue)
                } else {
                    throw CardanoCoreError.deserializeError("Unsupported CBOR type for AnyValue conversion")
                }
            }
        case .plutusData(let plutusData):
            // Convert PlutusData to its AnyValue representation
            self = plutusData.toAnyValue()
        }
    }
    
    public func toPrimitive() -> Primitive {
        switch self {
            case .nil:
                return .null
            case .bool(let bool):
                return .bool(bool)
            case .string(let string):
                return .string(string)
            case .indefiniteString(let string):
                return .string(string)
            case .int8(let value):
                return .int(Int(value))
            case .int16(let value):
                return .int(Int(value))
            case .int32(let value):
                return .int(Int(value))
            case .int64(let value):
                return .int(Int(value))
            case .uint8(let value):
                return .int(Int(value))
            case .uint16(let value):
                return .int(Int(value))
            case .uint32(let value):
                return .int(Int(value))
            case .uint64(let value):
                return .int(Int(value))
            case .integer(let value):
                return .int(Int(value))
            case .unsignedInteger(let value):
                return .int(Int(value))
            case .float16(let value):
                return .float(Double(value))
            case .float(let value):
                return .float(Double(value))
            case .double(let value):
                return .float(value)
            case .decimal(let value):
                return .decimal(value)
            case .data(let data):
                return .bytes(data)
            case .indefiniteData(let data):
                return .bytes(data)
            case .url(let url):
                return .string(url.absoluteString)
            case .uuid(let uuid):
                return .string(uuid.uuidString)
            case .date(let date):
                return .datetime(date)
            case .array(let array):
                return .list(array.map { $0.toPrimitive() })
            case .indefiniteArray(let array):
                return .indefiniteList(IndefiniteList(array.map { $0.toPrimitive() }))
            case .dictionary(let dictionary):
                return .dict(dictionary.reduce(into: [:]) { result, entry in
                    result[entry.key.toPrimitive()] = entry.value.toPrimitive()
                })
            case .indefiniteDictionary(let dictionary):
                return .dict(dictionary.reduce(into: [:]) { result, entry in
                    result[entry.key.toPrimitive()] = entry.value.toPrimitive()
                })
        }
    }
}


// MARK: - SingleValueEncodingContainer Extension

public extension SingleValueEncodingContainer {
    
    mutating func encode<Transformer: ValueEncodingTransformer>(
        _ value: Transformer.Target,
        using transformer: Transformer
    ) throws where Transformer.Source: Encodable {
        try encode(transformer.encode(value))
    }
    
}
