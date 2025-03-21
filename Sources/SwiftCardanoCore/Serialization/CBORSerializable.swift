import Foundation
import PotentCBOR

public protocol CBORSerializable: Codable {
    func toCBOR() throws -> Data
    func toCBORHex() throws -> String
    static func fromCBOR(data: Data) throws -> Self
}

extension CBORSerializable {
    public func toCBOR() throws -> Data {
        return try CBOREncoder().encode(self)
    }
    
    public func toCBORHex() throws -> String {
        return try toCBOR().toHexString()
    }
    
    public static func fromCBOR(data: Data) throws -> Self {
        return try CBORDecoder().decode(Self.self, from: data)
    }

}
