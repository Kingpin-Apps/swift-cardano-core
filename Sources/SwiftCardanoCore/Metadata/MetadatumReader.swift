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
            entries[label] = try read(at: value.lowerBound).0
        }
        return (entries, try scanner.end(ofItemAt: offset))
    }

    /// The metadatum that makes up all of `bytes`.
    static func read(_ bytes: Data) throws -> TransactionMetadatum {
        let reader = MetadatumReader(bytes)
        let (value, end) = try reader.read(at: 0)
        guard end == bytes.count else {
            throw CardanoCoreError.deserializeError("Trailing bytes after a metadatum")
        }
        return value
    }

    /// A list or map whose items are still being read.
    private struct Frame {
        let isMap: Bool
        var items: [TransactionMetadatum] = []
        /// Items left to read, or `nil` until a break.
        var remaining: UInt64?
    }

    /// The metadatum that starts at `offset`, and the offset just past it.
    ///
    /// The ledger sets no depth limit on metadata. Reading is a loop, with
    /// the lists and maps being read kept in an array, so any depth costs no
    /// stack; so are writing, comparing, hashing and freeing what it reads.
    func read(at offset: Int) throws -> (TransactionMetadatum, end: Int) {
        var stack: [Frame] = []
        var position = offset
        while true {
            var value: TransactionMetadatum
            if let top = stack.last, try isComplete(top, at: &position) {
                stack.removeLast()
                value = try finish(top)
            } else {
                let header = try scanner.header(at: position)
                switch (header.major, header.argument) {
                case (0, let argument?):
                    value = .integer(BigInt(argument))
                    position = header.end
                case (1, let argument?):
                    value = .integer(-1 - BigInt(argument))
                    position = header.end
                case (2, _):
                    let (bytes, end) = try chunks(at: position, major: 2)
                    value = .bytes(bytes.reduce(Data(), +))
                    position = end
                case (3, _):
                    let (bytes, end) = try chunks(at: position, major: 3)
                    guard let text = String(data: bytes.reduce(Data(), +), encoding: .utf8) else {
                        throw CardanoCoreError.deserializeError("Invalid UTF-8 in a metadata text string")
                    }
                    value = .text(text)
                    position = end
                case (4, let count):
                    stack.append(Frame(isMap: false, remaining: count))
                    position = header.end
                    continue
                case (5, let count):
                    // Every item takes at least a byte, so a count beyond the
                    // bytes is truncated; checking first keeps the doubling in range.
                    if let count, count > UInt64(scanner.bytes.count) {
                        throw CardanoCoreError.deserializeError("Truncated metadata map at byte \(position)")
                    }
                    stack.append(Frame(isMap: true, remaining: count.map { $0 * 2 }))
                    position = header.end
                    continue
                case (6, let tag?) where tag == 2 || tag == 3:
                    // The ledger reads a CBOR bignum as a metadata integer too.
                    let (bytes, end) = try chunks(at: header.end, major: 2)
                    let magnitude = BigInt(BigUInt(bytes.reduce(Data(), +)))
                    value = .integer(tag == 2 ? magnitude : -1 - magnitude)
                    position = end
                default:
                    throw CardanoCoreError.deserializeError(
                        "Not a metadatum: CBOR major type \(header.major) at byte \(position)")
                }
            }
            guard !stack.isEmpty else { return (value, position) }
            stack[stack.count - 1].items.append(value)
            if let remaining = stack[stack.count - 1].remaining {
                stack[stack.count - 1].remaining = remaining - 1
            }
        }
    }

    /// Whether every item of `frame` has been read; past the break, if it
    /// ends with one.
    private func isComplete(_ frame: Frame, at position: inout Int) throws -> Bool {
        if let remaining = frame.remaining { return remaining == 0 }
        guard let byte = scanner.bytes[safe: position] else {
            throw CardanoCoreError.deserializeError("Truncated metadata at byte \(position)")
        }
        guard byte == 0xFF else { return false }
        position += 1
        return true
    }

    private func finish(_ frame: Frame) throws -> TransactionMetadatum {
        guard frame.isMap else { return .list(frame.items) }
        guard frame.items.count % 2 == 0 else {
            throw CardanoCoreError.deserializeError("A metadata map key without a value")
        }
        var pairs = MapPairs<TransactionMetadatum, TransactionMetadatum>()
        for index in stride(from: 0, to: frame.items.count, by: 2) {
            pairs.append(key: frame.items[index], value: frame.items[index + 1])
        }
        return .map(pairs)
    }

    /// The content of a byte or text string, as its chunks, and the offset
    /// just past it.
    private func chunks(at offset: Int, major: UInt8) throws -> ([Data], end: Int) {
        let header = try scanner.header(at: offset)
        guard header.major == major else {
            throw CardanoCoreError.deserializeError("Expected major type \(major) at byte \(offset)")
        }
        if header.argument != nil {
            let end = try scanner.end(ofItemAt: offset)
            return ([scanner.bytes.subdata(in: header.end..<end)], end)
        }
        var chunks: [Data] = []
        var position = header.end
        while scanner.bytes[safe: position] != 0xFF {
            guard position < scanner.bytes.count else {
                throw CardanoCoreError.deserializeError("Truncated string at byte \(offset)")
            }
            let chunk = try scanner.header(at: position)
            guard chunk.major == major, chunk.argument != nil else {
                throw CardanoCoreError.deserializeError(
                    "A chunk of a string must be a definite string of its type, at byte \(position)")
            }
            let end = try scanner.end(ofItemAt: position)
            chunks.append(scanner.bytes.subdata(in: chunk.end..<end))
            position = end
        }
        return (chunks, position + 1)
    }
}
