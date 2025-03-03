import Foundation
import PotentCBOR
import PotentCodables
import FractionNumber
import Network


public struct SingleHostAddr: Codable, Equatable, Hashable {
    public var code: Int { get { return 0 } }

    public let port: Int?
    public let ipv4: IPv4Address?
    public let ipv6: IPv6Address?
    
    public init(port: Int?, ipv4: IPv4Address?, ipv6: IPv6Address?) {
        self.port = port
        self.ipv4 = ipv4
        self.ipv6 = ipv6
    }
    
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)
        
        guard code == 0 else {
            throw CardanoCoreError.deserializeError("Invalid SingleHostAddr type: \(code)")
        }
        
        port = try container.decodeIfPresent(Int.self)
        ipv4 = try container.decodeIfPresent(IPv4Address.self)
        ipv6 = try container.decodeIfPresent(IPv6Address.self)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(code)
        try container.encode(port)
        try container.encode(ipv4)
        try container.encode(ipv6)
    }
}

public struct SingleHostName: Codable, Equatable, Hashable {
    public var code: Int { get { return 1 } }
    
    public let port: Int?
    public let dnsName: String?
    
    public init(port: Int?, dnsName: String?) {
        self.port = port
        self.dnsName = dnsName
    }
    
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)
        
        guard code == 1 else {
            throw CardanoCoreError.deserializeError("Invalid SingleHostName type: \(code)")
        }
        
        port = try container.decodeIfPresent(Int.self)
        dnsName = try container.decodeIfPresent(String.self)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(code)
        try container.encode(port)
        try container.encode(dnsName)
    }
}

public struct MultiHostName: Codable, Equatable, Hashable {
    public var code: Int { get { return 2 } }
    public let dnsName: String?
    
    public init(dnsName: String?) {
        self.dnsName = dnsName
    }
    
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)
        
        guard code == 2 else {
            throw CardanoCoreError.deserializeError("Invalid MultiHostName type: \(code)")
        }
        
        dnsName = try container.decodeIfPresent(String.self)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(code)
        try container.encode(dnsName)
    }
}

public enum Relay: Codable, Equatable, Hashable {
    case singleHostAddr(SingleHostAddr)
    case singleHostName(SingleHostName)
    case multiHostName(MultiHostName)
    
    public init(from decoder: Decoder) throws {
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
    
    public func encode(to encoder: Encoder) throws {
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

public struct PoolParams: Codable, Equatable, Hashable {
    public let poolOperator: PoolKeyHash
    public let vrfKeyHash: VrfKeyHash
    public let pledge: Int
    public let cost: Int
    public let margin: UnitInterval
    public let rewardAccount: RewardAccountHash
    public let poolOwners: CBORSet<VerificationKeyHash>
    public let relays: [Relay]?
    public let poolMetadata: PoolMetadata?
    public let id: PoolId?
    
    public init(
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
    
    public init(from decoder: Decoder) throws {
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
    
    public func encode(to encoder: Encoder) throws {
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
