import Foundation

public struct ProtocolVersion: CBORSerializable, Hashable, Equatable {
    public var major: Int?
    public var minor: Int?

    public init(major: Int, minor: Int) {
        self.major = major
        self.minor = minor
    }

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        major = try container.decode(Int.self)
        minor = try container.decode(Int.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(major)
        try container.encode(minor)
    }
    
    public init(from primitive: Primitive) throws {
        guard case let .list(elements) = primitive else {
            throw CardanoCoreError.valueError("Invalid ProtocolVersion type")
        }
        
        guard elements.count == 2 else {
            throw CardanoCoreError.valueError("ProtocolVersion must contain exactly 2 elements")
        }
        guard case let .int(major) = elements[0],
              case let .int(minor) = elements[1] else {
            throw CardanoCoreError.valueError("Invalid ProtocolVersion element types")
        }
        self.init(
            major: Int(major),
            minor: Int(minor)
        )
    }

    public func toPrimitive() throws -> Primitive {
        return .list([
            .int(major ?? 0),
            .int(minor ?? 0)
        ])
    }

}
