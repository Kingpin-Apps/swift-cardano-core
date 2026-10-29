import Foundation
import CBORCodable


// MARK: - ByteString
public struct ByteString: CBORSerializable, CustomStringConvertible, Sendable {
    public static var preservesEncoding: Bool { true }

    public let bytes: Data
    /// The widths of the chunks this was read with, when it was written as an
    /// indefinite-length string; nil when it was written definite or built in
    /// code.
    ///
    /// The chunking is part of the encoding, and so of any hash taken over
    /// it. Plutus data caps each chunk at 64 bytes, not at exactly 64, so a
    /// value another tool chunked at 60/60/62 is valid and has to be written
    /// back the way it was read.
    public let chunks: [Int]?
    
    public var toHex: String {
        return self.bytes.toHex
    }
    
    public var description: String {
        "ByteString(length: \(bytes.count))"
    }

    public init(bytes: Data) {
        self.bytes = bytes
        self.chunks = nil
    }

    /// A byte string written as an indefinite-length string of `chunks`.
    public init(chunks: [Data]) {
        var bytes = Data()
        for chunk in chunks { bytes.append(chunk) }
        self.bytes = bytes
        self.chunks = chunks.map(\.count)
    }
    
    public init(from primitive: Primitive) throws {
        switch primitive {
        case .bytes(let data):
            self.init(bytes: data)
        case .byteString(let byteString):
            self = byteString
        default:
            throw CardanoCoreError.valueError("Invalid ByteString type")
        }
    }

    /// Plain bytes when written definite, otherwise the byte string itself,
    /// which encodes in the chunks it was read with.
    public func toPrimitive() throws -> Primitive {
        return chunks == nil ? .bytes(self.bytes) : .byteString(self)
    }

    /// The CBOR for these bytes: definite, or in the chunks they were read with.
    func toCBOR() -> CBOR {
        guard let chunks else { return .byteString(bytes) }
        var start = bytes.startIndex
        return .indefiniteByteString(chunks.map { width in
            defer { start += width }
            return Data(bytes[start..<start + width])
        })
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

