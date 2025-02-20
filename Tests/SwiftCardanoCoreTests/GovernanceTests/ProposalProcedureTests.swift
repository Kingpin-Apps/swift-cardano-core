import Testing
import Foundation
import PotentCBOR
@testable import SwiftCardanoCore

@Suite struct ProposalProcedureTests {
    let deposit = Coin(1_000_000)
    let rewardAccount = RewardAccount(Data(repeating: 0x01, count: 32))
    let govAction = GovAction.infoAction(InfoAction())
    let anchor = Anchor(
        anchorUrl: try! Url("https://example.com"),
        anchorDataHash: AnchorDataHash(
            payload: Data(repeating: 0x02, count: 32)
        )
    )
    
    @Test("Test ProposalProcedure Initialization")
    func testProposalProcedureInitialization() async throws {
        let proposalProcedure = ProposalProcedure(
            deposit: deposit,
            rewardAccount: rewardAccount,
            govAction: govAction,
            anchor: anchor
        )

        #expect(proposalProcedure.deposit == deposit)
        #expect(proposalProcedure.rewardAccount == rewardAccount)
        #expect(proposalProcedure.govAction == govAction)
        #expect(proposalProcedure.anchor == anchor)
    }

    @Test("Test ProposalProcedure CBOR Encoding and Decoding")
    func testProposalProcedureCBORSerialization() async throws {
        let originalProposal = ProposalProcedure(
            deposit: deposit,
            rewardAccount: rewardAccount,
            govAction: govAction,
            anchor: anchor
        )

        let encodedData = try CBOREncoder().encode(originalProposal)
        let decodedProposal = try CBORDecoder().decode(ProposalProcedure.self, from: encodedData)

        #expect(decodedProposal == originalProposal)
    }

    @Test("Test ProposalProcedure JSON Encoding")
    func testProposalProcedureJSONEncoding() async throws {
        let proposal = ProposalProcedure(
            deposit: deposit,
            rewardAccount: rewardAccount,
            govAction: govAction,
            anchor: anchor
        )

        let jsonString = try proposal.toJSON()
        #expect(jsonString != nil)
        #expect(jsonString!.contains("\"type\": \"Governance proposal\""))
        #expect(jsonString!.contains("\"description\": \"New constitutional committee and/or threshold and/or terms proposal\""))
    }

    @Test("Test ProposalProcedure Decoding from CBOR Payload")
    func testProposalProcedureDecodingFromCBOR() async throws {
        let originalProposal = ProposalProcedure(
            deposit: deposit,
            rewardAccount: rewardAccount,
            govAction: govAction,
            anchor: anchor
        )

        let encodedPayload = try CBOREncoder().encode(originalProposal)
        let decodedProposal = ProposalProcedure(payload: encodedPayload, type: nil, description: nil)

        #expect(decodedProposal.deposit == deposit)
        #expect(decodedProposal.rewardAccount == rewardAccount)
        #expect(decodedProposal.govAction == govAction)
        #expect(decodedProposal.anchor == anchor)
    }

    @Test("Test ProposalProcedures Collection Initialization")
    func testProposalProceduresCollection() async throws {
        let proposal1 = ProposalProcedure(
            deposit: deposit,
            rewardAccount: rewardAccount,
            govAction: govAction,
            anchor: anchor
        )

        let proposal2 = ProposalProcedure(
            deposit: Coin(1_000_000_000),
            rewardAccount: rewardAccount,
            govAction: govAction,
            anchor: anchor
        )

        let proposals = ProposalProcedures(procedures: NonEmptyCBORSet([proposal1, proposal2]))

        #expect(proposals.procedures.contains(proposal1))
        #expect(proposals.procedures.contains(proposal2))
        #expect(proposals.procedures.count == 2)
    }
}
