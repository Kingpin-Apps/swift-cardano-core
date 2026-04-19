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
    
    /// Get the era corresponding to a given epoch number
    /// - Parameter epoch: The epoch number to determine the era for
    /// - Returns: The era corresponding to the given epoch number
    /// - Note: The epoch ranges are based on the Cardano roadmap and may need to be updated as new eras are introduced
    /// - Byron: Epochs 0-207
    /// - Shelley: Epochs 208-235
    /// - Allegra: Epochs 236-250
    /// - Mary: Epochs 251-289
    /// - Alonzo: Epochs 290-364
    /// - Babbage: Epochs 365-506
    /// - Conway: Epochs 507 and beyond
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
    
    /// A textual description of the era
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
    
    /// Initialize an era from a string representation
    /// - Parameter era: The string representation of the era
    /// - Note: The string is case-insensitive and defaults to "conway" if the input does not match any known era
    /// - Example: `Era(from: "shelley")` will initialize the `shelley` era
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
    
    /// Initialize an era from a wire tag (UInt16)
    /// - Parameter wireTag: The wire tag to initialize from
    /// - Note: The wire tag is expected to be a UInt16 value corresponding to the index of the era in the `allCases` array. If the wire tag is out of bounds, the initializer will return nil.
    public init?(from wireTag: UInt16) {
        guard Int(wireTag) < Era.allCases.count else { return nil }
        self = Era.allCases[Int(wireTag)]
    }
    
    /// Convert the era to a wire tag (UInt16) for serialization
    /// - Returns: The wire tag corresponding to the era
    /// - Throws: An error if the era cannot be converted to a wire tag (e.g., if the era is not found in the `allCases` array, which should not happen since all cases are defined)
    public func toWireTag() throws -> UInt16 {
        guard let index = Era.allCases.firstIndex(of: self) else {
            throw CardanoCoreError.valueError("Invalid Era: \(self)")
        }
        return UInt16(index)
    }
    
    /// Initialize an era from a CBOR primitive representation
    /// - Parameter primitive: The CBOR primitive to initialize from
    /// - Throws: An error if the primitive is not a valid string representation of an era
    public init(from primitive: Primitive) throws {
        guard case let .string(eraString) = primitive,
              let era = Era(rawValue: eraString.lowercased()) else {
            throw CardanoCoreError.valueError("Invalid Era type")
        }
        self = era
    }

    /// Convert the era to a CBOR primitive representation
    /// - Returns: A CBOR primitive representing the era as a string
    public func toPrimitive() throws -> Primitive {
        return .string(self.rawValue)
    }
    
    /// Compare eras chronologically
    public static func < (lhs: Era, rhs: Era) -> Bool {
        lhs.index < rhs.index
    }
}
