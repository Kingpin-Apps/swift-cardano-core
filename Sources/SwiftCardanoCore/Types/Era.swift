///  Era.swift
public enum Era: String, CBORSerializable, Equatable, CaseIterable, Sendable {
    case byron
    case shelley
    case allegra
    case mary
    case alonzo
    case babbage
    case conway
    
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
