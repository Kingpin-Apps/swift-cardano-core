import BigInt
import CBORCodable
import Foundation
import Testing

@testable import SwiftCardanoCore

/// A decoded ``Primitive`` keeps how it was written: indefinite-length byte
/// strings, text strings and maps encode back as they were read.
///
/// The vectors follow pycardano pull request 508.
@Suite("Primitive keeps its encoding")
struct PrimitiveEncodingTests {
    func decode(_ hex: String) throws -> Primitive {
        try CBORDecoder().decode(Primitive.self, from: hex.hexStringToData)
    }

    @Test("Indefinite strings and maps round trip byte for byte", arguments: [
        "5f4101ff",
        "5fff",
        "5f41014102ff",
        "7f6161ff",
        "7f62c3a96162ff",
        "bf0102ff",
        "bfff",
        "bf01bf0203ffff",
        "a15f4101ff02",
        "a1bf0102ff03",
        "81bf0102ff",
        "d8799f5f4101ffff",
        "d9d9f7820102",
        "d9d9f79f0102ff",
    ])
    func roundTrip(hex: String) throws {
        #expect(try CBOREncoder().encode(decode(hex)).toHex == hex)
    }

    @Test("Negative integers below -2^63 are read with their value")
    func negativeIntegers() throws {
        #expect(try decode("3bffffffffffffffff") == .bigInt(-(BigInt(1) << 64)))
        #expect(try decode("3b8000000000000000") == .bigInt(-(BigInt(1) << 63) - 1))
        #expect(try decode("3b7fffffffffffffff") == .int(Int64.min))
        let cbor = try CBORDecoder().decode(CBOR.self, from: "3bffffffffffffffff".hexStringToData)
        #expect(try cbor.toPrimitive() == .bigInt(-(BigInt(1) << 64)))
        #expect(try CBOREncoder().encode(decode("3bffffffffffffffff")).toHex == "3bffffffffffffffff")
    }

    @Test("A chunked byte string holds its bytes and its chunk widths")
    func chunkedByteString() throws {
        guard case .byteString(let byteString) = try decode("5f41014102ff") else {
            Issue.record("not a byte string")
            return
        }
        #expect(byteString.bytes == Data([0x01, 0x02]))
        #expect(byteString.chunks == [1, 1])
        #expect(byteString == ByteString(bytes: Data([0x01, 0x02])))
    }

    @Test("Normalizing gives the form types read")
    func normalized() throws {
        #expect(try decode("5f41014102ff").normalized() == .bytes(Data([0x01, 0x02])))
        #expect(try decode("7f6161ff").normalized() == .string("a"))
        #expect(try decode("bf0102ff").normalized() == .dict([.uint(1): .uint(2)]))
        #expect(try decode("81bf5f4101ff02ff").normalized()
            == .list([.dict([.bytes(Data([0x01])): .uint(2)])]))
    }

    @Test("Converting without preserving the encoding is unchanged")
    func legacyConversion() throws {
        let cbor = try CBORDecoder().decode(CBOR.self, from: "bf5f4101ff7f6161ffff".hexStringToData)
        #expect(try Primitive.from(cbor: cbor) == .dict([.bytes(Data([0x01])): .string("a")]))
    }

    @Test("A map used as a metadata map key decodes")
    func mapAsMetadataKey() throws {
        let primitive = try decode("a101a1bf0102ff03").normalized()
        let metadata = try Metadata(from: primitive)
        #expect(try Metadata(from: metadata.toPrimitive()) == metadata)
    }

    @Test("A map that repeats a key is rejected, unless the decoder allows it")
    func duplicateKeys() throws {
        // {1: [2], 1: [_ 2]}
        #expect(throws: DecodingError.self) { try decode("a2018102019f02ff") }

        let decoder = CBORDecoder()
        decoder.allowDuplicateMapKeys = true
        let primitive = try decoder.decode(Primitive.self, from: "a2018102019f02ff".hexStringToData)
        #expect(primitive == .orderedDict([.uint(1): .indefiniteList(IndefiniteList([.uint(2)]))]))
    }

    @Test("Bytes after the value are rejected")
    func trailingBytes() {
        #expect(throws: DecodingError.self) { try decode("0102") }
    }

    @Test("A byte string built from chunks writes those chunks, empty ones included")
    func byteStringChunks() throws {
        let byteString = ByteString(chunks: [Data([0x01]), Data(), Data([0x02, 0x03])])
        #expect(byteString.bytes == Data([0x01, 0x02, 0x03]))
        #expect(byteString.chunks == [1, 0, 2])
        #expect(try CBOREncoder().encode(Primitive.byteString(byteString)).toHex == "5f410140420203ff")
    }
}
