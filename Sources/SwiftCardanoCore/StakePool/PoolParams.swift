import Foundation
import PotentCBOR
import PotentCodables
import FractionNumber
import Network


struct SingleHostAddr: Codable, Equatable, Hashable {
    public var code: Int { get { return 0 } }

    let port: Int?
    let ipv4: IPv4Address?
    let ipv6: IPv6Address?
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)
        
        guard code == 0 else {
            throw CardanoCoreError.deserializeError("Invalid SingleHostAddr type: \(code)")
        }
        
        port = try container.decodeIfPresent(Int.self)
        ipv4 = try container.decodeIfPresent(IPv4Address.self)
        ipv6 = try container.decodeIfPresent(IPv6Address.self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(code)
        try container.encode(port)
        try container.encode(ipv4)
        try container.encode(ipv6)
    }
}

struct SingleHostName: Codable, Equatable, Hashable {
    public var code: Int { get { return 1 } }
    
    let port: Int?
    let dnsName: String?
    
    init(port: Int?, dnsName: String?) {
        self.port = port
        self.dnsName = dnsName
    }
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)
        
        guard code == 1 else {
            throw CardanoCoreError.deserializeError("Invalid SingleHostName type: \(code)")
        }
        
        port = try container.decodeIfPresent(Int.self)
        dnsName = try container.decodeIfPresent(String.self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(code)
        try container.encode(port)
        try container.encode(dnsName)
    }
}

struct MultiHostName: Codable, Equatable, Hashable {
    public var code: Int { get { return 2 } }
    let dnsName: String?
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)
        
        guard code == 2 else {
            throw CardanoCoreError.deserializeError("Invalid MultiHostName type: \(code)")
        }
        
        dnsName = try container.decodeIfPresent(String.self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(code)
        try container.encode(dnsName)
    }
}

enum Relay: Codable, Equatable, Hashable {
    case singleHostAddr(SingleHostAddr)
    case singleHostName(SingleHostName)
    case multiHostName(MultiHostName)
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)
        
        switch code {
            case 0:
                self = .singleHostAddr(try SingleHostAddr(from: decoder))
            case 1:
                self = .singleHostName(try SingleHostName(from: decoder))
            case 2:
                self = .multiHostName(try MultiHostName(from: decoder))
            default:
                throw CardanoCoreError.deserializeError("Invalid Relay type: \(code)")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        switch self {
            case .singleHostAddr(let value):
                try value.encode(to: encoder)
            case .singleHostName(let value):
                try value.encode(to: encoder)
            case .multiHostName(let value):
                try value.encode(to: encoder)
        }
    }
}

//struct PoolOwners: Codable, Equatable, Hashable {
//    let addressKeyHashes: Set<VerificationKeyHash>
//    
//    init(addressKeyHashes: Set<VerificationKeyHash>) {
//        self.addressKeyHashes = addressKeyHashes
//    }
//    
//    init(from decoder: Decoder) throws {
//        let container = try decoder.singleValueContainer()
//        let cborData = try container.decode(AnyValue.self)
//        
//        switch cborData {
//            case .array(let array):
//                var set = Set<VerificationKeyHash>()
//                array.forEach {
//                    if let data = $0.dataValue {
//                        set.insert(VerificationKeyHash(payload: data))
//                    }
//                }
//                addressKeyHashes = set
//            default:
//                throw CardanoCoreError.decodingError("Invalid PoolOwners data")
//        }
//    }
//    
//    func encode(to encoder: Encoder) throws {
//        var container = encoder.singleValueContainer()
//        try container.encode(addressKeyHashes)
//    }
//}

struct PoolParams: Codable, Equatable, Hashable {
    let poolOperator: PoolKeyHash
    let vrfKeyHash: VrfKeyHash
    let pledge: Int
    let cost: Int
    let margin: UnitInterval
    let rewardAccount: RewardAccountHash
    let poolOwners: CBORSet<VerificationKeyHash>
    let relays: [Relay]?
    let poolMetadata: PoolMetadata?
    let id: PoolId?
    
    init(
        poolOperator: PoolKeyHash,
        vrfKeyHash: VrfKeyHash,
        pledge: Int,
        cost: Int,
        margin: UnitInterval,
        rewardAccount: RewardAccountHash,
        poolOwners: CBORSet<VerificationKeyHash>,
        relays: [Relay]?,
        poolMetadata: PoolMetadata?,
        id: PoolId?
    ) {
        self.poolOperator = poolOperator
        self.vrfKeyHash = vrfKeyHash
        self.pledge = pledge
        self.cost = cost
        self.margin = margin
        self.rewardAccount = rewardAccount
        self.poolOwners = poolOwners
        self.relays = relays
        self.poolMetadata = poolMetadata
        self.id = id
    }
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        
        poolOperator = try container.decode(PoolKeyHash.self)
        vrfKeyHash = try container.decode(VrfKeyHash.self)
        pledge = try container.decode(Int.self)
        cost = try container.decode(Int.self)
        margin = try container.decode(UnitInterval.self)
        rewardAccount = try container.decode(RewardAccountHash.self)
        poolOwners = try container.decode(CBORSet<VerificationKeyHash>.self)
        relays = try container.decode([Relay].self)
        poolMetadata = try container.decode(PoolMetadata.self)
        id = nil
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(poolOperator)
        try container.encode(vrfKeyHash)
        try container.encode(pledge)
        try container.encode(cost)
        try container.encode(margin)
        try container.encode(rewardAccount)
        try container.encode(poolOwners)
        try container.encode(relays)
        try container.encode(poolMetadata)
    }
}
