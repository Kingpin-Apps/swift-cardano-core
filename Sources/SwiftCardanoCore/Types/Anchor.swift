import Foundation
import OrderedCollections

public struct Anchor: Serializable, Sendable {
    public let anchorUrl: Url
    public let anchorDataHash: AnchorDataHash

    public init(anchorUrl: Url, anchorDataHash: AnchorDataHash) {
        self.anchorUrl = anchorUrl
        self.anchorDataHash = anchorDataHash
    }
    
    // MARK: - CBORSerializable
    
    /// `anchor = [anchor_url : url, anchor_data_hash : hash32]`.
    ///
    /// - Throws: Unless the anchor is a two-element array (of definite or
    ///   indefinite length, as the ledger reads it) holding a URL of at most
    ///   128 bytes and a 32-byte hash.
    public init(from primitive: Primitive) throws {
        let elements: [Primitive]
        switch primitive {
        case .list(let list): elements = list
        case .indefiniteList(let list): elements = list.getAll()
        default:
            throw CardanoCoreError.valueError("Invalid Anchor type")
        }
        guard elements.count == 2 else {
            throw CardanoCoreError.valueError("Anchor must contain exactly 2 elements")
        }
        guard case let .bytes(dataHashData) = elements[1] else {
            throw CardanoCoreError.valueError("Invalid Anchor elements")
        }
        self.anchorUrl = try Url(from: elements[0])
        self.anchorDataHash = try Self.checkedHash(dataHashData)
    }

    /// `hash` as an anchor's data hash, which is a `hash32`.
    static func checkedHash(_ hash: Data) throws -> AnchorDataHash {
        guard hash.count == ANCHOR_DATA_HASH_SIZE else {
            throw CardanoCoreError.deserializeError(
                "Anchor data hash must be \(ANCHOR_DATA_HASH_SIZE) bytes, got \(hash.count)")
        }
        return AnchorDataHash(payload: hash)
    }

    public func toPrimitive() throws -> Primitive {
        return .list([
            try anchorUrl.toPrimitive(),
            anchorDataHash.toPrimitive()
        ])
    }
    
    // MARK: - JSONSerializable
    
    public static func fromDict(_ dict: Primitive) throws -> Anchor {
        guard case let .orderedDict(orderedDict) = dict else {
            throw CardanoCoreError.valueError("Invalid Anchor dict format")
        }
        guard let urlPrimitive = orderedDict[.string("anchorUrl")],
              let dataHashPrimitive = orderedDict[.string("anchorDataHash")] else {
            throw CardanoCoreError.valueError("Missing required Anchor fields")
        }
        guard case let .string(urlString) = urlPrimitive,
              case let .bytes(dataHashData) = dataHashPrimitive else {
            throw CardanoCoreError.valueError("Invalid Anchor field types")
        }
        let anchorUrl = try Url(urlString)
        let anchorDataHash = try checkedHash(dataHashData)
        return Anchor(anchorUrl: anchorUrl, anchorDataHash: anchorDataHash)
    }
    
    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        dict[.string("anchorUrl")] = try anchorUrl.toPrimitive()
        dict[.string("anchorDataHash")] = anchorDataHash.toPrimitive()
        return .orderedDict(dict)
    }

}
