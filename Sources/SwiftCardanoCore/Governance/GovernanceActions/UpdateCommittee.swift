import Foundation

struct UpdateCommittee: GovernanceAction {
    static var code: GovActionCode { get { .updateCommittee } }
    
    let id: GovActionID?
    let coldCredentials: Set<CommitteeColdCredential>
    let credentialEpochs: [CommitteeColdCredential: UInt64] // committee_cold_credential => epoch_no
    let interval: UnitInterval
    
    init(id: GovActionID?, coldCredentials: Set<CommitteeColdCredential>, credentialEpochs: [CommitteeColdCredential: UInt64], interval: UnitInterval) {
        self.id = id
        self.coldCredentials = coldCredentials
        self.credentialEpochs = credentialEpochs
        self.interval = interval
    }
    
    init(from decoder: Decoder) throws {
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
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(Self.code)
        try container.encode(id)
        try container.encode(coldCredentials)
        try container.encode(credentialEpochs)
        try container.encode(interval)
    }
}
