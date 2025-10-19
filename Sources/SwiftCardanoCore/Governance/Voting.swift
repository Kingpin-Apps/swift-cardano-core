import Foundation
import OrderedCollections

public enum Vote: Int, Codable, Sendable {
    case no = 0
    case yes = 1
    case abstain = 2
}

public enum VoterType: CBORSerializable, Equatable, Hashable {
    case constitutionalCommitteeHotKeyhash(VerificationKeyHash)
    case constitutionalCommitteeHotScriptHash(ScriptHash)
    case drepKeyhash(VerificationKeyHash)
    case drepScriptHash(ScriptHash)
    case stakePoolKeyhash(VerificationKeyHash)
    
    public init(from primitive: Primitive) throws {
        guard case let .list(elements) = primitive,
              elements.count == 2,
              case let .uint(tag) = elements[0] else {
            throw CardanoCoreError.deserializeError("Invalid VoterType primitive")
        }
        
        switch tag {
            case 0:
                self = .constitutionalCommitteeHotKeyhash(try VerificationKeyHash(from: elements[1]))
            case 1:
                self = .constitutionalCommitteeHotScriptHash(try ScriptHash(from: elements[1]))
            case 2:
                self = .drepKeyhash(try VerificationKeyHash(from: elements[1]))
            case 3:
                self = .drepScriptHash(try ScriptHash(from: elements[1]))
            case 4:
                self = .stakePoolKeyhash(try VerificationKeyHash(from: elements[1]))
            default:
                throw CardanoCoreError.deserializeError("Invalid VoterType tag: \(tag)")
        }
    }
    
    public func toPrimitive() throws -> Primitive {
        switch self {
            case .constitutionalCommitteeHotKeyhash(let hash):
                return .list([.uint(0), hash.toPrimitive()])
            case .constitutionalCommitteeHotScriptHash(let hash):
                return .list([.uint(1), hash.toPrimitive()])
            case .drepKeyhash(let hash):
                return .list([.uint(2), hash.toPrimitive()])
            case .drepScriptHash(let hash):
                return .list([.uint(3), hash.toPrimitive()])
            case .stakePoolKeyhash(let hash):
                return .list([.uint(4), hash.toPrimitive()])
        }
    }
}

public struct VotingProcedure: CBORSerializable, Equatable, Hashable {
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
    
    public init(from primitive: Primitive) throws {
        guard case let .list(elements) = primitive,
              elements.count == 2 else {
            throw CardanoCoreError.deserializeError("Invalid VotingProcedure primitive")
        }
        
        guard case let .uint(voteValue) = elements[0] else {
            throw CardanoCoreError.deserializeError("Invalid vote value in VotingProcedure")
        }
        
        guard let vote = Vote(rawValue: Int(voteValue)) else {
            throw CardanoCoreError.deserializeError("Invalid vote enum value: \(voteValue)")
        }
        
        self.vote = vote
        
        if elements[1] == .null {
            self.anchor = nil
        } else {
            self.anchor = try Anchor(from: elements[1])
        }
    }
    
    public func toPrimitive() throws -> Primitive {
        return .list([
            .int(vote.rawValue),
            try anchor?.toPrimitive() ?? .null
        ])
    }
}

public struct Voter: CBORSerializable, Equatable, Hashable {
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
    
    public init(from primitive: Primitive) throws {
        guard case let .list(elements) = primitive,
              elements.count == 2,
              case .uint(_) = elements[0] else {
            throw CardanoCoreError.deserializeError("Invalid Voter primitive: \(primitive)")
        }
        
        self.credential = try VoterType(from: elements[1])
    }
    
    public func toPrimitive() throws -> Primitive {
        return .list([
            .uint(UInt(code)),
            try credential.toPrimitive()
        ])
    }
    
    public static func == (lhs: Voter, rhs: Voter) -> Bool {
        return lhs.credential == rhs.credential
    }
}

public struct VotingProcedures: CBORSerializable, Equatable, Hashable {
    private var procedures: [Voter: [GovActionID: VotingProcedure]]
    
    public init() {
        self.procedures = [:]
    }
    
    public init(_ procedures: [Voter: [GovActionID: VotingProcedure]]) {
        self.procedures = procedures
    }
    
    // MARK: - Dictionary-like access
    
    public subscript(voter: Voter) -> [GovActionID: VotingProcedure]? {
        get {
            return procedures[voter]
        }
        set {
            procedures[voter] = newValue
        }
    }
    
    public subscript(voter: Voter, govActionID: GovActionID) -> VotingProcedure? {
        get {
            return procedures[voter]?[govActionID]
        }
        set {
            if procedures[voter] == nil {
                procedures[voter] = [:]
            }
            procedures[voter]![govActionID] = newValue
        }
    }
    
    // MARK: - Collection properties
    
    public var isEmpty: Bool {
        return procedures.isEmpty
    }
    
    public var count: Int {
        return procedures.count
    }
    
    public var voters: [Voter] {
        return Array(procedures.keys)
    }
    
    public var allVotes: [(Voter, GovActionID, VotingProcedure)] {
        var votes: [(Voter, GovActionID, VotingProcedure)] = []
        for (voter, actions) in procedures {
            for (govActionID, procedure) in actions {
                votes.append((voter, govActionID, procedure))
            }
        }
        return votes
    }
    
    // MARK: - Convenience methods
    
    /// Add a voting procedure for a specific voter and governance action
    /// - Parameters:
    ///   - procedure: The voting procedure to add
    ///   - voter: The voter casting the vote
    ///   - govActionID: The governance action being voted on
    public mutating func addVote(_ procedure: VotingProcedure, for voter: Voter, on govActionID: GovActionID) {
        if procedures[voter] == nil {
            procedures[voter] = [:]
        }
        procedures[voter]![govActionID] = procedure
    }
    
    /// Remove a vote for a specific voter and governance action
    /// - Parameters:
    ///   - voter: The voter whose vote to remove
    ///   - govActionID: The governance action to remove the vote for
    /// - Returns: The removed voting procedure, if it existed
    @discardableResult
    public mutating func removeVote(for voter: Voter, on govActionID: GovActionID) -> VotingProcedure? {
        let removed = procedures[voter]?.removeValue(forKey: govActionID)
        
        // Clean up empty voter entries
        if procedures[voter]?.isEmpty == true {
            procedures.removeValue(forKey: voter)
        }
        
        return removed
    }
    
    /// Remove all votes for a specific voter
    /// - Parameter voter: The voter whose votes to remove
    /// - Returns: The removed voting procedures dictionary, if it existed
    @discardableResult
    public mutating func removeAllVotes(for voter: Voter) -> [GovActionID: VotingProcedure]? {
        return procedures.removeValue(forKey: voter)
    }
    
    /// Check if a voter has cast a vote on a specific governance action
    /// - Parameters:
    ///   - voter: The voter to check
    ///   - govActionID: The governance action to check
    /// - Returns: True if the voter has voted on the action
    public func hasVote(from voter: Voter, on govActionID: GovActionID) -> Bool {
        return procedures[voter]?[govActionID] != nil
    }
    
    /// Get all governance actions a voter has voted on
    /// - Parameter voter: The voter to check
    /// - Returns: Array of governance action IDs the voter has voted on
    public func govActionsVotedOn(by voter: Voter) -> [GovActionID] {
        guard let voterProcedures = procedures[voter] else {
            return []
        }
        return Array(voterProcedures.keys)
    }
    
    /// Get all votes of a specific type (yes/no/abstain)
    /// - Parameter vote: The vote type to filter by
    /// - Returns: Array of tuples containing voter, governance action ID, and voting procedure
    public func votes(of type: Vote) -> [(Voter, GovActionID, VotingProcedure)] {
        return allVotes.filter { $0.2.vote == type }
    }
    
    /// Get vote counts for a specific governance action
    /// - Parameter govActionID: The governance action to analyze
    /// - Returns: Dictionary with vote counts by vote type
    public func voteCounts(for govActionID: GovActionID) -> [Vote: Int] {
        var counts: [Vote: Int] = [.yes: 0, .no: 0, .abstain: 0]
        
        for (_, actions) in procedures {
            if let procedure = actions[govActionID] {
                counts[procedure.vote, default: 0] += 1
            }
        }
        
        return counts
    }
    
    /// Remove all voting procedures
    public mutating func removeAll() {
        procedures.removeAll()
    }
    
    // MARK: - Codable conformance
    
//    public init(from decoder: Decoder) throws {
//        let container = try decoder.singleValueContainer()
//        procedures = try container.decode([Voter: [GovActionID: VotingProcedure]].self)
//    }
//    
//    public func encode(to encoder: Encoder) throws {
//        var container = encoder.singleValueContainer()
//        try container.encode(procedures)
//    }
    
    // MARK: - CBORSerializable primitive methods
    
    public init(from primitive: Primitive) throws {
        // handle dict or ordered dict
        var dict: OrderedDictionary<Primitive, Primitive>
        switch primitive {
            case .orderedDict(let orderedDict):
                dict = orderedDict
            case .dict(let dictionary):
                dict = OrderedDictionary(uniqueKeysWithValues: dictionary.map { ($0.key, $0.value) })
            default:
                throw CardanoCoreError.deserializeError("Invalid VotingProcedures primitive: \(primitive)")
        }
        
        var procedures: [Voter: [GovActionID: VotingProcedure]] = [:]
        
        for (voterPrimitive, actionsPrimitive) in dict {
            let voter = try Voter(from: voterPrimitive)
            
            var actionsDict: OrderedDictionary<Primitive, Primitive>
            switch actionsPrimitive {
                case .orderedDict(let orderedDict):
                    actionsDict = orderedDict
                case .dict(let dictionary):
                    actionsDict = OrderedDictionary(uniqueKeysWithValues: dictionary.map { ($0.key, $0.value) })
                default:
                    throw CardanoCoreError.deserializeError("Invalid actions dictionary in VotingProcedures: \(actionsPrimitive)")
            }
            
            var actions: [GovActionID: VotingProcedure] = [:]
            for (govActionPrimitive, procedurePrimitive) in actionsDict {
                let govActionID = try GovActionID(from: govActionPrimitive)
                let procedure = try VotingProcedure(from: procedurePrimitive)
                actions[govActionID] = procedure
            }
            
            procedures[voter] = actions
        }
        
        self.procedures = procedures
    }
    
    public func toPrimitive() throws -> Primitive {
        var dict: [Primitive: Primitive] = [:]
        
        for (voter, actions) in procedures {
            var actionsDict: [Primitive: Primitive] = [:]
            
            for (govActionID, procedure) in actions {
                actionsDict[try govActionID.toPrimitive()] = try procedure.toPrimitive()
            }
            
            dict[try voter.toPrimitive()] = .dict(actionsDict)
        }
        
        return .dict(dict)
    }
    
    // MARK: - Equatable and Hashable
    
    public static func == (lhs: VotingProcedures, rhs: VotingProcedures) -> Bool {
        return lhs.procedures == rhs.procedures
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(procedures)
    }
}
