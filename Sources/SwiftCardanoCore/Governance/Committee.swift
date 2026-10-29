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
        guard let epochPrimitive = dict[credential] else {
            throw CardanoCoreError.deserializeError("Expected a single-entry dictionary")
        }
        
        self.coldCredential = try CommitteeColdCredential(from: credential)
        self.epoch = try epochPrimitive.integer("CommitteeMember epoch", as: EpochNumber.self)
    }
    
    public func toPrimitive() throws -> Primitive {
        return .orderedDict(
            OrderedDictionary<Primitive, Primitive>(uniqueKeysWithValues: [
                try self.coldCredential.toPrimitive(): .integer(self.epoch)
            ])
        )
    }
}

public struct Committee: Codable, Equatable, Hashable, Sendable {
    public let members: [String: Int]
    public let threshold: Threshold
}

public struct Threshold: Codable, Equatable, Hashable, Sendable {
    public let numerator: Int
    public let denominator: Int
}
