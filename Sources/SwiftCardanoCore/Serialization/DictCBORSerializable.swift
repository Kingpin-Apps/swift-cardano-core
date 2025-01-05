import Foundation

/// A dictionary class where all keys share the same type and all values share the same type.
protocol DictCBORSerializable: CBORSerializable {
    func toShallowPrimitive() -> Any
    static func fromPrimitive(_ value: Any) -> CBORSerializable
}

extension DictCBORSerializable {
    /// Convert the instance to a CBOR primitive. If the primitive is a container, e.g. list, dict, the type of
    /// its elements could be either a Primitive or a CBORSerializable.
    /// - Returns:  A CBOR primitive.
    func toShallowPrimitive() -> Any {
        fatalError("'to_shallow_primitive()' is not implemented by \(type(of: self))")
    }
    
    /// Turn a CBOR primitive to its original class type.
    /// - Parameter value: A CBOR primitive.
    /// - Returns:  A CBOR serializable object.
    static func fromPrimitive(_ value: Any) -> CBORSerializable {
        fatalError("This method must be overridden")
    }
}
