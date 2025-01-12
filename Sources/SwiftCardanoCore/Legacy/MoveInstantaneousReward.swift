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
        throw CardanoCoreError.notImplementedError("MoveInstantaneousReward.fromPrimitive")
    }
}
