import Foundation

public struct Url: CBORSerializable, Hashable {
    public let value: URL

    public var absoluteString: String {
        return value.absoluteString
    }

    public init(_ value: String) throws {
        guard value.count <= 128 else {
            throw CardanoCoreError.valueError("URL exceeds the maximum length of 128 characters.")
        }

        guard let url = URL(string: value) else {
            throw CardanoCoreError.valueError("Invalid URL format: \(value)")
        }

        self.value = url
    }
    
    public init(from primitive: Primitive) throws {
        guard case let .string(urlString) = primitive else {
            throw CardanoCoreError.valueError("Invalid Url type")
        }
        try self.init(urlString)
    }

    public func toPrimitive() throws -> Primitive {
        return .string(value.absoluteString)
    }
}
