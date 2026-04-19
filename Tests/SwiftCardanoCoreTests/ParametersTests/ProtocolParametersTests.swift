import Testing
import Foundation
import PotentCBOR
@testable import SwiftCardanoCore

@Suite("ProtocolParameters Tests")
struct ProtocolParametersTests {
    let filePath = try! getFilePath(
        forResource: protocolParametersJSONFilePath.forResource,
        ofType: protocolParametersJSONFilePath.ofType,
        inDirectory: protocolParametersJSONFilePath.inDirectory
    )

    func loadParams() throws -> ProtocolParameters {
        try ProtocolParameters.load(from: filePath!)
    }

    // MARK: JSON

    @Test func testInit() async throws {
        _ = try loadParams()
    }

    @Test func testSaveLoad() async throws {
        let tempDirURL = FileManager.default.temporaryDirectory
        let tempFileURL = tempDirURL.appendingPathComponent("protocolParameters.json")

        defer { try? FileManager.default.removeItem(at: tempFileURL) }

        let params = try loadParams()
        try params.save(to: tempFileURL.path)
        let loaded = try ProtocolParameters.load(from: tempFileURL.path)

        #expect(params == loaded)
    }

    // MARK: CBOR round-trip

    @Test("CBOR encode/decode round-trip")
    func testCBORRoundTrip() async throws {
        let params = try loadParams()

        let cborData = try CBOREncoder().encode(params)
        let decoded  = try CBORDecoder().decode(ProtocolParameters.self, from: cborData)

        // Integer fields must survive exactly.
        #expect(decoded.txFeePerByte        == params.txFeePerByte)
        #expect(decoded.txFeeFixed          == params.txFeeFixed)
        #expect(decoded.maxBlockBodySize    == params.maxBlockBodySize)
        #expect(decoded.maxTxSize           == params.maxTxSize)
        #expect(decoded.maxBlockHeaderSize  == params.maxBlockHeaderSize)
        #expect(decoded.stakeAddressDeposit == params.stakeAddressDeposit)
        #expect(decoded.stakePoolDeposit    == params.stakePoolDeposit)
        #expect(decoded.poolRetireMaxEpoch  == params.poolRetireMaxEpoch)
        #expect(decoded.stakePoolTargetNum  == params.stakePoolTargetNum)
        #expect(decoded.minPoolCost         == params.minPoolCost)
        #expect(decoded.utxoCostPerByte     == params.utxoCostPerByte)
        #expect(decoded.maxValueSize        == params.maxValueSize)
        #expect(decoded.collateralPercentage == params.collateralPercentage)
        #expect(decoded.maxCollateralInputs  == params.maxCollateralInputs)
        #expect(decoded.committeeMinSize        == params.committeeMinSize)
        #expect(decoded.committeeMaxTermLength  == params.committeeMaxTermLength)
        #expect(decoded.govActionLifetime       == params.govActionLifetime)
        #expect(decoded.govActionDeposit        == params.govActionDeposit)
        #expect(decoded.dRepDeposit             == params.dRepDeposit)
        #expect(decoded.dRepActivity            == params.dRepActivity)
        #expect(decoded.protocolVersion.major   == params.protocolVersion.major)
        #expect(decoded.protocolVersion.minor   == params.protocolVersion.minor)

        // Double fields are approximated as rationals — verify they round-trip to
        // within a negligible tolerance.
        let tolerance = 1e-6
        #expect(abs(decoded.monetaryExpansion   - params.monetaryExpansion)   < tolerance)
        #expect(abs(decoded.treasuryCut         - params.treasuryCut)         < tolerance)
        #expect(abs(decoded.poolPledgeInfluence - params.poolPledgeInfluence) < tolerance)

        #expect(abs(decoded.executionUnitPrices.priceMemory - params.executionUnitPrices.priceMemory) < tolerance)
        #expect(abs(decoded.executionUnitPrices.priceSteps  - params.executionUnitPrices.priceSteps)  < tolerance)

        #expect(decoded.maxTxExecutionUnits.memory   == params.maxTxExecutionUnits.memory)
        #expect(decoded.maxTxExecutionUnits.steps    == params.maxTxExecutionUnits.steps)
        #expect(decoded.maxBlockExecutionUnits.memory == params.maxBlockExecutionUnits.memory)
        #expect(decoded.maxBlockExecutionUnits.steps  == params.maxBlockExecutionUnits.steps)

        let dvt  = params.dRepVotingThresholds
        let dvt2 = decoded.dRepVotingThresholds
        #expect(abs(dvt2.motionNoConfidence   - dvt.motionNoConfidence)   < tolerance)
        #expect(abs(dvt2.committeeNormal      - dvt.committeeNormal)      < tolerance)
        #expect(abs(dvt2.committeeNoConfidence - dvt.committeeNoConfidence) < tolerance)
        #expect(abs(dvt2.updateToConstitution - dvt.updateToConstitution) < tolerance)
        #expect(abs(dvt2.hardForkInitiation   - dvt.hardForkInitiation)   < tolerance)
        #expect(abs(dvt2.ppNetworkGroup       - dvt.ppNetworkGroup)       < tolerance)
        #expect(abs(dvt2.ppEconomicGroup      - dvt.ppEconomicGroup)      < tolerance)
        #expect(abs(dvt2.ppTechnicalGroup     - dvt.ppTechnicalGroup)     < tolerance)
        #expect(abs(dvt2.ppGovGroup           - dvt.ppGovGroup)           < tolerance)
        #expect(abs(dvt2.treasuryWithdrawal   - dvt.treasuryWithdrawal)   < tolerance)

        let pvt  = params.poolVotingThresholds
        let pvt2 = decoded.poolVotingThresholds
        #expect(abs(pvt2.committeeNoConfidence - pvt.committeeNoConfidence) < tolerance)
        #expect(abs(pvt2.committeeNormal       - pvt.committeeNormal)       < tolerance)
        #expect(abs(pvt2.hardForkInitiation    - pvt.hardForkInitiation)    < tolerance)
        #expect(abs(pvt2.motionNoConfidence    - pvt.motionNoConfidence)    < tolerance)
        #expect(abs(pvt2.ppSecurityGroup       - pvt.ppSecurityGroup)       < tolerance)
    }

    @Test("CBOR toCBORData / fromCBOR helpers")
    func testCBORHelpers() async throws {
        let params = try loadParams()
        let data = try params.toCBORData()
        let restored = try ProtocolParameters.fromCBOR(data: data)
        #expect(restored.txFeePerByte == params.txFeePerByte)
        #expect(restored.utxoCostPerByte == params.utxoCostPerByte)
    }

    // MARK: Conversion to ProtocolParamUpdate

    @Test("Conversion to ProtocolParamUpdate preserves integer fields")
    func testConversionToProtocolParamUpdate() async throws {
        let params = try loadParams()
        let update = ProtocolParamUpdate(from: params)

        #expect(update.minFeeA         == Coin(params.txFeePerByte))
        #expect(update.minFeeB         == Coin(params.txFeeFixed))
        #expect(update.maxBlockBodySize == UInt32(params.maxBlockBodySize))
        #expect(update.maxTransactionSize == UInt32(params.maxTxSize))
        #expect(update.maxBlockHeaderSize == UInt16(params.maxBlockHeaderSize))
        #expect(update.keyDeposit      == Coin(params.stakeAddressDeposit))
        #expect(update.poolDeposit     == Coin(params.stakePoolDeposit))
        #expect(update.maximumEpoch    == EpochInterval(params.poolRetireMaxEpoch))
        #expect(update.nOpt            == UInt16(params.stakePoolTargetNum))
        #expect(update.minPoolCost     == Coin(params.minPoolCost))
        #expect(update.adaPerUtxoByte  == Coin(params.utxoCostPerByte))
        #expect(update.maxValueSize    == UInt32(params.maxValueSize))
        #expect(update.collateralPercentage == UInt16(params.collateralPercentage))
        #expect(update.maxCollateralInputs  == UInt16(params.maxCollateralInputs))
        #expect(update.minCommitteeSize     == UInt16(params.committeeMinSize))
        #expect(update.committeeTermLimit   == EpochInterval(params.committeeMaxTermLength))
        #expect(update.governanceActionValidityPeriod == EpochInterval(params.govActionLifetime))
        #expect(update.governanceActionDeposit == Coin(params.govActionDeposit))
        #expect(update.drepDeposit            == Coin(params.dRepDeposit))
        #expect(update.drepInactivityPeriod   == EpochInterval(params.dRepActivity))
    }

    @Test("Conversion to ProtocolParamUpdate approximates rate fields")
    func testConversionRateFields() async throws {
        let params = try loadParams()
        let update = ProtocolParamUpdate(from: params)
        let tolerance = 1e-6

        if let rate = update.expansionRate {
            #expect(abs(rate.toDouble - params.monetaryExpansion) < tolerance)
        }
        if let rate = update.treasuryGrowthRate {
            #expect(abs(rate.toDouble - params.treasuryCut) < tolerance)
        }
        if let rate = update.poolPledgeInfluence {
            #expect(abs(rate.toDouble - params.poolPledgeInfluence) < tolerance)
        }
    }

    @Test("Conversion to ProtocolParamUpdate includes execution units")
    func testConversionExecutionUnits() async throws {
        let params = try loadParams()
        let update = ProtocolParamUpdate(from: params)

        if let units = update.maxTxExUnits {
            #expect(units.mem   == UInt(params.maxTxExecutionUnits.memory))
            #expect(units.steps == UInt(params.maxTxExecutionUnits.steps))
        }
        if let units = update.maxBlockExUnits {
            #expect(units.mem   == UInt(params.maxBlockExecutionUnits.memory))
            #expect(units.steps == UInt(params.maxBlockExecutionUnits.steps))
        }
    }

    @Test("Conversion produces a CBOR-encodable ProtocolParamUpdate")
    func testConversionCBOREncodable() async throws {
        let params = try loadParams()
        let update = ProtocolParamUpdate(from: params)

        // Should not throw
        let data    = try CBOREncoder().encode(update)
        let decoded = try CBORDecoder().decode(ProtocolParamUpdate.self, from: data)
        #expect(decoded == update)
    }
}
