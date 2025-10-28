import Foundation
import PotentCBOR
import FractionNumber
import OrderedCollections

/// Parameters required for registering a stake pool on the Cardano blockchain.
public struct PoolParams: Serializable {
    public let poolOperator: PoolKeyHash
    public let vrfKeyHash: VrfKeyHash
    public let pledge: Int
    public let cost: Int
    public let margin: UnitInterval
    public let rewardAccount: RewardAccountHash
    public let poolOwners: ListOrOrderedSet<VerificationKeyHash>
    public let relays: [Relay]?
    public let poolMetadata: PoolMetadata?
    
    public enum CodingKeys: String, CodingKey {
        case poolOperator
        case vrfKeyHash
        case pledge
        case cost
        case margin
        case rewardAccount
        case poolOwners
        case relays
        case poolMetadata
    }
    
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
    }
    
    // MARK: - CBORSerializable
    
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
        guard case let .uint(pledge) = elements[2] else {
            throw CardanoCoreError.deserializeError("Invalid pledge value in PoolParams")
        }
        self.pledge = Int(pledge)
        
        // cost (Int)
        guard case let .uint(cost) = elements[3] else {
            throw CardanoCoreError.deserializeError("Invalid cost value in PoolParams")
        }
        self.cost = Int(cost)
        
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
    
    // MARK: - JSONSerializable
    
    public static func fromDict(_ dict: Primitive) throws -> PoolParams {
        guard case let .orderedDict(dictValue) = dict,
              case let .string(poolOperatorId) = dictValue[.string(CodingKeys.poolOperator.rawValue)] else {
            throw CardanoCoreError.deserializeError("Invalid or missing poolOperator in PoolParams")
        }
        
        let poolOperator = try PoolOperator(from: poolOperatorId)
        
        guard case let .string(vrfKeyHashHex) = dictValue[.string(CodingKeys.vrfKeyHash.rawValue)] else {
            throw CardanoCoreError.deserializeError("Invalid or missing vrfKeyHash in PoolParams")
        }
        let vrfKeyHash = VrfKeyHash(
            payload: Data(hexString: vrfKeyHashHex) ?? Data()
        )
        
        guard case let .int(pledge) = dictValue[.string(CodingKeys.pledge.rawValue)] else {
            throw CardanoCoreError.deserializeError("Invalid or missing pledge in PoolParams")
        }
        
        guard case let .int(cost) = dictValue[.string(CodingKeys.cost.rawValue)] else {
            throw CardanoCoreError.deserializeError("Invalid or missing cost in PoolParams")
        }
        
        guard let marginPrimitive = dictValue[.string(CodingKeys.margin.rawValue)] else {
            throw CardanoCoreError.deserializeError("Missing margin in PoolParams")
        }
        let margin = try UnitInterval(from: marginPrimitive)
        
        guard case let .string(rewardAccountHex) = dictValue[.string(CodingKeys.rewardAccount.rawValue)] else {
            throw CardanoCoreError.deserializeError("Invalid or missing rewardAccount in PoolParams")
        }
        let rewardAccount = RewardAccountHash(
            payload: Data(hexString: rewardAccountHex) ?? Data()
        )
        
        guard let poolOwnersPrimitive = dictValue[.string(CodingKeys.poolOwners.rawValue)] else {
            throw CardanoCoreError.deserializeError("Missing poolOwners in PoolParams")
        }
        let poolOwners = try ListOrOrderedSet<VerificationKeyHash>(from: poolOwnersPrimitive)
        
        var relays: [Relay]? = nil
        if let relaysPrimitive = dictValue[.string(CodingKeys.relays.rawValue)] {
            if case .null = relaysPrimitive {
                relays = nil
            } else {
                guard case let .list(relayElements) = relaysPrimitive else {
                    throw CardanoCoreError.deserializeError("Invalid relays in PoolParams")
                }
                relays = try relayElements.map { try Relay(from: $0) }
            }
        }
        
        var poolMetadata: PoolMetadata? = nil
        if let poolMetadataPrimitive = dictValue[.string(CodingKeys.poolMetadata.rawValue)] {
            if case .null = poolMetadataPrimitive {
                poolMetadata = nil
            } else {
                poolMetadata = try PoolMetadata(from: poolMetadataPrimitive)
            }
        }
        return PoolParams(
            poolOperator: poolOperator.poolKeyHash,
            vrfKeyHash: vrfKeyHash,
            pledge: pledge,
            cost: cost,
            margin: margin,
            rewardAccount: rewardAccount,
            poolOwners: poolOwners,
            relays: relays,
            poolMetadata: poolMetadata
        )
    }
    
    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        let poolOperator = PoolOperator(poolKeyHash: poolOperator)
        
        dict[.string(CodingKeys.poolOperator.rawValue)] = .string(try poolOperator.id())
        dict[.string(CodingKeys.vrfKeyHash.rawValue)] = .string(vrfKeyHash.payload.toHex)
        dict[.string(CodingKeys.pledge.rawValue)] = .int(pledge)
        dict[.string(CodingKeys.cost.rawValue)] = .int(cost)
        dict[.string(CodingKeys.margin.rawValue)] = try margin.toPrimitive()
        dict[.string(CodingKeys.rewardAccount.rawValue)] = .string(rewardAccount.payload.toHex)
        dict[.string(CodingKeys.poolOwners.rawValue)] = try poolOwners.toPrimitive()
        if let relays = relays {
            let relaysArray = try relays.map { try $0.toPrimitive() }
            dict[.string(CodingKeys.relays.rawValue)] = .list(relaysArray)
        } else {
            dict[.string(CodingKeys.relays.rawValue)] = .null
        }
        if let poolMetadata = poolMetadata {
            dict[.string(CodingKeys.poolMetadata.rawValue)] = try poolMetadata.toPrimitive()
        } else {
            dict[.string(CodingKeys.poolMetadata.rawValue)] = .null
        }
        return .orderedDict(dict)
    }

}
