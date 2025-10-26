import OrderedCollections

public struct CommitteeMember: CBORSerializable, CustomStringConvertible, CustomDebugStringConvertible, Sendable {
    public let coldCredential: CommitteeColdCredential
    public let epoch: EpochNumber
    
    public var description: String { "CommitteeMember(\(coldCredential), \(epoch))" }
    
    public var debugDescription: String { self.description }
    
    public init(from primitive: Primitive) throws {
        guard case let .orderedDict(dict) = primitive, dict.count == 1 else {
            throw CardanoCoreError.deserializeError("Expected a single-entry dictionary")
        }
        
        guard let credential = dict.keys.first else {
            throw CardanoCoreError.deserializeError("Expected a single-entry dictionary")
        }
        guard let epochPrimitive = dict[credential],
              case let .int(epoch) = epochPrimitive else {
            throw CardanoCoreError.deserializeError("Expected a single-entry dictionary")
        }
        
        self.coldCredential = try CommitteeColdCredential(from: credential)
        self.epoch = EpochNumber(epoch)
    }
    
    public func toPrimitive() throws -> Primitive {
        return .orderedDict(
            OrderedDictionary<Primitive, Primitive>(uniqueKeysWithValues: [
                try self.coldCredential.toPrimitive(): .int(Int(self.epoch))
            ])
        )
    }
}

public struct Committee: Codable, Equatable, Hashable {
    public let members: [String: Int]
    public let threshold: Threshold
}

public struct Threshold: Codable, Equatable, Hashable {
    public let numerator: Int
    public let denominator: Int
}


//public struct Committee: CBORSerializable, CustomStringConvertible, CustomDebugStringConvertible, Sendable {
//    public let members: [CommitteeMember]
//    public let quorumThreshold: Fraction
//    
//    public var description: String
//    
//    public var debugDescription: String
//    
//    public init(from primitive: Primitive) throws {
//        <#code#>
//    }
//
//    public func toPrimitive() throws -> Primitive {
//        <#code#>
//    }
//}
