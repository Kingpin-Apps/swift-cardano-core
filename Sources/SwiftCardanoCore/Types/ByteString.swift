import Foundation
import PotentCodables


// MARK: - ByteString
public struct ByteString: CBORSerializable, CustomStringConvertible, Sendable {
    public let bytes: Data
    
    public var toHex: String {
        return self.bytes.toHex
    }
    
    public var description: String {
        "ByteString(length: \(bytes.count))"
    }

    public init(bytes: Data) {
        self.bytes = bytes
    }
    
    public init(from primitive: Primitive) throws {
        guard case let .bytes(data) = primitive else {
            throw CardanoCoreError.valueError("Invalid ByteString type")
        }
        self.init(bytes: data)
    }

    public func toPrimitive() throws -> Primitive {
        return .bytes(self.bytes)
    }

    public static func == (lhs: ByteString, rhs: ByteString) -> Bool {
        return lhs.bytes == rhs.bytes
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(bytes)
    }

    public func isEqual(to other: Any) -> Bool {
        if let otherByteString = other as? ByteString {
            return self.bytes == otherByteString.bytes
        } else if let otherData = other as? Data {
            return self.bytes == otherData
        } else {
            return false
        }
    }
}

// MARK: - BoundedBytes

/// Bounded bytes with enforced maximum length (0..64).
/// Mirrors the CDDL `bounded_bytes = bytes .size (0 .. 64)`
public struct BoundedBytes: CBORSerializable, CustomStringConvertible, Sendable {
    public let bytes: Data
    
    /// Creates a `BoundedBytes` if `bytes.count` is <= 64. Returns nil otherwise.
    public init(bytes: Data) throws {
        guard bytes.count <= 64 else {
            throw CardanoCoreError.valueError("BoundedBytes length exceeds 64 bytes")
        }
        self.bytes = bytes
    }
    
    /// Create from an array of bytes
    public init(_ bytesArray: [UInt8]) throws {
        try self.init(bytes: Data(bytesArray))
    }
    
    public var description: String {
        "BoundedBytes(length: \(bytes.count))"
    }
    
    public var toHex: String {
        return self.bytes.toHex
    }
    
    public init(from primitive: Primitive) throws {
        guard case let .bytes(data) = primitive else {
            throw CardanoCoreError.deserializeError("Invalid BoundedBytes type")
        }
        try self.init(bytes: data)
    }
    
    public func toPrimitive() throws -> Primitive {
        return .bytes(self.bytes)
    }
    
    public func toDict() throws -> [String: String] {
        return ["bytes": bytes.toHex]
    }
}

// MARK: - RawBytesTransformer
public struct RawBytesTransformer: ValueEncodingTransformer {
    public typealias Source = Data
    public typealias Target = Data
    
    public func encode(_ value: Data) throws -> Data {
        return value
    }

}
