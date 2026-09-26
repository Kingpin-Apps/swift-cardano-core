import Foundation

/// Finds where CBOR data items start and end in encoded bytes, without
/// decoding them.
///
/// Decoding into ``Primitive`` loses how an item was written — the width of an
/// integer's header, definite or indefinite lengths, the order of map keys —
/// so bytes rebuilt from it can differ from the bytes that were read. Where the
/// exact bytes matter, such as a transaction body whose hash is the transaction
/// id, this gives the slice that was actually written.
struct CBORItemScanner {
    let bytes: Data

    init(_ bytes: Data) {
        // Work in zero-based offsets whatever slice was passed in.
        self.bytes = Data(bytes)
    }

    /// The header of an item: its major type, and its argument — the value, the
    /// length or the count — or `nil` when the length is indefinite.
    struct Header {
        var major: UInt8
        var argument: UInt64?
        /// The offset just past the header.
        var end: Int
    }

    func header(at offset: Int) throws -> Header {
        let initial = try byte(at: offset)
        let major = initial >> 5
        let info = initial & 0x1F
        switch info {
        case 0..<24:
            return Header(major: major, argument: UInt64(info), end: offset + 1)
        case 24...27:
            let width = 1 << Int(info - 24)
            var value: UInt64 = 0
            for index in 0..<width {
                value = value << 8 | UInt64(try byte(at: offset + 1 + index))
            }
            return Header(major: major, argument: value, end: offset + 1 + width)
        case 31 where [2, 3, 4, 5, 7].contains(major):
            return Header(major: major, argument: nil, end: offset + 1)
        default:
            throw CardanoCoreError.deserializeError(
                "Malformed CBOR: reserved additional information \(info) at byte \(offset)"
            )
        }
    }

    /// The offset just past the item that starts at `offset`.
    func end(ofItemAt offset: Int) throws -> Int {
        let header = try header(at: offset)
        switch (header.major, header.argument) {
        case (0, _), (1, _), (7, .some):
            return header.end
        case (2, let length?), (3, let length?):
            let end = header.end + Int(clamping: length)
            guard end <= bytes.count else { throw truncated(at: offset) }
            return end
        case (2, nil), (3, nil):
            // Indefinite string: definite chunks up to a break.
            var position = header.end
            while try byte(at: position) != 0xFF {
                position = try end(ofItemAt: position)
            }
            return position + 1
        case (4, let count?):
            return try skip(Int(clamping: count), itemsFrom: header.end)
        case (5, let count?):
            return try skip(Int(clamping: count) * 2, itemsFrom: header.end)
        case (4, nil), (5, nil):
            var position = header.end
            while try byte(at: position) != 0xFF {
                position = try end(ofItemAt: position)
            }
            return position + 1
        case (6, _):
            return try end(ofItemAt: header.end)
        default:
            throw CardanoCoreError.deserializeError("Malformed CBOR at byte \(offset)")
        }
    }

    /// The byte spans of the elements of the array that starts at `offset`.
    func elements(ofArrayAt offset: Int) throws -> [Range<Int>] {
        let header = try header(at: offset)
        guard header.major == 4 else {
            throw CardanoCoreError.deserializeError("Expected a CBOR array at byte \(offset)")
        }
        var spans: [Range<Int>] = []
        var position = header.end
        if let count = header.argument {
            for _ in 0..<count {
                let end = try end(ofItemAt: position)
                spans.append(position..<end)
                position = end
            }
        } else {
            while try byte(at: position) != 0xFF {
                let end = try end(ofItemAt: position)
                spans.append(position..<end)
                position = end
            }
        }
        return spans
    }

    private func skip(_ count: Int, itemsFrom offset: Int) throws -> Int {
        var position = offset
        for _ in 0..<count {
            position = try end(ofItemAt: position)
        }
        return position
    }

    private func byte(at offset: Int) throws -> UInt8 {
        guard offset < bytes.count else { throw truncated(at: offset) }
        return bytes[offset]
    }

    private func truncated(at offset: Int) -> CardanoCoreError {
        .deserializeError("Truncated CBOR at byte \(offset) of \(bytes.count)")
    }
}
