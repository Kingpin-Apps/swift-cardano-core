import Foundation

public struct ProtocolVersion: CBORSerializable, Sendable {
    public var major: Int?
    public var minor: Int?

    public init(major: Int, minor: Int) {
        self.major = major
        self.minor = minor
    }

    public init(from decoder: Decoder) throws {
        // protocol_version = [major_protocol_version, uint .size 4]
        var container = try decoder.unkeyedContainer()
        major = Int(exactly: try container.decode(UInt32.self))
        minor = Int(exactly: try container.decode(UInt32.self))
        guard major != nil, minor != nil else {
            throw CardanoCoreError.valueError("ProtocolVersion is out of range for Int")
        }
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

        // protocol_version = [major_protocol_version, uint .size 4]. The major
        // version is only range-checked as a uint here, so a later era's
        // major version still decodes.
        let major = try elements[0].integer("ProtocolVersion major", as: Int.self)
        let minor = try elements[1].integer("ProtocolVersion minor", as: Int.self)
        guard UInt32(exactly: major) != nil, UInt32(exactly: minor) != nil else {
            throw CardanoCoreError.valueError("ProtocolVersion [\(major), \(minor)] is out of range")
        }

        self.init(major: major, minor: minor)
    }

    public func toPrimitive() throws -> Primitive {
        return .list([
            .int(Int64(major ?? 0)),
            .int(Int64(minor ?? 0))
        ])
    }

}
