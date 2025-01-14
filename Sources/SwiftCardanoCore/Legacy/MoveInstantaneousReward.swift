import Foundation


enum MoveInstantaneousRewardSource: Int {
    case reserves = 0
    case treasury = 1
}

struct DeltaCoin {
    let deltaCoin: Int
}

struct MoveInstantaneousReward: ArrayCBORSerializable {

    let source: MoveInstantaneousRewardSource
    let rewards: [String: DeltaCoin]?
    let coin: UInt64?
    
    static func fromPrimitive<T>(_ value: Any) throws -> T {
        guard let list = value as? [Any], list.count == 3 else {
            throw CardanoCoreError.deserializeError("Invalid MoveInstantaneousReward data: \(value)")
        }
        
        let source = MoveInstantaneousRewardSource(rawValue: list[0] as! Int)!
        let rewards = list[1] as? [String: DeltaCoin]
        let coin = list[2] as? UInt64
        
        return MoveInstantaneousReward(
            source: source,
            rewards: rewards,
            coin: coin
        ) as! T
    }
}
