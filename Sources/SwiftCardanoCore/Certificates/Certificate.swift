import Foundation
import CBORCodable
import OrderedCollections

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

public enum Certificate: Serializable {
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
    
    // MARK: - CBORSerializable
    
    public init(from primitive: Primitive) throws {
        let first: Primitive?
        switch primitive {
        case .list(let elements): first = elements.first
        case .indefiniteList(let elements): first = elements.first
        default:
            throw CardanoCoreError.deserializeError("Invalid Certificate format")
        }
        let certificateCode = try Self.code(first)
        
        switch certificateCode {
            case .stakeRegistration:
                let stakeReg = try StakeRegistration(from: primitive)
                self = .stakeRegistration(stakeReg)
            case .stakeDeregistration:
                let stakeDereg = try StakeDeregistration(from: primitive)
                self = .stakeDeregistration(stakeDereg)
            case .stakeDelegation:
                let stakeDel = try StakeDelegation(from: primitive)
                self = .stakeDelegation(stakeDel)
            case .poolRegistration:
                let poolReg = try PoolRegistration(from: primitive)
                self = .poolRegistration(poolReg)
            case .poolRetirement:
                let poolRet = try PoolRetirement(from: primitive)
                self = .poolRetirement(poolRet)
            case .genesisKeyDelegation:
                let genKeyDel = try GenesisKeyDelegation(from: primitive)
                self = .genesisKeyDelegation(genKeyDel)
            case .moveInstantaneousRewards:
                let mir = try MoveInstantaneousRewards(from: primitive)
                self = .moveInstantaneousRewards(mir)
            case .register:
                let reg = try Register(from: primitive)
                self = .register(reg)
            case .unregister:
                let unreg = try Unregister(from: primitive)
                self = .unregister(unreg)
            case .voteDelegate:
                let voteDel = try VoteDelegate(from: primitive)
                self = .voteDelegate(voteDel)
            case .stakeVoteDelegate:
                let stakeVoteDel = try StakeVoteDelegate(from: primitive)
                self = .stakeVoteDelegate(stakeVoteDel)
            case .stakeRegisterDelegate:
                let stakeRegDel = try StakeRegisterDelegate(from: primitive)
                self = .stakeRegisterDelegate(stakeRegDel)
            case .voteRegisterDelegate:
                let voteRegDel = try VoteRegisterDelegate(from: primitive)
                self = .voteRegisterDelegate(voteRegDel)
            case .stakeVoteRegisterDelegate:
                let stakeVoteRegDel = try StakeVoteRegisterDelegate(from: primitive)
                self = .stakeVoteRegisterDelegate(stakeVoteRegDel)
            case .authCommitteeHot:
                let authCommHot = try AuthCommitteeHot(from: primitive)
                self = .authCommitteeHot(authCommHot)
            case .resignCommitteeCold:
                let resignCommCold = try ResignCommitteeCold(from: primitive)
                self = .resignCommitteeCold(resignCommCold)
            case .registerDRep:
                let regDRep = try RegisterDRep(from: primitive)
                self = .registerDRep(regDRep)
            case .unRegisterDRep:
                let unRegDRep = try UnregisterDRep(from: primitive)
                self = .unRegisterDRep(unRegDRep)
            case .updateDRep:
                let updDRep = try UpdateDRep(from: primitive)
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
    
    // MARK: - JSONSerializable
    
    /// The certificate code that starts a certificate array.
    private static func code(_ primitive: Primitive?) throws -> CertificateCode {
        guard let primitive else {
            throw CardanoCoreError.deserializeError("Invalid Certificate code: empty certificate")
        }
        let code = try primitive.integer("Certificate code", as: UInt64.self)
        guard let intCode = Int(exactly: code),
              let certificateCode = CertificateCode(rawValue: intCode) else {
            throw CardanoCoreError.deserializeError("Invalid Certificate code: \(code)")
        }
        return certificateCode
    }

    /// The key of ``toDict()``'s form that holds the certificate code.
    static let dictCodeKey = "certificateCode"

    /// Reads ``toDict()``'s form: the certificate's own dict with its code
    /// under `certificateCode`.
    public static func fromDict(_ primitive: Primitive) throws -> Certificate {
        guard case let .orderedDict(entries) = primitive else {
            throw CardanoCoreError.deserializeError("Invalid Certificate dict: \(primitive)")
        }
        let certificateCode = try code(entries[.string(dictCodeKey)])
        switch certificateCode {
            case .stakeRegistration: return .stakeRegistration(try .fromDict(primitive))
            case .stakeDeregistration: return .stakeDeregistration(try .fromDict(primitive))
            case .stakeDelegation: return .stakeDelegation(try .fromDict(primitive))
            case .poolRegistration: return .poolRegistration(try .fromDict(primitive))
            case .poolRetirement: return .poolRetirement(try .fromDict(primitive))
            case .genesisKeyDelegation: return .genesisKeyDelegation(try .fromDict(primitive))
            case .moveInstantaneousRewards: return .moveInstantaneousRewards(try .fromDict(primitive))
            case .register: return .register(try .fromDict(primitive))
            case .unregister: return .unregister(try .fromDict(primitive))
            case .voteDelegate: return .voteDelegate(try .fromDict(primitive))
            case .stakeVoteDelegate: return .stakeVoteDelegate(try .fromDict(primitive))
            case .stakeRegisterDelegate: return .stakeRegisterDelegate(try .fromDict(primitive))
            case .voteRegisterDelegate: return .voteRegisterDelegate(try .fromDict(primitive))
            case .stakeVoteRegisterDelegate: return .stakeVoteRegisterDelegate(try .fromDict(primitive))
            case .authCommitteeHot: return .authCommitteeHot(try .fromDict(primitive))
            case .resignCommitteeCold: return .resignCommitteeCold(try .fromDict(primitive))
            case .registerDRep: return .registerDRep(try .fromDict(primitive))
            case .unRegisterDRep: return .unRegisterDRep(try .fromDict(primitive))
            case .updateDRep: return .updateDRep(try .fromDict(primitive))
        }
    }

    /// The certificate's own dict, with its code first under
    /// `certificateCode` so ``fromDict(_:)`` knows which certificate it is.
    public func toDict() throws -> Primitive {
        let (code, inner): (CertificateCode, Primitive)
        switch self {
            case .stakeRegistration(let c): (code, inner) = (StakeRegistration.CODE, try c.toDict())
            case .stakeDeregistration(let c): (code, inner) = (StakeDeregistration.CODE, try c.toDict())
            case .stakeDelegation(let c): (code, inner) = (StakeDelegation.CODE, try c.toDict())
            case .poolRegistration(let c): (code, inner) = (PoolRegistration.CODE, try c.toDict())
            case .poolRetirement(let c): (code, inner) = (PoolRetirement.CODE, try c.toDict())
            case .genesisKeyDelegation(let c): (code, inner) = (GenesisKeyDelegation.CODE, try c.toDict())
            case .moveInstantaneousRewards(let c): (code, inner) = (MoveInstantaneousRewards.CODE, try c.toDict())
            case .register(let c): (code, inner) = (Register.CODE, try c.toDict())
            case .unregister(let c): (code, inner) = (Unregister.CODE, try c.toDict())
            case .voteDelegate(let c): (code, inner) = (VoteDelegate.CODE, try c.toDict())
            case .stakeVoteDelegate(let c): (code, inner) = (StakeVoteDelegate.CODE, try c.toDict())
            case .stakeRegisterDelegate(let c): (code, inner) = (StakeRegisterDelegate.CODE, try c.toDict())
            case .voteRegisterDelegate(let c): (code, inner) = (VoteRegisterDelegate.CODE, try c.toDict())
            case .stakeVoteRegisterDelegate(let c): (code, inner) = (StakeVoteRegisterDelegate.CODE, try c.toDict())
            case .authCommitteeHot(let c): (code, inner) = (AuthCommitteeHot.CODE, try c.toDict())
            case .resignCommitteeCold(let c): (code, inner) = (ResignCommitteeCold.CODE, try c.toDict())
            case .registerDRep(let c): (code, inner) = (RegisterDRep.CODE, try c.toDict())
            case .unRegisterDRep(let c): (code, inner) = (UnregisterDRep.CODE, try c.toDict())
            case .updateDRep(let c): (code, inner) = (UpdateDRep.CODE, try c.toDict())
        }
        guard case let .orderedDict(fields) = inner else {
            throw CardanoCoreError.serializeError("Certificate dict is not a dict: \(inner)")
        }
        var dict = OrderedDictionary<Primitive, Primitive>()
        dict[.string(Self.dictCodeKey)] = .uint(UInt64(code.rawValue))
        for (key, value) in fields { dict[key] = value }
        return .orderedDict(dict)
    }

    public func save(to path: String, overwrite: Bool = false) throws {
        switch self {
            case .stakeRegistration(let stakeReg):
                try stakeReg.save(to: path, overwrite: overwrite)
            case .stakeDeregistration(let stakeDereg):
                try stakeDereg.save(to: path, overwrite: overwrite)
            case .stakeDelegation(let stakeDel):
                try stakeDel.save(to: path, overwrite: overwrite)
            case .poolRegistration(let poolReg):
                try poolReg.save(to: path, overwrite: overwrite)
            case .poolRetirement(let poolRet):
                try poolRet.save(to: path, overwrite: overwrite)
            case .genesisKeyDelegation(let genKeyDel):
                try genKeyDel.save(to: path, overwrite: overwrite)
            case .moveInstantaneousRewards(let mir):
                try mir.save(to: path, overwrite: overwrite)
            case .register(let reg):
                try reg.save(to: path, overwrite: overwrite)
            case .unregister(let unreg):
                try unreg.save(to: path, overwrite: overwrite)
            case .voteDelegate(let voteDel):
                try voteDel.save(to: path, overwrite: overwrite)
            case .stakeVoteDelegate(let stakeVoteDel):
                try stakeVoteDel.save(to: path, overwrite: overwrite)
            case .stakeRegisterDelegate(let stakeRegDel):
                try stakeRegDel.save(to: path, overwrite: overwrite)
            case .voteRegisterDelegate(let voteRegDel):
                try voteRegDel.save(to: path, overwrite: overwrite)
            case .stakeVoteRegisterDelegate(let stakeVoteRegDel):
                try stakeVoteRegDel.save(to: path, overwrite: overwrite)
            case .authCommitteeHot(let authCommHot):
                try authCommHot.save(to: path, overwrite: overwrite)
            case .resignCommitteeCold(let resignCommCold):
                try resignCommCold.save(to: path, overwrite: overwrite)
            case .registerDRep(let regDRep):
                try regDRep.save(to: path, overwrite: overwrite)
            case .unRegisterDRep(let unRegDRep):
                try unRegDRep.save(to: path, overwrite: overwrite)
            case .updateDRep(let updDRep):
                try updDRep.save(to: path, overwrite: overwrite)
        }
    }
    
    static func load(from path: String) throws -> Certificate {
        let jsonString = try String(contentsOfFile: path, encoding: .utf8)
        
        guard let data = jsonString.data(using: .utf8),
              let dict = try JSONSerialization.jsonObject(with: data) as? [String: String] else {
            throw CardanoCoreError.valueError("Invalid Certificate JSON")
        }
        
        guard let _ = dict["type"],
              let _ = dict["description"],
              let cborHex = dict["cborHex"] else {
            throw CardanoCoreError.valueError("Invalid Dictionary")
        }
        
        guard let cborData = Data(hexString: cborHex) else {
            throw CardanoCoreError.valueError("Invalid Certificate cborHex")
        }
        let cbor = try CBORSerialization.cbor(from: cborData)
        
        if case let .array(cborArray) = cbor,
            case let .unsignedInt(code) = cborArray.first {
            
            let certificateCode = Int(exactly: code).flatMap { CertificateCode(rawValue: $0) }
            
            switch certificateCode {
                case .stakeRegistration:
                    return .stakeRegistration(
                        try StakeRegistration.load(from: path)
                    )
                case .stakeDeregistration:
                    return .stakeDeregistration(
                        try StakeDeregistration.load(from: path)
                    )
                case .stakeDelegation:
                    return .stakeDelegation(
                        try StakeDelegation.load(from: path)
                    )
                case .poolRegistration:
                    return .poolRegistration(
                        try PoolRegistration.load(from: path)
                    )
                case .poolRetirement:
                    return .poolRetirement(
                        try PoolRetirement.load(from: path)
                    )
                case .genesisKeyDelegation:
                    return .genesisKeyDelegation(
                        try GenesisKeyDelegation.load(from: path)
                    )
                case .moveInstantaneousRewards:
                    return .moveInstantaneousRewards(
                        try MoveInstantaneousRewards.load(from: path)
                    )
                case .register:
                    return .register(
                        try Register.load(from: path)
                    )
                case .unregister:
                    return .unregister(
                        try Unregister.load(from: path)
                    )
                case .voteDelegate:
                    return .voteDelegate(
                        try VoteDelegate.load(from: path)
                    )
                case .stakeVoteDelegate:
                    return .stakeVoteDelegate(
                        try StakeVoteDelegate.load(from: path)
                    )
                case .stakeRegisterDelegate:
                    return .stakeRegisterDelegate(
                        try StakeRegisterDelegate.load(from: path)
                    )
                case .voteRegisterDelegate:
                    return .voteRegisterDelegate(
                        try VoteRegisterDelegate.load(from: path)
                    )
                case .stakeVoteRegisterDelegate:
                    return .stakeVoteRegisterDelegate(
                        try StakeVoteRegisterDelegate.load(from: path)
                    )
                case .authCommitteeHot:
                    return .authCommitteeHot(
                        try AuthCommitteeHot.load(from: path)
                    )
                case .resignCommitteeCold:
                    return .resignCommitteeCold(
                        try ResignCommitteeCold.load(from: path)
                    )
                case .registerDRep:
                    return .registerDRep(
                        try RegisterDRep.load(from: path)
                    )
                case .unRegisterDRep:
                    return .unRegisterDRep(
                        try UnregisterDRep.load(from: path)
                    )
                case .updateDRep:
                    return .updateDRep(
                        try UpdateDRep.load(from: path)
                    )
                case .none:
                    throw CardanoCoreError.valueError("Unknown Certificate code: \(code)")
            }
        } else {
            throw CardanoCoreError.deserializeError("Invalid CBOR format: \(cbor)")
        }
    }
}

public protocol CertificateSerializable: TextEnvelopable, JSONSerializable, Sendable {
    static var CODE: CertificateCode { get }
    
    var type: String { get }
    var description: String { get }
}

public extension CertificateSerializable {
    /// Serialize to JSON.
    ///
    /// The json output has three fields: "type", "description", and "cborHex".
    /// - Returns: JSON representation
    func toTextEnvelope() throws -> String? {
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
