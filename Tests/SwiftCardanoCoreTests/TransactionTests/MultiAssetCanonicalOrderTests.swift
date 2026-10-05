import Foundation
import OrderedCollections
import Testing

@testable import SwiftCardanoCore

/// Multi-assets are written in canonical order (RFC 7049 §3.9), as CIP-21
/// asks of transactions hardware wallets sign: policies by their bytes, asset
/// names shortest first and then by their bytes, whatever order they were
/// added in.
@Suite("Multi-asset canonical order")
struct MultiAssetCanonicalOrderTests {
    @Test("Policies and asset names are written in canonical order")
    func order() throws {
        let names: [String] = ["bb", "a", "aa", "0102"]
        var assets: OrderedDictionary<AssetName, Int64> = [:]
        for name in names { assets[try AssetName(payload: Data(name.utf8))] = 1 }
        let asset = Asset(assets)
        var policies: [ScriptHash: Asset] = [:]
        for byte: UInt8 in [0x30, 0x10, 0x20] { policies[ScriptHash(payload: Data(repeating: byte, count: 28))] = asset }
        let encoded = try MultiAsset(policies).toCBORData()

        guard case .orderedDict(let written) = try Primitive.fromCBOR(data: encoded) else {
            Issue.record("Not a map")
            return
        }
        let policyOrder = written.keys.compactMap { key -> UInt8? in if case .bytes(let data) = key { data.first } else { nil } }
        #expect(policyOrder == [0x10, 0x20, 0x30])
        guard case .orderedDict(let inner)? = written.values.first else {
            Issue.record("No assets")
            return
        }
        let nameOrder = inner.keys.compactMap { key -> String? in if case .bytes(let data) = key { String(decoding: data, as: UTF8.self) } else { nil } }
        #expect(nameOrder == ["a", "aa", "bb", "0102"])
    }
}
