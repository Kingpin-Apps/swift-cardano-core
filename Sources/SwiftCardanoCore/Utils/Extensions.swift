import Foundation
import FractionNumber
import Network
import OrderedCollections
import PotentCBOR
import PotentCodables

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
        } else if let simpleValue = value as? UInt8 {
            return .simple(simpleValue)
        } else if let simpleValue = value as? Int8 {
            return .simple(UInt8(simpleValue))
        } else if let floatValue = value as? Float {
            return .float(floatValue)
        } else if let doubleValue = value as? Double {
            return .double(doubleValue)
        } else if let intValue = value as? Int {
            return CBOR(intValue)
        } else if let intValue = value as? Int64 {
            return CBOR(intValue)
        } else if let intValue = value as? UInt64 {
            return CBOR(intValue)
        } else if let arrayValue = value as? Array {
            return .array(arrayValue.map { CBOR.fromAny($0) })
        } else if let arrayValue = value as? [Any] {
            return .array(arrayValue.map { CBOR.fromAny($0) })
        }  else if let indefiniteListValue = value as? IndefiniteList<AnyValue> {
            return .indefiniteArray(indefiniteListValue.map { CBOR.fromAny($0) })
        } else if let boolValue = value as? Bool {
            return .boolean(boolValue)
        } else if let taggedValue = value as? (Tag, CBOR) {
            return .tagged(taggedValue.0, taggedValue.1)
        } else if let taggedValue = value as? CBORTag {
            return taggedValue.taggedCBOR()
        } else if let dataValue = value as? Data {
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
