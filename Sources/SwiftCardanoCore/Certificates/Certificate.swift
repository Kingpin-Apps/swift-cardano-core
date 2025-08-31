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
                case let .int(code) = firstElement,
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
                var elements: [Primitive] = [.int(CertificateCode.stakeRegistration.rawValue)]
                elements.append(try stakeReg.toPrimitive())
                return .list(elements)
            case .stakeDeregistration(let stakeDereg):
                var elements: [Primitive] = [.int(CertificateCode.stakeDeregistration.rawValue)]
                elements.append(try stakeDereg.toPrimitive())
                return .list(elements)
            case .stakeDelegation(let stakeDel):
                var elements: [Primitive] = [.int(CertificateCode.stakeDelegation.rawValue)]
                elements.append(try stakeDel.toPrimitive())
                return .list(elements)
            case .poolRegistration(let poolReg):
                var elements: [Primitive] = [.int(CertificateCode.poolRegistration.rawValue)]
                elements.append(try poolReg.toPrimitive())
                return .list(elements)
            case .poolRetirement(let poolRet):
                var elements: [Primitive] = [.int(CertificateCode.poolRetirement.rawValue)]
                elements.append(try poolRet.toPrimitive())
                return .list(elements)
            case .genesisKeyDelegation(let genKeyDel):
                var elements: [Primitive] = [.int(CertificateCode.genesisKeyDelegation.rawValue)]
                elements.append(try genKeyDel.toPrimitive())
                return .list(elements)
            case .moveInstantaneousRewards(let mir):
                var elements: [Primitive] = [.int(CertificateCode.moveInstantaneousRewards.rawValue)]
                elements.append(try mir.toPrimitive())
                return .list(elements)
            case .register(let reg):
                var elements: [Primitive] = [.int(CertificateCode.register.rawValue)]
                elements.append(try reg.toPrimitive())
                return .list(elements)
            case .unregister(let unreg):
                var elements: [Primitive] = [.int(CertificateCode.unregister.rawValue)]
                elements.append(try unreg.toPrimitive())
                return .list(elements)
            case .voteDelegate(let voteDel):
                var elements: [Primitive] = [.int(CertificateCode.voteDelegate.rawValue)]
                elements.append(try voteDel.toPrimitive())
                return .list(elements)
            case .stakeVoteDelegate(let stakeVoteDel):
                var elements: [Primitive] = [.int(CertificateCode.stakeVoteDelegate.rawValue)]
                elements.append(try stakeVoteDel.toPrimitive())
                return .list(elements)
            case .stakeRegisterDelegate(let stakeRegDel):
                var elements: [Primitive] = [.int(CertificateCode.stakeRegisterDelegate.rawValue)]
                elements.append(try stakeRegDel.toPrimitive())
                return .list(elements)
            case .voteRegisterDelegate(let voteRegDel):
                var elements: [Primitive] = [.int(CertificateCode.voteRegisterDelegate.rawValue)]
                elements.append(try voteRegDel.toPrimitive())
                return .list(elements)
            case .stakeVoteRegisterDelegate(let stakeVoteRegDel):
                var elements: [Primitive] = [.int(CertificateCode.stakeVoteRegisterDelegate.rawValue)]
                elements.append(try stakeVoteRegDel.toPrimitive())
                return .list(elements)
            case .authCommitteeHot(let authCommHot):
                var elements: [Primitive] = [.int(CertificateCode.authCommitteeHot.rawValue)]
                elements.append(try authCommHot.toPrimitive())
                return .list(elements)
            case .resignCommitteeCold(let resignCommCold):
                var elements: [Primitive] = [.int(CertificateCode.resignCommitteeCold.rawValue)]
                elements.append(try resignCommCold.toPrimitive())
                return .list(elements)
            case .registerDRep(let regDRep):
                var elements: [Primitive] = [.int(CertificateCode.registerDRep.rawValue)]
                elements.append(try regDRep.toPrimitive())
                return .list(elements)
            case .unRegisterDRep(let unRegDRep):
                var elements: [Primitive] = [.int(CertificateCode.unRegisterDRep.rawValue)]
                elements.append(try unRegDRep.toPrimitive())
                return .list(elements)
            case .updateDRep(let updDRep):
                var elements: [Primitive] = [.int(CertificateCode.updateDRep.rawValue)]
                elements.append(try updDRep.toPrimitive())
                return .list(elements)
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
