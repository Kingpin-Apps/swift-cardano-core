import Foundation
import PotentCBOR

public protocol Payloadable {
    var _payload: Data { get set }
    var _type: String { get set }
    var _description: String { get set }
}

public extension Payloadable {
    var payload: Data { get { return _payload } }
    var type: String { get { return _type } }
    var description: String { get { return _description } }
}

public protocol PayloadSerializable: Payloadable, CBORSerializable, Sendable {
    static var TYPE: String { get }
    static var DESCRIPTION: String { get }
    
    init(payload: Data, type: String?, description: String?) throws
}

public extension PayloadSerializable {
    init(payload: Data) throws {
        try self.init(payload: payload, type: Self.TYPE, description: Self.DESCRIPTION)
    }
    
    /// Convert to raw bytes
    /// - Returns: The raw bytes
    func toBytes() -> Data {
        return payload
    }
    
    // Equality check
    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.payload == rhs.payload &&
               lhs.description == rhs.description && lhs.type == rhs.type
    }
    
    /// Hash the object.
    /// - Parameter hasher: The hasher.
    func hash(into hasher: inout Hasher) {
        hasher.combine(payload)
    }
}
