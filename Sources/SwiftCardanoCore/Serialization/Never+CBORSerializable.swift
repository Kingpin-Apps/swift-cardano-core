import Foundation
import PotentCBOR

extension Never: CBORSerializable {
    public init(from primitive: Primitive) throws {
        // This should never be called because Never can't be instantiated
        throw CardanoCoreError.deserializeError("Cannot instantiate Never")
    }
    
    public func toPrimitive() throws -> Primitive {
        // This should never be called because Never can't be instantiated
        fatalError("Cannot convert Never to Primitive")
    }
}
