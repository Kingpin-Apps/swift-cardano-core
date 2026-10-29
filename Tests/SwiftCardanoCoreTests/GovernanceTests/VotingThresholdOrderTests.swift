import Foundation
import Testing

@testable import SwiftCardanoCore

/// `pool_voting_thresholds = [motion no confidence, committee normal,
/// committee no confidence, hard fork initiation, security group]`.
@Suite("Pool voting thresholds follow the CDDL's order")
struct VotingThresholdOrderTests {
    func interval(_ n: UInt64) -> UnitInterval { UnitInterval(numerator: n, denominator: 10) }

    @Test("Each position decodes to its named threshold, and encodes back")
    func positions() throws {
        let hex = try Primitive.list((1...5).map { try interval(UInt64($0)).toPrimitive() })
        let thresholds = try PoolVotingThresholds(from: hex)
        #expect(thresholds.motionNoConfidence == interval(1))
        #expect(thresholds.committeeNormal == interval(2))
        #expect(thresholds.committeeNoConfidence == interval(3))
        #expect(thresholds.hardForkInitiation == interval(4))
        #expect(thresholds.ppSecurityGroup == interval(5))
        #expect(try thresholds.toPrimitive() == hex)
    }

    @Test("A threshold list of the wrong length throws")
    func wrongLength() {
        #expect(throws: CardanoCoreError.self) { try PoolVotingThresholds(from: [interval(1)]) }
        #expect(throws: CardanoCoreError.self) { try DrepVotingThresholds(thresholds: [interval(1)]) }
    }
}
