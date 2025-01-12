import Foundation

/// A base class that can serialize its child `struct`into a (CBOR Map)[https://datatracker.ietf.org/doc/html/rfc8610#section-3.5.1].
///
/// The class is useful when each key in a map have its own semantic meaning.
protocol MapCBORSerializable: CBORSerializable {
    func toShallowPrimitive() throws -> Any
    static func fromPrimitive<T>(_ value: Any) throws -> T
}

extension MapCBORSerializable {
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
