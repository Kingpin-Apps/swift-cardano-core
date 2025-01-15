import Foundation

struct UpdateCommittee: Codable  {
    public var code: Int { get { return 4 } }
    
    let id: GovActionID?
    let coldCredentials: Set<CommitteeColdCredential>
    let credentialEpochs: [CommitteeColdCredential: UInt64] // committee_cold_credential => epoch_no
    let interval: UnitInterval
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)
        
        guard code == 4 else {
            throw CardanoCoreError.deserializeError("Invalid UpdateCommittee type: \(code)")
        }
        
        id = try container.decode(GovActionID.self)
        coldCredentials = try Set(container.decode([CommitteeColdCredential].self))
        credentialEpochs = try container.decode([CommitteeColdCredential: UInt64].self)
        interval = try container.decode(UnitInterval.self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(code)
        try container.encode(id)
        try container.encode(coldCredentials)
        try container.encode(credentialEpochs)
        try container.encode(interval)
    }
    
//    static func fromPrimitive<T>(_ value: Any) throws -> T {
//        var code: Int
//        var id: [Any]
//        var coldCredentials: Set<AnyHashable>
//        var credentialEpochs: [CommitteeColdCredential: UInt64]
//        var interval: Data
//        
//        if let list = value as? [Any] {
//            code = list[0] as! Int
//            id = list[1] as! [Any]
//            coldCredentials = list[2] as! Set<AnyHashable>
//            credentialEpochs = list[3] as! [CommitteeColdCredential: UInt64]
//            interval = list[4] as! Data
//        } else if let tuple = value as? (Any, Any, Any, Any, Any) {
//            code = tuple.0 as! Int
//            id = tuple.1 as! [Any]
//            coldCredentials = tuple.2 as! Set<AnyHashable>
//            credentialEpochs = tuple.3 as! [CommitteeColdCredential: UInt64]
//            interval = tuple.4 as! Data
//        } else {
//            throw CardanoCoreError.deserializeError("Invalid UpdateCommittee data: \(value)")
//        }
//        
//        guard code == 4 else {
//            throw CardanoCoreError.deserializeError("Invalid UpdateCommittee type: \(code)")
//        }
//        
//        return UpdateCommittee(
//            id: try GovActionID.fromPrimitive(id),
//            coldCredentials: try Set(coldCredentials.map {
//                try CommitteeColdCredential.fromPrimitive($0)
//            }),
//            credentialEpochs: credentialEpochs,
//            interval: try UnitInterval.fromPrimitive(interval)
//        ) as! T
//    }
}
