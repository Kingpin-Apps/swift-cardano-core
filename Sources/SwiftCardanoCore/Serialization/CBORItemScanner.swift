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
    ///
    /// Walked in a loop, with the containers still open kept in an array, so
    /// an item nested as deep as the input allows — the ledger sets no depth
    /// limit on Plutus data, metadata or native scripts — costs no stack.
    func end(ofItemAt offset: Int) throws -> Int {
        // Items still to step over in each open container, or `nil` until a
        // break.
        var open: [UInt64?] = []
        var position = offset
        repeat {
            let itemStart = position
            let header = try header(at: position)
            position = header.end
            switch (header.major, header.argument) {
            case (0, _), (1, _), (7, .some):
                break
            case (2, let length?), (3, let length?):
                // Compared before adding, so a huge length cannot overflow.
                guard length <= UInt64(bytes.count - position) else { throw truncated(at: itemStart) }
                position += Int(length)
            case (2, nil), (3, nil), (4, nil), (5, nil):
                // Indefinite: items up to a break.
                open.append(nil)
            case (4, let count?):
                guard count <= UInt64(bytes.count - position) else { throw truncated(at: itemStart) }
                open.append(count)
            case (5, let count?):
                // Every item takes at least a byte, so a count beyond the
                // bytes left is truncated; checking first keeps the doubling
                // in range.
                guard count <= UInt64(bytes.count - position) else { throw truncated(at: itemStart) }
                open.append(count * 2)
            case (6, _):
                open.append(1)
            default:
                throw CardanoCoreError.deserializeError("Malformed CBOR at byte \(itemStart)")
            }
            // Close what is complete; claim the next item's slot in what is not.
            while let remaining = open.last {
                if let remaining {
                    if remaining > 0 {
                        open[open.count - 1] = remaining - 1
                        break
                    }
                    open.removeLast()
                } else if try byte(at: position) == 0xFF {
                    position += 1
                    open.removeLast()
                } else {
                    break
                }
            }
        } while !open.isEmpty
        return position
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

    /// The byte spans of the keys and values of the map that starts at
    /// `offset`, in the order they were written.
    func entries(ofMapAt offset: Int) throws -> [(key: Range<Int>, value: Range<Int>)] {
        let header = try header(at: offset)
        guard header.major == 5 else {
            throw CardanoCoreError.deserializeError("Expected a CBOR map at byte \(offset)")
        }
        var entries: [(key: Range<Int>, value: Range<Int>)] = []
        var position = header.end
        func next() throws {
            let keyEnd = try end(ofItemAt: position)
            let valueEnd = try end(ofItemAt: keyEnd)
            entries.append((position..<keyEnd, keyEnd..<valueEnd))
            position = valueEnd
        }
        if let count = header.argument {
            for _ in 0..<count { try next() }
        } else {
            while try byte(at: position) != 0xFF { try next() }
        }
        return entries
    }

    /// The offset of the item inside any tags that start at `offset`.
    func untagged(at offset: Int) throws -> Int {
        var position = offset
        while case let header = try header(at: position), header.major == 6 {
            position = header.end
        }
        return position
    }

    /// The unsigned integer that starts at `offset`, or `nil` when the item
    /// there is anything else.
    func unsignedInteger(at offset: Int) throws -> UInt64? {
        let header = try header(at: offset)
        return header.major == 0 ? header.argument : nil
    }

    /// The header of a definite-length array (major type 4) or map (major
    /// type 5) of `count` items or entries, in its shortest form.
    static func definiteHeader(major: UInt8, count: Int) -> Data {
        head(major: major, argument: UInt64(count))
    }

    /// The header of an item of major type `major` with `argument` — a
    /// value, length, count or tag — in its shortest form.
    static func head(major: UInt8, argument count: UInt64) -> Data {
        let initial = major << 5
        switch count {
        case 0..<24: return Data([initial | UInt8(count)])
        case 24...0xFF: return Data([initial | 24, UInt8(count)])
        case 0x100...0xFFFF: return Data([initial | 25]) + withUnsafeBytes(of: UInt16(count).bigEndian) { Data($0) }
        case 0x10000...0xFFFF_FFFF: return Data([initial | 26]) + withUnsafeBytes(of: UInt32(count).bigEndian) { Data($0) }
        default: return Data([initial | 27]) + withUnsafeBytes(of: count.bigEndian) { Data($0) }
        }
    }

    private func byte(at offset: Int) throws -> UInt8 {
        guard offset < bytes.count else { throw truncated(at: offset) }
        return bytes[offset]
    }

    private func truncated(at offset: Int) -> CardanoCoreError {
        .deserializeError("Truncated CBOR at byte \(offset) of \(bytes.count)")
    }
}
