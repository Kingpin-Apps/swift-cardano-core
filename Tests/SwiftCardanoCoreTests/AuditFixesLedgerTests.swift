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
