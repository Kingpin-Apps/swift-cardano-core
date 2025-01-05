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

struct PoolId: CBORSerializable, CustomStringConvertible, CustomDebugStringConvertible {
    var description: String { return value }

    var debugDescription: String { return value }

    let value: String
    
    init(value: String) throws {
        guard isBech32CardanoPoolId(value) else {
            throw CardanoException.valueError("Invalid PoolId format. The PoolId should be a valid Cardano stake pool ID in bech32 format.")
        }
        self.value = value
    }
    
    func toPrimitive() -> String {
        return value
    }
    
    static func fromPrimitive(_ value: String) throws -> PoolId {
        return try PoolId(value: value)
    }
    
    // CBOR Serialization
    func toCBOR() -> [Any] {
        return [value]
    }
    
    static func fromCBOR(_ values: [Any]) throws -> PoolId {
        guard let value = values.first as? String else {
            throw CardanoException.deserializeException("Failed to deserialize PoolId from CBOR.")
        }
        return try PoolId(value: value)
    }
}

struct SingleHostAddr: CBORSerializable {
    public var code: Int { get { return 0 } }

    let port: Int?
    let ipv4: IPv4Address?
    let ipv6: IPv6Address?
    
    func toPrimitive() -> [Any?] {
        return [
            code,
            port ?? nil,
            ipv4?.rawValue ?? nil,
            ipv6?.rawValue ?? nil
        ]
    }
    
    static func fromPrimitive(_ value: Any) throws -> SingleHostAddr {
        var code: Int
        var port: Int?
        var ipv4Raw: Any?
        var ipv6Raw: Any?
        var ipv4: IPv4Address?
        var ipv6: IPv6Address?
        
        if let list = value as? [Any] {
            code = list[0] as! Int
            port = list[1] as? Int
            ipv4Raw = list[2]
            ipv6Raw = list[3]
        } else if let tuple = value as? (Any, Any, Any, Any) {
            code = tuple.0 as! Int
            port = tuple.1 as? Int
            ipv4Raw = tuple.2
            ipv6Raw = tuple.3
        }else {
            throw CardanoException.deserializeException("Invalid SingleHostAddr data: \(value)")
        }
        
        guard code == 0 else {
            throw CardanoException.deserializeException("Invalid SingleHostAddr type: \(code)")
        }
        
        if let ipv4String = ipv4Raw as? String {
            ipv4 = IPv4Address(ipv4String)
        } else if let ipv4Data = ipv4Raw as? Data {
            ipv4 = IPv4Address(ipv4Data)
        }
        
        if let ipv6String = ipv6Raw as? String {
            ipv6 = IPv6Address(ipv6String)
        } else if let ipv6Data = ipv6Raw as? Data {
            ipv6 = IPv6Address(ipv6Data)
        }
        
        return SingleHostAddr(
            port: port,
            ipv4: ipv4,
            ipv6: ipv6
        )
    }
}

struct SingleHostName: CBORSerializable {
    public var code: Int { get { return 1 } }
    
    let port: Int?
    let dnsName: String?
    
    static func fromPrimitive(_ value: Any) throws -> SingleHostName {
        var code: Int
        var port: Int?
        var dnsName: String?
        
        if let list = value as? [Any] {
            code = list[0] as! Int
            port = list[1] as? Int
            dnsName = list[2] as? String
        } else if let tuple = value as? (Any, Any, Any) {
            code = tuple.0 as! Int
            port = tuple.1 as? Int
            dnsName = tuple.2 as? String
        } else {
            throw CardanoException.deserializeException("Invalid SingleHostName data: \(value)")
        }
        
        guard code == 1 else {
            throw CardanoException.deserializeException("Invalid SingleHostName type: \(code)")
        }
        
        return SingleHostName(
            port: port,
            dnsName: dnsName
        )
    }
}

struct MultiHostName: CBORSerializable {
    public var code: Int { get { return 2 } }
    let dnsName: String?
    
    static func fromPrimitive(_ value: Any) throws -> MultiHostName {
        var code: Int
        var dnsName: String?
        
        if let list = value as? [Any] {
            code = list[0] as! Int
            dnsName = list[1] as? String
        } else if let tuple = value as? (Any, Any, Any) {
            code = tuple.0 as! Int
            dnsName = tuple.1 as? String
        } else {
            throw CardanoException.deserializeException("Invalid MultiHostName data: \(value)")
        }
        
        guard code == 2 else {
            throw CardanoException.deserializeException("Invalid MultiHostName type: \(code)")
        }
        
        return MultiHostName(
            dnsName: dnsName
        )
    }
}

enum Relay: CBORSerializable {
    case singleHostAddr(SingleHostAddr)
    case singleHostName(SingleHostName)
    case multiHostName(MultiHostName)
}

struct PoolMetadata: CBORSerializable {
    let url: String
    let poolMetadataHash: PoolMetadataHash
}


struct PoolParams: CBORSerializable {
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
}
