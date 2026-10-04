import Foundation
import Testing

@testable import SwiftCardanoCore

/// Plutus data caps a byte string at 64 bytes. Longer ones are written as an
/// indefinite-length string of 64-byte chunks; Aiken's `cbor.serialise` gives
/// the expected bytes here.
@Suite("Long Plutus byte strings")
struct PlutusDataLongBytesTests {
    let bytes = Data(0...0x43)
    let aiken = "5f5840000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f4440414243ff"

    @Test("Bytes over 64 are written in 64-byte chunks, as Aiken writes them")
    func chunked() throws {
        let data = PlutusData.bytes(try Bytes(from: bytes))
        #expect(try data.toCBORData().toHex == aiken)
    }

    @Test("Chunked bytes read back whole, and write the same again")
    func roundTrip() throws {
        let data = try PlutusData.fromCBOR(data: aiken.hexStringToData)
        guard case .bytes(let read) = data else {
            Issue.record("\(data)")
            return
        }
        #expect(read.data == bytes)
        #expect(try data.toCBORData().toHex == aiken)
    }

    @Test("64 bytes or fewer stay one definite string")
    func short() throws {
        let data = PlutusData.bytes(try Bytes(from: Data(repeating: 0xAB, count: 64)))
        #expect(try data.toCBORData().toHex == "5840" + String(repeating: "ab", count: 64))
    }
}
