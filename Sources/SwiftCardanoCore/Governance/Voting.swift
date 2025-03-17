import Foundation

public enum Vote: Int, Codable {
    case no = 0
    case yes = 1
    case abstain = 2
}

public enum VoterType: Codable, Equatable, Hashable {
    case constitutionalCommitteeHotKeyhash(AddressKeyHash)
    case constitutionalCommitteeHotScriptHash(ScriptHash)
    case drepKeyhash(AddressKeyHash)
    case drepScriptHash(ScriptHash)
    case stakePoolKeyhash(AddressKeyHash)
}

public struct VotingProcedure: Codable, Equatable, Hashable {
    public let vote: Vote
    public let anchor: Anchor?
    
    public init(vote: Vote, anchor: Anchor? = nil) {
        self.vote = vote
        self.anchor = anchor
    }
    
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        vote = try container.decode(Vote.self)
        anchor = try container.decode(Anchor.self)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(vote)
        try container.encode(anchor)
    }
}

public struct Voter: Codable, Equatable, Hashable {
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
    public let credential: VoterType
    
    public init(credential: VoterType) {
        self.credential = credential
    }
    
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        _ = try container.decode(Int.self)
        credential = try container.decode(VoterType.self)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(code)
        try container.encode(credential)
    }
    
    public static func == (lhs: Voter, rhs: Voter) -> Bool {
        return lhs.credential == rhs.credential
    }
}

public struct VotingProcedures: Codable, Equatable, Hashable  {
    public var procedures: [Voter: [GovActionID: VotingProcedure]]
    
    public init(procedures: [Voter: [GovActionID: VotingProcedure]]) {
        self.procedures = procedures
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        procedures = try container.decode([Voter: [GovActionID: VotingProcedure]].self)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(procedures)
    }
}

