import Foundation

enum Vote: Int, Codable {
    case no = 0
    case yes = 1
    case abstain = 2
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
}

struct VotingProcedures: Codable {
    let procedures: [Voter: [GovActionID: VotingProcedure]]
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        procedures = try container.decode([Voter: [GovActionID: VotingProcedure]].self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(procedures)
    }
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
                    AddressKeyHash(payload: payload)
                )
        } else if code == 1 {
            credential = .constitutionalCommitteeHotScriptHash(ScriptHash(payload: payload))
        } else if code == 2 {
            credential = .drepKeyhash(AddressKeyHash(payload: payload))
        } else if code == 3 {
            credential = .drepScriptHash(ScriptHash(payload: payload))
        } else if code == 4 {
            credential = .stakePoolKeyhash(AddressKeyHash(payload: payload))
        } else {
            throw CardanoCoreError.deserializeError("Invalid Voter type: \(code)")
        }
        
        return Voter(credential: credential) as! T
    }
    
    static func == (lhs: Voter, rhs: Voter) -> Bool {
        return lhs.credential == rhs.credential
    }
}

