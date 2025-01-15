import Foundation

enum Vote: Int, Codable {
    case no = 0
    case yes = 1
    case abstain = 2
    
//    func toShallowPrimitive() throws -> Any {
//        self.rawValue
//    }
//
//    static func fromPrimitive<T>(_ value: Any) throws -> T {
//        return Vote(rawValue: value as! Int) as! T
//    }
}

enum VoterType: Codable, Hashable {
    case constitutionalCommitteeHotKeyhash(AddressKeyHash)
    case constitutionalCommitteeHotScriptHash(ScriptHash)
    case drepKeyhash(AddressKeyHash)
    case drepScriptHash(ScriptHash)
    case stakePoolKeyhash(AddressKeyHash)
}

struct VotingProcedure: Codable {
    let vote: Vote
    let anchor: Anchor?
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        vote = try container.decode(Vote.self)
        anchor = try container.decode(Anchor.self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(vote)
        try container.encode(anchor)
    }

    
//    static func fromPrimitive<T>(_ value: Any) throws -> T {
//        guard let list = value as? [Any], list.count == 2 else {
//            throw CardanoCoreError.deserializeError("Invalid VotingProcedure data: \(value)")
//        }
//        
//        let vote: Vote = try Vote.fromPrimitive(list[0])
//        let anchor: Anchor = try Anchor.fromPrimitive(list[1])
//        
//        return VotingProcedure(vote: vote, anchor: anchor) as! T
//    }
}

struct VotingProcedures: Codable {
    let procedures: [Voter: [GovActionID: VotingProcedure]]
    
    init(from decoder: Decoder) throws {
        var container = try decoder.singleValueContainer()
        procedures = try container.decode([Voter: [GovActionID: VotingProcedure]].self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(procedures)
    }
    
//    static func fromPrimitive<T>(_ value: Any) throws -> T {
//        guard let dict = value as? [Voter: [GovActionID: VotingProcedure]] else {
//            throw CardanoCoreError.deserializeError("Invalid VotingProcedures data: \(value)")
//        }
//        
//        return VotingProcedures(procedures: dict) as! T
//    }
}

struct Voter: Codable, Hashable {
    public var code: Int {
        get {
            switch credential {
                case .constitutionalCommitteeHotKeyhash(_):
                    return 0
                case .constitutionalCommitteeHotScriptHash(_):
                    return 1
                case .drepKeyhash(_):
                    return 2
                case .drepScriptHash(_):
                    return 3
                case .stakePoolKeyhash(_):
                    return 4
            }
        }
    }
    let credential: VoterType
    
    static func fromPrimitive<T>(_ value: Any) throws -> T {
        var code: Int
        var payload: Data
        var credential: VoterType
        
        if let list = value as? [Any] {
            code = list[0] as! Int
            payload = list[1] as! Data
        } else if let tuple = value as? (Any, Any) {
            code = tuple.0 as! Int
            payload = tuple.1 as! Data
        } else {
            throw CardanoCoreError.deserializeError("Invalid Voter data: \(value)")
        }
        
        if code == 0 {
            credential =
                .constitutionalCommitteeHotKeyhash(
                    try AddressKeyHash(payload: payload)
                )
        } else if code == 1 {
            credential = .constitutionalCommitteeHotScriptHash(try ScriptHash(payload: payload))
        } else if code == 2 {
            credential = .drepKeyhash(try AddressKeyHash(payload: payload))
        } else if code == 3 {
            credential = .drepScriptHash(try ScriptHash(payload: payload))
        } else if code == 4 {
            credential = .stakePoolKeyhash(try AddressKeyHash(payload: payload))
        } else {
            throw CardanoCoreError.deserializeError("Invalid Voter type: \(code)")
        }
        
        return Voter(credential: credential) as! T
    }
    
    static func == (lhs: Voter, rhs: Voter) -> Bool {
        return lhs.credential == rhs.credential
    }
}

