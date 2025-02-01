import Foundation



struct InfoAction: Codable {
    let value: Int = 6
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let code = try container.decode(Int.self)
        
        guard code == 6 else {
            throw CardanoCoreError.deserializeError("Invalid InfoAction type: \(code)")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(value)
    }
    
//    func toShallowPrimitive() throws -> Any {
//        return value
//    }
//    
//    static func fromPrimitive<T>(_ value: Any) throws -> T {
//        if let value = value as? Int {
//            guard value == 6 else {
//                throw CardanoCoreError.deserializeError("Invalid InfoAction type: \(value)")
//            }
//            return InfoAction() as! T
//        } else {
//            throw CardanoCoreError.deserializeError("Invalid InfoAction data: \(value)")
//        }
//    }
}
