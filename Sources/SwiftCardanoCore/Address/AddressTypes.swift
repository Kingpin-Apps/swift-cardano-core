import Foundation

/// The payment part of an address.
public enum PaymentPart: Sendable {
    case verificationKeyHash(VerificationKeyHash)
    case scriptHash(ScriptHash)
    
    func hash() -> Data {
        switch self {
            case .verificationKeyHash(let verificationKeyHash):
                return verificationKeyHash.payload
            case .scriptHash(let scriptHash):
                return scriptHash.payload
        }
    }
}

/// The staking part of an address.
public enum StakingPart: Sendable {
    case verificationKeyHash(VerificationKeyHash)
    case scriptHash(ScriptHash)
    case pointerAddress(PointerAddress)
    
    func hash() -> Data {
        switch self {
            case .verificationKeyHash(let verificationKeyHash):
                return verificationKeyHash.payload
            case .scriptHash(let scriptHash):
                return scriptHash.payload
            case .pointerAddress(let pointerAddress):
                return pointerAddress.encode()
        }
    }
}

public enum AddressFromPrimitiveData {
    case bytes(Data)
    case string(String)
}

/// Address type definition.
public enum AddressType: Int, Sendable  {
    
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
    public var description: String {
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
