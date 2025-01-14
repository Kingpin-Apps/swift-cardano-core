import Foundation
import PotentCBOR


enum Certificate: ArrayCBORSerializable {
    case stakeRegistration(StakeRegistration)
    case stakeDeregistration(StakeDeregistration)
    case stakeDelegation(StakeDelegation)
    case poolRegistration(PoolRegistration)
    case poolRetirement(PoolRetirement)
    case genesisKeyDelegation(GenesisKeyDelegation)
    case moveInstantaneousRewards(MoveInstantaneousRewards)
    case register(Register)
    case unregister(Unregister)
    case voteDelegate(VoteDelegate)
    case stakeVoteDelegate(StakeVoteDelegate)
    case stakeRegisterDelegate(StakeRegisterDelegate)
    case voteRegisterDelegate(VoteRegisterDelegate)
    case stakeVoteRegisterDelegate(StakeVoteRegisterDelegate)
    case authCommitteeHot(AuthCommitteeHot)
    case resignCommitteeCold(ResignCommitteeCold)
    case registerDRep(RegisterDRep)
    case unRegisterDRep(UnRegisterDRep)
    case updateDRep(UpdateDRep)
    
    static func fromPrimitive<T>(_ value: Any) throws -> T {
        var code: Int
        if let list = value as? [Any] {
            code = list[0] as! Int
            switch code {
                case 0: return try StakeRegistration.fromPrimitive(list)
                case 1: return try StakeDeregistration.fromPrimitive(list)
                case 2: return try StakeDelegation.fromPrimitive(list)
                case 3: return try PoolRegistration.fromPrimitive(list)
                case 4: return try PoolRetirement.fromPrimitive(list)
                case 5: return try GenesisKeyDelegation.fromPrimitive(list)
                case 6: return try MoveInstantaneousRewards.fromPrimitive(list)
                case 7: return try Register.fromPrimitive(list)
                case 8: return try Unregister.fromPrimitive(list)
                case 9: return try VoteDelegate.fromPrimitive(list)
                case 10: return try StakeVoteDelegate.fromPrimitive(list)
                case 11: return try StakeRegisterDelegate.fromPrimitive(list)
                case 12: return try VoteRegisterDelegate.fromPrimitive(list)
                case 13: return try StakeVoteRegisterDelegate.fromPrimitive(list)
                case 14: return try AuthCommitteeHot.fromPrimitive(list)
                case 15: return try ResignCommitteeCold.fromPrimitive(list)
                case 16: return try RegisterDRep.fromPrimitive(list)
                case 17: return try UnRegisterDRep.fromPrimitive(list)
                case 18: return try UpdateDRep.fromPrimitive(list)
                default:
                    throw CardanoCoreError.deserializeError("Invalid Certificate code: \(code)")
            }
        } else if let tuple = value as? (Any, Any) {
            code = tuple.0 as! Int
            
            switch code {
                case 0: return try StakeRegistration.fromPrimitive(tuple)
                case 1: return try StakeDeregistration.fromPrimitive(tuple)
                case 3: return try PoolRegistration.fromPrimitive(tuple)
                case 6: return try MoveInstantaneousRewards.fromPrimitive(tuple)
                default:
                    throw CardanoCoreError.deserializeError("Invalid Certificate code: \(code)")
            }
        } else if let tuple = value as? (Any, Any, Any) {
            code = tuple.0 as! Int
            
            switch code {
                case 2: return try StakeDelegation.fromPrimitive(tuple)
                case 4: return try PoolRetirement.fromPrimitive(tuple)
                case 7: return try Register.fromPrimitive(tuple)
                case 8: return try Unregister.fromPrimitive(tuple)
                case 9: return try VoteDelegate.fromPrimitive(tuple)
                case 14: return try AuthCommitteeHot.fromPrimitive(tuple)
                case 15: return try ResignCommitteeCold.fromPrimitive(tuple)
                case 16: return try RegisterDRep.fromPrimitive(tuple)
                case 17: return try UnRegisterDRep.fromPrimitive(tuple)
                case 18: return try UpdateDRep.fromPrimitive(tuple)
                default:
                    throw CardanoCoreError.deserializeError("Invalid Certificate code: \(code)")
            }
        } else if let tuple = value as? (Any, Any, Any, Any) {
            code = tuple.0 as! Int
            
            switch code {
                case 5: return try GenesisKeyDelegation.fromPrimitive(tuple)
                case 4: return try PoolRetirement.fromPrimitive(tuple)
                case 10: return try StakeVoteDelegate.fromPrimitive(tuple)
                case 11: return try StakeRegisterDelegate.fromPrimitive(tuple)
                case 12: return try VoteRegisterDelegate.fromPrimitive(tuple)
                default:
                    throw CardanoCoreError.deserializeError("Invalid Certificate code: \(code)")
            }
        }  else if let tuple = value as? (Any, Any, Any, Any) {
            code = tuple.0 as! Int
            
            switch code {
               case 13: return try StakeVoteRegisterDelegate.fromPrimitive(tuple)
                default:
                    throw CardanoCoreError.deserializeError("Invalid Certificate code: \(code)")
            }
        } else {
            throw CardanoCoreError.deserializeError("Invalid Certificate data: \(value)")
        
            
        }
    }
}


