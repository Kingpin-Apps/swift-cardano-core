import Foundation
import PotentCBOR


protocol CertificateSerializable {
    static var TYPE: String { get }
    static var DESCRIPTION: String { get }
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
    case unRegisterDRep(UnRegisterDRep)
    case updateDRep(UpdateDRep)
    
    func toJSON() -> CertificateJSON {
        switch self {
            case .stakeRegistration(let value):
                let cbor = try! CBOREncoder().encode(value)
                return CertificateJSON(
                    payload: cbor,
                    type: StakeRegistration.TYPE,
                    description: StakeRegistration.DESCRIPTION
                )
            case .stakeDeregistration(let value):
                let cbor = try! CBOREncoder().encode(value)
                return CertificateJSON(
                    payload: cbor,
                    type: StakeDeregistration.TYPE,
                    description: StakeDeregistration.DESCRIPTION
                )
            case .stakeDelegation(let value):
                let cbor = try! CBOREncoder().encode(value)
                return CertificateJSON(
                    payload: cbor,
                    type: StakeDelegation.TYPE,
                    description: StakeDelegation.DESCRIPTION
                )
            case .poolRegistration(let value):
                let cbor = try! CBOREncoder().encode(value)
                return CertificateJSON(
                    payload: cbor,
                    type: PoolRegistration.TYPE,
                    description: PoolRegistration.DESCRIPTION
                )
            case .poolRetirement(let value):
                let cbor = try! CBOREncoder().encode(value)
                return CertificateJSON(
                    payload: cbor,
                    type: PoolRetirement.TYPE,
                    description: PoolRetirement.DESCRIPTION
                )
            case .genesisKeyDelegation(let value):
                let cbor = try! CBOREncoder().encode(value)
                return CertificateJSON(
                    payload: cbor,
                    type: GenesisKeyDelegation.TYPE,
                    description: GenesisKeyDelegation.DESCRIPTION
                )
            case .moveInstantaneousRewards(let value):
                let cbor = try! CBOREncoder().encode(value)
                return CertificateJSON(
                    payload: cbor,
                    type: MoveInstantaneousRewards.TYPE,
                    description: MoveInstantaneousRewards.DESCRIPTION
                )
            case .register(let value):
                let cbor = try! CBOREncoder().encode(value)
                return CertificateJSON(
                    payload: cbor,
                    type: Register.TYPE,
                    description: Register.DESCRIPTION
                )
            case .unregister(let value):
                let cbor = try! CBOREncoder().encode(value)
                return CertificateJSON(
                    payload: cbor,
                    type: Unregister.TYPE,
                    description: Unregister.DESCRIPTION
                )
            case .voteDelegate(let value):
                let cbor = try! CBOREncoder().encode(value)
                return CertificateJSON(
                    payload: cbor,
                    type: VoteDelegate.TYPE,
                    description: VoteDelegate.DESCRIPTION
                )
            case .stakeVoteDelegate(let value):
                let cbor = try! CBOREncoder().encode(value)
                return CertificateJSON(
                    payload: cbor,
                    type: StakeVoteDelegate.TYPE,
                    description: StakeVoteDelegate.DESCRIPTION
                )
            case .stakeRegisterDelegate(let value):
                let cbor = try! CBOREncoder().encode(value)
                return CertificateJSON(
                    payload: cbor,
                    type: StakeRegisterDelegate.TYPE,
                    description: StakeRegisterDelegate.DESCRIPTION
                )
            case .voteRegisterDelegate(let value):
                let cbor = try! CBOREncoder().encode(value)
                return CertificateJSON(
                    payload: cbor,
                    type: VoteRegisterDelegate.TYPE,
                    description: VoteRegisterDelegate.DESCRIPTION
                )
            case .stakeVoteRegisterDelegate(let value):
                let cbor = try! CBOREncoder().encode(value)
                return CertificateJSON(
                    payload: cbor,
                    type: StakeVoteRegisterDelegate.TYPE,
                    description: StakeVoteRegisterDelegate.DESCRIPTION
                )
            case .authCommitteeHot(let value):
                let cbor = try! CBOREncoder().encode(value)
                return CertificateJSON(
                    payload: cbor,
                    type: AuthCommitteeHot.TYPE,
                    description: AuthCommitteeHot.DESCRIPTION
                )
            case .resignCommitteeCold(let value):
                let cbor = try! CBOREncoder().encode(value)
                return CertificateJSON(
                    payload: cbor,
                    type: ResignCommitteeCold.TYPE,
                    description: ResignCommitteeCold.DESCRIPTION
                )
            case .registerDRep(let value):
                let cbor = try! CBOREncoder().encode(value)
                return CertificateJSON(
                    payload: cbor,
                    type: RegisterDRep.TYPE,
                    description: RegisterDRep.DESCRIPTION
                )
            case .unRegisterDRep(let value):
                let cbor = try! CBOREncoder().encode(value)
                return CertificateJSON(
                    payload: cbor,
                    type: UnRegisterDRep.TYPE,
                    description: UnRegisterDRep.DESCRIPTION
                )
            case .updateDRep(let value):
                let cbor = try! CBOREncoder().encode(value)
                return CertificateJSON(
                    payload: cbor,
                    type: UpdateDRep.TYPE,
                    description: UpdateDRep.DESCRIPTION
                )
                    
        }
    }
}

class CertificateJSON: PayloadJSONSerializable {
    class var TYPE: String  { return "CertificateShelley" }
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


