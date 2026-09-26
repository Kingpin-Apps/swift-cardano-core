import Foundation
import Testing
@testable import SwiftCardanoCore

/// Deeply nested PlutusData must decode (or throw) without overflowing the
/// ~512 KB stack of a Swift-concurrency cooperative thread. The deep cases
/// run in `Task.detached` so they land on such a thread.
@Suite struct PlutusDataDepthTests {
    /// `[[[...0...]]]`, `depth` definite-length arrays deep.
    private static func nestedArrays(_ depth: Int) -> Data {
        Data(repeating: 0x81, count: depth) + Data([0x00])
    }

    /// `Constr 0 [Constr 0 [... leaf]]`; each Constr is two CBOR levels
    /// (tag 121 + array).
    private static func nestedConstrs(_ depth: Int, leaf: UInt8 = 0x00) -> Data {
        Data(Array(repeating: [UInt8(0xd8), 0x79, 0x81], count: depth).joined()) + Data([leaf])
    }

    private static func arrayDepth(_ data: PlutusData) -> Int {
        var depth = 0
        var current = data
        while case .array(let items) = current, let first = items.first {
            depth += 1
            current = first
        }
        return depth
    }

    @Test("127-level nested array decodes on a cooperative thread")
    func decodesDeepNestingInDetachedTask() async throws {
        let data = Self.nestedArrays(127)
        let depth = try await Task.detached {
            Self.arrayDepth(try PlutusData.fromCBOR(data: data))
        }.value
        #expect(depth == 127)
    }

    @Test("127-level nested array re-encodes and hashes on a cooperative thread")
    func roundTripsDeepNestingInDetachedTask() async throws {
        let data = Self.nestedArrays(127)
        let encoded = try await Task.detached {
            let decoded = try PlutusData.fromCBOR(data: data)
            _ = try decoded.hash()
            return try decoded.toCBORData()
        }.value
        #expect(encoded == data)
    }

    @Test("Nesting past the depth cap throws instead of crashing")
    func rejectsNestingPastCap() async {
        let data = Self.nestedArrays(200)
        await #expect(throws: (any Error).self) {
            try await Task.detached { try PlutusData.fromCBOR(data: data) }.value
        }
    }

    @Test("63 nested constructors decode on a cooperative thread")
    func decodesDeepConstrs() async throws {
        let data = Self.nestedConstrs(63)
        let decoded = try await Task.detached { try PlutusData.fromCBOR(data: data) }.value
        guard case .constructor = decoded else {
            Issue.record("expected a constructor, got \(decoded)")
            return
        }
    }

    @Test("127 nested maps decode in linear time")
    func decodesDeepMaps() async throws {
        // {0: {0: ... 0}}. Converting each map twice made this O(2^depth).
        let data = Data(Array(repeating: [UInt8(0xa1), 0x00], count: 127).joined()) + Data([0x00])
        let decoded = try await Task.detached { try PlutusData.fromCBOR(data: data) }.value
        guard case .map = decoded else {
            Issue.record("expected a map, got \(decoded)")
            return
        }
    }

    @Test("Map keys that collapse to the same Primitive do not trap")
    func toleratesCollidingMapKeys() throws {
        // {h'00': 0, (_ h'00'): 1}: distinct CBOR keys, both Primitive.bytes.
        let data = Data([0xa2, 0x41, 0x00, 0x00, 0x5f, 0x41, 0x00, 0xff, 0x01])
        let decoded = try PlutusData.fromCBOR(data: data)
        guard case .map(let map) = decoded else {
            Issue.record("expected a map, got \(decoded)")
            return
        }
        #expect(map.count == 1)
    }

}
