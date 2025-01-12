import Foundation
import PotentCBOR

struct MoveInstantaneousRewards: ArrayCBORSerializable {
    public var code: Int { get { return 6 } }
    
    let moveInstantaneousRewards: MoveInstantaneousReward
    
    static func fromPrimitive<T>(_ value: Any) throws -> T {
        <#code#>
    }
}
