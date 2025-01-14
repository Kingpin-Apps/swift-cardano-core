import Foundation



struct InfoAction: CBORSerializable {
    let value: Int = 6
    
    func toShallowPrimitive() throws -> Any {
        return value
    }
    
    static func fromPrimitive<T>(_ value: Any) throws -> T {
        if let value = value as? Int {
            guard value == 6 else {
                throw CardanoCoreError.deserializeError("Invalid InfoAction type: \(value)")
            }
            return InfoAction() as! T
        } else {
            throw CardanoCoreError.deserializeError("Invalid InfoAction data: \(value)")
        }
    }
}
