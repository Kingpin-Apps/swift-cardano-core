///  Era.swift
public enum Era: String, CBORSerializable, Equatable, CaseIterable, Comparable, Sendable {
    case byron
    case shelley
    case allegra
    case mary
    case alonzo
    case babbage
    case conway
    
    /// The chronological index of this era (0-based)
    public var index: Int {
        Era.allCases.firstIndex(of: self)!
    }
    
    public static func fromEpoch(epoch: EpochNumber) -> Era {
        switch epoch {
            case 0...207: return .byron
            case 208...235: return .shelley
            case 236...250: return .allegra
            case 251...289: return .mary
            case 290...364: return .alonzo
            case 365...506: return .babbage
            case 507: return .conway
            default: return .conway
        }
    }
    
    public var description: String {
        switch self {
            case .byron: return "byron"
            case .shelley: return "shelley"
            case .allegra: return "allegra"
            case .mary: return "mary"
            case .alonzo: return "alonzo"
            case .babbage: return "babbage"
            case .conway: return "conway"
        }
    }
    
    public init(from era: String) {
        switch era.lowercased() {
            case "byron":
                self = .byron
            case "shelley":
                self = .shelley
            case "allegra":
                self = .allegra
            case "mary":
                self = .mary
            case "alonzo":
                self = .alonzo
            case "babbage":
                self = .babbage
            case "conway":
                self = .conway
            default:
                self = .conway
        }
    }
    
    public init(from primitive: Primitive) throws {
        guard case let .string(eraString) = primitive,
              let era = Era(rawValue: eraString.lowercased()) else {
            throw CardanoCoreError.valueError("Invalid Era type")
        }
        self = era
    }

    public func toPrimitive() throws -> Primitive {
        return .string(self.rawValue)
    }
    
    /// Compare eras chronologically
    public static func < (lhs: Era, rhs: Era) -> Bool {
        lhs.index < rhs.index
    }
}
