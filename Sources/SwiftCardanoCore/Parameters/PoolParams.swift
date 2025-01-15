import Foundation
import FractionNumber
import Network

func isBech32CardanoPoolId(_ poolId: String?) -> Bool {
    guard let poolId = poolId, poolId.hasPrefix("pool") else {
        return false
    }
     let decoded = try? Bech32().bech32Decode(poolId)
    return decoded != nil
}

struct PoolId: Codable, CustomStringConvertible, CustomDebugStringConvertible {

    var description: String { return value }

    var debugDescription: String { return value }

    let value: String
    
    init(value: String) throws {
        guard isBech32CardanoPoolId(value) else {
            throw CardanoCoreError.valueError("Invalid PoolId format. The PoolId should be a valid Cardano stake pool ID in bech32 format.")
        }
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        try self.init(value: value)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
    
//    func toShallowPrimitive() -> Any {
//        return value
//    }
//    
//    func toPrimitive() -> String {
//        return value
//    }
//
//    static func fromPrimitive<T>(_ value: Any) throws -> T  {
//        return try PoolId(value: value as! String) as! T
//    }
    
    // CBOR Serialization
//    func toCBOR() -> [Any] {
//        return [value]
//    }
//    
//    static func fromCBOR(_ values: [Any]) throws -> PoolId {
//        guard let value = values.first as? String else {
//            throw CardanoCoreError.deserializeError("Failed to deserialize PoolId from CBOR.")
//        }
//        return try PoolId(value: value)
//    }
}

struct SingleHostAddr: Codable {
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
    
    func toShallowPrimitive() -> Any {
        return [
            code,
            port as Any,
            ipv4?.rawValue as Any,
            ipv6?.rawValue as Any
        ]
    }
    
//    func toPrimitive() -> [Any?] {
//        return [
//            code,
//            port ?? nil,
//            ipv4?.rawValue ?? nil,
//            ipv6?.rawValue ?? nil
//        ]
//    }
    
//    static func fromPrimitive<T>(_ value: Any) throws -> T {
//        var code: Int
//        var port: Int?
//        var ipv4Raw: Any?
//        var ipv6Raw: Any?
//        var ipv4: IPv4Address?
//        var ipv6: IPv6Address?
//        
//        if let list = value as? [Any] {
//            code = list[0] as! Int
//            port = list[1] as? Int
//            ipv4Raw = list[2]
//            ipv6Raw = list[3]
//        } else if let tuple = value as? (Any, Any, Any, Any) {
//            code = tuple.0 as! Int
//            port = tuple.1 as? Int
//            ipv4Raw = tuple.2
//            ipv6Raw = tuple.3
//        }else {
//            throw CardanoCoreError.deserializeError("Invalid SingleHostAddr data: \(value)")
//        }
//        
//        guard code == 0 else {
//            throw CardanoCoreError.deserializeError("Invalid SingleHostAddr type: \(code)")
//        }
//        
//        if let ipv4String = ipv4Raw as? String {
//            ipv4 = IPv4Address(ipv4String)
//        } else if let ipv4Data = ipv4Raw as? Data {
//            ipv4 = IPv4Address(ipv4Data)
//        }
//        
//        if let ipv6String = ipv6Raw as? String {
//            ipv6 = IPv6Address(ipv6String)
//        } else if let ipv6Data = ipv6Raw as? Data {
//            ipv6 = IPv6Address(ipv6Data)
//        }
//        
//        return SingleHostAddr(
//            port: port,
//            ipv4: ipv4,
//            ipv6: ipv6
//        ) as! T
//    }
}

struct SingleHostName: Codable {
    public var code: Int { get { return 1 } }
    
    let port: Int?
    let dnsName: String?
    
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
    
//    func toShallowPrimitive() -> Any {
//        return [
//            code,
//            port as Any,
//            dnsName as Any
//        ]
//    }
//    
//    static func fromPrimitive<T>(_ value: Any) throws -> T {
//        var code: Int
//        var port: Int?
//        var dnsName: String?
//        
//        if let list = value as? [Any] {
//            code = list[0] as! Int
//            port = list[1] as? Int
//            dnsName = list[2] as? String
//        } else if let tuple = value as? (Any, Any, Any) {
//            code = tuple.0 as! Int
//            port = tuple.1 as? Int
//            dnsName = tuple.2 as? String
//        } else {
//            throw CardanoCoreError.deserializeError("Invalid SingleHostName data: \(value)")
//        }
//        
//        guard code == 1 else {
//            throw CardanoCoreError.deserializeError("Invalid SingleHostName type: \(code)")
//        }
//        
//        return SingleHostName(
//            port: port,
//            dnsName: dnsName
//        ) as! T
//    }
}

struct MultiHostName: Codable {
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
    
//    func toShallowPrimitive() -> Any {
//        return [
//            code,
//            dnsName as Any
//        ]
//    }
//    
//    static func fromPrimitive<T>(_ value: Any) throws -> T {
//        var code: Int
//        var dnsName: String?
//        
//        if let list = value as? [Any] {
//            code = list[0] as! Int
//            dnsName = list[1] as? String
//        } else if let tuple = value as? (Any, Any, Any) {
//            code = tuple.0 as! Int
//            dnsName = tuple.1 as? String
//        } else {
//            throw CardanoCoreError.deserializeError("Invalid MultiHostName data: \(value)")
//        }
//        
//        guard code == 2 else {
//            throw CardanoCoreError.deserializeError("Invalid MultiHostName type: \(code)")
//        }
//        
//        return MultiHostName(
//            dnsName: dnsName
//        ) as! T
//    }
}

enum Relay: Codable {
    case singleHostAddr(SingleHostAddr)
    case singleHostName(SingleHostName)
    case multiHostName(MultiHostName)
    
//    static func fromPrimitive<T>(_ value: Any) throws -> T {
//        if let singleHostAddr: SingleHostAddr = try? SingleHostAddr.fromPrimitive(value) {
//            return Relay.singleHostAddr(singleHostAddr) as! T
//        } else if let singleHostName: SingleHostName = try? SingleHostName.fromPrimitive(value) {
//            return Relay.singleHostName(singleHostName) as! T
//        } else if let multiHostName: MultiHostName = try? MultiHostName.fromPrimitive(value) {
//            return Relay.multiHostName(multiHostName) as! T
//        } else {
//            throw CardanoCoreError.deserializeError("Invalid Relay data: \(value)")
//        }
//    }
}

struct PoolMetadata: Codable {
    let url: String
    let poolMetadataHash: PoolMetadataHash
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        url = try container.decode(String.self)
        poolMetadataHash = try container.decode(PoolMetadataHash.self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(url)
        try container.encode(poolMetadataHash)
    }
    
//    static func fromPrimitive<T>(_ value: Any) throws -> T {
//        let url: String
//        let poolMetadataHash: PoolMetadataHash
//        
//        if let list = value as? [Any] {
//            url = list[0] as! String
//            poolMetadataHash = try PoolMetadataHash.fromPrimitive(list[1])
//        } else if let tuple = value as? (Any, Any) {
//            url = tuple.0 as! String
//            poolMetadataHash = try PoolMetadataHash.fromPrimitive(tuple.1)
//        } else {
//            throw CardanoCoreError.deserializeError("Invalid PoolMetadata data: \(value)")
//        }
//        
//        return PoolMetadata(
//            url: url,
//            poolMetadataHash: poolMetadataHash
//        ) as! T
//    }
}


struct PoolParams: Codable {
    let poolOperator: PoolKeyHash
    let vrfKeyHash: VrfKeyHash
    let pledge: Int
    let cost: Int
    let margin: FractionNumber
    let rewardAccount: RewardAccountHash
    let poolOwners: [VerificationKeyHash]
    let relays: [Relay]?
    let poolMetadata: PoolMetadata?
    let id: PoolId?
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        
        poolOperator = try container.decode(PoolKeyHash.self)
        vrfKeyHash = try container.decode(VrfKeyHash.self)
        pledge = try container.decode(Int.self)
        cost = try container.decode(Int.self)
        margin = try container.decode(FractionNumber.self)
        rewardAccount = try container.decode(RewardAccountHash.self)
        poolOwners = try container.decode([VerificationKeyHash].self)
        relays = try container.decodeIfPresent([Relay].self)
        poolMetadata = try container.decodeIfPresent(PoolMetadata.self)
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
    
//    static func fromPrimitive<T>(_ value: Any) throws -> T {
//        let poolOperator: PoolKeyHash
//        let vrfKeyHash: VrfKeyHash
//        let pledge: Int
//        let cost: Int
//        let margin: FractionNumber
//        let rewardAccount: RewardAccountHash
//        let poolOwners: [VerificationKeyHash]
//        let relays: [Relay]?
//        let poolMetadata: PoolMetadata?
//        let id: PoolId? = nil
//        
//        if let list = value as? [Any] {
//            poolOperator = try PoolKeyHash.fromPrimitive(list[0])
//            vrfKeyHash = try VrfKeyHash.fromPrimitive(list[1])
//            pledge = list[2] as! Int
//            cost = list[3] as! Int
//            margin = FractionNumber(
//                numerator: (list[4] as! (Any, Any)).0 as! Int,
//                denominator: (list[4] as! (Any, Any)).1 as! Int
//            )!
//            rewardAccount = try RewardAccountHash.fromPrimitive(list[5])
//            poolOwners = (list[6] as! [Any]).map {
//                try! VerificationKeyHash.fromPrimitive($0)
//            }
//            relays = (list[6] as! [Any]).map {
//                try! Relay.fromPrimitive($0)
//            }
//            poolMetadata = try PoolMetadata.fromPrimitive(list[8])
//        } else if let tuple = value as? (Any, Any, Any, Any, Any, Any, Any, Any, Any) {
//            poolOperator = try PoolKeyHash.fromPrimitive(tuple.0)
//            vrfKeyHash = try VrfKeyHash.fromPrimitive(tuple.1)
//            pledge = tuple.2 as! Int
//            cost = tuple.3 as! Int
//            margin = FractionNumber(
//                numerator: (tuple.4 as! (Any, Any)).0 as! Int,
//                denominator: (tuple.4 as! (Any, Any)).1 as! Int
//            )!
//            rewardAccount = try RewardAccountHash.fromPrimitive(tuple.5)
//            poolOwners = (tuple.6 as! [Any]).map {
//                try! VerificationKeyHash.fromPrimitive($0)
//            }
//            relays = (tuple.7 as! [Any]).map {
//                try! Relay.fromPrimitive($0)
//            }
//            poolMetadata = try PoolMetadata.fromPrimitive(tuple.8)
//        } else {
//            throw CardanoCoreError.deserializeError("Invalid PoolParams data: \(value)")
//        }
//        
//        return PoolParams(
//            poolOperator: poolOperator,
//            vrfKeyHash: vrfKeyHash,
//            pledge: pledge,
//            cost: cost,
//            margin: margin,
//            rewardAccount: rewardAccount,
//            poolOwners: poolOwners,
//            relays: relays,
//            poolMetadata: poolMetadata,
//            id: id
//        ) as! T
//    }
}
