@preconcurrency import BigInt
import Foundation
import OrderedCollections

/// Reads transaction metadata straight from its bytes.
///
/// The ledger reads a metadatum map as a list of pairs, so a key may repeat;
/// the generic CBOR layer would keep one pair per key. This reads the bytes
/// itself and keeps every pair, in order. It rejects what the ledger does not
/// read as a metadatum: floats, simple values and tags other than bignums.
struct MetadatumReader {
    let scanner: CBORItemScanner

    init(_ bytes: Data) {
        scanner = CBORItemScanner(bytes)
    }

    /// The metadata — `{* label => metadatum}` — that starts at `offset`, and
    /// the offset just past it. A repeated label keeps its later value, as
    /// the ledger reads it before Conway; ``LedgerDuplicateRules`` rejects it
    /// where the ledger does.
    func metadata(at offset: Int) throws -> (OrderedDictionary<TransactionMetadatumLabel, TransactionMetadatum>, end: Int) {
        var entries = OrderedDictionary<TransactionMetadatumLabel, TransactionMetadatum>()
        for (key, value) in try scanner.entries(ofMapAt: offset) {
            guard let label = try scanner.unsignedInteger(at: key.lowerBound),
                try scanner.end(ofItemAt: key.lowerBound) == key.upperBound
            else {
                throw CardanoCoreError.deserializeError("A metadata label must be an unsigned integer")
            }
            entries[label] = try read(at: value.lowerBound, depth: 0).0
        }
        return (entries, try scanner.end(ofItemAt: offset))
    }

    /// The metadatum that starts at `offset`, and the offset just past it.
    /// The deepest nesting read. Reading recurses once per level, so this
    /// keeps it within a small thread stack; metadata sits inside the
    /// transaction's own CBOR, which the generic decoder reads no deeper.
    static let maxDepth = 128

    func read(at offset: Int, depth: Int) throws -> (TransactionMetadatum, end: Int) {
        guard depth < Self.maxDepth else {
            throw CardanoCoreError.deserializeError(
                "Metadata nested deeper than \(Self.maxDepth)")
        }
        let header = try scanner.header(at: offset)
        let end = try scanner.end(ofItemAt: offset)
        switch (header.major, header.argument) {
        case (0, let value?):
            return (.integer(BigInt(value)), end)
        case (1, let value?):
            return (.integer(-1 - BigInt(value)), end)
        case (2, _):
            return (.bytes(try chunks(at: offset, major: 2).reduce(Data(), +)), end)
        case (3, _):
            let bytes = try chunks(at: offset, major: 3).reduce(Data(), +)
            guard let text = String(data: bytes, encoding: .utf8) else {
                throw CardanoCoreError.deserializeError("Invalid UTF-8 in a metadata text string")
            }
            return (.text(text), end)
        case (4, _):
            var elements: [TransactionMetadatum] = []
            for span in try scanner.elements(ofArrayAt: offset) {
                elements.append(try read(at: span.lowerBound, depth: depth + 1).0)
            }
            return (.list(elements), end)
        case (5, _):
            var pairs = MapPairs<TransactionMetadatum, TransactionMetadatum>()
            for (key, value) in try scanner.entries(ofMapAt: offset) {
                pairs.append(
                    key: try read(at: key.lowerBound, depth: depth + 1).0,
                    value: try read(at: value.lowerBound, depth: depth + 1).0)
            }
            return (.map(pairs), end)
        case (6, let tag?) where tag == 2 || tag == 3:
            // The ledger reads a CBOR bignum as a metadata integer too.
            let magnitude = BigInt(BigUInt(try chunks(at: header.end, major: 2).reduce(Data(), +)))
            return (.integer(tag == 2 ? magnitude : -1 - magnitude), end)
        default:
            throw CardanoCoreError.deserializeError(
                "Not a metadatum: CBOR major type \(header.major) at byte \(offset)")
        }
    }

    /// The content of a byte or text string, as its chunks.
    private func chunks(at offset: Int, major: UInt8) throws -> [Data] {
        let header = try scanner.header(at: offset)
        guard header.major == major else {
            throw CardanoCoreError.deserializeError("Expected major type \(major) at byte \(offset)")
        }
        if header.argument != nil {
            return [scanner.bytes.subdata(in: header.end..<(try scanner.end(ofItemAt: offset)))]
        }
        var chunks: [Data] = []
        var position = header.end
        while scanner.bytes[safe: position] != 0xFF {
            let chunk = try scanner.header(at: position)
            guard chunk.major == major, chunk.argument != nil else {
                throw CardanoCoreError.deserializeError(
                    "A chunk of a string must be a definite string of its type, at byte \(position)")
            }
            let end = try scanner.end(ofItemAt: position)
            chunks.append(scanner.bytes.subdata(in: chunk.end..<end))
            position = end
        }
        return chunks
    }
}
