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
