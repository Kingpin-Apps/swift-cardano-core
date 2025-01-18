import Foundation

enum PaymentPart: Sendable {
    case verificationKeyHash(VerificationKeyHash)
    case scriptHash(ScriptHash)
}

enum StakingPart: Sendable {
    case verificationKeyHash(VerificationKeyHash)
    case scriptHash(ScriptHash)
    case pointerAddress(PointerAddress)
}

enum AddressFromPrimitiveData {
    case bytes(Data)
    case string(String)
}

/// Address type definition.
enum AddressType: Int {
    
    /// Byron address
    case byron = 0b1000
    
    /// Payment key hash + Stake key hash
    case keyKey = 0b0000
    
    /// Script hash + Stake key hash
    case scriptKey = 0b0001
    
    /// Payment key hash + Script hash
    case keyScript = 0b0010
    
    /// Script hash + Script hash
    case scriptScript = 0b0011
    
    /// Payment key hash + Pointer address
    case keyPointer = 0b0100
    
    /// Script hash + Pointer address
    case scriptPointer = 0b0101
    
    /// Payment key hash only
    case keyNone = 0b0110
    
    /// Script hash for payment part only
    case scriptNone = 0b0111
    
    /// Stake key hash for stake part only
    case noneKey = 0b1110
    
    /// Script hash for stake part only
    case noneScript = 0b1111
}

extension AddressType: CustomStringConvertible {
    var description: String {
        switch self {
        case .byron:
            return "byron"
        case .keyKey:
            return "keyKey"
        case .scriptKey:
            return "scriptKey"
        case .keyScript:
            return "keyScript"
        case .scriptScript:
            return "scriptScript"
        case .keyPointer:
            return "keyPointer"
        case .scriptPointer:
            return "scriptPointer"
        case .keyNone:
            return "keyNone"
        case .scriptNone:
            return "scriptNone"
        case .noneKey:
            return "noneKey"
        case .noneScript:
            return "noneScript"
        }
    }
}
