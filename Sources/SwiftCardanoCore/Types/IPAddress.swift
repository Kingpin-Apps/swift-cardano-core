import Foundation

// MARK: - IPv4Address Extensions
public struct IPv4Address: CBORSerializable, LosslessStringConvertible, Equatable {
    public let ip: UInt32
    
    public var description: String {
        return address
    }
    
    public var address: String {
        return "\( (ip >> 24) & 0xFF ).\( (ip >> 16) & 0xFF ).\( (ip >> 8) & 0xFF ).\( ip & 0xFF )"
    }
    
    /// Returns an array of octets representing the parts of the IP address.
    public var octets: [UInt8] {
        return [UInt8(ip & 0xFF),
                UInt8((ip >> 8) & 0xFF),
                UInt8((ip >> 16) & 0xFF),
                UInt8(ip >> 24)]
    }
    
    public var rawValue: Data {
        return Data(octets)
    }
    
    public init?(_ description: String) {
        do {
            try self.init(address: description)
        } catch {
            return nil
        }
    }
    
    public init (from ip: UInt32) throws {
        self.ip = ip
    }
    
    public init (from octets: [UInt8]) throws {
        try self.init(Data(octets))
    }

    public init(_ data: Data) throws {
        guard data.count == 4 else {
            throw CardanoCoreError.valueError("Data must be exactly 4 bytes to represent an IPv4 address.")
        }
        
        self.ip = data.withUnsafeBytes { $0.load(as: UInt32.self) }
    }
    
    public init(address: String) throws {
        let chunks = address.split(separator: ".")
        guard chunks.count == 4 else {
            throw CardanoCoreError.valueError("Address does not conform to format a.b.c.d: \(address)")
        }
        
        var ip = 0
        var shift = 24
        for chunk in chunks {
            if let byte_value = Int(chunk) {
                if !(0...255 ~= byte_value) {
                    throw CardanoCoreError.valueError("Numbers in address must be in range [0, 255]")
                }
                
                ip += byte_value << shift
                shift -= 8
            } else {
                throw CardanoCoreError.valueError("Invalid IP address format: \(address)")
            }
        }
        
        self.ip = UInt32(ip)
    }
    
    public init(from primitive: Primitive) throws {
        guard case let .string(addressString) = primitive else {
            throw CardanoCoreError.deserializeError("Invalid IPv4 address type")
        }
        
        try self.init(address: addressString)
    }
    
    public func toPrimitive() throws -> Primitive {
        return .string(address)
    }
    
    // MARK: - Codable Implementation Override
    public init(from decoder: Decoder) throws {
        if String(describing: type(of: decoder)).contains("JSONDecoder") {
            let container = try decoder.singleValueContainer()
            let addressString = try container.decode(String.self)
            try self.init(address: addressString)
        } else {
            let container = try decoder.singleValueContainer()
            let primitive = try container.decode(Primitive.self)
            try self.init(from: primitive)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        if String(describing: type(of: encoder)).contains("JSONEncoder") {
            var container = encoder.singleValueContainer()
            try container.encode(address)
        } else {
            var container = encoder.singleValueContainer()
            try container.encode(try toPrimitive())
        }
    }
}

// MARK: - IPv6Address Extensions
public struct  IPv6Address: CBORSerializable, LosslessStringConvertible, Equatable {
    public let high, low: UInt64
    
    public var description: String {
        return address
    }
    
    public var address: String {
        var segments: [String] = []
        for i in 0..<8 {
            let word: UInt16
            if i < 4 {
                let shift = (3 - i) * 16
                word = UInt16((high >> shift) & 0xFFFF)
            } else {
                let shift = (7 - i) * 16
                word = UInt16((low >> shift) & 0xFFFF)
            }
            segments.append(String(format: "%x", word))
        }
        return segments.joined(separator: ":")
    }
        
    
    public var octets: [UInt8] {
        return [UInt8(high & 0xFF), UInt8((high >> 8) & 0xFF),
                UInt8((high >> 16) & 0xFF), UInt8((high >> 24) & 0xFF),
                UInt8((high >> 32) & 0xFF), UInt8((high >> 40) & 0xFF),
                UInt8((high >> 48) & 0xFF), UInt8(high >> 56),
                UInt8(low & 0xFF), UInt8((low >> 8) & 0xFF),
                UInt8((low >> 16) & 0xFF), UInt8((low >> 24) & 0xFF),
                UInt8((low >> 32) & 0xFF), UInt8((low >> 40) & 0xFF),
                UInt8((low >> 48) & 0xFF), UInt8(low >> 56)]
    }
    
    
    public var rawValue: Data {
        return Data(octets)
    }
    
    public init?(_ description: String) {
        do {
            try self.init(address: description)
        } catch {
            return nil
        }
    }
    
    public init (from octets: [UInt8]) throws {
        try self.init(Data(octets))
    }
    
    public init(_ data: Data) throws {
        guard data.count == 16 else {
            throw CardanoCoreError.valueError("Data must be exactly 16 bytes to represent an IPv6 address.")
        }
        
        self.high = data.prefix(8).withUnsafeBytes { $0.load(as: UInt64.self) }
        self.low = data.suffix(8).withUnsafeBytes { $0.load(as: UInt64.self) }
    }
    
    public init(address: String) throws {
        // Handle IPv6 address with :: shorthand notation
        let normalizedAddress = try Self.normalizeIPv6(address)
        let chunks = normalizedAddress.split(separator: ":")
        
        guard chunks.count == 8 else {
            throw CardanoCoreError.valueError("Address does not conform to IPv6 format: \(address)")
        }
        
        var hi: UInt64 = 0
        var lo: UInt64 = 0
        
        for (i, chunk) in chunks.enumerated() {
            guard let word_value = UInt64(chunk, radix: 16) else {
                throw CardanoCoreError.valueError("Invalid hexadecimal in IPv6 address: \(chunk)")
            }
            
            if !(0...0xFFFF ~= word_value) {
                throw CardanoCoreError.valueError("Words in address must be in range [0, 0xFFFF]")
            }
            
            if i < 4 {
                let shift = (3 - i) * 16
                hi |= word_value << shift
            } else {
                let shift = (7 - i) * 16
                lo |= word_value << shift
            }
        }
        
        self.high = hi
        self.low = lo
    }
    
    public init(from primitive: Primitive) throws {
        guard case let .string(addressString) = primitive else {
            throw CardanoCoreError.deserializeError("Invalid IPv6 address type")
        }
        
        try self.init(address: addressString)
    }
    
    public func toPrimitive() throws -> Primitive {
        return .string(address)
    }
    
    // MARK: - Codable Implementation Override
    public init(from decoder: Decoder) throws {
        if String(describing: type(of: decoder)).contains("JSONDecoder") {
            let container = try decoder.singleValueContainer()
            let addressString = try container.decode(String.self)
            try self.init(address: addressString)
        } else {
            let container = try decoder.singleValueContainer()
            let primitive = try container.decode(Primitive.self)
            try self.init(from: primitive)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        if String(describing: type(of: encoder)).contains("JSONEncoder") {
            var container = encoder.singleValueContainer()
            try container.encode(address)
        } else {
            var container = encoder.singleValueContainer()
            try container.encode(try toPrimitive())
        }
    }
    
    // MARK: - Helper Methods
    public static func debugNormalizeIPv6(_ address: String) throws -> String {
        return try normalizeIPv6(address)
    }
    
    private static func normalizeIPv6(_ address: String) throws -> String {
        // Handle :: shorthand notation by expanding it
        if address.contains("::") {
            let parts = address.components(separatedBy: "::")
            guard parts.count <= 2 else {
                throw CardanoCoreError.valueError("Invalid IPv6 address: multiple :: found")
            }
            
            let leftParts = parts[0].isEmpty ? [] : parts[0].split(separator: ":").map(String.init)
            let rightParts = parts.count > 1 ? (parts[1].isEmpty ? [] : parts[1].split(separator: ":").map(String.init)) : []
            
            let totalParts = leftParts.count + rightParts.count
            guard totalParts < 8 else {
                throw CardanoCoreError.valueError("Invalid IPv6 address: too many parts")
            }
            
            let missingParts = 8 - totalParts
            let expandedParts = leftParts + Array(repeating: "0", count: missingParts) + rightParts
            
            return expandedParts.joined(separator: ":")
        } else {
            // Already in full form
            return address
        }
    }
}

