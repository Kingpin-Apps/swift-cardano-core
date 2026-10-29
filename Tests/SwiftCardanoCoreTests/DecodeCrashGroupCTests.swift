import BigInt
import CBORCodable
import Foundation
import OrderedCollections
import Testing
@testable import SwiftCardanoCore

// Decoding — CBOR, a `Primitive` or JSON — must throw on what the ledger
// rejects, never trap. These cover block headers, Plutus, protocol
// parameters, genesis configs and the `AnyValue`/`CBOR` helpers.

private func hex(_ string: String) -> Data {
    Data(hexString: string.replacingOccurrences(of: " ", with: ""))!
}

private let maxU64: Primitive = .uint(UInt64.max)
private let twoTo32: Primitive = .uint(1 << 32)

private func rational(_ n: UInt64, _ d: UInt64) -> Primitive {
    .cborTag(CBORTag(tag: 30, value: .list([.uint(n), .uint(d)])))
}

private func replacing(_ primitive: Primitive, at index: Int, with value: Primitive) -> Primitive {
    guard case .list(var elements) = primitive else { return primitive }
    elements[index] = value
    return .list(elements)
}

private func dict(_ pairs: [(String, Primitive)]) -> Primitive {
    .orderedDict(OrderedDictionary(uniqueKeysWithValues: pairs.map { (.string($0.0), $0.1) }))
}

private func replacingKey(_ primitive: Primitive, _ key: String, with value: Primitive) -> Primitive {
    guard case .orderedDict(var d) = primitive else { return primitive }
    d[.string(key)] = value
    return .orderedDict(d)
}

// MARK: - Block headers

@Suite struct DecodeCrashGroupCHeaderTests {
    @Test("A negative block number or slot throws")
    func negativeBlockNumberAndSlot() throws {
        #expect(throws: CardanoCoreError.self) {
            try HeaderBody.fromCBOR(data: hex("8a 20 00 00 00 00 00 00 00 00 00"))
        }
        #expect(throws: CardanoCoreError.self) {
            try HeaderBody.fromCBOR(data: hex("8a 00 20 00 00 00 00 00 00 00 00"))
        }
    }

    @Test("A block body size beyond UInt32 throws")
    func blockBodySize() throws {
        #expect(throws: CardanoCoreError.self) {
            try HeaderBody.fromCBOR(data: hex("8a 00 00 f6 40 40 82 40 40 1b0000000100000000 00 00 00"))
        }
        let flat = try makeHeaderBody().toPrimitive()
        #expect(throws: CardanoCoreError.self) { try HeaderBody(from: replacing(flat, at: 6, with: .int(-1))) }
    }

    @Test("A negative sequence number or KES period throws, flat or nested")
    func operationalCertificateFields() throws {
        let flat = try makeHeaderBody().toPrimitive()
        #expect(throws: CardanoCoreError.self) { try HeaderBody(from: replacing(flat, at: 9, with: .int(-1))) }
        #expect(throws: CardanoCoreError.self) { try HeaderBody(from: replacing(flat, at: 10, with: .int(-1))) }

        // The nested, 10-element form.
        guard case .list(let e) = flat else { Issue.record("expected a list"); return }
        func nested(sequence: Primitive = .uint(1), kes: Primitive = .uint(2),
                    major: Primitive = .uint(10), minor: Primitive = .uint(0)) -> Primitive {
            .list(Array(e[0...7]) + [.list([e[8], sequence, kes, e[11]]), .list([major, minor])])
        }
        let decoded = try HeaderBody(from: nested())
        #expect(decoded.operationalCert.sequenceNumber == 1)
        #expect(decoded.protocolVersion.major == 10)
        #expect(throws: CardanoCoreError.self) { try HeaderBody(from: nested(sequence: .int(-1))) }
        #expect(throws: CardanoCoreError.self) { try HeaderBody(from: nested(kes: .int(-1))) }
        #expect(throws: CardanoCoreError.self) { try HeaderBody(from: nested(major: maxU64)) }
        #expect(throws: CardanoCoreError.self) { try HeaderBody(from: nested(minor: .int(-1))) }
    }

    @Test("A protocol version beyond Int, or negative, throws; a valid one round-trips")
    func protocolVersion() throws {
        let flat = try makeHeaderBody().toPrimitive()
        #expect(throws: CardanoCoreError.self) { try HeaderBody(from: replacing(flat, at: 12, with: maxU64)) }
        #expect(throws: CardanoCoreError.self) { try HeaderBody(from: replacing(flat, at: 13, with: maxU64)) }
        // A negative major was accepted, then trapped on when written.
        #expect(throws: CardanoCoreError.self) { try HeaderBody(from: replacing(flat, at: 12, with: .int(-1))) }

        let body = try HeaderBody(from: flat)
        #expect(try HeaderBody.fromCBOR(data: body.toCBORData()) == body)

        // A version set by hand to a negative number is written, not trapped on.
        var negative = body
        negative.protocolVersion = ProtocolVersion(major: -1, minor: 0)
        _ = try negative.toPrimitive()
    }

    @Test("JSON numbers out of range throw")
    func fromDict() throws {
        let body = try makeHeaderBody().toDict()
        #expect(throws: CardanoCoreError.self) { try HeaderBody.fromDict(replacingKey(body, "blockNumber", with: .int(-1))) }
        #expect(throws: CardanoCoreError.self) { try HeaderBody.fromDict(replacingKey(body, "slot", with: .int(-1))) }
        #expect(throws: CardanoCoreError.self) {
            try HeaderBody.fromDict(replacingKey(body, "blockBodySize", with: .int(1 << 32)))
        }
        #expect(throws: CardanoCoreError.self) {
            try HeaderBody.fromDict(replacingKey(body, "blockBodySize", with: .int(-1)))
        }
    }

    @Test("A negative era id throws")
    func eraIds() throws {
        #expect(throws: CardanoCoreError.self) { try EraBlock.fromNetworkCBOR(data: hex("82 20 40")) }
        #expect(throws: CardanoCoreError.self) { try EraBlock.fromCBOR(data: hex("82 20 40")) }
        #expect(throws: CardanoCoreError.self) { try EraBlockHeader.fromCBOR(data: hex("82 20 40")) }
        #expect(throws: CardanoCoreError.self) {
            try EraBlock.fromDict(dict([("era", .int(-1)), ("block", .null)]))
        }
        #expect(throws: CardanoCoreError.self) {
            try EraBlockHeader.fromDict(dict([("era", .int(-1)), ("header", .null)]))
        }

        // A valid era id still decodes.
        let header = EraBlockHeader.conway(try makeHeader())
        #expect(try EraBlockHeader.fromCBOR(data: header.toCBORData()) == header)
    }

    @Test("An invalid-transaction index beyond UInt16 throws")
    func invalidTransactionIndex() throws {
        let block = try makeBlock(includeTxs: true, includeInvalidTxs: true)
        let json = try block.toDict()
        #expect(try Block.fromDict(json) == block)
        #expect(throws: CardanoCoreError.self) {
            try Block.fromDict(replacingKey(json, "invalidTransactions", with: .list([.int(70000)])))
        }
        #expect(throws: CardanoCoreError.self) {
            try Block.fromDict(replacingKey(json, "invalidTransactions", with: .list([.int(-1)])))
        }
    }
}

// MARK: - Plutus

@Suite struct DecodeCrashGroupCPlutusTests {
    @Test("A #6.102 constructor with any UInt64 alternative round-trips")
    func generalConstructor() throws {
        let bytes = hex("d866821bffffffffffffffff80")
        let data = try PlutusData.fromCBOR(data: bytes)
        guard case .constructor(let constr) = data else {
            Issue.record("expected a constructor"); return
        }
        #expect(constr.tag == UInt64.max)
        #expect(try data.toCBORData() == bytes)

        // Alternatives a compact tag could carry, but written in the general
        // form, stay in the general form.
        let small = hex("d8668205 80")
        #expect(try PlutusData.fromCBOR(data: small).toCBORData() == small)

        // A constructor without a tag is written, not trapped on.
        _ = try Constr(tag: nil).toPrimitive()
    }

    @Test("A negative JSON constructor throws")
    func negativeJSONConstructor() throws {
        #expect(throws: CardanoCoreError.self) {
            try Constr.fromDict(dict([("constructor", .int(-1)), ("fields", .list([]))]))
        }
        let constr = try Constr.fromDict(dict([("constructor", .int(3)), ("fields", .list([]))]))
        #expect(constr.tag == 3)
    }

    @Test("An unknown Plutus script version throws")
    func scriptVersion() throws {
        #expect(throws: CardanoCoreError.self) { try PlutusScript.fromCBOR(data: hex("82 04 40")) }
        #expect(throws: CardanoCoreError.self) { try PlutusScript.fromCBOR(data: hex("82 1bffffffffffffffff 40")) }
        #expect(throws: CardanoCoreError.self) { try PlutusScript.fromVersion(0, data: Data()) }
        #expect(throws: CardanoCoreError.self) { try PlutusScript.fromDict(.list([.int(-1), .bytes(Data())])) }
        #expect(try PlutusScript.fromCBOR(data: hex("82 03 41 01")) == .plutusV3Script(PlutusV3Script(data: Data([1]))))
    }

    @Test("A redeemer index beyond UInt32 throws")
    func redeemerIndex() throws {
        #expect(throws: CardanoCoreError.self) {
            try TransactionWitnessSet.fromCBOR(data: hex("a1 05 a1 82 00 1bffffffffffffffff 82 80 82 00 00"))
        }
        #expect(throws: CardanoCoreError.self) {
            try TransactionWitnessSet.fromCBOR(data: hex("a1 05 a1 82 00 1b0000000100000000 82 80 82 00 00"))
        }
        // The legacy list form.
        #expect(throws: CardanoCoreError.self) {
            try TransactionWitnessSet.fromCBOR(data: hex("a1 05 81 84 00 1b0000000100000000 80 82 00 00"))
        }
        #expect(throws: CardanoCoreError.self) {
            try TransactionWitnessSet.fromCBOR(data: hex("a1 05 81 84 00 20 80 82 00 00"))
        }
        #expect(throws: CardanoCoreError.self) { try RedeemerKey.fromDict(.list([.int(0), .int(-1)])) }

        // The largest index the ledger accepts decodes.
        let key = try RedeemerKey.fromCBOR(data: hex("82 00 1affffffff"))
        #expect(key.index == Int(UInt32.max))
        _ = try TransactionWitnessSet.fromCBOR(data: hex("a1 05 a1 82 00 1affffffff 82 80 82 00 00"))
    }

    @Test("RawPlutusData from lists, maps and constructors does not trap")
    func rawPlutusDataFromPlutusData() throws {
        let list = PlutusData.array([.bigInt(.int(1)), .bytes(try Bytes(from: Data([1, 2])))])
        let raw = try RawPlutusData(from: list)
        #expect(try raw.toPlutusData() == list)
        _ = try raw.toAnyValue()

        let constr = PlutusData.constructor(Constr(tag: 0, fields: [.bigInt(.int(7))]))
        let nested = PlutusData.array([constr])
        #expect(try RawPlutusData(from: nested).toPlutusData() == nested)

        let map = try PlutusData.fromCBOR(data: hex("a2 01 02 03 80"))
        #expect(try RawPlutusData(from: map).toPlutusData() == map)

        // The old path through `RawPlutusData.toAnyValue` always trapped.
        _ = try RawPlutusData(data: .int(5)).toAnyValue()
        _ = try RawPlutusData.fromCBOR(data: hex("9f 01 ff")).toAnyValue()
    }
}

// MARK: - Protocol parameters

@Suite struct DecodeCrashGroupCParameterTests {
    func loadParams() throws -> ProtocolParameters {
        let path = try getFilePath(
            forResource: protocolParametersJSONFilePath.forResource,
            ofType: protocolParametersJSONFilePath.ofType,
            inDirectory: protocolParametersJSONFilePath.inDirectory
        )
        return try ProtocolParameters.load(from: path!)
    }

    /// The parameters as an integer-keyed map, with `key` set to `value`.
    func map(setting key: Int64, to value: Primitive) throws -> Primitive {
        guard case .dict(var d) = try loadParams().toPrimitive() else {
            throw CardanoCoreError.valueError("expected a map")
        }
        d[.int(key)] = value
        return .dict(d)
    }

    @Test("Map keys and values beyond their ranges throw")
    func mapForm() throws {
        #expect(throws: CardanoCoreError.self) { try ProtocolParameters.fromCBOR(data: hex("a1 1bffffffffffffffff 00")) }
        #expect(throws: CardanoCoreError.self) { try ProtocolParameters.fromCBOR(data: hex("a1 00 1bffffffffffffffff")) }

        _ = try ProtocolParameters(from: map(setting: 0, to: .uint(44)))
        #expect(throws: CardanoCoreError.self) { try ProtocolParameters(from: map(setting: 0, to: .int(-1))) }
        #expect(throws: CardanoCoreError.self) { try ProtocolParameters(from: map(setting: 2, to: twoTo32)) }
        #expect(throws: CardanoCoreError.self) { try ProtocolParameters(from: map(setting: 4, to: .uint(70000))) }
        #expect(throws: CardanoCoreError.self) { try ProtocolParameters(from: map(setting: 20, to: .list([maxU64, .uint(0)]))) }
        #expect(throws: CardanoCoreError.self) { try ProtocolParameters(from: map(setting: 21, to: .list([.uint(0), maxU64]))) }
        #expect(throws: CardanoCoreError.self) { try ProtocolParameters(from: map(setting: 33, to: rational(UInt64.max, 1))) }
    }

    /// A 31-element node-to-client parameter array, with `index` set to `value`.
    func n2c(setting index: Int? = nil, to value: Primitive = .null) -> Primitive {
        let half = rational(1, 2)
        var e: [Primitive] = Array(repeating: .uint(1), count: 31)
        e[9] = half; e[10] = half; e[11] = half
        e[12] = .list([.uint(10), .uint(0)])
        e[15] = .dict([.uint(0): .list([.uint(1), .int(-2)])])
        e[16] = .list([half, half])
        e[17] = .list([.uint(10), .uint(20)])
        e[18] = .list([.uint(10), .uint(20)])
        e[22] = .list(Array(repeating: half, count: 5))
        e[23] = .list(Array(repeating: half, count: 10))
        e[30] = rational(15, 1)
        if let index { e[index] = value }
        return .list(e)
    }

    @Test("The node-to-client array decodes, and throws on out-of-range values")
    func n2cForm() throws {
        let params = try ProtocolParameters(from: n2c())
        #expect(params.costModels.PlutusV1 == [1, -2])
        #expect(params.minFeeRefScriptCostPerByte == 15)

        #expect(throws: CardanoCoreError.self) { try ProtocolParameters(from: n2c(setting: 0, to: maxU64)) }
        #expect(throws: CardanoCoreError.self) { try ProtocolParameters(from: n2c(setting: 0, to: .int(-1))) }
        #expect(throws: CardanoCoreError.self) { try ProtocolParameters(from: n2c(setting: 2, to: twoTo32)) }
        #expect(throws: CardanoCoreError.self) { try ProtocolParameters(from: n2c(setting: 12, to: .list([maxU64, .uint(0)]))) }
        #expect(throws: CardanoCoreError.self) { try ProtocolParameters(from: n2c(setting: 15, to: .dict([.uint(0): .list([maxU64])]))) }
        #expect(throws: CardanoCoreError.self) { try ProtocolParameters(from: n2c(setting: 15, to: .dict([maxU64: .list([])]))) }
        #expect(throws: CardanoCoreError.self) { try ProtocolParameters(from: n2c(setting: 17, to: .list([maxU64, .uint(0)]))) }
        #expect(throws: CardanoCoreError.self) { try ProtocolParameters(from: n2c(setting: 18, to: .list([.uint(0), maxU64]))) }
        #expect(throws: CardanoCoreError.self) { try ProtocolParameters(from: n2c(setting: 30, to: rational(UInt64.max, 1))) }
    }

    @Test("JSON numbers beyond Int64 throw")
    func fromDict() throws {
        let json = try loadParams().toDict()
        #expect(throws: (any Error).self) {
            try ProtocolParameters.fromDict(replacingKey(json, "txFeeFixed", with: maxU64))
        }
    }

    @Test("Prices and execution units that cannot be written throw, not trap")
    func encode() throws {
        let p = try loadParams()
        func with(prices: ExecutionUnitPrices? = nil, tx: ProtocolParametersExecutionUnits? = nil,
                  pledge: Double? = nil) -> ProtocolParameters {
            ProtocolParameters(
                collateralPercentage: p.collateralPercentage, committeeMaxTermLength: p.committeeMaxTermLength,
                committeeMinSize: p.committeeMinSize, costModels: p.costModels, dRepActivity: p.dRepActivity,
                dRepDeposit: p.dRepDeposit, dRepVotingThresholds: p.dRepVotingThresholds,
                executionUnitPrices: prices ?? p.executionUnitPrices, govActionDeposit: p.govActionDeposit,
                govActionLifetime: p.govActionLifetime, maxBlockBodySize: p.maxBlockBodySize,
                maxBlockExecutionUnits: p.maxBlockExecutionUnits, maxBlockHeaderSize: p.maxBlockHeaderSize,
                maxCollateralInputs: p.maxCollateralInputs, maxTxExecutionUnits: tx ?? p.maxTxExecutionUnits,
                maxTxSize: p.maxTxSize, maxValueSize: p.maxValueSize, minPoolCost: p.minPoolCost,
                monetaryExpansion: p.monetaryExpansion, poolPledgeInfluence: pledge ?? p.poolPledgeInfluence,
                poolRetireMaxEpoch: p.poolRetireMaxEpoch, poolVotingThresholds: p.poolVotingThresholds,
                protocolVersion: p.protocolVersion, stakeAddressDeposit: p.stakeAddressDeposit,
                stakePoolDeposit: p.stakePoolDeposit, stakePoolTargetNum: p.stakePoolTargetNum,
                treasuryCut: p.treasuryCut, txFeeFixed: p.txFeeFixed, txFeePerByte: p.txFeePerByte,
                utxoCostPerByte: p.utxoCostPerByte)
        }
        _ = try with().toPrimitive()
        #expect(throws: CardanoCoreError.self) {
            try with(prices: ExecutionUnitPrices(priceMemory: 2e10, priceSteps: 0)).toPrimitive()
        }
        #expect(throws: CardanoCoreError.self) {
            try with(prices: ExecutionUnitPrices(priceMemory: .infinity, priceSteps: 0)).toPrimitive()
        }
        #expect(throws: CardanoCoreError.self) { try with(pledge: .nan).toPrimitive() }
        #expect(throws: CardanoCoreError.self) {
            try with(tx: ProtocolParametersExecutionUnits(memory: -1, steps: 0)).toPrimitive()
        }
    }
}

// MARK: - Genesis configs

@Suite struct DecodeCrashGroupCGenesisTests {
    // Conway

    func conway(setting index: Int? = nil, to value: Primitive = .null) -> Primitive {
        let half = rational(1, 2)
        var e: [Primitive] = [
            .list(Array(repeating: half, count: 5)),
            .list(Array(repeating: half, count: 10)),
            .uint(7), .uint(146), .uint(6), .uint(100_000_000_000), .uint(500_000_000), .uint(20),
            rational(15, 1),
            .list([.uint(1), .int(-2)]),
            .list([.list([.string("https://example.com"), .string("00")]), .list([])]),
            .list([.dict([.string("aa"): .uint(580)]), rational(2, 3)]),
        ]
        if let index { e[index] = value }
        return .list(e)
    }

    @Test("ConwayGenesis decodes, and throws on out-of-range values")
    func conwayGenesis() throws {
        let genesis = try ConwayGenesis(from: conway())
        #expect(genesis.committeeMinSize == 7)
        #expect(genesis.minFeeRefScriptCostPerByte == 15)
        #expect(genesis.committee.members["aa"] == 580)
        _ = try genesis.toPrimitive()

        #expect(throws: CardanoCoreError.self) { try ConwayGenesis(from: conway(setting: 2, to: maxU64)) }
        #expect(throws: CardanoCoreError.self) { try ConwayGenesis(from: conway(setting: 2, to: .uint(70000))) }
        #expect(throws: CardanoCoreError.self) { try ConwayGenesis(from: conway(setting: 3, to: twoTo32)) }
        #expect(throws: CardanoCoreError.self) { try ConwayGenesis(from: conway(setting: 7, to: .int(-1))) }
        #expect(throws: CardanoCoreError.self) { try ConwayGenesis(from: conway(setting: 8, to: maxU64)) }
        #expect(throws: CardanoCoreError.self) { try ConwayGenesis(from: conway(setting: 8, to: rational(1, 0))) }
        #expect(throws: CardanoCoreError.self) { try ConwayGenesis(from: conway(setting: 9, to: .list([maxU64]))) }
        #expect(throws: CardanoCoreError.self) {
            try ConwayGenesis(from: conway(setting: 0, to: .list(Array(repeating: rational(1, 0), count: 5))))
        }
        #expect(throws: CardanoCoreError.self) {
            try ConwayGenesis(from: conway(setting: 1, to: .list(Array(repeating: rational(3, 2), count: 10))))
        }
        #expect(throws: CardanoCoreError.self) {
            try ConwayGenesis(from: conway(setting: 11, to: .list([.dict([.string("aa"): maxU64]), rational(2, 3)])))
        }
        #expect(throws: CardanoCoreError.self) {
            try ConwayGenesis(from: conway(setting: 11, to: .list([.dict([:]), rational(UInt64.max, UInt64.max - 1)])))
        }
    }

    @Test("Conway thresholds that cannot be written throw, not trap")
    func conwayEncode() throws {
        let bad = ConwayGenesisPoolVotingThresholds(
            committeeNormal: .infinity, committeeNoConfidence: 0, hardForkInitiation: 0,
            motionNoConfidence: 0, ppSecurityGroup: 0)
        #expect(throws: CardanoCoreError.self) { try bad.toPrimitive() }
        let huge = ConwayGenesisDRepVotingThresholds(
            motionNoConfidence: 1e300, committeeNormal: 0, committeeNoConfidence: 0, updateToConstitution: 0,
            hardForkInitiation: 0, ppNetworkGroup: 0, ppEconomicGroup: 0, ppTechnicalGroup: 0, ppGovGroup: 0,
            treasuryWithdrawal: .nan)
        #expect(throws: CardanoCoreError.self) { try huge.toPrimitive() }
    }

    // Shelley

    func shelleyParams(setting index: Int? = nil, to value: Primitive = .null) -> Primitive {
        var e: [Primitive] = [
            .uint(44), .uint(155_381), .uint(65536), .uint(16384), .uint(1100),
            .uint(2_000_000), .uint(500_000_000), .uint(18), .uint(150),
            rational(3, 10), rational(3, 1000), rational(1, 5), rational(1, 1),
            .list([.uint(0)]), .list([.uint(2), .uint(0)]), .uint(1_000_000), .uint(340_000_000),
        ]
        if let index { e[index] = value }
        return .list(e)
    }

    func shelley(setting index: Int? = nil, to value: Primitive = .null) -> Primitive {
        var e: [Primitive] = [
            .string("2017-09-23T21:44:51Z"), .uint(764_824_073), .uint(1), rational(1, 20),
            .uint(2160), .uint(432_000), .uint(129_600), .uint(62), .uint(1), .uint(5),
            .uint(45_000_000_000_000_000), shelleyParams(), .list([]),
            .list([.list([.string("addr"), .uint(1_000_000)])]),
        ]
        if let index { e[index] = value }
        return .list(e)
    }

    @Test("ShelleyGenesis decodes, and throws on out-of-range values")
    func shelleyGenesis() throws {
        #expect(throws: CardanoCoreError.self) {
            try ShelleyGenesis.fromCBOR(data: hex("8e 60 1b0000000100000000" + String(repeating: "00", count: 12)))
        }

        let genesis = try ShelleyGenesis(from: shelley())
        #expect(genesis.networkMagic == 764_824_073)
        #expect(genesis.initialFunds["addr"] == 1_000_000)
        _ = try genesis.toPrimitive()

        #expect(throws: CardanoCoreError.self) { try ShelleyGenesis(from: shelley(setting: 3, to: rational(1, 0))) }
        #expect(throws: CardanoCoreError.self) { try ShelleyGenesis(from: shelley(setting: 3, to: rational(0, 1))) }
        #expect(throws: CardanoCoreError.self) { try ShelleyGenesis(from: shelley(setting: 3, to: rational(3, 2))) }
        #expect(throws: CardanoCoreError.self) { try ShelleyGenesis(from: shelley(setting: 4, to: twoTo32)) }
        #expect(throws: CardanoCoreError.self) {
            try ShelleyGenesis(from: shelley(setting: 8, to: rational(UInt64.max, 1)))
        }
        #expect(throws: CardanoCoreError.self) { try ShelleyGenesis(from: shelley(setting: 8, to: twoTo32)) }
        #expect(throws: CardanoCoreError.self) { try ShelleyGenesis(from: shelley(setting: 9, to: maxU64)) }
        #expect(throws: CardanoCoreError.self) {
            try ShelleyGenesis(from: shelley(setting: 13, to: .list([.list([.string("a"), maxU64])])))
        }
        #expect(throws: CardanoCoreError.self) {
            try ShelleyGenesis(from: shelley(setting: 13, to: .list([.list([.string("a"), .int(-1)])])))
        }
        #expect(throws: CardanoCoreError.self) {
            try ShelleyGenesis(from: shelley(setting: 0, to: .list([maxU64, .uint(1), .uint(0)])))
        }
        #expect(throws: CardanoCoreError.self) {
            try ShelleyGenesis(from: shelley(setting: 0, to: .list([.uint(2017), maxU64, .uint(0)])))
        }
        _ = try ShelleyGenesis(from: shelley(setting: 0, to: .list([.uint(2017), .uint(266), .uint(0)])))
    }

    @Test("Shelley protocol params throw on out-of-range values")
    func shelleyProtocolParams() throws {
        _ = try ProtocolParams(from: shelleyParams())
        #expect(throws: CardanoCoreError.self) { try ProtocolParams(from: shelleyParams(setting: 0, to: twoTo32)) }
        #expect(throws: CardanoCoreError.self) { try ProtocolParams(from: shelleyParams(setting: 4, to: .uint(70000))) }
        #expect(throws: CardanoCoreError.self) { try ProtocolParams(from: shelleyParams(setting: 7, to: maxU64)) }
        #expect(throws: CardanoCoreError.self) { try ProtocolParams(from: shelleyParams(setting: 8, to: .uint(70000))) }
        #expect(throws: CardanoCoreError.self) { try ProtocolParams(from: shelleyParams(setting: 9, to: rational(1, 0))) }
        #expect(throws: CardanoCoreError.self) { try ProtocolParams(from: shelleyParams(setting: 10, to: rational(2, 1))) }
        #expect(throws: CardanoCoreError.self) {
            try ProtocolParams(from: shelleyParams(setting: 14, to: .list([maxU64, .uint(0)])))
        }
    }

    @Test("Shelley rationals that cannot be written throw, not trap")
    func shelleyEncode() throws {
        let params = try ProtocolParams(from: shelleyParams())
        let bad = ProtocolParams(
            protocolVersion: params.protocolVersion, decentralisationParam: .nan, eMax: params.eMax,
            extraEntropy: params.extraEntropy, maxTxSize: params.maxTxSize,
            maxBlockBodySize: params.maxBlockBodySize, maxBlockHeaderSize: params.maxBlockHeaderSize,
            minFeeA: params.minFeeA, minFeeB: params.minFeeB, minUTxOValue: params.minUTxOValue,
            poolDeposit: params.poolDeposit, minPoolCost: params.minPoolCost, keyDeposit: params.keyDeposit,
            nOpt: -1, rho: params.rho, tau: params.tau, a0: .infinity)
        #expect(throws: CardanoCoreError.self) { try bad.toPrimitive() }

        let genesis = try ShelleyGenesis(from: shelley())
        let infinite = ShelleyGenesis(
            activeSlotsCoeff: .infinity, protocolParams: genesis.protocolParams, genDelegs: [:],
            updateQuorum: -1, networkId: "Mainnet", initialFunds: ["a": -5],
            maxLovelaceSupply: 1, networkMagic: 1, epochLength: 1, systemStart: "x",
            slotsPerKESPeriod: 1, slotLength: 1, maxKESEvolutions: 1, securityParam: 1)
        #expect(throws: CardanoCoreError.self) { try infinite.toPrimitive() }
    }

    // Alonzo

    func alonzo(setting index: Int? = nil, to value: Primitive = .null) -> Primitive {
        var e: [Primitive] = [
            .uint(34482), .dict([.uint(0): .list([.uint(1), .int(-2)])]),
            .list([rational(721, 10_000_000), rational(577, 10_000)]),
            .list([.uint(10_000_000), .uint(10_000_000_000)]),
            .list([.uint(50_000_000), .uint(40_000_000_000)]),
            .uint(5000), .uint(150), .uint(3),
        ]
        if let index { e[index] = value }
        return .list(e)
    }

    @Test("AlonzoGenesis decodes, and throws on out-of-range values")
    func alonzoGenesis() throws {
        #expect(throws: CardanoCoreError.self) {
            try AlonzoGenesis.fromCBOR(data: hex("88 1bffffffffffffffff 00 00 00 00 00 00 00"))
        }

        let genesis = try AlonzoGenesis(from: alonzo())
        #expect(genesis.costModels.plutusV1 == ["0": 1, "1": -2])
        _ = try genesis.toPrimitive()

        #expect(throws: CardanoCoreError.self) {
            try AlonzoGenesis(from: alonzo(setting: 1, to: .dict([.uint(0): .list([maxU64])])))
        }
        _ = try AlonzoGenesis(from: alonzo(setting: 1, to: .dict([maxU64: .list([])])))
        #expect(throws: CardanoCoreError.self) {
            try AlonzoGenesis(from: alonzo(setting: 2, to: .list([rational(1, 0), rational(1, 1)])))
        }
        #expect(throws: CardanoCoreError.self) {
            try AlonzoGenesis(from: alonzo(setting: 2, to: .list([rational(UInt64.max, 1), rational(1, 1)])))
        }
        #expect(throws: CardanoCoreError.self) {
            try AlonzoGenesis(from: alonzo(setting: 3, to: .list([maxU64, .uint(0)])))
        }
        #expect(throws: CardanoCoreError.self) { try AlonzoGenesis(from: alonzo(setting: 5, to: twoTo32)) }
        #expect(throws: CardanoCoreError.self) { try AlonzoGenesis(from: alonzo(setting: 6, to: .uint(70000))) }
        #expect(throws: CardanoCoreError.self) { try AlonzoGenesis(from: alonzo(setting: 7, to: .int(-1))) }
    }
}

// MARK: - AnyValue and CBOR helpers

@Suite struct DecodeCrashGroupCExtensionTests {
    @Test("Integers beyond Int64 become primitives without trapping")
    func anyValueToPrimitive() {
        #expect(AnyValue.uint64(UInt64.max).toPrimitive() == .uint(UInt64.max))
        #expect(AnyValue.uint64(5).toPrimitive() == .int(5))
        #expect(AnyValue.unsignedInteger(BigUInt(UInt64.max)).toPrimitive() == .uint(UInt64.max))
        let big = BigInt(1) << 70
        #expect(AnyValue.integer(big).toPrimitive() == .bigInt(big))
        #expect(AnyValue.integer(-big).toPrimitive() == .bigInt(-big))
    }

    @Test("A unit interval beyond Int becomes an AnyValue without trapping")
    func unitIntervalToAnyValue() throws {
        let value = try AnyValue(from: .unitInterval(UnitInterval(numerator: UInt64.max, denominator: UInt64.max)))
        #expect(value == .array([.uint64(UInt64.max), .uint64(UInt64.max)]))
        #expect(try AnyValue(from: .unitInterval(UnitInterval(numerator: 1, denominator: 2))) == .array([.int(1), .int(2)]))
    }

    @Test("Nil and negative Int8 values become CBOR without trapping")
    func fromAnyCardano() {
        #expect(CBOR.fromAnyCardano(AnyValue.nil) == .null)
        #expect(CBOR.fromAnyCardano(Int8(-5)) == .negativeInt(4))
        #expect(CBOR.fromAnyCardano(Int8(5)) == .simple(5))
    }
}
