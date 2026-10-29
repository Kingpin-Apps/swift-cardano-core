import CBORCodable
import Foundation
import Testing
@testable import SwiftCardanoCore

// The ledger holds every rational parameter as a `BoundedRatio Word64` and
// reads a JSON decimal exactly (`0.0577` is 577/10000), so fees and rewards
// computed from them are exact. These tests check that the parameters and
// genesis files are read, held and written that way, never through a Double.

private func hex(_ string: String) -> Data {
    let digits = string.filter { !$0.isWhitespace }
    var data = Data()
    var index = digits.startIndex
    while index < digits.endIndex {
        let next = digits.index(index, offsetBy: 2)
        data.append(UInt8(digits[index ..< next], radix: 16)!)
        index = next
    }
    return data
}

private func path(_ resource: String, _ directory: String) throws -> String {
    try #require(try getFilePath(forResource: resource, ofType: "json", inDirectory: directory))
}

private func unit(_ n: UInt64, _ d: UInt64) -> UnitInterval { UnitInterval(numerator: n, denominator: d) }
private func nonNegative(_ n: UInt64, _ d: UInt64) -> NonNegativeInterval { NonNegativeInterval(numerator: n, denominator: d) }

private let mainnetMemPrice = nonNegative(577, 10_000)
private let mainnetStepPrice = nonNegative(721, 10_000_000)

// MARK: - Reading the real files exactly

@Suite struct ExactRationalFileTests {
    static func loadParams() throws -> ProtocolParameters {
        try ProtocolParameters.load(from: path("protocol-parameters", "data"))
    }

    @Test("Mainnet protocol-parameters.json: 5.77e-2 and 7.21e-5 read as 577/10000 and 721/10000000")
    func protocolParameters() throws {
        let p = try Self.loadParams()
        #expect(p.executionUnitPrices.priceMemory == mainnetMemPrice)
        #expect(p.executionUnitPrices.priceSteps == mainnetStepPrice)
        // 3.0e-3, 0.2 and 0.3.
        #expect(p.monetaryExpansion == unit(3, 1000))
        #expect(p.treasuryCut == unit(1, 5))
        #expect(p.poolPledgeInfluence == nonNegative(3, 10))
        #expect(p.minFeeRefScriptCostPerByte == nonNegative(15, 1))
        #expect(p.poolVotingThresholds.ppSecurityGroup == unit(51, 100))
        #expect(p.dRepVotingThresholds.committeeNormal == unit(67, 100))
        #expect(p.dRepVotingThresholds.committeeNoConfidence == unit(3, 5))
        #expect(p.dRepVotingThresholds.updateToConstitution == unit(3, 4))
    }

    @Test("Alonzo genesis prices read exactly, as fractions or decimals",
          arguments: ["mainnet", "preprod", "preview", "sanchonet"])
    func alonzoGenesis(_ network: String) throws {
        // Mainnet, preprod and preview write {"numerator", "denominator"};
        // sanchonet writes 5.77e-2 and 7.21e-5.
        let genesis = try AlonzoGenesis.load(from: path("alonzo-genesis", "data/config/\(network)"))
        #expect(genesis.executionPrices.priceMemory == mainnetMemPrice)
        #expect(genesis.executionPrices.priceSteps == mainnetStepPrice)
        #expect(genesis.costModels.plutusV1.count == 166)
    }

    @Test("Alonzo genesis reads the named PlutusV1 cost model in the ledger's order")
    func alonzoCostModelOrder() throws {
        let named = try AlonzoGenesis.load(from: path("alonzo-genesis", "data/config/mainnet"))
        let object = try #require(try JSONSerialization.jsonObject(
            with: Data(contentsOf: URL(fileURLWithPath: path("alonzo-genesis", "data/config/mainnet")))) as? [String: Any])
        let models = try #require(object["costModels"] as? [String: Any])
        let byName = try #require(models["PlutusV1"] as? [String: Int64])
        // ParamName order is the sorted order of the names.
        #expect(named.costModels.plutusV1 == byName.keys.sorted().map { byName[$0]! })
    }

    @Test("Shelley genesis rationals read exactly", arguments: ["mainnet", "preprod", "preview", "sanchonet"])
    func shelleyGenesis(_ network: String) throws {
        // Sanchonet writes 5.0e-2 and 3.0e-3; the others 0.05 and 0.003.
        let genesis = try ShelleyGenesis.load(from: path("shelley-genesis", "data/config/\(network)"))
        #expect(genesis.activeSlotsCoeff == unit(1, 20))
        #expect(genesis.protocolParams.rho == unit(3, 1000))
        #expect(genesis.protocolParams.tau == unit(1, 5))
        #expect(genesis.protocolParams.a0 == nonNegative(3, 10))
        #expect(genesis.protocolParams.decentralisationParam == unit(1, 1))
    }

    @Test("Conway genesis rationals read exactly", arguments: ["mainnet", "preprod", "preview", "sanchonet"])
    func conwayGenesis(_ network: String) throws {
        let genesis = try ConwayGenesis.load(from: path("conway-genesis", "data/config/\(network)"))
        #expect(genesis.dRepVotingThresholds.ppGovGroup == unit(3, 4))
        #expect(genesis.dRepVotingThresholds.hardForkInitiation == unit(3, 5))
        #expect(genesis.minFeeRefScriptCostPerByte == nonNegative(15, 1))
        // Sanchonet writes the quorum as 0.67; the others as 2/3.
        #expect(genesis.committee.threshold == (network == "sanchonet" ? unit(67, 100) : unit(2, 3)))
    }

    @Test("GenesisParameters carries the exact active slot coefficient")
    func genesisParameters() throws {
        let parameters = try GenesisParameters(nodeConfigFilePath: path("config", "data/config/mainnet"))
        #expect(parameters.activeSlotsCoefficient == unit(1, 20))
        #expect(parameters.alonzoGenesis?.executionPrices.priceMemory == mainnetMemPrice)
    }
}

// MARK: - Reading JSON numbers exactly

@Suite struct ExactRationalJSONTests {
    struct Holder: Decodable {
        let unit: UnitInterval?
        let positive: UnitInterval?
        let nonNegative: NonNegativeInterval?

        enum CodingKeys: String, CodingKey { case unit, positive, nonNegative }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            unit = try c.decodeUnitIntervalIfPresent(forKey: .unit)
            positive = try c.decodeUnitIntervalIfPresent(forKey: .positive, bounds: .positiveUnitInterval)
            nonNegative = try c.decodeNonNegativeIntervalIfPresent(forKey: .nonNegative)
        }
    }

    func read(_ json: String) throws -> Holder {
        try JSONDecoder().decode(Holder.self, from: Data(json.utf8))
    }

    @Test("Decimals read as the ledger's boundRational of a Scientific",
          arguments: [
            ("0.0577", 577, 10_000), ("5.77e-2", 577, 10_000), ("5.770E-2", 577, 10_000),
            ("7.21e-5", 721, 10_000_000), ("0.0000721", 721, 10_000_000), ("5.0e-2", 1, 20),
            ("0.20", 1, 5), ("1", 1, 1), ("1.0", 1, 1), ("0", 0, 1), ("-0", 0, 1),
            ("1e-19", 1, 10_000_000_000_000_000_000), ("0.3333333333333333333", 3_333_333_333_333_333_333, 10_000_000_000_000_000_000),
          ] as [(String, UInt64, UInt64)])
    func decimals(_ text: String, _ numerator: UInt64, _ denominator: UInt64) throws {
        #expect(try read(#"{"unit": \#(text)}"#).unit == unit(numerator, denominator))
    }

    @Test("A fraction object is read, reduced and checked")
    func fractions() throws {
        #expect(try read(#"{"unit": {"numerator": 2, "denominator": 4}}"#).unit == unit(1, 2))
        #expect(try read(#"{"unit": {"numerator": -1, "denominator": -3}}"#).unit == unit(1, 3))
        #expect(try read(#"{"nonNegative": {"numerator": 18446744073709551616, "denominator": 2}}"#).nonNegative
                == nonNegative(1 << 63, 1))
        for bad in [#"{"numerator": 1, "denominator": 0}"#, #"{"numerator": 3, "denominator": 2}"#,
                    #"{"numerator": -1, "denominator": 2}"#, #"{"numerator": 1.5, "denominator": 2}"#,
                    #"{"numerator": 1, "denominator": 18446744073709551616}"#] {
            #expect(throws: (any Error).self) { try read(#"{"unit": \#(bad)}"#) }
        }
    }

    @Test("Twenty places is too precise, but trailing zeros do not count")
    func trailingZeros() throws {
        #expect(try read(#"{"unit": 0.12345678901234567890}"#).unit == unit(1_234_567_890_123_456_789, 10_000_000_000_000_000_000))
    }

    @Test("Numbers the ledger refuses are refused",
          arguments: ["1.5", "-0.5", "1e-20", "0.12345678901234567891", "2", "0.000000000000000000000000000000000000001"])
    func unitRejections(_ text: String) {
        #expect(throws: (any Error).self) { try read(#"{"unit": \#(text)}"#) }
    }

    @Test("A PositiveUnitInterval is at least 1/10^19 and at most one")
    func positiveUnitInterval() throws {
        #expect(try read(#"{"positive": 1e-19}"#).positive == unit(1, 10_000_000_000_000_000_000))
        #expect(throws: (any Error).self) { try read(#"{"positive": 0}"#) }
        #expect(throws: (any Error).self) { try read(#"{"positive": 1.01}"#) }
    }

    @Test("A NonNegativeInterval reaches Word64 and no further")
    func nonNegativeRange() throws {
        #expect(try read(#"{"nonNegative": 18446744073709551615}"#).nonNegative == nonNegative(.max, 1))
        #expect(try read(#"{"nonNegative": 15.5}"#).nonNegative == nonNegative(31, 2))
        #expect(try read(#"{"nonNegative": 1.2e3}"#).nonNegative == nonNegative(1200, 1))
        #expect(throws: (any Error).self) { try read(#"{"nonNegative": 18446744073709551616}"#) }
        #expect(throws: (any Error).self) { try read(#"{"nonNegative": 1e20}"#) }
        #expect(throws: (any Error).self) { try read(#"{"nonNegative": -1}"#) }
    }

    @Test("Values are written as the ledger's ToJSON writes them")
    func writing() throws {
        func text(_ value: UnitInterval) throws -> String {
            struct Wrapper: Encodable {
                let value: UnitInterval
                enum CodingKeys: String, CodingKey { case v }
                func encode(to encoder: Encoder) throws {
                    var c = encoder.container(keyedBy: CodingKeys.self)
                    try c.encodeLedgerRational(value, forKey: .v)
                }
            }
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            return String(decoding: try encoder.encode(Wrapper(value: value)), as: UTF8.self)
        }
        // A decimal when the expansion ends within 19 places, reduced first.
        #expect(try text(unit(577, 10_000)) == #"{"v":0.0577}"#)
        #expect(try text(unit(1154, 20_000)) == #"{"v":0.0577}"#)
        #expect(try text(unit(1, 1)) == #"{"v":1}"#)
        #expect(try text(unit(1, 10_000_000_000_000_000_000)) == #"{"v":0.0000000000000000001}"#)
        // A fraction object otherwise.
        #expect(try text(unit(2, 3)) == #"{"v":{"denominator":3,"numerator":2}}"#)
        #expect(try text(unit(1, 1 << 63)) == #"{"v":{"denominator":9223372036854775808,"numerator":1}}"#)
    }
}

// MARK: - Round trips

@Suite struct ExactRationalRoundTripTests {
    @Test("Protocol parameters round-trip exactly through JSON, toDict and CBOR")
    func protocolParameters() throws {
        let p = try ExactRationalFileTests.loadParams()

        let json = try JSONDecoder().decode(ProtocolParameters.self, from: JSONEncoder().encode(p))
        #expect(json == p)

        let dict = try p.toDict()
        guard case .orderedDict(let top) = dict, case .orderedDict(let prices)? = top[.string("executionUnitPrices")] else {
            Issue.record("expected an object")
            return
        }
        #expect(prices[.string("priceSteps")] == .decimal(Decimal(string: "0.0000721")!))
        #expect(try ProtocolParameters.fromDict(dict) == p)

        #expect(try ProtocolParameters.fromCBOR(data: p.toCBORData()) == p)
        #expect(try ProtocolParameters(from: p.toPrimitive()) == p)
    }

    @Test("A value with no short decimal round-trips as a fraction")
    func repeatingDecimal() throws {
        let p = try ExactRationalFileTests.loadParams()
        let thirds = ExecutionUnitPrices(priceMemory: nonNegative(1, 3), priceSteps: nonNegative(2, 7))
        let withThirds = ProtocolParameters(
            collateralPercentage: p.collateralPercentage, committeeMaxTermLength: p.committeeMaxTermLength,
            committeeMinSize: p.committeeMinSize, costModels: p.costModels, dRepActivity: p.dRepActivity,
            dRepDeposit: p.dRepDeposit, dRepVotingThresholds: p.dRepVotingThresholds,
            executionUnitPrices: thirds, govActionDeposit: p.govActionDeposit,
            govActionLifetime: p.govActionLifetime, maxBlockBodySize: p.maxBlockBodySize,
            maxBlockExecutionUnits: p.maxBlockExecutionUnits, maxBlockHeaderSize: p.maxBlockHeaderSize,
            maxCollateralInputs: p.maxCollateralInputs, maxTxExecutionUnits: p.maxTxExecutionUnits,
            maxTxSize: p.maxTxSize, maxValueSize: p.maxValueSize,
            minFeeRefScriptCostPerByte: p.minFeeRefScriptCostPerByte, minPoolCost: p.minPoolCost,
            monetaryExpansion: p.monetaryExpansion, poolPledgeInfluence: p.poolPledgeInfluence,
            poolRetireMaxEpoch: p.poolRetireMaxEpoch, poolVotingThresholds: p.poolVotingThresholds,
            protocolVersion: p.protocolVersion, stakeAddressDeposit: p.stakeAddressDeposit,
            stakePoolDeposit: p.stakePoolDeposit, stakePoolTargetNum: p.stakePoolTargetNum,
            treasuryCut: p.treasuryCut, txFeeFixed: p.txFeeFixed, txFeePerByte: p.txFeePerByte,
            utxoCostPerByte: p.utxoCostPerByte)
        let json = try JSONDecoder().decode(ProtocolParameters.self, from: JSONEncoder().encode(withThirds))
        #expect(json.executionUnitPrices == thirds)
        #expect(try ProtocolParameters.fromDict(withThirds.toDict()).executionUnitPrices == thirds)
        #expect(try ProtocolParameters.fromCBOR(data: withThirds.toCBORData()).executionUnitPrices == thirds)
    }

    @Test("A Double handed to fromDict means its shortest decimal")
    func doubleInDict() throws {
        guard case .orderedDict(var top) = try ExactRationalFileTests.loadParams().toDict() else {
            Issue.record("expected an object")
            return
        }
        top[.string("monetaryExpansion")] = .float(0.003)
        top[.string("executionUnitPrices")] = .orderedDict([
            .string("priceMemory"): .float(0.0577), .string("priceSteps"): .float(7.21e-5),
        ])
        let p = try ProtocolParameters.fromDict(.orderedDict(top))
        #expect(p.monetaryExpansion == unit(3, 1000))
        #expect(p.executionUnitPrices.priceMemory == mainnetMemPrice)
        #expect(p.executionUnitPrices.priceSteps == mainnetStepPrice)
    }

    @Test("Genesis files round-trip exactly through JSON and CBOR", arguments: ["mainnet", "preprod", "preview", "sanchonet"])
    func genesis(_ network: String) throws {
        let directory = "data/config/\(network)"
        let alonzo = try AlonzoGenesis.load(from: path("alonzo-genesis", directory))
        #expect(try JSONDecoder().decode(AlonzoGenesis.self, from: JSONEncoder().encode(alonzo)) == alonzo)
        #expect(try AlonzoGenesis.fromCBOR(data: alonzo.toCBORData()) == alonzo)

        let shelley = try ShelleyGenesis.load(from: path("shelley-genesis", directory))
        #expect(try JSONDecoder().decode(ShelleyGenesis.self, from: JSONEncoder().encode(shelley)) == shelley)
        #expect(try ShelleyGenesis.fromCBOR(data: shelley.toCBORData()) == shelley)

        let conway = try ConwayGenesis.load(from: path("conway-genesis", directory))
        #expect(try JSONDecoder().decode(ConwayGenesis.self, from: JSONEncoder().encode(conway)) == conway)
        #expect(try ConwayGenesis.fromCBOR(data: conway.toCBORData()) == conway)
    }
}

// MARK: - CBOR layouts

@Suite struct ExactRationalCBORTests {
    /// `#6.30([n, d])` with small parts.
    static func ratio(_ n: UInt8, _ d: UInt8) -> String { "d81e82" + String(format: "%02x%02x", n, d) }

    @Test("Pool voting thresholds are read and written in the ledger's order")
    func poolVotingThresholdOrder() throws {
        // [motionNoConfidence 1/10, committeeNormal 2/10 → 1/5, committeeNoConfidence 3/10,
        //  hardForkInitiation 4/10 → 2/5, ppSecurityGroup 5/10 → 1/2]
        let ledger = Primitive.list([
            LedgerRational.primitive(1, 10), LedgerRational.primitive(1, 5), LedgerRational.primitive(3, 10),
            LedgerRational.primitive(2, 5), LedgerRational.primitive(1, 2),
        ])
        let t = try ProtocolParametersPoolVotingThresholds(cbor: ledger)
        #expect(t.motionNoConfidence == unit(1, 10))
        #expect(t.committeeNormal == unit(1, 5))
        #expect(t.committeeNoConfidence == unit(3, 10))
        #expect(t.hardForkInitiation == unit(2, 5))
        #expect(t.ppSecurityGroup == unit(1, 2))
        #expect(try t.ledgerPrimitive() == ledger)

        // A ProtocolParamUpdate built from them writes the same order.
        let p = try ExactRationalFileTests.loadParams()
        guard case .dict(var map) = try p.toPrimitive() else {
            Issue.record("expected a map")
            return
        }
        map[.int(25)] = ledger
        let update = ProtocolParamUpdate(from: try ProtocolParameters(from: .dict(map)))
        #expect(try update.poolVotingThresholds?.toPrimitive() == ledger)
    }

    @Test("Rationals in protocol-parameter CBOR are tagged, reduced and range-checked")
    func protocolParameterRationals() throws {
        let p = try ExactRationalFileTests.loadParams()
        guard case .dict(var map) = try p.toPrimitive() else {
            Issue.record("expected a map")
            return
        }
        #expect(map[.int(19)] == .list([LedgerRational.primitive(577, 10_000), LedgerRational.primitive(721, 10_000_000)]))
        #expect(map[.int(10)] == LedgerRational.primitive(3, 1000))

        // 6/2000 is held as the ledger holds it: 3/1000.
        map[.int(10)] = .cborTag(CBORTag(tag: 30, value: .list([.uint(6), .uint(2000)])))
        #expect(try ProtocolParameters(from: .dict(map)).monetaryExpansion == unit(3, 1000))
        // Untagged, above one or with a zero denominator, the ledger refuses it.
        for bad: Primitive in [.list([.uint(3), .uint(1000)]),
                               .cborTag(CBORTag(tag: 30, value: .list([.uint(3), .uint(2)])))] {
            map[.int(10)] = bad
            #expect(throws: CardanoCoreError.self) { try ProtocolParameters(from: .dict(map)) }
        }
        #expect(throws: (any Error).self) {
            try ProtocolParameters.fromCBOR(data: hex("a1 0a d81e82 01 00"))
        }
    }

    /// The ledger's AlonzoGenesis for the mainnet values, with a two-entry
    /// cost model replaced by 166 zeros, built field by field from its
    /// `ToCBOR`: [coinsPerUTxOWord, costModel, [prMem, prSteps], maxTxExUnits,
    /// maxBlockExUnits, maxValSize, collateralPercentage, maxCollateralInputs,
    /// extraConfig].
    static func alonzoVector(extraConfig: String = "80") -> String {
        "89" + "1986b2"
            + "98a6" + String(repeating: "00", count: 166)
            + "82" + "d81e82 190241 192710" + "d81e82 1902d1 1a00989680"
            + "82 1a00989680 1b00000002540be400"
            + "82 1a02faf080 1b00000009502f9000"
            + "191388" + "1896" + "03"
            + extraConfig
    }

    @Test("AlonzoGenesis decodes and encodes the ledger's 9-field layout",
          arguments: ["80", "81 81 f6", "81 81 a2 00 820102 01 8103"])
    func alonzoVector(_ extraConfig: String) throws {
        let bytes = hex(Self.alonzoVector(extraConfig: extraConfig))
        let genesis = try AlonzoGenesis.fromCBOR(data: bytes)
        #expect(genesis.lovelacePerUTxOWord == 34482)
        #expect(genesis.executionPrices.priceMemory == mainnetMemPrice)
        #expect(genesis.executionPrices.priceSteps == mainnetStepPrice)
        #expect(genesis.maxTxExUnits == AlonzoGenesisExUnits(exUnitsMem: 10_000_000, exUnitsSteps: 10_000_000_000))
        #expect(genesis.maxBlockExUnits == AlonzoGenesisExUnits(exUnitsMem: 50_000_000, exUnitsSteps: 40_000_000_000))
        #expect(genesis.maxValueSize == 5000)
        #expect(genesis.collateralPercentage == 150)
        #expect(genesis.maxCollateralInputs == 3)
        switch extraConfig {
        case "80": #expect(genesis.extraConfig == nil)
        case "81 81 f6": #expect(genesis.extraConfig == AlonzoExtraConfig(costModels: nil))
        default: #expect(genesis.extraConfig?.costModels == [0: [1, 2], 1: [3]])
        }
        #expect(try genesis.toCBORData() == bytes)
    }

    @Test("AlonzoGenesis refuses layouts the ledger refuses")
    func alonzoRejections() throws {
        // The old 8-field list, prices in the wrong order, a short cost model.
        let eight = String(Self.alonzoVector().dropFirst(2).dropLast(2))
        #expect(throws: (any Error).self) { try AlonzoGenesis.fromCBOR(data: hex("88" + eight)) }
        let swapped = Self.alonzoVector().replacingOccurrences(
            of: "d81e82 190241 192710" + "d81e82 1902d1 1a00989680",
            with: "d81e82 1902d1 1a00989680" + "d81e82 190241 192710")
        // Swapped prices decode, but as the other price: memory is first.
        #expect(try AlonzoGenesis.fromCBOR(data: hex(swapped)).executionPrices.priceMemory == mainnetStepPrice)
        let short = Self.alonzoVector().replacingOccurrences(
            of: "98a6" + String(repeating: "00", count: 166), with: "98a5" + String(repeating: "00", count: 165))
        #expect(throws: (any Error).self) { try AlonzoGenesis.fromCBOR(data: hex(short)) }
        // A price above Word64 once reduced, or with a zero denominator.
        let zero = Self.alonzoVector().replacingOccurrences(of: "d81e82 190241 192710", with: "d81e82 190241 00")
        #expect(throws: (any Error).self) { try AlonzoGenesis.fromCBOR(data: hex(zero)) }
    }

    @Test("Execution units and prices from the node-to-client array are exact")
    func n2cPrices() throws {
        let p = try ExactRationalFileTests.loadParams()
        #expect(try ExecutionUnitPrices(cbor: p.executionUnitPrices.ledgerPrimitive(), "prices") == p.executionUnitPrices)
    }
}

// MARK: - Fees from exact prices

@Suite struct ExactRationalFeeTests {
    @Test("Script fees are ceiling(mem × priceMemory + steps × priceSteps), exactly",
          arguments: [
            // A whole transaction's budget: 807800 + 721000.
            (UInt64(14_000_000), UInt64(10_000_000_000), Coin(1_528_800)),
            // 0.0577 + 0.0000721 rounds up to 1.
            (1, 1, 1),
            (0, 0, 0),
            // 10000 × 577/10000 is exactly 577: no rounding up.
            (10_000, 0, 577),
            // 10001 × 577/10000 = 577.0577 → 578.
            (10_001, 0, 578),
            // 10^7 × 721/10^7 is exactly 721.
            (0, 10_000_000, 721),
          ] as [(UInt64, UInt64, Coin)])
    func scriptFee(_ memory: UInt64, _ steps: UInt64, _ fee: Coin) throws {
        let prices = try ExactRationalFileTests.loadParams().executionUnitPrices
        #expect(try prices.scriptFee(memory: memory, steps: steps) == fee)
    }

    @Test("A fee that does not fit a Coin throws")
    func scriptFeeOverflow() {
        let prices = ExecutionUnitPrices(priceMemory: nonNegative(.max, 1), priceSteps: nonNegative(0, 1))
        #expect(throws: CardanoCoreError.self) { try prices.scriptFee(memory: 2, steps: 0) }
    }
}
