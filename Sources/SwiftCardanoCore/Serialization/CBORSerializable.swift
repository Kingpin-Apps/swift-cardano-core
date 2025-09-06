import Foundation
import PotentCBOR

public protocol CBORSerializable: Codable, Hashable {
    init(from primitive: Primitive) throws
    func toPrimitive() throws -> Primitive
    func toCBORData(deterministic: Bool) throws -> Data
    func toCBORHex(deterministic: Bool) throws -> String
    static func fromCBOR(data: Data) throws -> Self
}

extension CBORSerializable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let primitive = try container.decode(Primitive.self)
        try self.init(from: primitive)
    }
    
    public init(from cbor: Data) throws {
        self = try CBORDecoder().decode(Self.self, from: cbor)
    }
    
    public func encode(to encoder: Swift.Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(try toPrimitive())
    }
    
    public func toCBORData(deterministic: Bool = false) throws -> Data {
        let cborEncoder = CBOREncoder()
        cborEncoder.deterministic = deterministic
        return try cborEncoder.encode(self)
    }
    
    public func toCBORHex(deterministic: Bool = false) throws -> String {
        return try toCBORData(deterministic: deterministic).toHex
    }
    
    public static func fromCBOR(data: Data) throws -> Self {
        return try CBORDecoder().decode(Self.self, from: data)
    }
    
    public static func fromCBORHex(_ hexString: String) throws -> Self {
        guard let data = Data(hexString: hexString) else {
            throw CardanoCoreError.invalidArgument("Invalid hex string: \(hexString)")
        }
        return try fromCBOR(data: data)
    }

}
