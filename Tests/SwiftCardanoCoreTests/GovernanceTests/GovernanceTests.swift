import Testing
import Foundation
import PotentCBOR
@testable import SwiftCardanoCore

@Suite struct GovernanceTests {
    
    @Test("Test GovActionCode Raw Values")
    func testGovActionCodeRawValues() async throws {
        #expect(GovActionCode.parameterChangeAction.rawValue == 0)
        #expect(GovActionCode.hardForkInitiationAction.rawValue == 1)
        #expect(GovActionCode.treasuryWithdrawalsAction.rawValue == 2)
        #expect(GovActionCode.noConfidence.rawValue == 3)
        #expect(GovActionCode.updateCommittee.rawValue == 4)
        #expect(GovActionCode.newConstitution.rawValue == 5)
        #expect(GovActionCode.infoAction.rawValue == 6)
    }

    @Test("Test GovActionID Initialization")
    func testGovActionIDInitialization() async throws {
        let transactionID = TransactionId(payload: Data(repeating: 0x01, count: 32))
        let govActionID = GovActionID(transactionID: transactionID, govActionIndex: 10)
        
        #expect(govActionID.transactionID == transactionID)
        #expect(govActionID.govActionIndex == 10)
    }

    @Test("Test GovActionID Encoding and Decoding")
    func testGovActionIDEncodingDecoding() async throws {
        let transactionID = TransactionId(payload: Data(repeating: 0x01, count: 32))
        let originalID = GovActionID(transactionID: transactionID, govActionIndex: 10)

        let encodedData = try CBOREncoder().encode(originalID)
        let decodedID = try CBORDecoder().decode(GovActionID.self, from: encodedData)

        #expect(decodedID == originalID)
    }

    @Test("Test PoolVotingThresholds Initialization")
    func testPoolVotingThresholdsInitialization() async throws {
        let thresholds: [UnitInterval] = [
            UnitInterval(numerator: 1, denominator: 2),
            UnitInterval(numerator: 1, denominator: 2),
            UnitInterval(numerator: 1, denominator: 2),
            UnitInterval(numerator: 1, denominator: 2),
            UnitInterval(numerator: 1, denominator: 2),
        ]

        let poolThresholds = PoolVotingThresholds(from: thresholds)

        #expect(poolThresholds.thresholds.count == 5)
        #expect(poolThresholds.thresholds.allSatisfy { $0.numerator == 1 })
        #expect(poolThresholds.thresholds.allSatisfy { $0.denominator == 2 })
    }

    @Test("Test DrepVotingThresholds Initialization")
    func testDrepVotingThresholdsInitialization() async throws {
        let thresholds: [UnitInterval] = [
            UnitInterval(numerator: 1, denominator: 2),
            UnitInterval(numerator: 1, denominator: 2),
            UnitInterval(numerator: 1, denominator: 2),
            UnitInterval(numerator: 1, denominator: 2),
            UnitInterval(numerator: 1, denominator: 2),
            UnitInterval(numerator: 1, denominator: 2),
            UnitInterval(numerator: 1, denominator: 2),
            UnitInterval(numerator: 1, denominator: 2),
            UnitInterval(numerator: 1, denominator: 2),
            UnitInterval(numerator: 1, denominator: 2),
        ]
        let drepThresholds = DrepVotingThresholds(thresholds: thresholds)

        #expect(drepThresholds.thresholds.count == 10)
        #expect(drepThresholds.thresholds.allSatisfy { $0.numerator == 1 })
        #expect(drepThresholds.thresholds.allSatisfy { $0.denominator == 2 })
    }

    @Test("Test Constitution Initialization")
    func testConstitutionInitialization() async throws {
        let anchor = Anchor(
            anchorUrl: try! Url("https://example.com"),
            anchorDataHash: AnchorDataHash(
                payload: Data(repeating: 0x02, count: 32)
            )
        )
        let scriptHash = ScriptHash(payload: Data(repeating: 0x03, count: 32))

        let constitution = Constitution(anchor: anchor, scriptHash: scriptHash)

        #expect(constitution.anchor == anchor)
        #expect(constitution.scriptHash == scriptHash)
    }

    @Test("Test Constitution Encoding and Decoding")
    func testConstitutionEncodingDecoding() async throws {
        let anchor = Anchor(
            anchorUrl: try! Url("https://example.com"),
            anchorDataHash: AnchorDataHash(
                payload: Data(repeating: 0x02, count: 32)
            )
        )
        let scriptHash = ScriptHash(payload: Data(repeating: 0x03, count: 32))

        let constitution = Constitution(anchor: anchor, scriptHash: scriptHash)

        let encodedData = try CBOREncoder().encode(constitution)
        let decodedConstitution = try CBORDecoder().decode(Constitution.self, from: encodedData)

        #expect(decodedConstitution == constitution)
    }
}
