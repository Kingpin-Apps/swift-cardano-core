///  Era.swift
public enum Era: String, CBORSerializable, Equatable, CaseIterable, Sendable {
    case byron
    case shelley
    case allegra
    case mary
    case alonzo
    case babbage
    case conway
    
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

}
