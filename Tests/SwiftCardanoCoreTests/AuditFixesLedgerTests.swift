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
