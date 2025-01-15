import Foundation
import OrderedCollections
import PotentCBOR
import Foundation
import Network

// MARK: - IPv4Address Extensions
extension IPv4Address: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let addressString = try container.decode(String.self)
        
        guard let address = IPv4Address(addressString) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid IPv4 address format")
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
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid IPv6 address format")
        }
        
        self = address
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.debugDescription)
    }
}

// MARK: - CBOR Extensions
extension CBOR {
    static func fromAny(_ value: Any) -> CBOR {
        if let stringValue = value as? String {
            return .utf8String(stringValue)
        } else if let intValue = value as? Int {
            return intValue >= 0 ?
                .unsignedInt(UInt64(intValue)) :
                .negativeInt(UInt64(abs(intValue)))
        } else if let dataValue = value as? Data {
            return .byteString(dataValue)
        } else if let dictValue = value as? [AnyHashable: Any] {
            return .map(dictValue.mapKeysToCbor)
        } else {
            return .null
        }
    }
}

// MARK: - Data Extensions
extension Data {
    var toBytes: [UInt8] {
        return [UInt8](self)
    }
    
    var toHex: String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
    
    var toCBOR: CBOR {
        return try! CBORSerialization.cbor(from: self)
    }
    
    static func randomBytes(count: Int) -> Data {
        var data = Data(count: count)
        _ = data.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, count, $0.baseAddress!)
        }
        return data
    }
    
    init?(hexString: String) {
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
    var mapKeysToCbor: OrderedDictionary<CBOR, CBOR> {
        return self.reduce(into: [:]) { result, element in
            result[CBOR.fromAny(element.key)] = CBOR.fromAny(element.value)
        }
    }
}

// MARK: - String Extensions
extension String {
    var toData: Data {
        return Data(self.utf8)
    }
    
    var hexStringToData: Data {
        var tempHex = self
        
        // Ensure string length is even
        if tempHex.count % 2 != 0 {
            tempHex = "0" + tempHex
        }
        
        let cleanHex = tempHex.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "\n", with: "")
        var bytes = [UInt8]()
        var currentIndex = cleanHex.startIndex
        
        while currentIndex < cleanHex.endIndex {
            let nextIndex = cleanHex.index(currentIndex, offsetBy: 2, limitedBy: cleanHex.endIndex) ?? cleanHex.endIndex
            let byteString = String(cleanHex[currentIndex..<nextIndex])
            if let byte = UInt8(byteString, radix: 16) {
                bytes.append(byte)
            }
            currentIndex = nextIndex
        }
        
        return Data(bytes)
    }
}
