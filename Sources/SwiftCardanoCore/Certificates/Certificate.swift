import Foundation
import PotentCBOR

enum CertificateType: String, Codable {
    case shelley = "CertificateShelley"
    case conway = "CertificateConway"
}

protocol CertificateSerializable {
    static var TYPE: String { get }
    static var DESCRIPTION: String { get }
    var type: String { get }
    var description: String { get }
}


enum CertificateDescription: String, Codable {
    case stakeRegistration = "Stake Address Registration Certificate"
    case stakeDeregistration = "Stake Address Deregistration Certificate"
    case stakeDelegation = "Stake Delegation Certificate"
    case poolRegistration = "Stake Pool Registration Certificate"
    case poolRetirement = "Stake Pool Retirement Certificate"
    case genesisKeyDelegation = "Genesis Key Delegation Certificate"
    case moveInstantaneousRewards = "Move Instantaneous Rewards Certificate"
    case register = "Registration Certificate"
    case unregister = "Stake Address Retirement Certificate"
    case voteDelegate = "Vote Delegation Certificate"
    case stakeVoteDelegate = "Stake and Vote Delegation Certificate"
    case stakeRegisterDelegate = "Stake address registration and stake delegation Certificate"
    case voteRegisterDelegate = "Stake address registration and vote delegation Certificate"
    case stakeVoteRegisterDelegate = "Stake address registration and vote delegation Certificate"
    case authCommitteeHot = "Constitutional Committee Hot Key Registration Certificate"
    case resignCommitteeCold = "Constitutional Committee Hot Key Retirement Certificate"
    case registerDRep = "DRep Key Registration Certificate"
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
    
    func toCertificateJSON() -> CertificateJSON {
        let cbor: Data
        let cert: CertificateSerializable
        
        switch self {
            case .stakeRegistration(let value):
                cbor = try! CBOREncoder().encode(value)
                cert = value
            case .stakeDeregistration(let value):
                cbor = try! CBOREncoder().encode(value)
                cert = value
            case .stakeDelegation(let value):
                cbor = try! CBOREncoder().encode(value)
                cert = value
            case .poolRegistration(let value):
                cbor = try! CBOREncoder().encode(value)
                cert = value
            case .poolRetirement(let value):
                cbor = try! CBOREncoder().encode(value)
                cert = value
            case .genesisKeyDelegation(let value):
                cbor = try! CBOREncoder().encode(value)
                cert = value
            case .moveInstantaneousRewards(let value):
                cbor = try! CBOREncoder().encode(value)
                cert = value
            case .register(let value):
                cbor = try! CBOREncoder().encode(value)
                cert = value
            case .unregister(let value):
                cbor = try! CBOREncoder().encode(value)
                cert = value
            case .voteDelegate(let value):
                cbor = try! CBOREncoder().encode(value)
                cert = value
            case .stakeVoteDelegate(let value):
                cbor = try! CBOREncoder().encode(value)
                cert = value
            case .stakeRegisterDelegate(let value):
                cbor = try! CBOREncoder().encode(value)
                cert = value
            case .voteRegisterDelegate(let value):
                cbor = try! CBOREncoder().encode(value)
                cert = value
            case .stakeVoteRegisterDelegate(let value):
                cbor = try! CBOREncoder().encode(value)
                cert = value
            case .authCommitteeHot(let value):
                cbor = try! CBOREncoder().encode(value)
                cert = value
            case .resignCommitteeCold(let value):
                cbor = try! CBOREncoder().encode(value)
                cert = value
            case .registerDRep(let value):
                cbor = try! CBOREncoder().encode(value)
                cert = value
            case .unRegisterDRep(let value):
                cbor = try! CBOREncoder().encode(value)
                cert = value
            case .updateDRep(let value):
                cbor = try! CBOREncoder().encode(value)
                cert = value
        }
        
        return CertificateJSON(
            payload: cbor,
            type: cert.type,
            description: cert.description
        )
    }
    
    static func fromCertificateJSON(_ json: CertificateJSON) throws -> Certificate {
        let decoded = try CBORDecoder().decode(Credential.self, from: json.payload)
        let cbor = CBORDecoder().decode(from: json.payload, using: <#_#>)
    }
}

class CertificateJSON: PayloadJSONSerializable {
    class var TYPE: String  { return CertificateType.conway.rawValue }
    class var DESCRIPTION: String { return "Certificate" }

    internal var _payload: Data
    internal var _type: String
    internal var _description: String
    
    required init(payload: Data) {
        self._payload = payload
        self._type = Self.TYPE
        self._description = Self.DESCRIPTION
    }
    
    required init(
        payload: Data,
        type: String? = nil,
        description: String? = nil
    ) {
        self._payload = payload
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
    }
}


