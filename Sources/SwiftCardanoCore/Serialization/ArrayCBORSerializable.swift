import Foundation

/// A base class that can serialize its child `struct` into a (CBOR array)[https://datatracker.ietf.org/doc/html/rfc8610#section-3.4].
///
/// The class is useful when the position of each item in a list have its own semantic meaning.
protocol ArrayCBORSerializable: CBORSerializable {
    static func fromPrimitive<T>(_ value: Any) throws -> T
}

extension ArrayCBORSerializable {
    
    /// Convert the instance to a CBOR primitive. If the primitive is a container,
   /// the type of its elements could be either a Primitive or CBORSerializable.
   ///
   /// - Returns: A CBOR primitive (e.g., array).
   func toShallowPrimitive() -> Any {
       var primitives: [Any] = []
       
       let mirror = Mirror(reflecting: self)
       for child in mirror.children {
           if let label = child.label, let value = child.value as? CBORSerializable {
               primitives.append(try! value.toShallowPrimitive())
           } else if child.value is NSNull {
               continue
           } else {
               primitives.append(child.value)
           }
       }
       return primitives
   }
   
   /// Restore a primitive value to its original class type.
   ///
   /// - Parameters:
   ///   - value: A CBOR primitive (e.g., array).
   /// - Returns: Restored object.
//   static func fromPrimitive<T>(_ value: Any) throws -> T {
//       guard let array = value as? [Any] else {
//           throw CardanoException.valueError("Expected array for deserialization.")
//       }
//       
//       let instance = self.init(array)
//       let mirror = Mirror(reflecting: Self.self)
//       let children = Array(mirror.children)
//       
//       for (index, element) in array.enumerated() {
//           if index < children.count, let key = children[index].label {
//               instance.setValue(element, forKey: key)
//           } else {
//               instance.setValue(element, forKey: "unknown_field\(index - children.count)")
//           }
//       }
//       return instance as! T
//   }
   
   /// Custom description to reflect internal properties for debugging.
   var description: String {
       let mirror = Mirror(reflecting: self)
       let properties = mirror.children.map { "\($0.label ?? "?"): \($0.value)" }
       return "\(type(of: self))(\(properties.joined(separator: ", ")))"
   }
}
class BaseArrayCBORSerializable: ArrayCBORSerializable {
    required init() {}
    
    /// Restore a primitive value to its original class type.
    ///
    /// - Parameters:
    ///   - value: A CBOR primitive (e.g., array).
    /// - Returns: Restored object.
    class func fromPrimitive<T>(_ value: Any) throws -> T {
        guard let array = value as? [Any] else {
            throw CardanoCoreError.valueError("Expected array for deserialization.")
        }
        
        let instance = self.init()
        let mirror = Mirror(reflecting: Self.self)
        let children = Array(mirror.children)
        
        for (index, element) in array.enumerated() {
            if index < children.count, let key = children[index].label {
                let _ = setAttribute(instance, propertyName: key, value: element)
            } else {
                let _ = setAttribute(instance, propertyName: "unknown_field\(index - children.count)", value: element)
            }
        }
        return instance as! T
    }
}
