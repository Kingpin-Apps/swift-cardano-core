import Foundation

public struct Anchor: CBORSerializable, Hashable {

    public let anchorUrl: Url
    public let anchorDataHash: AnchorDataHash

    public init(anchorUrl: Url, anchorDataHash: AnchorDataHash) {
        self.anchorUrl = anchorUrl
        self.anchorDataHash = anchorDataHash
    }

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let url = try container.decode(String.self)
        let dataHash = try container.decode(Data.self)

        self.anchorUrl = try Url(url)
        self.anchorDataHash = AnchorDataHash(payload: dataHash)
    }
    
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

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(anchorUrl.value.absoluteString)
        try container.encode(anchorDataHash.payload)
    }
}
