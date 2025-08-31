import Foundation

public struct UpdateCommittee: GovernanceAction {
    public static var code: GovActionCode { get { .updateCommittee } }
    
    public let id: GovActionID?
    public let coldCredentials: Set<CommitteeColdCredential>
    public let credentialEpochs: [CommitteeColdCredential: UInt64] // committee_cold_credential => epoch_no
    public let interval: UnitInterval
    
    public init(id: GovActionID?, coldCredentials: Set<CommitteeColdCredential>, credentialEpochs: [CommitteeColdCredential: UInt64], interval: UnitInterval) {
        self.id = id
        self.coldCredentials = coldCredentials
        self.credentialEpochs = credentialEpochs
        self.interval = interval
    }
    
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)
        
        guard code == Self.code.rawValue else {
            throw CardanoCoreError.deserializeError("Invalid UpdateCommittee type: \(code)")
        }
        
        id = try container.decode(GovActionID.self)
        coldCredentials = try Set(container.decode([CommitteeColdCredential].self))
        credentialEpochs = try container.decode([CommitteeColdCredential: UInt64].self)
        interval = try container.decode(UnitInterval.self)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(Self.code)
        try container.encode(id)
        try container.encode(coldCredentials)
        try container.encode(credentialEpochs)
        try container.encode(interval)
    }
    
    public init(from primitive: Primitive) throws {
        guard case let .list(elements) = primitive,
              elements.count == 5,
              case let .int(code) = elements[0],
              code == Self.code.rawValue else {
            throw CardanoCoreError.deserializeError("Invalid UpdateCommittee primitive")
        }
        
        // Parse optional id
        if elements[1] == .null {
            self.id = nil
        } else {
            self.id = try GovActionID(from: elements[1])
        }
        
        // Parse coldCredentials set
        guard case let .list(credentialsList) = elements[2] else {
            throw CardanoCoreError.deserializeError("Invalid coldCredentials in UpdateCommittee")
        }
        
        var coldCredentials: Set<CommitteeColdCredential> = []
        for credentialPrimitive in credentialsList {
            let credential = try CommitteeColdCredential(from: credentialPrimitive)
            coldCredentials.insert(credential)
        }
        self.coldCredentials = coldCredentials
        
        // Parse credentialEpochs dictionary
        guard case let .dict(credentialEpochsDict) = elements[3] else {
            throw CardanoCoreError.deserializeError("Invalid credentialEpochs in UpdateCommittee")
        }
        
        var credentialEpochs: [CommitteeColdCredential: UInt64] = [:]
        for (keyPrimitive, valuePrimitive) in credentialEpochsDict {
            let credential = try CommitteeColdCredential(from: keyPrimitive)
            guard case let .int(epochValue) = valuePrimitive else {
                throw CardanoCoreError.deserializeError("Invalid epoch value in credentialEpochs")
            }
            credentialEpochs[credential] = UInt64(epochValue)
        }
        self.credentialEpochs = credentialEpochs
        
        // Parse interval
        self.interval = try UnitInterval(from: elements[4])
    }
    
    public func toPrimitive() throws -> Primitive {
        // Convert coldCredentials set to list
        let credentialsList = try coldCredentials.map { try $0.toPrimitive() }
        
        // Convert credentialEpochs dictionary to primitive
        var credentialEpochsDict: [Primitive: Primitive] = [:]
        for (credential, epoch) in credentialEpochs {
            credentialEpochsDict[try credential.toPrimitive()] = .int(Int(epoch))
        }
        
        return .list([
            .int(Self.code.rawValue),
            try id?.toPrimitive() ?? .null,
            .list(credentialsList),
            .dict(credentialEpochsDict),
            try interval.toPrimitive()
        ])
    }
}
