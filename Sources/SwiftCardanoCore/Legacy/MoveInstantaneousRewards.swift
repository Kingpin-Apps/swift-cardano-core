import Foundation
import PotentCBOR

enum MoveInstantaneousRewardSource: Int, Codable {
    case reserves = 0
    case treasury = 1
}

struct DeltaCoin: Codable {
    let deltaCoin: Int
}

struct MoveInstantaneousReward: Codable {
    let source: MoveInstantaneousRewardSource
    let rewards: [String: DeltaCoin]?
    let coin: UInt64?
}

struct MoveInstantaneousRewards: Codable {
    public var code: Int { get { return 6 } }
    
    let moveInstantaneousRewards: MoveInstantaneousReward
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)
        
        guard code == 6 else {
            throw CardanoCoreError.deserializeError("Invalid MoveInstantaneousRewards type: \(code)")
        }
        
        let moveInstantaneousRewards = try container.decode(MoveInstantaneousReward.self)
        
        self.moveInstantaneousRewards = moveInstantaneousRewards
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(code)
        try container.encode(moveInstantaneousRewards)
    }
}
