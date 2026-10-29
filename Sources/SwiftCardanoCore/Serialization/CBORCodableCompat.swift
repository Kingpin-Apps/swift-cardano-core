import Foundation
import CBORCodable

// MARK: - PotentCBOR compatibility shim
//
// Provides the small piece of PotentCBOR's API surface that swift-cardano-core
// relied on but that CBORCodable doesn't expose in the same shape. Pure
// adapters — no behavioral change.

/// Drop-in replacement for `PotentCBOR.CBORSerialization`. PotentCBOR
/// exposed read/write of a top-level CBOR item as `cbor(from:)` and
/// `data(from:)`; CBORCodable does the same via its writer/reader types
/// directly. Keeping the old surface lets the migration touch every
/// other call site without breaking encapsulation here.
extension CBORDecoder {
    /// How deep ledger data is decoded into a CBOR tree. Every ledger
    /// structure fits within it, except Plutus data, metadata and native
    /// scripts, which the ledger lets nest without a limit; their parts
    /// below this depth are handed over as their bytes, which their own
    /// readers take apart in a loop.
    static let ledgerRawDepth = 32

    /// A decoder for ledger data: it hands over items nested deeper than
    /// ``ledgerRawDepth`` as their bytes.
    static func ledger() -> CBORDecoder {
        let decoder = CBORDecoder()
        decoder.rawDepth = ledgerRawDepth
        return decoder
    }
}

public enum CBORSerialization {

    /// Decode the bytes as a single CBOR data item. Lenient (matches
    /// PotentCBOR): trailing bytes after the first complete item are
    /// ignored. Use `CBORReader` directly if you want strict single-item
    /// enforcement.
    public static func cbor(from data: Data) throws -> CBOR {
        var reader = CBORReader(data, rawDepth: CBORDecoder.ledgerRawDepth)
        return try reader.decode()
    }

    /// Encode a CBOR value to bytes.
    public static func data(from cbor: CBOR) throws -> Data {
        var writer = CBORWriter()
        try writer.encode(cbor)
        return writer.data
    }
}

// MARK: - PotentCBOR tag-number constants
//
// PotentCBOR exposed common IANA tag numbers as `CBOR.Tag.iso8601DateTime`
// etc. SwiftCardanoCore has its own `CBORTag` (a tag + Primitive wrapper),
// so we can't disambiguate by typing — these UInt64 statics re-expose the
// well-known numbers so call sites stay shaped like
// `if tag == iso8601DateTime { ... }`.

extension UInt64 {
    /// CBOR tag 0 — date/time as an RFC 3339 string.
    public static let iso8601DateTime: UInt64 = 0
    /// CBOR tag 1 — epoch-based date/time (seconds since 1970).
    public static let epochDateTime: UInt64 = 1
}

// Note: `Data.toCBOR` already exists in `Utils/Extensions.swift`. No
// duplicate declaration needed here.
