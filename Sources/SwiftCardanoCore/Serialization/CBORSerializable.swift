import Foundation
import PotentCBOR

/// CBORSerializable standardizes the interfaces a class should implement in order for it to be serialized to and deserialized from CBOR.
///
/// Two required interfaces to implement are `to_primitive` and `from_primitive`.
/// `to_primitive` converts an object to a CBOR primitive type (see `Primitive`), which could be then
/// encoded by CBOR library. `from_primitive` restores an object from a CBOR primitive type.
/// To convert a CBORSerializable to CBOR, use `to_cbor`.
/// To restore a CBORSerializable from CBOR, use `from_cbor`.
///
/// #### Note
/// `to_primitive` needs to return a pure CBOR primitive type, meaning that the returned value and all its
/// child elements have to be CBOR primitives, which could mean a good amount of work. An alternative but simpler
/// approach is to implement `to_shallow_primitive` instead. `to_shallow_primitive` allows the returned object
/// to be either CBOR `Primitive` or a `CBORSerializable`, as long as the `CBORSerializable`
/// does not refer to itself, which could cause infinite loops.
protocol CBORSerializable {
    func toShallowPrimitive() -> Any
    static func fromPrimitive<T>(_ value: Any) throws -> T
}

extension CBORSerializable {
    /// Convert the instance to a CBOR primitive. If the primitive is a container, e.g. list, dict, the type of
    /// its elements could be either a Primitive or a CBORSerializable.
    /// - Returns:  A CBOR primitive.
//    func toShallowPrimitive() -> Any {
//        fatalError("'to_shallow_primitive()' is not implemented by \(type(of: self))")
//    }
    
    /// Convert the instance and its elements to CBOR primitives recursively.
    /// - Returns: A CBOR primitive.
    func toPrimitive() -> Any {
        let result = toShallowPrimitive()
        return result
    }
    
    /// Turn a CBOR primitive to its original class type.
    /// - Parameter value: A CBOR primitive.
    /// - Returns:  A CBOR serializable object.
//    static func fromPrimitive(_ value: Any) -> CBORSerializable {
//        fatalError("This method must be overridden")
//    }
    
    /// Encode a Python object into CBOR bytes.
    /// - Returns: Swift object encoded in cbor bytes.
    func toCBOR() throws -> Data {
        return try CBORSerialization.data(
            from: CBOR.fromAny(toPrimitive())
        )
    }
    
    /// Encode a Python object into CBOR hex.
    /// - Returns: Swift object encoded in cbor hex string.
    func toCBORHex() throws -> String? {
        let cbor = try toCBOR()
        return cbor.toHex
    }
    
    /// Restore a CBORSerializable object from a CBOR.
    /// - Parameter cbor: CBOR bytes or hex string to restore from.
    /// - Returns: Restored CBORSerializable object.
    static func fromCBOR(_ cbor: Data) throws -> Self? {
        let cborData =  try CBORSerialization.cbor(from: cbor)
        return try Self.fromPrimitive(cborData.unwrapped!)
    }
}
