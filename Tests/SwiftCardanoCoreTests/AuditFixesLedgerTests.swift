import Testing
import Foundation
import BigInt

import CBORCodable
@testable import SwiftCardanoCore

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Cost models

@Suite struct AuditCostModelNarrowingTests {
    /// A transaction body whose proposal carries a parameter change with a
    /// cost-model value of 2^64 - 1 (`1bffffffffffffffff`).
    static let bodyHex = "a40080018002001481841903e8581de0111111111111111111111111111111111111111111111111111111118400f6a112a101811bfffffffffffffffff6826968747470733a2f2f7858202222222222222222222222222222222222222222222222222222222222222222"

    @Test("A cost-model value above Int64.max in a transaction body throws instead of trapping")
    func bodyWithHugeCostModelValue() throws {
        let bytes = try #require(Data(hexString: Self.bodyHex))
        #expect(bytes.count == 107)
        #expect(throws: CardanoCoreError.self) { try TransactionBody.fromCBOR(data: bytes) }
    }

    @Test("The same body with a small cost-model value decodes")
    func bodyWithSmallCostModelValue() throws {
        let hex = Self.bodyHex.replacingOccurrences(
            of: "a112a101811bffffffffffffffff", with: "a112a1018105")
        let body = try TransactionBody.fromCBOR(data: try #require(Data(hexString: hex)))
        #expect(body.proposalProcedures != nil)
    }

    @Test("A language key above the ledger's range throws instead of trapping")
    func hugeLanguageKey() {
        #expect(throws: CardanoCoreError.self) {
            try CostModels(from: .orderedDict([.uint(UInt64.max): .list([])]))
        }
        #expect(throws: CardanoCoreError.self) {
            try CostModels(from: .orderedDict([.int(-1): .list([])]))
        }
    }

    @Test("A value of exactly Int64.max is still read")
    func int64MaxValue() throws {
        let models = try CostModels(from: .orderedDict([.uint(1): .list([.uint(UInt64(Int64.max))])]))
        #expect(models.plutusV2?.values.first == Int64.max)
    }
}

// MARK: - Nested cost-model byte strings

@Suite struct AuditCostModelWrapperTests {
    /// `item` wrapped `depth` times in a CBOR byte string.
    static func wrapped(_ item: Data, depth: Int) -> Data {
        var data = item
        for _ in 0..<depth {
            var header = Data()
            let count = data.count
            switch count {
            case 0..<24: header.append(0x40 | UInt8(count))
            case 24..<256: header.append(contentsOf: [0x58, UInt8(count)])
            case 256..<65_536: header.append(contentsOf: [0x59, UInt8(count >> 8), UInt8(count & 0xFF)])
            default:
                header.append(0x5A)
                header.append(contentsOf: withUnsafeBytes(of: UInt32(count).bigEndian, Array.init))
            }
            data = header + data
        }
        return data
    }

    /// The ledger's protocol parameters with cost models `{0: B^depth([1])}`.
    static func parameters(depth: Int) throws -> Data {
        let hex = ProtocolParametersLedgerCBORTests.ledgerHex
        let start = try #require(hex.range(of: "a2009f"))
        let end = try #require(hex.range(of: "82d81e82190241192710"))
        let costModels = Data([0xA1, 0x00]) + wrapped(Data([0x81, 0x01]), depth: depth)
        return try #require(Data(hexString: String(hex[..<start.lowerBound])
            + costModels.toHex + String(hex[end.lowerBound...])))
    }

    @Test("One byte-string wrapper around a cost model is read")
    func oneWrapper() throws {
        let params = try ProtocolParameters.fromCBOR(data: try Self.parameters(depth: 1))
        #expect(params.costModels.PlutusV1 == [1])
    }

    @Test("A byte-string wrapper inside another is refused")
    func twoWrappers() throws {
        let bytes = try Self.parameters(depth: 2)
        #expect(throws: CardanoCoreError.self) { try ProtocolParameters.fromCBOR(data: bytes) }
    }

    @Test("A thousand nested wrappers throw on a 512 KB stack instead of overflowing it")
    func deepWrappersOnSmallStack() throws {
        let bytes = try Self.parameters(depth: 1000)
        nonisolated(unsafe) var outcome: Result<ProtocolParameters, Error>?
        let done = DispatchSemaphore(value: 0)
        let thread = Thread {
            outcome = Result { try ProtocolParameters.fromCBOR(data: bytes) }
            done.signal()
        }
        thread.stackSize = 512 * 1024
        thread.start()
        done.wait()
        guard case .failure(let error)? = outcome else {
            Issue.record("Expected an error, got \(String(describing: outcome))")
            return
        }
        #expect(error is CardanoCoreError)
    }
}

// MARK: - Duplicate keys

@Suite struct AuditDuplicateRulesCostTests {
    /// `[{0: [], 1: [], 2: item}, {}, true, null]`: a transaction whose fee
    /// field is `item`.
    static func transaction(fee item: Data) -> Data {
        Data([0x84, 0xA3, 0x00, 0x80, 0x01, 0x80, 0x02]) + item + Data([0xA0, 0xF5, 0xF6])
    }

    static func rules(_ item: Data, era: Era = .conway) -> LedgerDuplicateRules {
        LedgerDuplicateRules(transaction(fee: item), era: era)
    }

    @Test("A 16 KB chain of maps nested in map keys is rejected well within a second")
    func nestedMapKeyChain() throws {
        let n = 8000
        let item = Data(repeating: 0xA1, count: n) + Data(repeating: 0x00, count: n + 1)
        let bytes = Self.transaction(fee: item)
        #expect(bytes.count == 16_011)
        let clock = ContinuousClock()
        let elapsed = clock.measure {
            #expect(throws: (any Error).self) { try Transaction.fromCBOR(data: bytes) }
        }
        #expect(elapsed < .seconds(1), "took \(elapsed)")
        // The duplicate check alone is linear too.
        let checkElapsed = try clock.measure {
            try Self.rules(item).checkTransaction()
        }
        #expect(checkElapsed < .milliseconds(500), "took \(checkElapsed)")
    }

    @Test("A chain whose every map has two keys is checked in linear time")
    func nestedChainWithSiblings() throws {
        // {chain: 0, 1: 0} at each level.
        let n = 3000
        var item = Data([0x00])
        for _ in 0..<n { item = Data([0xA2]) + item + Data([0x00, 0x01, 0x00]) }
        let clock = ContinuousClock()
        let elapsed = try clock.measure { try Self.rules(item).checkTransaction() }
        #expect(elapsed < .milliseconds(500), "took \(elapsed)")
    }

    @Test(
        "Keys equal by value but written differently are still repeats from Conway",
        arguments: [
            // 1 and 1 in a two-byte header.
            ("01", "1801"),
            // "a" definite and in indefinite chunks.
            ("6161", "7f6161ff"),
            // h'01' definite and indefinite.
            ("4101", "5f4101ff"),
            // 1.0 as a single and as a double.
            ("fa3f800000", "fb3ff0000000000000"),
            // 1.5 as a single and as a double.
            ("fa3fc00000", "fb3ff8000000000000"),
            // null and undefined.
            ("f6", "f7"),
            // A map definite and indefinite.
            ("a10102", "bf0102ff"),
            // A map key nested in a map key, written two ways.
            ("a1a1010200", "a1a118010200"),
            // A unit interval over a definite and an indefinite array.
            ("d81e820102", "d81e9f0102ff"),
            // A tag over equal values written two ways.
            ("d9010281a10102", "d9010281bf0102ff"),
        ]
    )
    func equalByValue(first: String, second: String) throws {
        let item = try #require(Data(hexString: "a2" + first + "00" + second + "00"))
        #expect(throws: CardanoCoreError.self) { try Self.rules(item).checkTransaction() }
        try Self.rules(item, era: .babbage).checkTransaction()
        // In a set too.
        let set = try #require(Data(hexString: "d9010282" + first + second))
        #expect(throws: CardanoCoreError.self) { try Self.rules(set).checkTransaction() }
    }

    @Test(
        "Keys that differ by value are not repeats",
        arguments: [
            ("01", "02"),
            ("6161", "6162"),
            ("4101", "6101"),
            ("f93c00", "f94000"),
            ("a10102", "a10103"),
            ("820102", "9f0102ff"),
            ("d81e820102", "d81e820103"),
        ]
    )
    func differentByValue(first: String, second: String) throws {
        let item = try #require(Data(hexString: "a2" + first + "00" + second + "00"))
        try Self.rules(item).checkTransaction()
    }
}

// MARK: - Slot timeline

@Suite struct AuditSlotTimelineArithmeticTests {
    @Test("A slot whose time does not fit an Int64 converts to nil instead of trapping")
    func hugeSlots() {
        #expect(SlotTimeline.mainnet.milliseconds(forSlot: UInt64.max) == nil)
        #expect(SlotTimeline.mainnet.milliseconds(forSlot: UInt64(Int64.max)) == nil)
        #expect(SlotTimeline.mainnet.milliseconds(forSlot: 1 << 54) == nil)
        #expect(SlotTimeline.mainnet.milliseconds(forSlot: 1 << 40) != nil)
    }

    @Test("Extreme times convert without trapping")
    func extremeTimes() {
        #expect(SlotTimeline.mainnet.slot(atMilliseconds: Int64.min) == 0)
        #expect(SlotTimeline.mainnet.slot(atMilliseconds: Int64.max) != nil)
        #expect(SlotTimeline.mainnet.slot(atMilliseconds: 1_596_059_091_000) == 4_492_800)
    }

    @Test("A slot length that is not positive is refused by every initializer")
    func nonPositiveSlotLength() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        #expect(throws: CardanoCoreError.self) {
            try SlotTimeline(systemStart: start, slotLengthMilliseconds: 0)
        }
        #expect(throws: CardanoCoreError.self) {
            try SlotTimeline(systemStart: start, slotLengthMilliseconds: -1_000)
        }
        for slotLength: Decimal in [0, -1] {
            let genesis = GenesisParameters(
                activeSlotsCoefficient: UnitInterval(numerator: 1, denominator: 20),
                epochLength: 432_000, maxKesEvolutions: 62, maxLovelaceSupply: 45_000_000_000_000_000,
                networkId: "Testnet", networkMagic: 42, securityParam: 2160,
                slotLength: slotLength, slotsPerKesPeriod: 129_600, systemStart: start,
                updateQuorum: 5)
            #expect(SlotTimeline.forChain(genesis: genesis) == nil)
        }
    }

    @Test("A system start out of range throws instead of trapping")
    func hugeSystemStart() {
        #expect(throws: CardanoCoreError.self) {
            try SlotTimeline(systemStart: Date(timeIntervalSince1970: 1e300), slotLengthMilliseconds: 1_000)
        }
    }

    @Test("An era history whose start overflows Int64 throws instead of trapping")
    func eraHistoryOverflow() throws {
        let relativeMilliseconds = BigInt(Int64.max) - 1_000
        let bound = Primitive.list([
            .bigInt(relativeMilliseconds * 1_000_000_000), .uint(0), .uint(0),
        ])
        let history = Primitive.list([
            .list([bound, bound, .list([.uint(432_000), .uint(1_000)])])
        ])
        let bytes = try CBORSerialization.data(from: try history.toCBOR())
        #expect(throws: CardanoCoreError.self) {
            try SlotTimeline(
                systemStart: Date(timeIntervalSince1970: 1_506_203_091), eraHistory: bytes)
        }
    }
}

// MARK: - Network decoding

@Suite struct AuditNetworkDecodingTests {
    static func decode(_ json: String) throws -> Network {
        try JSONDecoder().decode(Network.self, from: Data(json.utf8))
    }

    @Test(
        "An unknown network name throws instead of reading as mainnet",
        arguments: ["\"testnet\"", "\"custom(42)\"", "\"Preview \"", "\"\"", "\"mainnet2\""]
    )
    func unknownName(json: String) {
        #expect(throws: DecodingError.self) { try Self.decode(json) }
    }

    @Test(
        "Known magics read as their named networks",
        arguments: [
            ("764824073", Network.mainnet), ("1", .preprod), ("2", .preview),
            ("4", .sanchonet), ("141", .guildnet), ("42", .custom(42)),
            ("\"764824073\"", .mainnet), ("\"1\"", .preprod), ("\"42\"", .custom(42)),
            ("\"PREPROD\"", .preprod), ("\"mainnet\"", .mainnet),
        ]
    )
    func knownMagic(json: String, network: Network) throws {
        let decoded = try Self.decode(json)
        #expect(decoded == network)
        #expect(decoded.networkId == network.networkId)
    }

    @Test("The mainnet magic has the mainnet network id")
    func mainnetMagicId() throws {
        #expect(try Self.decode("764824073").networkId == .mainnet)
    }
}

// MARK: - Address prefixes

@Suite struct AuditAddressPrefixTests {
    static let base = Data([0x01]) + Data(repeating: 0xAA, count: 28) + Data(repeating: 0xBB, count: 28)
    static let testnetReward = Data([0xE0]) + Data(repeating: 0xCC, count: 28)

    @Test(
        "A Bech32 prefix that does not match the header is refused",
        arguments: [
            ("addr_test", base), ("stake", base), ("drep", base),
            ("addr", testnetReward), ("stake", testnetReward),
        ]
    )
    func mismatchedPrefix(hrp: String, bytes: Data) throws {
        let text = try #require(Bech32().encode(hrp: hrp, witprog: bytes))
        #expect(throws: CardanoCoreError.self) { try Address.fromBech32(text) }
        #expect(throws: CardanoCoreError.self) { try Address(from: .string(text)) }
    }

    @Test(
        "A Bech32 prefix that matches the header is read",
        arguments: [("addr", base), ("stake_test", testnetReward)]
    )
    func matchingPrefix(hrp: String, bytes: Data) throws {
        let text = try #require(Bech32().encode(hrp: hrp, witprog: bytes))
        let address = try Address.fromBech32(text)
        #expect(try address.toBech32() == text)
    }

    @Test("A Byron address's bytes in Bech32 are refused")
    func byronInBech32() throws {
        let byron = try Address(
            from: .string("Ae2tdPwUPEZFRbyhz3cpfC2CumGzNkFBN2L42rcUc2yjQpEkxDbkPodpMAi"))
        let text = try #require(Bech32().encode(hrp: "addr", witprog: byron.toBytes()))
        #expect(throws: CardanoCoreError.self) { try Address.fromBech32(text) }
    }
}
