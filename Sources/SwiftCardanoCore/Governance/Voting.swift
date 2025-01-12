import Foundation

enum Vote: Int, CBORSerializable {
    case no = 0
    case yes = 1
    case abstain = 2
    
    func toShallowPrimitive() throws -> Any {
        self.rawValue
    }

    static func fromPrimitive<T>(_ value: Any) throws -> T {
        return Vote(rawValue: value as! Int) as! T
    }
}

enum VoterType: Hashable {
    case constitutionalCommitteeHotKeyhash(AddressKeyHash)
    case constitutionalCommitteeHotScriptHash(ScriptHash)
    case drepKeyhash(AddressKeyHash)
    case drepScriptHash(ScriptHash)
    case stakePoolKeyhash(AddressKeyHash)
}

struct VotingProcedure: ArrayCBORSerializable {
    let vote: Vote
    let anchor: Anchor?
    
    static func fromPrimitive<T>(_ value: Any) throws -> T {
        <#code#>
    }
}

struct VotingProcedures: MapCBORSerializable {
    let procedures: [Voter: [GovActionID: VotingProcedure]]
    
    static func fromPrimitive<T>(_ value: Any) throws -> T {
        <#code#>
    }
}

struct Voter: ArrayCBORSerializable, Hashable {
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

