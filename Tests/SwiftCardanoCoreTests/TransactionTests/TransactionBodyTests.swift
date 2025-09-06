import Testing
import Foundation
import PotentCBOR
@testable import SwiftCardanoCore

@Suite("TransactionBody Tests")
struct TransactionBodyTests {
    // Test data
    let transactionId = try! TransactionId(
        from: .string("732bfd67e66be8e8288349fcaaa2294973ef6271cc189a239bb431275401b8e5")
    )
    let address = try! Address(from: .string("stake_test1upyz3gk6mw5he20apnwfn96cn9rscgvmmsxc9r86dh0k66gswf59n"))
    let amount = Value(coin: 1000000)
    
    let deposit = Coin(1_000_000)
    let rewardAccount = RewardAccount(Data(repeating: 0x01, count: 32))
    let govAction = GovAction.infoAction(InfoAction())
    let anchor = Anchor(
        anchorUrl: try! Url("https://example.com"),
        anchorDataHash: AnchorDataHash(
            payload: Data(repeating: 0x02, count: 32)
        )
    )
    
    let protocolParamUpdate = ProtocolParamUpdate(
        minFeeA: 0,
        minFeeB: 0,
        maxBlockBodySize: 0,
        maxTransactionSize: 0,
        maxBlockHeaderSize: 0,
        
        keyDeposit: 0,
        poolDeposit: 0,
        maximumEpoch: 0,
        nOpt: 0,
        poolPledgeInfluence: NonNegativeInterval(lowerBound: 0, upperBound: 10),
        
        expansionRate: UnitInterval(numerator: 1, denominator: 2),
        treasuryGrowthRate: UnitInterval(numerator: 1, denominator: 2),
        decentralizationConstant: UnitInterval(numerator: 1, denominator: 2),
        extraEntropy: 0,
        protocolVersion: ProtocolVersion(major: 1, minor: 2),
        
        minPoolCost: 0,
        adaPerUtxoByte: 0,
        costModels: try! CostModels([0:[]]),
        executionCosts: ExUnitPrices(
            memPrice: NonNegativeInterval(lowerBound: 0, upperBound: 10),
            stepPrice: NonNegativeInterval(lowerBound: 0, upperBound: 10)
        ),
        maxTxExUnits: ExUnits(mem: 0, steps: 0),
        maxBlockExUnits: ExUnits(mem: 0, steps: 0),
        maxValueSize: 0,
        collateralPercentage: 0,
        
        maxCollateralInputs: 0,
        poolVotingThresholds: PoolVotingThresholds(
            committeeNoConfidence: UnitInterval(numerator: 1, denominator: 2),
            committeeNormal: UnitInterval(numerator: 1, denominator: 2),
            hardForkInitiation: UnitInterval(numerator: 1, denominator: 2),
            motionNoConfidence: UnitInterval(numerator: 1, denominator: 2),
            ppSecurityGroup: UnitInterval(numerator: 1, denominator: 2)
        ),
        drepVotingThresholds: DrepVotingThresholds(
            thresholds: [
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
        ),
        minCommitteeSize: 0,
        committeeTermLimit: 0,
        
        governanceActionValidityPeriod: 0,
        governanceActionDeposit: 0,
        drepDeposit: 0,
        drepInactivityPeriod: 0,
        minFeeRefScriptCoinsPerByte: NonNegativeInterval(lowerBound: 0, upperBound: 10)
    )
    
    let voter = Voter(
        credential:
                .drepKeyhash(
                    VerificationKeyHash(
                        payload: Data(repeating: 0x03, count: 32)
                    )
                )
    )

    @Test("Test initialization with required parameters")
    func testRequiredParametersInitialization() throws {
        let input = TransactionInput(transactionId: transactionId, index: 0)
        let output = TransactionOutput(address: address, amount: amount)
        let fee = Coin(100000)
        
        let body = TransactionBody(
            inputs: .orderedSet(try OrderedSet([input])),
            outputs: [output],
            fee: fee
        )
        
        #expect(body.inputs == .orderedSet(try OrderedSet([input])))
        #expect(body.outputs == [output])
        #expect(body.fee == fee)
        #expect(body.ttl == nil)
        #expect(body.certificates == nil)
        #expect(body.withdrawals == nil)
        #expect(body.update == nil)
        #expect(body.auxiliaryDataHash == nil)
        #expect(body.validityStart == nil)
        #expect(body.mint == nil)
        #expect(body.scriptDataHash == nil)
        #expect(body.collateral == nil)
        #expect(body.requiredSigners == nil)
        #expect(body.networkId == nil)
        #expect(body.collateralReturn == nil)
        #expect(body.totalCollateral == nil)
        #expect(body.referenceInputs == nil)
        #expect(body.votingProcedures == nil)
        #expect(body.proposalProcedures == nil)
        #expect(body.currentTreasuryAmount == nil)
        #expect(body.treasuryDonation == nil)
    }
    
    @Test("Test initialization with all parameters")
    func testAllParametersInitialization() throws {
        let input = TransactionInput(transactionId: transactionId, index: 0)
        let output = TransactionOutput(address: address, amount: amount)
        let fee = Coin(100000)
        let ttl = 1000
        let certificates: [Certificate] = [
            Certificate.stakeRegistration(stakeRegistrationCertificate!),
        ]
        let withdrawals: Withdrawals = Withdrawals([RewardAccount(Data([1, 2, 3])):Coin(1000)])
        let update = Update(
            proposedprotocolParamUpdates: ProposedProtocolParamUpdates(
                [
                    GenesisHash(payload: Data(repeating: 0x01, count: 32)):protocolParamUpdate
                ]
            ),
            epoch: 0
        )
        let auxiliaryDataHash = AuxiliaryDataHash(payload: Data(repeating: 0x01, count: 32))
        let validityStart = 100
        let mint = try MultiAsset(from: .dict([.string("policyId"): .dict([.string("assetName"): .int(5)])]))
        let scriptDataHash = ScriptDataHash(payload: Data(repeating: 0x02, count: 32))
        let collateral = [TransactionInput(transactionId: transactionId, index: 1)]
        let requiredSigners = [VerificationKeyHash(payload: Data(repeating: 0x03, count: 32))]
        let networkId = 0
        let collateralReturn = TransactionOutput(address: address, amount: amount)
        let totalCollateral = Coin(200000)
        let referenceInputs = [TransactionInput(transactionId: transactionId, index: 2)]
        
        let voter: Voter = Voter(
            credential: .drepKeyhash(try drepVerificationKey!.hash())
        )
        let anchor = Anchor(
            anchorUrl: try! Url("https://example.com"),
            anchorDataHash: AnchorDataHash(payload: Data(repeating: 0x02, count: 32))
        )
        let transactionID = TransactionId(payload: Data(repeating: 0x01, count: 32))
        let originalID = GovActionID(transactionID: transactionID, govActionIndex: 10)
//        let votingProcedures: VotingProcedures = [
//            voter: [originalID: VotingProcedure(vote: .yes, anchor: anchor)]
//        ]
        let votingProcedures = VotingProcedures([
            voter: [originalID: VotingProcedure(vote: .yes, anchor: anchor)]
        ])
        let proposalProcedures: ProposalProcedures = NonEmptyOrderedSet(
            [
                ProposalProcedure(
                    deposit: deposit,
                    rewardAccount: rewardAccount,
                    govAction: govAction,
                    anchor: anchor
                )
            ]
        )
        let currentTreasuryAmount = Coin(300000)
        let treasuryDonation = PositiveCoin(400000)
        
        let body = TransactionBody(
            inputs: .orderedSet(try OrderedSet([input])),
            outputs: [output],
            fee: fee,
            ttl: ttl,
            certificates: .nonEmptyOrderedSet(NonEmptyOrderedSet(certificates)),
            withdrawals: withdrawals,
            update: update,
            auxiliaryDataHash: auxiliaryDataHash,
            validityStart: validityStart,
            mint: mint,
            scriptDataHash: scriptDataHash,
            collateral: .nonEmptyOrderedSet(NonEmptyOrderedSet(collateral)),
            requiredSigners: .nonEmptyOrderedSet(NonEmptyOrderedSet(requiredSigners)),
            networkId: networkId,
            collateralReturn: collateralReturn,
            totalCollateral: totalCollateral,
            referenceInputs: .nonEmptyOrderedSet(NonEmptyOrderedSet(referenceInputs)),
            votingProcedures: votingProcedures,
            proposalProcedures: proposalProcedures,
            currentTreasuryAmount: currentTreasuryAmount,
            treasuryDonation: treasuryDonation
        )
        
        #expect(body.inputs == .orderedSet(try OrderedSet([input])))
        #expect(body.outputs == [output])
        #expect(body.fee == fee)
        #expect(body.ttl == ttl)
        #expect(body.certificates! == .nonEmptyOrderedSet(NonEmptyOrderedSet(certificates)))
        #expect(body.withdrawals! == withdrawals)
        #expect(body.update == update)
        #expect(body.auxiliaryDataHash == auxiliaryDataHash)
        #expect(body.validityStart == validityStart)
        #expect(body.mint == mint)
        #expect(body.scriptDataHash == scriptDataHash)
        #expect(body.collateral == .nonEmptyOrderedSet(NonEmptyOrderedSet(collateral)))
        #expect(body.requiredSigners == .nonEmptyOrderedSet(NonEmptyOrderedSet(requiredSigners)))
        #expect(body.networkId == networkId)
        #expect(body.collateralReturn == collateralReturn)
        #expect(body.totalCollateral == totalCollateral)
        #expect(body.referenceInputs == .nonEmptyOrderedSet(NonEmptyOrderedSet(referenceInputs)))
        #expect(body.votingProcedures == votingProcedures)
        #expect(body.proposalProcedures == proposalProcedures)
        #expect(body.currentTreasuryAmount == currentTreasuryAmount)
        #expect(body.treasuryDonation == treasuryDonation)
    }
    
    @Test("Test Codable conformance")
    func testCodable() throws {
        let input = TransactionInput(transactionId: transactionId, index: 0)
        let output = TransactionOutput(address: address, amount: amount)
        let fee = Coin(100000)
        
        let originalBody = TransactionBody(
            inputs: .orderedSet(try OrderedSet([input])),
            outputs: [output],
            fee: fee
        )
        
        let encodedData = try originalBody.toCBORData()
        let decodedBody = try TransactionBody.fromCBOR(data: encodedData)
        
        #expect(decodedBody == originalBody)
        #expect(decodedBody.inputs == originalBody.inputs)
        #expect(decodedBody.outputs == originalBody.outputs)
        #expect(decodedBody.fee == originalBody.fee)
    }
    
    @Test("Test validation with valid mint")
    func testValidMintValidation() throws {
        let input = TransactionInput(transactionId: transactionId, index: 0)
        let output = TransactionOutput(address: address, amount: amount)
        let fee = Coin(100000)
        let mint = try MultiAsset(from: .dict([.string("policyId"): .dict([.string("assetName"): .int(5)])]))
        
        let body = TransactionBody(
            inputs: .orderedSet(try OrderedSet([input])),
            outputs: [output],
            fee: fee,
            mint: mint
        )
        
        try body.validate()
    }
    
    @Test("Test transaction ID generation")
    func testTransactionId() throws {
        let input = TransactionInput(transactionId: transactionId, index: 0)
        let output = TransactionOutput(address: address, amount: amount)
        let fee = Coin(100000)
        
        let body = TransactionBody(
            inputs: .orderedSet(try OrderedSet([input])),
            outputs: [output],
            fee: fee
        )
        
        let id = body.id
        #expect(id.payload.count == TRANSACTION_HASH_SIZE)
    }
    
    @Test("Test hash generation")
    func testHash() throws {
        let input = TransactionInput(transactionId: transactionId, index: 0)
        let output = TransactionOutput(address: address, amount: amount)
        let fee = Coin(100000)
        
        let body = TransactionBody(
            inputs: .orderedSet(try OrderedSet([input])),
            outputs: [output],
            fee: fee
        )
        
        let hash = body.hash()
        #expect(hash.count == TRANSACTION_HASH_SIZE)
    }
    
    @Test("Test CBOR encoding of transaction body")
    func testTransactionBodyCBOR() throws {
        let txBody = try makeTransactionBody()
        
        // Convert to CBOR and get the hex representation
        let cborHex = try txBody.toCBORHex()
        
        // Expected CBOR hex string from the Python test
        let expectedHex = "a50081825820732bfd67e66be8e8288349fcaaa2294973ef6271cc189a239bb431275401b8e500018282581d60f6532850e1bccee9c72a9113ad98bcc5dbb30d2ac960262444f6e5f41b000000174876e80082581d60f6532850e1bccee9c72a9113ad98bcc5dbb30d2ac960262444f6e5f41b000000ba43b4b7f7021a000288090d800e80"
        
        // Verify the CBOR encoding matches the expected hex
        #expect(cborHex == expectedHex, "CBOR encoding does not match expected value")
        
        // Verify two-way CBOR serialization works
        try checkTwoWayCBOR(serializable: txBody)
    }
}
