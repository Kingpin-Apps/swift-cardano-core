import Foundation
import PotentCodables


// MARK: - ByteString
public struct ByteString: CBORSerializable, Hashable {
    public let value: Data

    public init(value: Data) {
        self.value = value
    }
    
    public init(from primitive: Primitive) throws {
        guard case let .bytes(data) = primitive else {
            throw CardanoCoreError.valueError("Invalid ByteString type")
        }
        self.init(value: data)
    }

    public func toPrimitive() throws -> Primitive {
        return .bytes(value)
    }

    public static func == (lhs: ByteString, rhs: ByteString) -> Bool {
        return lhs.value == rhs.value
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(value)
    }

    public func isEqual(to other: Any) -> Bool {
        if let otherByteString = other as? ByteString {
            return self.value == otherByteString.value
        } else if let otherData = other as? Data {
            return self.value == otherData
        } else {
            return false
        }
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
