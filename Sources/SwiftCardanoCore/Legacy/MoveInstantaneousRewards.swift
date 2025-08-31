import Foundation
import PotentCBOR

public enum MoveInstantaneousRewardSource: Int, Codable {
    case reserves = 0
    case treasury = 1
}

public struct DeltaCoin: Codable, Hashable, Equatable {
    public let deltaCoin: Int
}

public struct MoveInstantaneousReward: CBORSerializable, Hashable, Equatable {
    public let source: MoveInstantaneousRewardSource
    public let rewards: [String: DeltaCoin]?
    public let coin: UInt64?
    
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

    
    /// Initialize a new `MoveInstantaneousRewards` certificate from its CBOR representation
    /// - Parameter decoder: The decoder
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)
        
        guard case Self.CODE.rawValue = code else {
            throw CardanoCoreError.deserializeError("Invalid MoveInstantaneousRewards type: \(code)")
        }
        
        let moveInstantaneousRewards = try container.decode(MoveInstantaneousReward.self)
        
        self.init(moveInstantaneousRewards: moveInstantaneousRewards)
    }
    
    /// Encode the `MoveInstantaneousRewards` certificate to the given encoder
    /// - Parameter encoder: The encoder
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(Self.CODE.rawValue)
        try container.encode(moveInstantaneousRewards)
    }
    
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

}
