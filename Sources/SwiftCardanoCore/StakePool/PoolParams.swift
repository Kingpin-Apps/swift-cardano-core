import Foundation
import PotentCBOR
import PotentCodables
import FractionNumber
import Network


public struct SingleHostAddr: CBORSerializable, Equatable, Hashable {
    public static var code: Int { get { return 0 } }

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
        try container.encode(Self.code)
        try container.encode(port)
        try container.encode(ipv4)
        try container.encode(ipv6)
    }
    
    public init(from primitive: Primitive) throws {
        guard case let .list(elements) = primitive else {
            throw CardanoCoreError.deserializeError("Invalid SingleHostAddr primitive")
        }
        var iterator = elements.makeIterator()
        guard let codeElement = iterator.next(),
                case let .int(code) = codeElement,
              code == Self.code else {
            throw CardanoCoreError.deserializeError("Invalid SingleHostAddr type")
        }
        
        if let portElement = iterator.next() {
            switch portElement {
                case .int(let portValue):
                    self.port = Int(portValue)
                case .null:
                    self.port = nil
                default:
                    throw CardanoCoreError.deserializeError("Invalid port value in SingleHostAddr")
            }
        } else {
            self.port = nil
        }
        
        if let ipv4Element = iterator.next() {
            switch ipv4Element {
                case .bytes(let ipv4Data):
                    if ipv4Data.count == 4 {
                        self.ipv4 = IPv4Address(ipv4Data)
                    } else {
                        throw CardanoCoreError.deserializeError("Invalid IPv4 address length in SingleHostAddr")
                    }
                case .null:
                    self.ipv4 = nil
                default:
                    throw CardanoCoreError.deserializeError("Invalid ipv4 value in SingleHostAddr")
            }
        } else {
            self.ipv4 = nil
        }
        
        if let ipv6Element = iterator.next() {
            switch ipv6Element {
                case .bytes(let ipv6Data):
                    if ipv6Data.count == 16 {
                        self.ipv6 = IPv6Address(ipv6Data)
                    } else {
                        throw CardanoCoreError.deserializeError("Invalid IPv6 address length in SingleHostAddr")
                    }
                case .null:
                    self.ipv6 = nil
                default:
                    throw CardanoCoreError.deserializeError("Invalid ipv6 value in SingleHostAddr")
            }
        } else {
            self.ipv6 = nil
        }
    }

    public func toPrimitive() throws -> Primitive {
        var elements: [Primitive] = []
        elements.append(.int(Int(Self.code)))
        
        if let port = self.port {
            elements.append(.int(Int(port)))
        } else {
            elements.append(.null)
        }
        
        if let ipv4 = self.ipv4 {
            elements.append(.bytes(ipv4.rawValue))
        } else {
            elements.append(.null)
        }
        
        if let ipv6 = self.ipv6 {
            elements.append(.bytes(ipv6.rawValue))
        } else {
            elements.append(.null)
        }
        
        return .list(elements)
    }
}

public struct SingleHostName: CBORSerializable, Equatable, Hashable {
    public static var code: Int { get { return 1 } }
    
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
        try container.encode(Self.code)
        try container.encode(port)
        try container.encode(dnsName)
    }
    
    public init(from primitive: Primitive) throws {
        guard case let .list(elements) = primitive else {
            throw CardanoCoreError.deserializeError("Invalid SingleHostName primitive")
        }
        
        var iterator = elements.makeIterator()
        guard let codeElement = iterator.next(),
                case let .int(code) = codeElement,
              code == Self.code else {
            throw CardanoCoreError.deserializeError("Invalid SingleHostName type")
        }
        
        if let portElement = iterator.next() {
            switch portElement {
                case .int(let portValue):
                    self.port = Int(portValue)
                case .null:
                    self.port = nil
                default:
                    throw CardanoCoreError.deserializeError("Invalid port value in SingleHostName")
            }
        } else {
            self.port = nil
        }
        
        if let dnsNameElement = iterator.next() {
            switch dnsNameElement {
                case .string(let dnsNameValue):
                    self.dnsName = dnsNameValue
                case .null:
                    self.dnsName = nil
                default:
                    throw CardanoCoreError.deserializeError("Invalid dnsName value in SingleHostName")
            }
        } else {
            self.dnsName = nil
        }
    }

    public func toPrimitive() throws -> Primitive {
        var elements: [Primitive] = []
        elements.append(.int(Int(Self.code)))
        
        if let port = self.port {
            elements.append(.int(Int(port)))
        } else {
            elements.append(.null)
        }
        
        if let dnsName = self.dnsName {
            elements.append(.string(dnsName))
        } else {
            elements.append(.null)
        }
        
        return .list(elements)
    }
}

public struct MultiHostName: CBORSerializable, Equatable, Hashable {
    public static var code: Int { get { return 2 } }
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
        try container.encode(Self.code)
        try container.encode(dnsName)
    }
    
    public init(from primitive: Primitive) throws {
        guard case let .list(elements) = primitive else {
            throw CardanoCoreError.deserializeError("Invalid MultiHostName primitive")
        }
        var iterator = elements.makeIterator()
        guard let codeElement = iterator.next(),
                case let .int(code) = codeElement,
              code == Self.code else {
            throw CardanoCoreError.deserializeError("Invalid MultiHostName type")
        }
        if let dnsNameElement = iterator.next() {
            switch dnsNameElement {
                case .string(let dnsNameValue):
                    self.dnsName = dnsNameValue
                case .null:
                    self.dnsName = nil
                default:
                    throw CardanoCoreError.deserializeError("Invalid dnsName value in MultiHostName")
            }
        } else {
            self.dnsName = nil
        }
    }

    public func toPrimitive() throws -> Primitive {
        var elements: [Primitive] = []
        elements.append(.int(Int(Self.code)))
        
        if let dnsName = self.dnsName {
            elements.append(.string(dnsName))
        } else {
            elements.append(.null)
        }
        
        return .list(elements)

    }
}

public enum Relay: CBORSerializable, Equatable, Hashable {
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
    
    public init(from primitive: Primitive) throws {
        guard case let .list(elements) = primitive else {
            throw CardanoCoreError.deserializeError("Invalid Relay primitive")
        }
        guard let firstElement = elements.first,
              case let .int(code) = firstElement else {
            throw CardanoCoreError.deserializeError("Invalid Relay type")
        }
        
        switch code {
            case 0:
                self = .singleHostAddr(try SingleHostAddr(from: primitive))
            case 1:
                self = .singleHostName(try SingleHostName(from: primitive))
            case 2:
                self = .multiHostName(try MultiHostName(from: primitive))
            default:
                throw CardanoCoreError.deserializeError("Invalid Relay type: \(code)")
        }
    }

    public func toPrimitive() throws -> Primitive {
        switch self {
            case .singleHostAddr(let value):
                return try value.toPrimitive()
            case .singleHostName(let value):
                return try value.toPrimitive()
            case .multiHostName(let value):
                return try value.toPrimitive()
        }
    }
}

public struct PoolParams: CBORSerializable, Equatable, Hashable {
    public let poolOperator: PoolKeyHash
    public let vrfKeyHash: VrfKeyHash
    public let pledge: Int
    public let cost: Int
    public let margin: UnitInterval
    public let rewardAccount: RewardAccountHash
    public let poolOwners: ListOrOrderedSet<VerificationKeyHash>
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
        poolOwners: ListOrOrderedSet<VerificationKeyHash>,
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
    
    public init(from primitive: Primitive) throws {
        guard case let .list(elements) = primitive else {
            throw CardanoCoreError.deserializeError("Invalid PoolParams primitive")
        }
        
        guard elements.count >= 8 else {
            throw CardanoCoreError.deserializeError("PoolParams requires at least 8 elements")
        }
        
        // poolOperator (PoolKeyHash)
        self.poolOperator = try PoolKeyHash(from: elements[0])
        
        // vrfKeyHash (VrfKeyHash) 
        self.vrfKeyHash = try VrfKeyHash(from: elements[1])
        
        // pledge (Int)
        guard case let .int(pledge) = elements[2] else {
            throw CardanoCoreError.deserializeError("Invalid pledge value in PoolParams")
        }
        self.pledge = pledge
        
        // cost (Int)
        guard case let .int(cost) = elements[3] else {
            throw CardanoCoreError.deserializeError("Invalid cost value in PoolParams")
        }
        self.cost = cost
        
        // margin (UnitInterval)
        self.margin = try UnitInterval(from: elements[4])
        
        // rewardAccount (RewardAccountHash)
        self.rewardAccount = try RewardAccountHash(from: elements[5])
        
        // poolOwners (OrderedSet<VerificationKeyHash>)
        self.poolOwners = try ListOrOrderedSet<VerificationKeyHash>(from: elements[6])
        
        // relays ([Relay]?)
        if case let .list(relayElements) = elements[7] {
            self.relays = try relayElements.map { try Relay(from: $0) }
        } else if case .null = elements[7] {
            self.relays = nil
        } else {
            self.relays = []
        }
        
        // poolMetadata (PoolMetadata?)
        if elements.count > 8 {
            if case .null = elements[8] {
                self.poolMetadata = nil
            } else {
                self.poolMetadata = try PoolMetadata(from: elements[8])
            }
        } else {
            self.poolMetadata = nil
        }
        
        // id is derived, not from primitive
        self.id = nil
    }

    public func toPrimitive() throws -> Primitive {
        var elements: [Primitive] = []
        
        // poolOperator (PoolKeyHash)
        elements.append(poolOperator.toPrimitive())
        
        // vrfKeyHash (VrfKeyHash)
        elements.append(vrfKeyHash.toPrimitive())
        
        // pledge (Int)
        elements.append(.int(pledge))
        
        // cost (Int)
        elements.append(.int(cost))
        
        // margin (UnitInterval)
        elements.append(try margin.toPrimitive())
        
        // rewardAccount (RewardAccountHash)
        elements.append(rewardAccount.toPrimitive())
        
        // poolOwners (ListOrOrderedSet<VerificationKeyHash>)
        elements.append( try poolOwners.toPrimitive())
        
        // relays ([Relay]?)
        if let relays = relays {
            let relaysArray = try relays.map { try $0.toPrimitive() }
            elements.append(.list(relaysArray))
        } else {
            elements.append(.null)
        }
        
        // poolMetadata (PoolMetadata?)
        if let poolMetadata = poolMetadata {
            elements.append(try poolMetadata.toPrimitive())
        } else {
            elements.append(.null)
        }
        
        return .list(elements)
    }
}
