import Foundation
import PotentCBOR
import OrderedCollections

public enum MoveInstantaneousRewardSource: Int, Codable, Sendable {
    case reserves = 0
    case treasury = 1
}

public struct DeltaCoin: Codable, Hashable, Equatable, Sendable {
    public let deltaCoin: Int
}

public struct MoveInstantaneousReward: Serializable, Sendable{
    public let source: MoveInstantaneousRewardSource
    public let rewards: [String: DeltaCoin]?
    public let coin: UInt64?
    
    public init(
        source: MoveInstantaneousRewardSource,
        rewards: [String: DeltaCoin]?,
        coin: UInt64?
    ) {
        self.source = source
        self.rewards = rewards
        self.coin = coin
    }
    
    public enum CodingKeys: String, CodingKey {
        case source
        case rewards
        case coin
    }
    
    // MARK: - CBORSerializable
    
    public init(from primitive: Primitive) throws {
        guard case let .list(primitive) = primitive else {
            throw CardanoCoreError.deserializeError("Invalid MoveInstantaneousReward type")
        }
        guard primitive.count == 3 else {
            throw CardanoCoreError.deserializeError("Invalid MoveInstantaneousReward type")
        }
        guard case let .int(source) = primitive[0],
              let rewardSource = MoveInstantaneousRewardSource(rawValue: Int(source)) else {
            throw CardanoCoreError.deserializeError("Invalid MoveInstantaneousReward source type")
        }
        self.source = rewardSource
        if case .dict(let rewardsMap) = primitive[1] {
            var rewardsDict: [String: DeltaCoin] = [:]
            for (key, value) in rewardsMap {
                if case let .string(keyStr) = key,
                   case let .int(delta) = value {
                    rewardsDict[keyStr] = DeltaCoin(deltaCoin: Int(delta))
                } else {
                    throw CardanoCoreError.deserializeError("Invalid MoveInstantaneousReward rewards type")
                }
            }
            self.rewards = rewardsDict
        } else if case .null = primitive[1] {
            self.rewards = nil
        } else {
            throw CardanoCoreError.deserializeError("Invalid MoveInstantaneousReward rewards type")
        }
        
        if case let .int(coinValue) = primitive[2] {
            self.coin = UInt64(coinValue)
        } else if case .null = primitive[2] {
            self.coin = nil
        } else {
            throw CardanoCoreError.deserializeError("Invalid MoveInstantaneousReward coin type")
        }
    }

    public func toPrimitive() throws -> Primitive {
        var elements: [Primitive] = []
        elements.append(.int(source.rawValue))
                    
        if let rewards = rewards {
            var rewardsMap: [Primitive: Primitive] = [:]
            for (key, value) in rewards {
                rewardsMap[.string(key)] = .int(value.deltaCoin)
            }
            elements.append(.dict(rewardsMap))
        } else {
            elements.append(.null)
        }
        if let coin = coin {
            elements.append(.int(Int(coin)))
        } else {
            elements.append(.null)
        }
        return .list(elements)
    }
    
    // MARK: - JSONSerializable
    
    public static func fromDict(_ dict: Primitive) throws -> MoveInstantaneousReward {
        guard case let .orderedDict(orderedDict) = dict else {
            throw CardanoCoreError.deserializeError("Invalid MoveInstantaneousReward dict format")
        }
        guard let sourcePrimitive = orderedDict[.string(CodingKeys.source.rawValue)],
              case let .int(sourceValue) = sourcePrimitive else {
            throw CardanoCoreError.deserializeError("Missing or invalid source in MoveInstantaneousReward")
        }
        
        guard let source = MoveInstantaneousRewardSource(rawValue: sourceValue) else {
            throw CardanoCoreError.deserializeError("Invalid source value in MoveInstantaneousReward")
        }
        
        var rewards: [String: DeltaCoin]? = nil
        if let rewardsPrimitive = orderedDict[.string(CodingKeys.rewards.rawValue)] {
            if case .null = rewardsPrimitive {
                rewards = nil
            } else if case let .orderedDict(rewardsDict) = rewardsPrimitive {
                var rewardsMap: [String: DeltaCoin] = [:]
                for (key, value) in rewardsDict {
                    guard case let .string(keyStr) = key,
                          case let .int(delta) = value else {
                        throw CardanoCoreError.deserializeError("Invalid rewards format in MoveInstantaneousReward")
                    }
                    rewardsMap[keyStr] = DeltaCoin(deltaCoin: delta)
                }
                rewards = rewardsMap
            } else {
                throw CardanoCoreError.deserializeError("Invalid rewards type in MoveInstantaneousReward")
            }
        }
        
        var coin: UInt64? = nil
        if let coinPrimitive = orderedDict[.string(CodingKeys.coin.rawValue)] {
            if case .null = coinPrimitive {
                coin = nil
            } else if case let .int(coinValue) = coinPrimitive {
                coin = UInt64(coinValue)
            } else {
                throw CardanoCoreError.deserializeError("Invalid coin type in MoveInstantaneousReward")
            }
        }
        
        return MoveInstantaneousReward(source: source, rewards: rewards, coin: coin)
    }
    
    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        
        dict[.string(CodingKeys.source.rawValue)] = .int(source.rawValue)
        
        if let rewards = rewards {
            var rewardsDict = OrderedDictionary<Primitive, Primitive>()
            for (key, value) in rewards {
                rewardsDict[.string(key)] = .int(value.deltaCoin)
            }
            dict[.string(CodingKeys.rewards.rawValue)] = .orderedDict(rewardsDict)
        } else {
            dict[.string(CodingKeys.rewards.rawValue)] = .null
        }
        
        if let coin = coin {
            dict[.string(CodingKeys.coin.rawValue)] = .int(Int(coin))
        } else {
            dict[.string(CodingKeys.coin.rawValue)] = .null
        }
        
        return .orderedDict(dict)
    }
    
    public static func == (lhs: MoveInstantaneousReward, rhs: MoveInstantaneousReward) -> Bool {
        return lhs.source == rhs.source &&
                lhs.rewards == rhs.rewards &&
                lhs.coin == rhs.coin
    }
}

public struct MoveInstantaneousRewards: CertificateSerializable {
    public var _payload: Data
    public var _type: String
    public var _description: String
    
    public var type: String { get { return MoveInstantaneousRewards.TYPE } }
    public var description: String { get { return MoveInstantaneousRewards.DESCRIPTION } }

    public static var TYPE: String { CertificateType.shelley.rawValue }
    public static var DESCRIPTION: String { CertificateDescription.moveInstantaneousRewards.rawValue }
    public static var CODE: CertificateCode { get { return .moveInstantaneousRewards } }
    
    public let moveInstantaneousRewards: MoveInstantaneousReward
    
    public enum CodingKeys: String, CodingKey {
        case moveInstantaneousRewards
    }
    
    /// Initialize a new `MoveInstantaneousRewards` certificate
    /// - Parameter moveInstantaneousRewards: The move instantaneous rewards
    public init(moveInstantaneousRewards: MoveInstantaneousReward) {
        self.moveInstantaneousRewards = moveInstantaneousRewards
        
        self._payload =  try! CBORSerialization.data(from:
                .array(
                    [
                        CBOR(integerLiteral: Self.CODE.rawValue),
                        try! CBOREncoder().encode(moveInstantaneousRewards).toCBOR
                    ]
                )
        )
        self._type = Self.TYPE
        self._description = Self.DESCRIPTION
    }
    
    /// Initialize a new `MoveInstantaneousRewards` certificate from its Text Envelope representation
    /// - Parameters:
    ///  - payload: The CBOR representation of the certificate
    ///  - type: The type of the certificate
    ///  - description: The description of the certificate
    public init(payload: Data, type: String?, description: String?) {
        self._payload = payload
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
        
        let cbor = try! CBORDecoder().decode(MoveInstantaneousRewards.self, from: payload)
        
        self.moveInstantaneousRewards = cbor.moveInstantaneousRewards
    }
    
    // MARK: - CBORSerializable
    
    public init(from primitive: Primitive) throws {
        guard case let .list(primitive) = primitive,
              primitive.count == 2 else {
            throw CardanoCoreError.deserializeError("Invalid MoveInstantaneousRewards type")
        }
        
        guard case let .int(code) = primitive[0],
              code == UInt64(Self.CODE.rawValue) else {
            throw CardanoCoreError.deserializeError("Invalid MoveInstantaneousRewards type: \(primitive[0])")
        }
        
        let moveInstantaneousRewards = try MoveInstantaneousReward(from: primitive[1])
        self.init(moveInstantaneousRewards: moveInstantaneousRewards)
    }

    public func toPrimitive() throws -> Primitive {
        return .list([
            .int(Int(Self.CODE.rawValue)),
            try moveInstantaneousRewards.toPrimitive()
        ])
    }
    
    // MARK: - JSONSerializable
    
    public static func fromDict(_ dict: Primitive) throws -> MoveInstantaneousRewards {
        guard case let .orderedDict(orderedDict) = dict else {
            throw CardanoCoreError.deserializeError("Invalid MoveInstantaneousRewards dict format")
        }
        guard let moveInstantaneousRewardsPrimitive = orderedDict[.string(CodingKeys.moveInstantaneousRewards.rawValue)] else {
            throw CardanoCoreError.deserializeError("Missing moveInstantaneousRewards in MoveInstantaneousRewards")
        }
        
        guard case let .orderedDict(rewardsDict) = moveInstantaneousRewardsPrimitive else {
            throw CardanoCoreError.deserializeError("Invalid moveInstantaneousRewards format in MoveInstantaneousRewards")
        }
        
        let moveInstantaneousRewards = try MoveInstantaneousReward.fromDict(.orderedDict(rewardsDict))
        
        return MoveInstantaneousRewards(moveInstantaneousRewards: moveInstantaneousRewards)
    }
    
    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        dict[.string(CodingKeys.moveInstantaneousRewards.rawValue)] = try moveInstantaneousRewards.toDict()
        return .orderedDict(dict)
    }

}
