import Foundation
import CBORCodable
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

    public static var preservesEncoding: Bool { true }
    
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
                return try Bytes.chunked(byteString).toPrimitive()
        }
    }
    
    /// `byteString` as Plutus data writes it. Bytes read in chunks keep the
    /// chunks they were read with: the ledger caps each chunk at 64 bytes, not
    /// at exactly 64, so re-chunking them would change the encoding. Bytes
    /// built in code are written in 64-byte chunks when longer than 64, as
    /// the ledger, cardano-cli and Aiken all write them, and definite
    /// otherwise.
    static func chunked(_ byteString: ByteString) -> ByteString {
        guard byteString.chunks == nil, byteString.bytes.count > 64 else { return byteString }
        let bytes = byteString.bytes
        return ByteString(chunks: stride(from: bytes.startIndex, to: bytes.endIndex, by: 64).map {
            Data(bytes[$0..<min($0 + 64, bytes.endIndex)])
        })
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

// MARK: - Long bytes in untyped Plutus data

extension Primitive {
    /// This value with every byte string over 64 bytes that was not read in
    /// chunks written in 64-byte chunks, at every depth.
    ///
    /// Plutus data refuses a definite-length byte string over 64 bytes, so
    /// untyped Plutus data built in code has to be chunked the way ``Bytes``
    /// chunks typed data. Byte strings that were read in chunks keep them.
    func chunkingLongBytes() throws -> Primitive {
        switch self {
        case .bytes(let data) where data.count > 64:
            return .byteString(Bytes.chunked(ByteString(bytes: data)))
        case .byteString(let byteString):
            return .byteString(Bytes.chunked(byteString))
        case .list(let list):
            return .list(try list.map { try $0.chunkingLongBytes() })
        case .indefiniteList(let list):
            return .indefiniteList(IndefiniteList(try list.map { try $0.chunkingLongBytes() }))
        case .orderedDict(let dict):
            var result = OrderedDictionary<Primitive, Primitive>()
            for (key, value) in dict {
                result[try key.chunkingLongBytes()] = try value.chunkingLongBytes()
            }
            return .orderedDict(result)
        case .indefiniteDictionary(let dict):
            var result = OrderedDictionary<Primitive, Primitive>()
            for (key, value) in dict {
                result[try key.chunkingLongBytes()] = try value.chunkingLongBytes()
            }
            return .indefiniteDictionary(result)
        case .dict(let dict):
            var result: [Primitive: Primitive] = [:]
            for (key, value) in dict {
                result[try key.chunkingLongBytes()] = try value.chunkingLongBytes()
            }
            return .dict(result)
        case .cborTag(let tag):
            return .cborTag(CBORTag(tag: tag.tag, value: try tag.value.chunkingLongBytes()))
        case .cborSimpleValue(let cbor):
            return .cborSimpleValue(cbor.chunkingLongBytes())
        default:
            return self
        }
    }
}

extension CBOR {
    /// See ``Primitive/chunkingLongBytes()``.
    func chunkingLongBytes() -> CBOR {
        switch self {
        case .byteString(let data) where data.count > 64:
            return Bytes.chunked(ByteString(bytes: data)).toCBOR()
        case .array(let items):
            return .array(items.map { $0.chunkingLongBytes() })
        case .indefiniteArray(let items):
            return .indefiniteArray(items.map { $0.chunkingLongBytes() })
        case .map(let map):
            return .map(CBOR.chunkingLongBytes(map))
        case .indefiniteMap(let map):
            return .indefiniteMap(CBOR.chunkingLongBytes(map))
        case .tagged(let tag, let value):
            return .tagged(tag, value.chunkingLongBytes())
        default:
            return self
        }
    }

    private static func chunkingLongBytes(
        _ map: OrderedDictionary<CBOR, CBOR>
    ) -> OrderedDictionary<CBOR, CBOR> {
        var result = OrderedDictionary<CBOR, CBOR>()
        for (key, value) in map {
            result[key.chunkingLongBytes()] = value.chunkingLongBytes()
        }
        return result
    }
}
