import Testing
import Foundation
import CBORCodable
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
        let tempFileURL = tempDirURL.appendingPathComponent(UUID().uuidString + "-protocolParameters.json")

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

        // Rationals are held exactly, so they round-trip exactly.
        #expect(decoded.monetaryExpansion == params.monetaryExpansion)
        #expect(decoded.treasuryCut == params.treasuryCut)
        #expect(decoded.poolPledgeInfluence == params.poolPledgeInfluence)

        #expect(decoded.executionUnitPrices.priceMemory == params.executionUnitPrices.priceMemory)
        #expect(decoded.executionUnitPrices.priceSteps == params.executionUnitPrices.priceSteps)

        #expect(decoded.maxTxExecutionUnits.memory   == params.maxTxExecutionUnits.memory)
        #expect(decoded.maxTxExecutionUnits.steps    == params.maxTxExecutionUnits.steps)
        #expect(decoded.maxBlockExecutionUnits.memory == params.maxBlockExecutionUnits.memory)
        #expect(decoded.maxBlockExecutionUnits.steps  == params.maxBlockExecutionUnits.steps)

        let dvt  = params.dRepVotingThresholds
        let dvt2 = decoded.dRepVotingThresholds
        #expect(dvt2.motionNoConfidence == dvt.motionNoConfidence)
        #expect(dvt2.committeeNormal == dvt.committeeNormal)
        #expect(dvt2.committeeNoConfidence == dvt.committeeNoConfidence)
        #expect(dvt2.updateToConstitution == dvt.updateToConstitution)
        #expect(dvt2.hardForkInitiation == dvt.hardForkInitiation)
        #expect(dvt2.ppNetworkGroup == dvt.ppNetworkGroup)
        #expect(dvt2.ppEconomicGroup == dvt.ppEconomicGroup)
        #expect(dvt2.ppTechnicalGroup == dvt.ppTechnicalGroup)
        #expect(dvt2.ppGovGroup == dvt.ppGovGroup)
        #expect(dvt2.treasuryWithdrawal == dvt.treasuryWithdrawal)

        let pvt  = params.poolVotingThresholds
        let pvt2 = decoded.poolVotingThresholds
        #expect(pvt2.committeeNoConfidence == pvt.committeeNoConfidence)
        #expect(pvt2.committeeNormal == pvt.committeeNormal)
        #expect(pvt2.hardForkInitiation == pvt.hardForkInitiation)
        #expect(pvt2.motionNoConfidence == pvt.motionNoConfidence)
        #expect(pvt2.ppSecurityGroup == pvt.ppSecurityGroup)
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

    @Test("Conversion to ProtocolParamUpdate copies rate fields exactly")
    func testConversionRateFields() async throws {
        let params = try loadParams()
        let update = ProtocolParamUpdate(from: params)

        #expect(update.expansionRate == params.monetaryExpansion)
        #expect(update.treasuryGrowthRate == params.treasuryCut)
        #expect(update.poolPledgeInfluence == params.poolPledgeInfluence)
        #expect(update.executionCosts?.memPrice == NonNegativeInterval(numerator: 577, denominator: 10_000))
        #expect(update.executionCosts?.stepPrice == NonNegativeInterval(numerator: 721, denominator: 10_000_000))
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
