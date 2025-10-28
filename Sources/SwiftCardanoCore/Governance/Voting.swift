import Foundation
import OrderedCollections

public enum Vote: Int, Codable, Sendable {
    case no = 0
    case yes = 1
    case abstain = 2
}

public enum VoterType: Serializable {
    case constitutionalCommitteeHotKeyhash(VerificationKeyHash)
    case constitutionalCommitteeHotScriptHash(ScriptHash)
    case drepKeyhash(VerificationKeyHash)
    case drepScriptHash(ScriptHash)
    case stakePoolKeyhash(VerificationKeyHash)
    
    // MARK: - CBORSerializable
    
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
    
    // MARK: - JSONSerializable
    
    public static func fromDict(_ dict: Primitive) throws -> VoterType {
        guard case let .orderedDict(orderedDict) = dict else {
            throw CardanoCoreError.deserializeError("Invalid VoterType dict format")
        }
        guard let typePrimitive = orderedDict[.string("type")] ,
              case let .string(typeString) = typePrimitive,
              let hashPrimitive = orderedDict[.string("hash")] else {
            throw CardanoCoreError.deserializeError("Invalid VoterType dict")
        }
        
        switch typeString {
            case "constitutionalCommitteeHotKeyhash":
                let hash = try VerificationKeyHash(from: hashPrimitive)
                return .constitutionalCommitteeHotKeyhash(hash)
            case "constitutionalCommitteeHotScriptHash":
                let hash = try ScriptHash(from: hashPrimitive)
                return .constitutionalCommitteeHotScriptHash(hash)
            case "drepKeyhash":
                let hash = try VerificationKeyHash(from: hashPrimitive)
                return .drepKeyhash(hash)
            case "drepScriptHash":
                let hash = try ScriptHash(from: hashPrimitive)
                return .drepScriptHash(hash)
            case "stakePoolKeyhash":
                let hash = try VerificationKeyHash(from: hashPrimitive)
                return .stakePoolKeyhash(hash)
            default:
                throw CardanoCoreError.deserializeError("Invalid VoterType type: \(typeString)")
        }
    }
    
    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        switch self {
            case .constitutionalCommitteeHotKeyhash(let hash):
                dict[.string("type")] = .string("constitutionalCommitteeHotKeyhash")
                dict[.string("hash")] = hash.toPrimitive()
            case .constitutionalCommitteeHotScriptHash(let hash):
                dict[.string("type")] = .string("constitutionalCommitteeHotScriptHash")
                dict[.string("hash")] = hash.toPrimitive()
            case .drepKeyhash(let hash):
                dict[.string("type")] = .string("drepKeyhash")
                dict[.string("hash")] = hash.toPrimitive()
            case .drepScriptHash(let hash):
                dict[.string("type")] = .string("drepScriptHash")
                dict[.string("hash")] = hash.toPrimitive()
            case .stakePoolKeyhash(let hash):
                dict[.string("type")] = .string("stakePoolKeyhash")
                dict[.string("hash")] = hash.toPrimitive()
        }
        return .orderedDict(dict)
    }

}

public struct VotingProcedure: Serializable {
    public let vote: Vote
    public let anchor: Anchor?
    
    public init(vote: Vote, anchor: Anchor? = nil) {
        self.vote = vote
        self.anchor = anchor
    }
    
    // MARK: - CBORSerializable
    
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
    
    // MARK: - JSONSerializable
    
    public static func fromDict(_ dict: Primitive) throws -> VotingProcedure {
        guard case let .orderedDict(orderedDict) = dict else {
            throw CardanoCoreError.deserializeError("Invalid VotingProcedure dict format")
        }
        guard let votePrimitive = orderedDict[.string("vote")],
              case let .int(voteValue) = votePrimitive,
              let vote = Vote(rawValue: Int(voteValue)) else {
            throw CardanoCoreError.deserializeError("Invalid or missing vote in VotingProcedure dict")
        }
        
        let anchor: Anchor?
        if let anchorPrimitive = orderedDict[.string("anchor")] {
            if anchorPrimitive == .null {
                anchor = nil
            } else {
                anchor = try Anchor(from: anchorPrimitive)
            }
        } else {
            anchor = nil
        }
        
        return VotingProcedure(vote: vote, anchor: anchor)
    }
    
    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        dict[.string("vote")] = .int(vote.rawValue)
        if let anchor = anchor {
            dict[.string("anchor")] = try anchor.toPrimitive()
        } else {
            dict[.string("anchor")] = .null
        }
        return .orderedDict(dict)
    }

}

public struct Voter: Serializable {
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
    
    // MARK: - CBORSerializable
    
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
    
    // MARK: - JSONSerializable
    
    public static func fromDict(_ dict: Primitive) throws -> Voter {
        guard case let .orderedDict(orderedDict) = dict else {
            throw CardanoCoreError.deserializeError("Invalid Voter dict format")
        }
        guard let codePrimitive = orderedDict[.string("code")],
              case .int(_) = codePrimitive else {
            throw CardanoCoreError.deserializeError("Invalid or missing code in Voter dict")
        }
        
        guard let credentialPrimitive = orderedDict[.string("credential")] else {
            throw CardanoCoreError.deserializeError("Missing credential in Voter dict")
        }
        
        let credential = try VoterType(from: credentialPrimitive)
        
        return Voter(credential: credential)
    }
    
    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        dict[.string("code")] = .int(code)
        dict[.string("credential")] = try credential.toPrimitive()
        return .orderedDict(dict)
    }
}

public struct VotingProcedures: Serializable {
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
    
    // MARK: - CBORSerializable
    
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
    
    // MARK: - JSONSerializable

    public static func fromDict(_ dict: Primitive) throws -> VotingProcedures {
        guard case let .orderedDict(orderedDict) = dict else {
            throw CardanoCoreError.deserializeError("Invalid VotingProcedures dict format")
        }
        var procedures: [Voter: [GovActionID: VotingProcedure]] = [:]
        
        for (voterPrimitive, actionsPrimitive) in orderedDict {
            let voter = try Voter(from: voterPrimitive)
            
            guard case let .orderedDict(actionsDict) = actionsPrimitive else {
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
        
        return VotingProcedures(procedures)
    }
    
    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        for (voter, actions) in procedures {
            var actionsDict = OrderedDictionary<Primitive, Primitive>()
            for (govActionID, procedure) in actions {
                actionsDict[try govActionID.toPrimitive()] = try procedure.toPrimitive()
            }
            dict[try voter.toPrimitive()] = .orderedDict(actionsDict)
        }
        return .orderedDict(dict)
    }
    
    // MARK: - Equatable and Hashable
    
    public static func == (lhs: VotingProcedures, rhs: VotingProcedures) -> Bool {
        return lhs.procedures == rhs.procedures
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(procedures)
    }
}
