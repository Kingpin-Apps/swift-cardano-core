import BigInt
import CBORCodable
import Foundation
import Testing
@testable import SwiftCardanoCore

// Each protocol-parameter and genesis field holds the whole range of its
// ledger type: the top of the range decodes and round-trips, and the first
// value past it throws.
//
// Ledger types (cardano-ledger): Coin and CompactForm Coin are Word64;
// EpochInterval and ProtVer's parts are Word32; EpochSize, EpochNo and the
// Shelley genesis counts are Word64; ExUnits are Natural, read from JSON up to
// Word64 and from CBOR up to Int64.max; rationals are BoundedRatio Word64.

// MARK: - JSON helpers

private let u16Max = "65535", u16Beyond = "65536"
private let u32Max = "4294967295", u32Beyond = "4294967296"
private let u64Max = "18446744073709551615", u64Beyond = "18446744073709551616"
private let i64Max = "9223372036854775807", i64Beyond = "9223372036854775808"

private func number(_ digits: String) -> NSDecimalNumber { NSDecimalNumber(string: digits) }

private func jsonObject(_ file: (forResource: String, ofType: String, inDirectory: String)) throws -> [String: Any] {
    let path = try #require(try getFilePath(
        forResource: file.forResource, ofType: file.ofType, inDirectory: file.inDirectory))
    let data = try Data(contentsOf: URL(fileURLWithPath: path))
    return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
}

/// `object` with the value at `path` set to `value`, adding the key if needed.
private func setting(_ object: [String: Any], _ path: [String], to value: Any) -> [String: Any] {
    var copy = object
    guard let key = path.first else { return copy }
    if path.count == 1 {
        copy[key] = value
    } else {
        copy[key] = setting(copy[key] as? [String: Any] ?? [:], Array(path.dropFirst()), to: value)
    }
    return copy
}

private func value(in object: Any, at path: [String]) -> Any? {
    path.reduce(Optional(object)) { ($0 as? [String: Any])?[$1] }
}

/// `value` with each floating-point number replaced by its shortest decimal.
/// JSONSerialization reads `7.21e-5` into a Double and writes that back with
/// 17 digits (`7.2100000000000004e-05`), which an exact reader takes at its
/// word; the shortest form is the number the file holds.
private func shortestDecimals(_ value: Any) -> Any {
    switch value {
    case let n as NSNumber where !(n is NSDecimalNumber) && String(cString: n.objCType) == "d":
        return NSDecimalNumber(string: "\(n.doubleValue)")
    case let array as [Any]:
        return array.map(shortestDecimals)
    case let dict as [String: Any]:
        return dict.mapValues(shortestDecimals)
    default:
        return value
    }
}

private func decode<T: Decodable>(_ type: T.Type, _ object: [String: Any]) throws -> T {
    try JSONDecoder().decode(T.self, from: JSONSerialization.data(withJSONObject: shortestDecimals(object)))
}

/// `item` written as JSON, then read back as a plain object.
private func reencoded<T: Encodable>(_ item: T) throws -> Any {
    try JSONSerialization.jsonObject(with: JSONEncoder().encode(item))
}

/// The JSON value at `path` of `item`, as text.
private func text<T: Encodable>(of item: T, at path: [String]) throws -> String {
    let found = try #require(value(in: try reencoded(item), at: path))
    return "\(found)"
}

/// The integer field at `path`, its largest value and the first past it, and
/// its key in the CBOR map, if it has one there.
struct WidthCase: Sendable, CustomTestStringConvertible {
    let path: [String]
    let top: String
    let beyond: String
    let cborKey: Int64?
    let inCBOR: Bool

    init(_ path: String, _ top: String, _ beyond: String, cbor cborKey: Int64? = nil, inCBOR: Bool = true) {
        self.path = path.split(separator: ".").map(String.init)
        self.top = top
        self.beyond = beyond
        self.cborKey = cborKey
        self.inCBOR = inCBOR
    }

    var testDescription: String { path.joined(separator: ".") }
}

// MARK: - Protocol parameters

@Suite struct ProtocolParameterWidthTests {
    func params() throws -> [String: Any] { try jsonObject(protocolParametersJSONFilePath) }

    static let cases: [WidthCase] = [
        // Coin (CompactForm Coin, CoinPerByte): Word64.
        WidthCase("txFeePerByte", u64Max, u64Beyond, cbor: 0),
        WidthCase("txFeeFixed", u64Max, u64Beyond, cbor: 1),
        WidthCase("stakeAddressDeposit", u64Max, u64Beyond, cbor: 5),
        WidthCase("stakePoolDeposit", u64Max, u64Beyond, cbor: 6),
        WidthCase("minPoolCost", u64Max, u64Beyond, cbor: 16),
        WidthCase("utxoCostPerByte", u64Max, u64Beyond, cbor: 17),
        WidthCase("govActionDeposit", u64Max, u64Beyond, cbor: 30),
        WidthCase("dRepDeposit", u64Max, u64Beyond, cbor: 31),
        // Alonzo's CoinPerWord: JSON only.
        WidthCase("coinsPerUtxoWord", u64Max, u64Beyond, inCBOR: false),
        // Word32 and EpochInterval (Word32).
        WidthCase("maxBlockBodySize", u32Max, u32Beyond, cbor: 2),
        WidthCase("maxTxSize", u32Max, u32Beyond, cbor: 3),
        WidthCase("poolRetireMaxEpoch", u32Max, u32Beyond, cbor: 7),
        WidthCase("maxValueSize", u32Max, u32Beyond, cbor: 22),
        WidthCase("committeeMaxTermLength", u32Max, u32Beyond, cbor: 28),
        WidthCase("govActionLifetime", u32Max, u32Beyond, cbor: 29),
        WidthCase("dRepActivity", u32Max, u32Beyond, cbor: 32),
        WidthCase("protocolVersion.major", u32Max, u32Beyond),
        WidthCase("protocolVersion.minor", u32Max, u32Beyond),
        // Word16.
        WidthCase("maxBlockHeaderSize", u16Max, u16Beyond, cbor: 4),
        WidthCase("stakePoolTargetNum", u16Max, u16Beyond, cbor: 8),
        WidthCase("collateralPercentage", u16Max, u16Beyond, cbor: 23),
        WidthCase("maxCollateralInputs", u16Max, u16Beyond, cbor: 24),
        WidthCase("committeeMinSize", u16Max, u16Beyond, cbor: 27),
        // ExUnits: Word64 in JSON (CBOR is checked on its own below).
        WidthCase("maxTxExecutionUnits.memory", u64Max, u64Beyond, inCBOR: false),
        WidthCase("maxTxExecutionUnits.steps", u64Max, u64Beyond, inCBOR: false),
        WidthCase("maxBlockExecutionUnits.memory", u64Max, u64Beyond, inCBOR: false),
        WidthCase("maxBlockExecutionUnits.steps", u64Max, u64Beyond, inCBOR: false),
    ]

    @Test("The top of the ledger's range decodes and round-trips", arguments: cases)
    func top(_ field: WidthCase) throws {
        let decoded = try decode(ProtocolParameters.self, setting(params(), field.path, to: number(field.top)))
        #expect(try text(of: decoded, at: field.path) == field.top)

        let viaDict = try ProtocolParameters.fromDict(try decoded.toDict())
        #expect(try text(of: viaDict, at: field.path) == field.top)

        if field.inCBOR {
            let viaCBOR = try ProtocolParameters(from: try decoded.toPrimitive())
            #expect(try text(of: viaCBOR, at: field.path) == field.top)
            let viaBytes = try ProtocolParameters.fromCBOR(data: try decoded.toCBORData())
            #expect(try text(of: viaBytes, at: field.path) == field.top)
        }
    }

    @Test("A value past the ledger's range throws", arguments: cases)
    func beyond(_ field: WidthCase) throws {
        #expect(throws: (any Error).self) {
            try decode(ProtocolParameters.self, setting(params(), field.path, to: number(field.beyond)))
        }
        #expect(throws: (any Error).self) {
            try decode(ProtocolParameters.self, setting(params(), field.path, to: -1))
        }
        guard let key = field.cborKey else { return }
        let base = try decode(ProtocolParameters.self, params())
        guard case .dict(var map) = try base.toPrimitive() else {
            Issue.record("expected a CBOR map")
            return
        }
        map[.int(key)] = .bigUInt(BigUInt(field.beyond)!)
        #expect(throws: CardanoCoreError.self) { try ProtocolParameters(from: .dict(map)) }
        map[.int(key)] = .int(-1)
        #expect(throws: CardanoCoreError.self) { try ProtocolParameters(from: .dict(map)) }
    }

    @Test("Execution units: Word64 in JSON, at most Int64.max in CBOR")
    func executionUnitsInCBOR() throws {
        let top = try decode(ProtocolParameters.self, setting(
            setting(params(), ["maxTxExecutionUnits", "memory"], to: number(i64Max)),
            ["maxBlockExecutionUnits", "steps"], to: number(i64Max)))
        let back = try ProtocolParameters(from: try top.toPrimitive())
        #expect(back.maxTxExecutionUnits.memory == UInt64(Int64.max))
        #expect(back.maxBlockExecutionUnits.steps == UInt64(Int64.max))

        // The ledger's CBOR reader refuses anything past Int64.max, so neither
        // writing nor reading one succeeds.
        let past = try decode(ProtocolParameters.self, setting(
            params(), ["maxTxExecutionUnits", "steps"], to: number(i64Beyond)))
        #expect(past.maxTxExecutionUnits.steps == UInt64(Int64.max) + 1)
        #expect(throws: CardanoCoreError.self) { try past.toPrimitive() }

        guard case .dict(var map) = try top.toPrimitive() else {
            Issue.record("expected a CBOR map")
            return
        }
        map[.int(20)] = .list([.uint(UInt64(Int64.max) + 1), .uint(0)])
        #expect(throws: CardanoCoreError.self) { try ProtocolParameters(from: .dict(map)) }
    }

    @Test("minFeeRefScriptCostPerByte is a NonNegativeInterval, not a whole number")
    func minFeeRefScriptCostPerByte() throws {
        let fractional = try decode(ProtocolParameters.self, setting(params(), ["minFeeRefScriptCostPerByte"], to: 15.5))
        let fifteenAndAHalf = NonNegativeInterval(numerator: 31, denominator: 2)
        #expect(fractional.minFeeRefScriptCostPerByte == fifteenAndAHalf)
        #expect(try ProtocolParameters(from: fractional.toPrimitive()).minFeeRefScriptCostPerByte == fifteenAndAHalf)

        // A whole number up to Word64 is written exactly, over one.
        let whole = NonNegativeInterval(numerator: UInt64(1) << 63, denominator: 1)
        let large = try decode(ProtocolParameters.self, setting(params(), ["minFeeRefScriptCostPerByte"], to: UInt64(1) << 63))
        #expect(large.minFeeRefScriptCostPerByte == whole)
        #expect(try ProtocolParameters(from: large.toPrimitive()).minFeeRefScriptCostPerByte == whole)

        // A ratio of Word64s, at the top of their range, decodes.
        guard case .dict(var map) = try fractional.toPrimitive() else {
            Issue.record("expected a CBOR map")
            return
        }
        map[.int(33)] = .cborTag(CBORTag(tag: 30, value: .list([.uint(.max), .uint(.max)])))
        // The ledger reduces it to 1/1.
        #expect(try ProtocolParameters(from: .dict(map)).minFeeRefScriptCostPerByte
                == NonNegativeInterval(numerator: 1, denominator: 1))
        map[.int(33)] = .cborTag(CBORTag(tag: 30, value: .list([.bigUInt(BigUInt(u64Beyond)!), .uint(1)])))
        #expect(throws: CardanoCoreError.self) { try ProtocolParameters(from: .dict(map)) }

        #expect(throws: CardanoCoreError.self) {
            try decode(ProtocolParameters.self, setting(params(), ["minFeeRefScriptCostPerByte"], to: -1))
        }
    }

    @Test("A unit-interval parameter above one throws")
    func unitIntervals() throws {
        #expect(throws: CardanoCoreError.self) {
            try decode(ProtocolParameters.self, setting(params(), ["monetaryExpansion"], to: 1.5))
        }
        #expect(throws: CardanoCoreError.self) {
            try decode(ProtocolParameters.self, setting(params(), ["poolVotingThresholds", "ppSecurityGroup"], to: 2))
        }
    }

    @Test("A whole ProtocolParamUpdate builds from parameters at the top of their range")
    func paramUpdate() throws {
        var object = try params()
        for field in Self.cases where !field.path.contains(where: { $0.hasPrefix("max") && $0.hasSuffix("Units") }) {
            object = setting(object, field.path, to: number(field.top))
        }
        let update = ProtocolParamUpdate(from: try decode(ProtocolParameters.self, object))
        #expect(update.minFeeA == .max)
        #expect(update.governanceActionDeposit == .max)
        #expect(update.maxTransactionSize == .max)
        #expect(update.minCommitteeSize == .max)
        #expect(update.minFeeRefScriptCoinsPerByte != nil)
    }
}

// MARK: - Shelley genesis

@Suite struct ShelleyGenesisWidthTests {
    func genesis() throws -> [String: Any] { try jsonObject(shelleyGenesisJSONFilePath) }

    static let cases: [WidthCase] = [
        WidthCase("securityParam", u64Max, u64Beyond),
        WidthCase("epochLength", u64Max, u64Beyond),
        WidthCase("slotsPerKESPeriod", u64Max, u64Beyond),
        WidthCase("maxKESEvolutions", u64Max, u64Beyond),
        WidthCase("updateQuorum", u64Max, u64Beyond),
        WidthCase("maxLovelaceSupply", u64Max, u64Beyond),
        WidthCase("networkMagic", u32Max, u32Beyond),
        // A hex address key, as the ledger's `parseAddr` requires.
        WidthCase("initialFunds.61" + String(repeating: "ab", count: 28), u64Max, u64Beyond),
        WidthCase("protocolParams.minFeeA", u64Max, u64Beyond),
        WidthCase("protocolParams.minFeeB", u64Max, u64Beyond),
        WidthCase("protocolParams.keyDeposit", u64Max, u64Beyond),
        WidthCase("protocolParams.poolDeposit", u64Max, u64Beyond),
        WidthCase("protocolParams.minUTxOValue", u64Max, u64Beyond),
        WidthCase("protocolParams.minPoolCost", u64Max, u64Beyond),
        WidthCase("protocolParams.maxTxSize", u32Max, u32Beyond),
        WidthCase("protocolParams.maxBlockBodySize", u32Max, u32Beyond),
        WidthCase("protocolParams.eMax", u32Max, u32Beyond),
        WidthCase("protocolParams.protocolVersion.major", u32Max, u32Beyond),
        WidthCase("protocolParams.protocolVersion.minor", u32Max, u32Beyond),
        WidthCase("protocolParams.maxBlockHeaderSize", u16Max, u16Beyond),
        WidthCase("protocolParams.nOpt", u16Max, u16Beyond),
    ]

    @Test("The top of the ledger's range decodes and round-trips", arguments: cases)
    func top(_ field: WidthCase) throws {
        let decoded = try decode(ShelleyGenesis.self, setting(genesis(), field.path, to: number(field.top)))
        #expect(try text(of: decoded, at: field.path) == field.top)
        let viaCBOR = try ShelleyGenesis(from: try decoded.toPrimitive())
        #expect(try text(of: viaCBOR, at: field.path) == field.top)
    }

    @Test("A value past the ledger's range throws", arguments: cases)
    func beyond(_ field: WidthCase) throws {
        #expect(throws: (any Error).self) {
            try decode(ShelleyGenesis.self, setting(genesis(), field.path, to: number(field.beyond)))
        }
        #expect(throws: (any Error).self) {
            try decode(ShelleyGenesis.self, setting(genesis(), field.path, to: -1))
        }
    }

    @Test("securityParam is NonZero")
    func securityParamNonZero() throws {
        #expect(throws: CardanoCoreError.self) {
            try decode(ShelleyGenesis.self, setting(genesis(), ["securityParam"], to: 0))
        }
        guard case .list(var fields) = try decode(ShelleyGenesis.self, genesis()).toPrimitive() else {
            Issue.record("expected a CBOR list")
            return
        }
        fields[4] = .uint(0)
        #expect(throws: CardanoCoreError.self) { try ShelleyGenesis(from: .list(fields)) }
    }

    @Test("slotLength holds fractions of a second, to the microsecond, in CBOR as microseconds")
    func slotLength() throws {
        let fast = try decode(ShelleyGenesis.self, setting(genesis(), ["slotLength"], to: 0.2))
        #expect(fast.slotLength == Decimal(string: "0.2"))
        guard case .list(let fields) = try fast.toPrimitive() else {
            Issue.record("expected a CBOR list")
            return
        }
        #expect(fields[8] == .uint(200_000))
        #expect(try ShelleyGenesis(from: fast.toPrimitive()).slotLength == Decimal(string: "0.2"))

        // Microsecond precision, as the ledger's Micro: finer digits are cut.
        let fine = try decode(ShelleyGenesis.self, setting(genesis(), ["slotLength"], to: number("1.0000019")))
        #expect(fine.slotLength == Decimal(string: "1.000001"))

        // Mainnet's one second is a million microseconds.
        let mainnet = try decode(ShelleyGenesis.self, genesis())
        #expect(mainnet.slotLength == 1)
        guard case .list(let mainnetFields) = try mainnet.toPrimitive() else {
            Issue.record("expected a CBOR list")
            return
        }
        #expect(mainnetFields[8] == .uint(1_000_000))
    }

    @Test("GenesisParameters carries the widened values without trapping")
    func genesisParameters() throws {
        let shelley = try decode(ShelleyGenesis.self, setting(
            setting(genesis(), ["maxLovelaceSupply"], to: number(u64Max)), ["epochLength"], to: number(u64Max)))
        let parameters = GenesisParameters(
            alonzoGenesis: try AlonzoGenesis.load(from: try #require(try getFilePath(
                forResource: alonzoGenesisJSONFilePath.forResource, ofType: alonzoGenesisJSONFilePath.ofType,
                inDirectory: alonzoGenesisJSONFilePath.inDirectory))),
            byronGenesis: try ByronGenesis.load(from: try #require(try getFilePath(
                forResource: byronGenesisJSONFilePath.forResource, ofType: byronGenesisJSONFilePath.ofType,
                inDirectory: byronGenesisJSONFilePath.inDirectory))),
            conwayGenesis: try ConwayGenesis.load(from: try #require(try getFilePath(
                forResource: conwayGenesisJSONFilePath.forResource, ofType: conwayGenesisJSONFilePath.ofType,
                inDirectory: conwayGenesisJSONFilePath.inDirectory))),
            shelleyGenesis: shelley)
        #expect(parameters.maxLovelaceSupply == .max)
        #expect(parameters.epochLength == .max)
        #expect(parameters.slotLength == 1)
    }
}

// MARK: - Alonzo genesis

@Suite struct AlonzoGenesisWidthTests {
    func genesis() throws -> [String: Any] { try jsonObject(alonzoGenesisJSONFilePath) }

    @Test("Execution prices hold a Word64 over a Word64, once reduced")
    func prices() throws {
        func prices(_ numerator: String, _ denominator: String) throws -> ExecutionUnitPrices {
            let fraction: [String: Any] = ["numerator": number(numerator), "denominator": number(denominator)]
            return try decode(AlonzoGenesis.self, setting(genesis(), ["executionPrices", "prSteps"], to: fraction))
                .executionPrices
        }
        let top = try prices(u64Max, "1")
        #expect(top.priceSteps == NonNegativeInterval(numerator: .max, denominator: 1))
        #expect(try AlonzoGenesis(from: decode(AlonzoGenesis.self, genesis()).toPrimitive())
            .executionPrices.priceSteps == NonNegativeInterval(numerator: 721, denominator: 10_000_000))
        #expect(try prices("1", u64Max).priceSteps == NonNegativeInterval(numerator: 1, denominator: .max))
        // 2^64 / 2 reduces to 2^63, which fits.
        #expect(try prices(u64Beyond, "2").priceSteps == NonNegativeInterval(numerator: 1 << 63, denominator: 1))
        #expect(throws: (any Error).self) { try prices(u64Beyond, "1") }
        #expect(throws: (any Error).self) { try prices("1", u64Beyond) }
        #expect(throws: (any Error).self) { try prices("1", "0") }
        #expect(throws: (any Error).self) { try prices("-1", "2") }
    }

    static let cases: [WidthCase] = [
        WidthCase("lovelacePerUTxOWord", u64Max, u64Beyond),
        WidthCase("maxValueSize", u32Max, u32Beyond),
        WidthCase("collateralPercentage", u16Max, u16Beyond),
        WidthCase("maxCollateralInputs", u16Max, u16Beyond),
        // The prices are rationals, reduced as the ledger holds them, so
        // their parts are checked on their own below.
        // ExUnits: Word64 in JSON, written as the ledger's `memory`/`steps`;
        // at most Int64.max in CBOR, checked below.
        WidthCase("maxTxExUnits.memory", u64Max, u64Beyond, inCBOR: false),
        WidthCase("maxTxExUnits.steps", u64Max, u64Beyond, inCBOR: false),
        WidthCase("maxBlockExUnits.memory", u64Max, u64Beyond, inCBOR: false),
        WidthCase("maxBlockExUnits.steps", u64Max, u64Beyond, inCBOR: false),
    ]

    @Test("The top of the ledger's range decodes and round-trips", arguments: cases)
    func top(_ field: WidthCase) throws {
        let decoded = try decode(AlonzoGenesis.self, setting(genesis(), field.path, to: number(field.top)))
        #expect(try text(of: decoded, at: field.path) == field.top)
        if field.inCBOR {
            let viaCBOR = try AlonzoGenesis(from: try decoded.toPrimitive())
            #expect(try text(of: viaCBOR, at: field.path) == field.top)
        }
    }

    @Test("A value past the ledger's range throws", arguments: cases)
    func beyond(_ field: WidthCase) throws {
        #expect(throws: (any Error).self) {
            try decode(AlonzoGenesis.self, setting(genesis(), field.path, to: number(field.beyond)))
        }
        #expect(throws: (any Error).self) {
            try decode(AlonzoGenesis.self, setting(genesis(), field.path, to: -1))
        }
    }

    @Test("Execution units round-trip through CBOR up to Int64.max, and no further")
    func executionUnitsInCBOR() throws {
        let top = try decode(AlonzoGenesis.self, setting(genesis(), ["maxBlockExUnits", "exUnitsSteps"], to: number(i64Max)))
        #expect(try AlonzoGenesis(from: top.toPrimitive()).maxBlockExUnits.exUnitsSteps == UInt64(Int64.max))

        let past = try decode(AlonzoGenesis.self, setting(genesis(), ["maxBlockExUnits", "exUnitsSteps"], to: number(i64Beyond)))
        #expect(throws: CardanoCoreError.self) { try past.toPrimitive() }
        #expect(throws: CardanoCoreError.self) {
            try AlonzoGenesisExUnits(from: .list([.uint(0), .uint(UInt64(Int64.max) + 1)]))
        }
    }

    @Test("A price with a zero denominator throws")
    func zeroDenominator() throws {
        #expect(throws: (any Error).self) {
            try decode(AlonzoGenesis.self, setting(genesis(), ["executionPrices", "prMem", "denominator"], to: 0))
        }
    }
}

// MARK: - Conway genesis

@Suite struct ConwayGenesisWidthTests {
    func genesis() throws -> [String: Any] { try jsonObject(conwayGenesisJSONFilePath) }

    static let cases: [WidthCase] = [
        WidthCase("govActionDeposit", u64Max, u64Beyond),
        WidthCase("dRepDeposit", u64Max, u64Beyond),
        WidthCase("committeeMaxTermLength", u32Max, u32Beyond),
        WidthCase("govActionLifetime", u32Max, u32Beyond),
        WidthCase("dRepActivity", u32Max, u32Beyond),
        WidthCase("committeeMinSize", u16Max, u16Beyond),
        // EpochNo: Word64.
        WidthCase("committee.members.keyHash-00000000000000000000000000000000000000000000000000000000",
                  u64Max, u64Beyond),
    ]

    @Test("The top of the ledger's range decodes and round-trips", arguments: cases)
    func top(_ field: WidthCase) throws {
        let decoded = try decode(ConwayGenesis.self, setting(genesis(), field.path, to: number(field.top)))
        #expect(try text(of: decoded, at: field.path) == field.top)
        let viaCBOR = try ConwayGenesis(from: try decoded.toPrimitive())
        #expect(try text(of: viaCBOR, at: field.path) == field.top)
    }

    @Test("A value past the ledger's range throws", arguments: cases)
    func beyond(_ field: WidthCase) throws {
        #expect(throws: (any Error).self) {
            try decode(ConwayGenesis.self, setting(genesis(), field.path, to: number(field.beyond)))
        }
        #expect(throws: (any Error).self) {
            try decode(ConwayGenesis.self, setting(genesis(), field.path, to: -1))
        }
    }

    @Test("The committee quorum is a UnitInterval, written as a fraction or a decimal")
    func threshold() throws {
        let full = try decode(ConwayGenesis.self, setting(
            genesis(), ["committee", "threshold"],
            to: ["numerator": number("18446744073709551614"), "denominator": number(u64Max)]))
        #expect(full.committee.threshold.numerator == UInt64.max - 1)
        #expect(full.committee.threshold.denominator == UInt64.max)
        #expect(try ConwayGenesis(from: full.toPrimitive()).committee.threshold == full.committee.threshold)
        // The ledger holds the reduced ratio: n/n is 1/1.
        let one = try decode(ConwayGenesis.self, setting(
            genesis(), ["committee", "threshold"], to: ["numerator": number(u64Max), "denominator": number(u64Max)]))
        #expect(one.committee.threshold == UnitInterval(numerator: 1, denominator: 1))
        // Word64 parts once reduced, as the ledger's boundRational checks:
        // 2/2^64 is 1/2^63, but 3/2^64 does not fit.
        let halved = try decode(ConwayGenesis.self, setting(
            genesis(), ["committee", "threshold"], to: ["numerator": 2, "denominator": number(u64Beyond)]))
        #expect(halved.committee.threshold == UnitInterval(numerator: 1, denominator: 1 << 63))
        #expect(throws: (any Error).self) {
            try decode(ConwayGenesis.self, setting(
                genesis(), ["committee", "threshold"], to: ["numerator": 3, "denominator": number(u64Beyond)]))
        }

        let decimal = try decode(ConwayGenesis.self, setting(genesis(), ["committee", "threshold"], to: number("0.67")))
        #expect(decimal.committee.threshold.numerator == 67)
        #expect(decimal.committee.threshold.denominator == 100)

        #expect(throws: (any Error).self) {
            try decode(ConwayGenesis.self, setting(
                genesis(), ["committee", "threshold"], to: ["numerator": 3, "denominator": 2]))
        }
        #expect(throws: (any Error).self) {
            try decode(ConwayGenesis.self, setting(
                genesis(), ["committee", "threshold"], to: ["numerator": 0, "denominator": 0]))
        }
    }

    @Test("minFeeRefScriptCostPerByte is a NonNegativeInterval, not a whole number")
    func minFeeRefScriptCostPerByte() throws {
        let fractional = try decode(ConwayGenesis.self, setting(genesis(), ["minFeeRefScriptCostPerByte"], to: 15.5))
        #expect(fractional.minFeeRefScriptCostPerByte == NonNegativeInterval(numerator: 31, denominator: 2))
        #expect(try ConwayGenesis(from: fractional.toPrimitive()).minFeeRefScriptCostPerByte
                == NonNegativeInterval(numerator: 31, denominator: 2))
        #expect(throws: CardanoCoreError.self) {
            try decode(ConwayGenesis.self, setting(genesis(), ["minFeeRefScriptCostPerByte"], to: -1))
        }
    }
}

// MARK: - Real network files

@Suite struct NetworkFileWidthTests {
    @Test("The real genesis and parameter files still load", arguments: ["mainnet", "preprod", "preview"])
    func load(_ network: String) throws {
        let directory = "data/config/\(network)"
        func path(_ name: String) throws -> String {
            try #require(try getFilePath(forResource: name, ofType: "json", inDirectory: directory))
        }
        let shelley = try ShelleyGenesis.load(from: path("shelley-genesis"))
        #expect(shelley.slotLength == 1)
        #expect(shelley.securityParam > 0)
        _ = try ShelleyGenesis(from: shelley.toPrimitive())
        let alonzo = try AlonzoGenesis.load(from: path("alonzo-genesis"))
        _ = try AlonzoGenesis(from: alonzo.toPrimitive())
        let conway = try ConwayGenesis.load(from: path("conway-genesis"))
        #expect(conway.minFeeRefScriptCostPerByte == NonNegativeInterval(numerator: 15, denominator: 1))
        _ = try ConwayGenesis(from: conway.toPrimitive())
        _ = try GenesisParameters(nodeConfigFilePath: path("config"))

        let params = try ProtocolParameters.load(from: try #require(try getFilePath(
            forResource: protocolParametersJSONFilePath.forResource, ofType: protocolParametersJSONFilePath.ofType,
            inDirectory: protocolParametersJSONFilePath.inDirectory)))
        #expect(try ProtocolParameters(from: params.toPrimitive()).txFeeFixed == params.txFeeFixed)
    }
}
