import Foundation

func hasAttribute(_ object: Any, propertyName: String) -> Bool {
    let mirror = Mirror(reflecting: object)
    return mirror.children.contains { $0.label == propertyName }
}

func getAttribute(_ object: Any, propertyName: String) -> Any? {
    let mirror = Mirror(reflecting: object)
    for child in mirror.children {
        if child.label == propertyName {
            return child.value
        }
    }
    return nil
}
func setAttribute(_ object: Any, propertyName: String, value: Any) -> Any? {
    let mirror = Mirror(reflecting: object)
    for child in mirror.children {
        if child.label == propertyName {
            if let object = object as? NSObject {
                object.setValue(value, forKey: propertyName)
                return true
            }
        }
    }
    return false
}

//func setAttribute(_ object: AnyObject, propertyName: String, value: Any) -> Bool {
//    var mirror: Mirror? = Mirror(reflecting: object)
//    
//    while let currentMirror = mirror {
//        for child in currentMirror.children {
//            if child.label == propertyName {
//                if let object = object as? NSObject {
//                    // Use Key-Value Coding if possible
//                    object.setValue(value, forKey: propertyName)
//                    return true
//                }
//            }
//        }
//        mirror = currentMirror.superclassMirror
//    }
//    return false
//}
