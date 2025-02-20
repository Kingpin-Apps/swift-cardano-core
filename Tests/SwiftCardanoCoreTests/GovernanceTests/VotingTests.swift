import Testing
import Foundation
import PotentCBOR
@testable import SwiftCardanoCore

@Suite struct VotingTests {
    
    let voteYes = Vote.yes
    let voteNo = Vote.no
    let voteAbstain = Vote.abstain
    let anchor = Anchor(
        anchorUrl: try! Url("https://example.com"),
        anchorDataHash: AnchorDataHash(payload: Data(repeating: 0x02, count: 32))
    )
    let govActionID = GovActionID(
        transactionID: TransactionId(payload: Data(repeating: 0x01, count: 32)),
        govActionIndex: 10
    )
    let voter = Voter(credential: .drepKeyhash(AddressKeyHash(payload: Data(repeating: 0x03, count: 32))))

    @Test("Test Vote Enum Raw Values")
    func testVoteEnumValues() async throws {
        #expect(voteNo.rawValue == 0)
        #expect(voteYes.rawValue == 1)
        #expect(voteAbstain.rawValue == 2)
    }

    @Test("Test VotingProcedure Initialization")
    func testVotingProcedureInitialization() async throws {
        let votingProcedure = VotingProcedure(
            vote: voteYes,
            anchor: anchor
        )

        #expect(votingProcedure.vote == voteYes)
        #expect(votingProcedure.anchor == anchor)
    }

    @Test("Test VotingProcedure CBOR Encoding and Decoding")
    func testVotingProcedureCBORSerialization() async throws {
        let originalVotingProcedure = VotingProcedure(vote: voteYes, anchor: anchor)

        let encodedData = try CBOREncoder().encode(originalVotingProcedure)
        let decodedVotingProcedure = try CBORDecoder().decode(VotingProcedure.self, from: encodedData)

        #expect(decodedVotingProcedure == originalVotingProcedure)
    }

    @Test("Test Voter Initialization")
    func testVoterInitialization() async throws {
        let voter = Voter(credential: .stakePoolKeyhash(AddressKeyHash(payload: Data(repeating: 0x04, count: 32))))

        #expect(voter.credential == .stakePoolKeyhash(AddressKeyHash(payload: Data(repeating: 0x04, count: 32))))
    }

    @Test("Test Voter Code Computation")
    func testVoterCodeComputation() async throws {
        let constitutionalKeyVoter = Voter(credential: .constitutionalCommitteeHotKeyhash(AddressKeyHash(payload: Data())))
        let constitutionalScriptVoter = Voter(credential: .constitutionalCommitteeHotScriptHash(ScriptHash(payload: Data())))
        let drepKeyVoter = Voter(credential: .drepKeyhash(AddressKeyHash(payload: Data())))
        let drepScriptVoter = Voter(credential: .drepScriptHash(ScriptHash(payload: Data())))
        let stakePoolVoter = Voter(credential: .stakePoolKeyhash(AddressKeyHash(payload: Data())))

        #expect(constitutionalKeyVoter.code == 0)
        #expect(constitutionalScriptVoter.code == 1)
        #expect(drepKeyVoter.code == 2)
        #expect(drepScriptVoter.code == 3)
        #expect(stakePoolVoter.code == 4)
    }

    @Test("Test VotingProcedures Initialization")
    func testVotingProceduresInitialization() async throws {
        let votingProcedure = VotingProcedure(vote: voteYes, anchor: anchor)
        let votingProcedures = VotingProcedures(
            procedures: [voter: [govActionID: votingProcedure]]
        )

        #expect(votingProcedures.procedures[voter] != nil)
        #expect(votingProcedures.procedures[voter]![govActionID] == votingProcedure)
    }

    @Test("Test VotingProcedures CBOR Encoding and Decoding")
    func testVotingProceduresCBORSerialization() async throws {
        let votingProcedure = VotingProcedure(vote: voteYes, anchor: anchor)
        let votingProcedures = VotingProcedures(
            procedures: [voter: [govActionID: votingProcedure]]
        )

        let encoded = try CBOREncoder().encode(votingProcedures)
        print(encoded.hexEncodedString())
        let decoded = try CBORDecoder().decode(VotingProcedures.self, from: encoded)

        #expect(decoded == votingProcedures)
    }

    @Test("Test Voter Equality")
    func testVoterEquality() async throws {
        let voter1 = Voter(credential: .drepKeyhash(AddressKeyHash(payload: Data(repeating: 0x06, count: 32))))
        let voter2 = Voter(credential: .drepKeyhash(AddressKeyHash(payload: Data(repeating: 0x06, count: 32))))
        let voter3 = Voter(credential: .stakePoolKeyhash(AddressKeyHash(payload: Data(repeating: 0x07, count: 32))))

        #expect(voter1 == voter2)
        #expect(voter1 != voter3)
    }
}
