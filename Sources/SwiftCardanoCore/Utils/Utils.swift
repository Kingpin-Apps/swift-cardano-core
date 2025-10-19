//import Foundation
//
///// Cross-platform implementation of isSubclass functionality
///// Uses instance creation and casting instead of Objective-C runtime for Linux compatibility
///// - Parameters:
/////   - subclass: The potential subclass to check
/////   - superclass: The potential superclass to check against
///// - Returns: true if subclass is a subclass of superclass, false otherwise
//public func isSubclassOf(_ subclass: AnyClass, _ superclass: AnyClass) -> Bool {
//    // Direct equality check
//    if subclass == superclass {
//        return true
//    }
//    
//    // For PlutusData inheritance checking, we need to be more thorough
//    if superclass == PlutusData.self {
//        // Try to create an instance and check if it can be cast to PlutusData
//        // This is safe because PlutusData has a required init()
//        if let plutusDataType = subclass as? PlutusData.Type {
//            let _ = plutusDataType.init()
//            return true
//        }
//    }
//    
//    // Use string-based comparison for general inheritance checking
//    let subclassName = String(describing: subclass)
//    let superclassName = String(describing: superclass)
//    
//    // Handle common inheritance patterns by checking if subclass name contains superclass name
//    if subclassName.contains(superclassName) {
//        return true
//    }
//    
//    // For most Foundation/Swift types in our validTypes array, they are concrete types
//    // that don't typically have subclasses, so this fallback is sufficient
//    return false
//}
//
//
//func hasAttribute(_ object: Any, propertyName: String) -> Bool {
//    let mirror = Mirror(reflecting: object)
//    return mirror.children.contains { $0.label == propertyName }
//}
//
//func getAttribute(_ object: Any, propertyName: String) -> Any? {
//    let mirror = Mirror(reflecting: object)
//    for child in mirror.children {
//        if child.label == propertyName {
//            return child.value
//        }
//    }
//    return nil
//}
//
//func isArray(_ obj: Any) -> Bool {
//    return Mirror(reflecting: obj).displayStyle == .collection
//}
//
//func isDictionary(_ obj: Any) -> Bool {
//    return Mirror(reflecting: obj).displayStyle == .dictionary
//}
//
//func isEnum<T>(_ value: T) -> Bool {
//    let mirror = Mirror(reflecting: value)
//    
//    if mirror.displayStyle == .optional {
//        if let child = mirror.children.first {
//            return Mirror(reflecting: child.value).displayStyle == .enum
//        } else {
//            return false
//        }
//    } else {
//        return mirror.displayStyle == .enum
//    }
//}
//
//func extractEnumInfo<T>(_ value: T) -> (caseName: String, associatedValue: Any)? {
//    let mirror = Mirror(reflecting: value)
//    
//    let targetMirror: Mirror
//    if mirror.displayStyle == .optional {
//        guard let unwrapped = mirror.children.first?.value else { return nil }
//        targetMirror = Mirror(reflecting: unwrapped)
//    } else {
//        targetMirror = mirror
//    }
//    
//    guard targetMirror.displayStyle == .enum else { return nil }
//    
//    let caseName = targetMirror.children.first?.label ?? String(describing: value)
//    let associatedValue = targetMirror.children.first?.value
//    
//    return associatedValue.map { (caseName, $0) }
//}
////func setAttribute(_ object: AnyObject, propertyName: String, value: Any) -> Bool {
////    var mirror: Mirror? = Mirror(reflecting: object)
////
////    while let currentMirror = mirror {
////        for child in currentMirror.children {
////            if child.label == propertyName {
////                if let object = object as? NSObject {
////                    // Use Key-Value Coding if possible
////                    object.setValue(value, forKey: propertyName)
////                    return true
////                }
////            }
////        }
////        mirror = currentMirror.superclassMirror
////    }
////    return false
////}
