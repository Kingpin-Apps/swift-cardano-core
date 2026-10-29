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

    /// Wrap `payload` in a CBOR byte-string head.
    private static func byteString(_ payload: Data) -> Data {
        let n = payload.count
        let head: [UInt8] =
            n < 24 ? [0x40 | UInt8(n)]
            : n < 256 ? [0x58, UInt8(n)]
            : [0x59, UInt8(n >> 8), UInt8(n & 0xff)]
        return Data(head) + payload
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

    @Test("Deep constructors with an invalid leaf throw in linear time")
    func rejectsInvalidLeafUnderDeepConstrs() async {
        // A failed Constr used to be retried as an untagged value, which
        // re-decoded the subtree at every level: O(2^depth).
        let data = Self.nestedConstrs(60, leaf: 0xf5)  // `true` is not PlutusData
        await #expect(throws: (any Error).self) {
            try await Task.detached { try PlutusData.fromCBOR(data: data) }.value
        }
    }

    @Test("Map keys that hold the same value are both kept")
    func keepsCollidingMapKeys() throws {
        // {h'00': 0, (_ h'00'): 1}: two keys holding the same bytes. The
        // ledger reads a Plutus map as a list of pairs, so both stay.
        let data = Data([0xa2, 0x41, 0x00, 0x00, 0x5f, 0x41, 0x00, 0xff, 0x01])
        let decoded = try PlutusData.fromCBOR(data: data)
        guard case .map(let map) = decoded else {
            Issue.record("expected a map, got \(decoded)")
            return
        }
        #expect(map.count == 2)
        #expect(try decoded.toCBORData() == data)
    }

    @Test("CBOR nested in byte strings cannot bypass the depth cap")
    func boundsBytesNestedInBytes() async throws {
        // bytes(Constr 0 [bytes(Constr 0 [...])]). Each embedded decode used
        // to start a fresh reader, so the depth cap never applied.
        var data = Data([0x00])
        for _ in 0..<1000 {
            data = Self.byteString(Data([0xd8, 0x79, 0x81]) + data)
        }
        let input = data
        let decoded = try await Task.detached { try PlutusData.fromCBOR(data: input) }.value
        guard case .bytes(let bytes) = decoded else {
            Issue.record("expected bytes, got \(decoded)")
            return
        }
        #expect(bytes.count == input.count - 3)
    }

    @Test("Max-depth embedded CBOR under max-depth nesting round-trips on a cooperative thread")
    func roundTripsDeepEmbeddedConstr() async throws {
        // 126 arrays, then bytes holding the deepest Constr chain the
        // embedded decode accepts. Unwrapping it makes the re-encoded tree
        // deeper than the input, so this is the worst case for encoding.
        let constrs = (16 - 1) / 2
        let data = Self.nestedArrays(126).dropLast() + Self.byteString(Self.nestedConstrs(constrs))
        let depth = try await Task.detached {
            let decoded = try PlutusData.fromCBOR(data: data)
            _ = try decoded.hash()
            _ = try decoded.toCBORData()
            return Self.arrayDepth(decoded)
        }.value
        #expect(depth == 126)
    }

    @Test("Bytes whose content is CBOR stay bytes")
    func keepsBytesThatLookLikeCBOR() throws {
        // h'd87980' is a byte string, not the constructor its content encodes.
        let data = Self.byteString(Self.nestedConstrs(1))
        let decoded = try PlutusData.fromCBOR(data: data)
        guard case .bytes = decoded else {
            Issue.record("expected bytes, got \(decoded)")
            return
        }
        #expect(try decoded.toCBORData() == data)
    }
}
