import Foundation

/// The payment part of an address.
public enum PaymentPart: Sendable {
    /// A payment part locked by a verification key hash.
    case verificationKeyHash(VerificationKeyHash)
    /// A payment part locked by a script hash.
    case scriptHash(ScriptHash)
    
    /// The bytes of the payment part: the 28-byte key or script hash.
    public func hash() -> Data {
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
    /// A staking part that is a stake verification key hash.
    case verificationKeyHash(VerificationKeyHash)
    /// A staking part that is a script hash.
    case scriptHash(ScriptHash)
    /// A staking part that points to a stake registration certificate.
    case pointerAddress(PointerAddress)
    
    /// The bytes of the staking part: the 28-byte key or script hash, or the
    /// encoded pointer for a pointer address.
    public func hash() -> Data {
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

/// Raw input an address can be read from: bytes or a string.
public enum AddressFromPrimitiveData {
    /// The address in binary form.
    case bytes(Data)
    /// The address as a string.
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
