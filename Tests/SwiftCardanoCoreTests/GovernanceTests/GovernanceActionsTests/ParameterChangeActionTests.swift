import Testing
import Foundation
import PotentCBOR
@testable import SwiftCardanoCore

@Suite struct ParameterChangeActionTests {
    let govActionID = GovActionID(
        transactionID: TransactionId(payload: Data(repeating: 0, count: 32)),
        govActionIndex: 0
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
        costModels: try! CostModels.fromStaticData(),
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
    
    let policyHash: PolicyHash? = PolicyHash(
        payload: Data(repeating: 0, count: SCRIPT_HASH_SIZE)
    )
    
    @Test func testInitialization() async throws {
        let action = ParameterChangeAction(
            id: govActionID,
            protocolParamUpdate: protocolParamUpdate,
            policyHash: policyHash
        )
        
        #expect(ParameterChangeAction.code == .parameterChangeAction)
        #expect(
            action.id!.transactionID.payload == govActionID.transactionID.payload
        )
        #expect(action.id!.govActionIndex == govActionID.govActionIndex)
        #expect(action.protocolParamUpdate == protocolParamUpdate)
        #expect(action.policyHash == policyHash)
    }
    
    @Test func testEncoding() async throws {
        let action = ParameterChangeAction(
            id: govActionID,
            protocolParamUpdate: protocolParamUpdate,
            policyHash: policyHash
        )

        let cborData = try CBOREncoder().encode(action)
        let decoded = try CBORDecoder().decode(ParameterChangeAction.self, from: cborData)

        #expect(action == decoded)
    }

    // MARK: - ProtocolParamUpdate from ProtocolParameters

    let filePath = try! getFilePath(
        forResource: protocolParametersJSONFilePath.forResource,
        ofType: protocolParametersJSONFilePath.ofType,
        inDirectory: protocolParametersJSONFilePath.inDirectory
    )

    @Test("ProtocolParamUpdate.init(from:ProtocolParameters) builds from JSON params")
    func testInitFromProtocolParameters() async throws {
        let params = try ProtocolParameters.load(from: filePath!)
        let update = ProtocolParamUpdate(from: params)

        #expect(update.minFeeA        == Coin(params.txFeePerByte))
        #expect(update.minFeeB        == Coin(params.txFeeFixed))
        #expect(update.adaPerUtxoByte == Coin(params.utxoCostPerByte))
        #expect(update.keyDeposit     == Coin(params.stakeAddressDeposit))
        #expect(update.poolDeposit    == Coin(params.stakePoolDeposit))
        #expect(update.maxBlockBodySize   == UInt32(params.maxBlockBodySize))
        #expect(update.maxTransactionSize == UInt32(params.maxTxSize))
        #expect(update.nOpt               == UInt16(params.stakePoolTargetNum))
        #expect(update.governanceActionDeposit == Coin(params.govActionDeposit))
        #expect(update.drepDeposit             == Coin(params.dRepDeposit))
    }

    @Test("ProtocolParamUpdate from ProtocolParameters is CBOR round-trippable")
    func testUpdateFromParamsCBORRoundTrip() async throws {
        let params = try ProtocolParameters.load(from: filePath!)
        let update = ProtocolParamUpdate(from: params)

        let data    = try CBOREncoder().encode(update)
        let decoded = try CBORDecoder().decode(ProtocolParamUpdate.self, from: data)
        #expect(decoded == update)
    }

    @Test("ParameterChangeAction built from ProtocolParameters encodes correctly")
    func testParameterChangeActionFromProtocolParameters() async throws {
        let params = try ProtocolParameters.load(from: filePath!)
        let update = ProtocolParamUpdate(from: params)
        let action = ParameterChangeAction(
            id: govActionID,
            protocolParamUpdate: update,
            policyHash: nil
        )

        let data    = try CBOREncoder().encode(action)
        let decoded = try CBORDecoder().decode(ParameterChangeAction.self, from: data)
        #expect(decoded == action)
    }
}
