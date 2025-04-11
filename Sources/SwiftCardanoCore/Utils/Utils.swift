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

func isArray(_ obj: Any) -> Bool {
    return Mirror(reflecting: obj).displayStyle == .collection
}

func isDictionary(_ obj: Any) -> Bool {
    return Mirror(reflecting: obj).displayStyle == .dictionary
}

func isEnum<T>(_ value: T) -> Bool {
    let mirror = Mirror(reflecting: value)
    
    if mirror.displayStyle == .optional {
        if let child = mirror.children.first {
            return Mirror(reflecting: child.value).displayStyle == .enum
        } else {
            return false
        }
    } else {
        return mirror.displayStyle == .enum
    }
}

func extractEnumInfo<T>(_ value: T) -> (caseName: String, associatedValue: Any)? {
    let mirror = Mirror(reflecting: value)
    
    let targetMirror: Mirror
    if mirror.displayStyle == .optional {
        guard let unwrapped = mirror.children.first?.value else { return nil }
        targetMirror = Mirror(reflecting: unwrapped)
    } else {
        targetMirror = mirror
    }
    
    guard targetMirror.displayStyle == .enum else { return nil }
    
    let caseName = targetMirror.children.first?.label ?? String(describing: value)
    let associatedValue = targetMirror.children.first?.value
    
    return associatedValue.map { (caseName, $0) }
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
