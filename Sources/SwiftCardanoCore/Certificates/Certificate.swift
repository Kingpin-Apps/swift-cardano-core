import Foundation
import PotentCBOR

enum CertificateType: String, Codable {
    case shelley = "CertificateShelley"
    case conway = "CertificateConway"
}

enum CertificateCode: Int, Codable {
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

enum CertificateDescription: String, Codable {
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
    case stakeRegisterDelegate = "Stake address registration and stake delegation Certificate"
    case voteRegisterDelegate = "Stake address registration and vote delegation Certificate"
    case stakeVoteRegisterDelegate = "Stake address registration delegation and vote delegation Certificate"
    case authCommitteeHot = "Constitutional Committee Hot Key Registration Certificate"
    case resignCommitteeCold = "Constitutional Committee Cold Key Resignation Certificate"
    case registerDRep = "DRep Registration Certificate"
    case unRegisterDRep = "DRep Retirement Certificate"
    case updateDRep = "DRep Update Certificate"
}

enum Certificate: Codable {
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
}

protocol CertificateSerializable: PayloadJSONSerializable {
    static var CODE: CertificateCode { get }
    
    var type: String { get }
    var description: String { get }
}

extension CertificateSerializable {
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
