import Foundation

/// A base class that can serialize its child `struct` into a (CBOR array)[https://datatracker.ietf.org/doc/html/rfc8610#section-3.4].
///
/// The class is useful when the position of each item in a list have its own semantic meaning.
protocol ArrayCBORSerializable: CBORSerializable {
    func toShallowPrimitive() -> Any
    static func fromPrimitive(_ value: Any) -> CBORSerializable
}

extension ArrayCBORSerializable {
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
