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
    
    public init(from primitive: Primitive) throws {
        guard case let .list(elements) = primitive else {
            throw CardanoCoreError.valueError("Invalid Anchor type")
        }
        guard elements.count == 2 else {
            throw CardanoCoreError.valueError("Anchor must contain exactly 2 elements")
        }
        let urlPrimitive = elements[0]
        let dataHashPrimitive = elements[1]
        guard case let .string(urlString) = urlPrimitive,
              case let .bytes(dataHashData) = dataHashPrimitive else {
            throw CardanoCoreError.valueError("Invalid Anchor elements")
        }
        self.anchorUrl = try Url(urlString)
        self.anchorDataHash = AnchorDataHash(payload: dataHashData)
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
        let anchorDataHash = AnchorDataHash(payload: dataHashData)
        return Anchor(anchorUrl: anchorUrl, anchorDataHash: anchorDataHash)
    }
    
    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        dict[.string("anchorUrl")] = try anchorUrl.toPrimitive()
        dict[.string("anchorDataHash")] = anchorDataHash.toPrimitive()
        return .orderedDict(dict)
    }

}
