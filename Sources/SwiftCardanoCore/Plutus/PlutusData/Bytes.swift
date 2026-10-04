import Foundation
import OrderedCollections


public enum Bytes: Serializable, CustomStringConvertible, Sendable {
    case boundedBytes(BoundedBytes)
    case byteString(ByteString)
    
    public var description: String {
        switch self {
            case .boundedBytes(let b): return "BoundedBytes(size: \(b.bytes.count))"
            case .byteString(let b): return "ByteString(size: \(b.bytes.count))"
        }
    }
    
    public var data : Data {
        switch self {
            case .boundedBytes(let b):
                return b.bytes
            case .byteString(let b):
                return b.bytes
        }
    }
    
    public var count : Int {
        switch self {
            case .boundedBytes(let boundedBytes):
                return boundedBytes.bytes.count
            case .byteString(let byteString):
                return byteString.bytes.count
        }
    }
    
    public init(from data: Data) throws {
        if data.count > 64 {
            self = .byteString(ByteString(bytes: data))
        } else {
            self = .boundedBytes(try BoundedBytes(bytes: data))
        }
    }
    
    /// Convenience initializer for unsigned magnitude bytes.
    public init(from boundedBytes: BoundedBytes) throws {
        self = .boundedBytes(boundedBytes)
    }
    
    /// Convenience initializer for unsigned magnitude bytes.
    public init(from byteString: ByteString) throws {
        self = .byteString(byteString)
    }
    
    // MARK: - CBORSerializable
    
    public init(from primitive: Primitive) throws {
        switch primitive {
            case .string(let stringValue):
                let byteString = try ByteString(from: .bytes(stringValue.toData))
                self = .byteString(byteString)
            case .byteString(let byteString):
                self = .byteString(byteString)
            case .bytes(let data):
                if data.count > 64 {
                    let byteString = try ByteString(from: primitive)
                    self = .byteString(byteString)
                } else {
                    let boundedBytes = try BoundedBytes(from: primitive)
                    self = .boundedBytes(boundedBytes)
                }
            default:
                throw CardanoCoreError.deserializeError("Invalid Bytes type: \(primitive)")
        }
    }
    
    public func toPrimitive() throws -> Primitive {
        switch self {
            case .boundedBytes(let boundedBytes):
                return try boundedBytes.toPrimitive()
            case .byteString(let byteString):
                // Plutus data caps a byte string at 64 bytes; longer ones are
                // written as an indefinite-length string of 64-byte chunks, as
                // the ledger, cardano-cli and Aiken all write them.
                guard byteString.bytes.count > 64 else { return try byteString.toPrimitive() }
                let bytes = byteString.bytes
                let chunks = stride(from: bytes.startIndex, to: bytes.endIndex, by: 64).map {
                    Data(bytes[$0..<min($0 + 64, bytes.endIndex)])
                }
                return .cborSimpleValue(.indefiniteByteString(chunks))
        }
    }
    
    // MARK: - JSONSerializable
    
    public static func fromDict(_ dict: Primitive) throws -> Bytes {
        guard case let .orderedDict(dictValue) = dict,
              case let .string(bytes) = dictValue[.string("bytes")] else {
            throw CardanoCoreError.deserializeError("Invalid Bytes type in JSON dictionary")
        }
        return try Bytes(from: bytes.hexStringToData)
    }
    
    public func toDict() throws -> Primitive {
        switch self {
            case .boundedBytes(let boundedBytes):
                return .orderedDict([.string("bytes"): .string(boundedBytes.toHex)])
            case .byteString(let byteString):
                return .orderedDict([.string("bytes"): .string(byteString.toHex)])
        }
    }
}
