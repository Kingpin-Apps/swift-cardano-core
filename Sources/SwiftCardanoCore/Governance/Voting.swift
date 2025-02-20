import Foundation

enum Vote: Int, Codable {
    case no = 0
    case yes = 1
    case abstain = 2
}

enum VoterType: Codable, Equatable, Hashable {
    case constitutionalCommitteeHotKeyhash(AddressKeyHash)
    case constitutionalCommitteeHotScriptHash(ScriptHash)
    case drepKeyhash(AddressKeyHash)
    case drepScriptHash(ScriptHash)
    case stakePoolKeyhash(AddressKeyHash)
}

struct VotingProcedure: Codable, Equatable, Hashable {
    let vote: Vote
    let anchor: Anchor?
    
    init(vote: Vote, anchor: Anchor? = nil) {
        self.vote = vote
        self.anchor = anchor
    }
    
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

struct Voter: Codable, Equatable, Hashable {
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
    
    init(credential: VoterType) {
        self.credential = credential
    }
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        _ = try container.decode(Int.self)
        credential = try container.decode(VoterType.self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(code)
        try container.encode(credential)
    }
    
    static func == (lhs: Voter, rhs: Voter) -> Bool {
        return lhs.credential == rhs.credential
    }
}

struct VotingProcedures: Codable, Equatable, Hashable  {
    let procedures: [Voter: [GovActionID: VotingProcedure]]
    
    init(procedures: [Voter: [GovActionID: VotingProcedure]]) {
        self.procedures = procedures
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        procedures = try container.decode([Voter: [GovActionID: VotingProcedure]].self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(procedures)
    }
}

