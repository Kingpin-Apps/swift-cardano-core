import Foundation
import PotentCBOR

enum CertificateType: String, Codable {
    case shelley = "CertificateShelley"
    case conway = "CertificateConway"
}

public enum CertificateCode: Int, Codable {
    case stakeRegistration = 0
    case stakeDeregistration = 1
    case stakeDelegation = 2
    case poolRegistration = 3
    case poolRetirement = 4
    case genesisKeyDelegation = 5
    case moveInstantaneousRewards = 6
    case register = 7
    case unregister = 8
    case voteDelegate = 9
    case stakeVoteDelegate = 10
    case stakeRegisterDelegate = 11
    case voteRegisterDelegate = 12
    case stakeVoteRegisterDelegate = 13
    case authCommitteeHot = 14
    case resignCommitteeCold = 15
    case registerDRep = 16
    case unRegisterDRep = 17
    case updateDRep = 18
}

public enum CertificateDescription: String, Codable {
    case stakeRegistration = "Stake Address Registration Certificate"
    case stakeDeregistration = "Stake Address Deregistration Certificate"
    case stakeDelegation = "Stake Delegation Certificate"
    case poolRegistration = "Stake Pool Registration Certificate"
    case poolRetirement = "Stake Pool Retirement Certificate"
    case genesisKeyDelegation = "Genesis Key Delegation Certificate"
    case moveInstantaneousRewards = "Move Instantaneous Rewards Certificate"
//    case unregister = "Stake Address Retirement Certificate"
    case voteDelegate = "Vote Delegation Certificate"
    case stakeVoteDelegate = "Stake and Vote Delegation Certificate"
    case stakeRegisterDelegate = "Stake address registration and stake delegation certificate"
    case voteRegisterDelegate = "Stake address registration and vote delegation certificate"
//    case stakeVoteRegisterDelegate = "Stake address registration and vote delegation certificate"
    case authCommitteeHot = "Constitutional Committee Hot Key Registration Certificate"
    case resignCommitteeCold = "Constitutional Committee Cold Key Resignation Certificate"
    case registerDRep = "DRep Registration Certificate"
    case unRegisterDRep = "DRep Retirement Certificate"
    case updateDRep = "DRep Update Certificate"
}

public enum Certificate: CBORSerializable, Equatable, Hashable {
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
    case unRegisterDRep(UnregisterDRep)
    case updateDRep(UpdateDRep)
    
    public init(from primitive: Primitive) throws {
        guard case let .list(elements) = primitive else {
            throw CardanoCoreError.deserializeError("Invalid Certificate format")
        }
        
        guard let firstElement = elements.first,
                case let .uint(code) = firstElement,
              let certificateCode = CertificateCode(rawValue: Int(code)) else {
            throw CardanoCoreError.deserializeError("Invalid Certificate code")
        }
        
        let restElements = Array(elements.dropFirst())
        let restPrimitive = Primitive.list(restElements)
        switch certificateCode {
            case .stakeRegistration:
                let stakeReg = try StakeRegistration(from: restPrimitive)
                self = .stakeRegistration(stakeReg)
            case .stakeDeregistration:
                let stakeDereg = try StakeDeregistration(from: restPrimitive)
                self = .stakeDeregistration(stakeDereg)
            case .stakeDelegation:
                let stakeDel = try StakeDelegation(from: restPrimitive)
                self = .stakeDelegation(stakeDel)
            case .poolRegistration:
                let poolReg = try PoolRegistration(from: restPrimitive)
                self = .poolRegistration(poolReg)
            case .poolRetirement:
                let poolRet = try PoolRetirement(from: restPrimitive)
                self = .poolRetirement(poolRet)
            case .genesisKeyDelegation:
                let genKeyDel = try GenesisKeyDelegation(from: restPrimitive)
                self = .genesisKeyDelegation(genKeyDel)
            case .moveInstantaneousRewards:
                let mir = try MoveInstantaneousRewards(from: restPrimitive)
                self = .moveInstantaneousRewards(mir)
            case .register:
                let reg = try Register(from: restPrimitive)
                self = .register(reg)
            case .unregister:
                let unreg = try Unregister(from: restPrimitive)
                self = .unregister(unreg)
            case .voteDelegate:
                let voteDel = try VoteDelegate(from: restPrimitive)
                self = .voteDelegate(voteDel)
            case .stakeVoteDelegate:
                let stakeVoteDel = try StakeVoteDelegate(from: restPrimitive)
                self = .stakeVoteDelegate(stakeVoteDel)
            case .stakeRegisterDelegate:
                let stakeRegDel = try StakeRegisterDelegate(from: restPrimitive)
                self = .stakeRegisterDelegate(stakeRegDel)
            case .voteRegisterDelegate:
                let voteRegDel = try VoteRegisterDelegate(from: restPrimitive)
                self = .voteRegisterDelegate(voteRegDel)
            case .stakeVoteRegisterDelegate:
                let stakeVoteRegDel = try StakeVoteRegisterDelegate(from: restPrimitive)
                self = .stakeVoteRegisterDelegate(stakeVoteRegDel)
            case .authCommitteeHot:
                let authCommHot = try AuthCommitteeHot(from: restPrimitive)
                self = .authCommitteeHot(authCommHot)
            case .resignCommitteeCold:
                let resignCommCold = try ResignCommitteeCold(from: restPrimitive)
                self = .resignCommitteeCold(resignCommCold)
            case .registerDRep:
                let regDRep = try RegisterDRep(from: restPrimitive)
                self = .registerDRep(regDRep)
            case .unRegisterDRep:
                let unRegDRep = try UnregisterDRep(from: restPrimitive)
                self = .unRegisterDRep(unRegDRep)
            case .updateDRep:
                let updDRep = try UpdateDRep(from: restPrimitive)
                self = .updateDRep(updDRep)
        }
    }

    public func toPrimitive() throws -> Primitive {        
        switch self {
            case .stakeRegistration(let stakeReg):
                return try stakeReg.toPrimitive()
            case .stakeDeregistration(let stakeDereg):
                return try stakeDereg.toPrimitive()
            case .stakeDelegation(let stakeDel):
                return try stakeDel.toPrimitive()
            case .poolRegistration(let poolReg):
                return try poolReg.toPrimitive()
            case .poolRetirement(let poolRet):
                return try poolRet.toPrimitive()
            case .genesisKeyDelegation(let genKeyDel):
                return try genKeyDel.toPrimitive()
            case .moveInstantaneousRewards(let mir):
                return try mir.toPrimitive()
            case .register(let reg):
                return try reg.toPrimitive()
            case .unregister(let unreg):
                return try unreg.toPrimitive()
            case .voteDelegate(let voteDel):
                return try voteDel.toPrimitive()
            case .stakeVoteDelegate(let stakeVoteDel):
                return try stakeVoteDel.toPrimitive()
            case .stakeRegisterDelegate(let stakeRegDel):
                return try stakeRegDel.toPrimitive()
            case .voteRegisterDelegate(let voteRegDel):
                return try voteRegDel.toPrimitive()
            case .stakeVoteRegisterDelegate(let stakeVoteRegDel):
                return try stakeVoteRegDel.toPrimitive()
            case .authCommitteeHot(let authCommHot):
                return try authCommHot.toPrimitive()
            case .resignCommitteeCold(let resignCommCold):
                return try resignCommCold.toPrimitive()
            case .registerDRep(let regDRep):
                return try regDRep.toPrimitive()
            case .unRegisterDRep(let unRegDRep):
                return try unRegDRep.toPrimitive()
            case .updateDRep(let updDRep):
                return try updDRep.toPrimitive()	
        }
    }
}

public protocol CertificateSerializable: PayloadJSONSerializable {
    static var CODE: CertificateCode { get }
    
    var type: String { get }
    var description: String { get }
}

public extension CertificateSerializable {
    /// Serialize to JSON.
    ///
    /// The json output has three fields: "type", "description", and "cborHex".
    /// - Returns: JSON representation
    func toJSON() throws -> String? {
        let jsonString = """
        {
            "type": "\(type)",
            "description": "\(description)",
            "cborHex": "\(payload.toHex)"
        }
        """
        return jsonString
    }
}
