import CBORCodable
import Foundation

/// The ledger's rules for a repeated map key or set element, applied to the
/// bytes of a transaction or of one of its parts.
///
/// Decoding keeps a repeated key's later value and a repeated set element
/// once, which is how the ledger reads them before Conway. The rules here then
/// reject what the ledger rejects (`cardano-ledger-binary` and the era
/// decoders, protocol versions 9 to 11):
///
/// - A sparse record — a transaction body, witness set, output, Alonzo
///   auxiliary data or protocol-parameter update — may not repeat a field, in
///   any era.
/// - From Conway, an ordinary map may not repeat a key, and a set may not
///   repeat an element.
/// - Except, in Conway, the key witnesses, bootstrap witnesses, native scripts
///   and datums of a witness set, which may repeat (each kept once), and the
///   redeemer map, which may repeat a key (the later one kept).
/// - Plutus data and metadatum maps may repeat a key in every era: the ledger
///   reads them as lists of pairs.
struct LedgerDuplicateRules {
    let scanner: CBORItemScanner
    let era: Era

    init(_ bytes: Data, era: Era) {
        scanner = CBORItemScanner(bytes)
        self.era = era
    }

    /// Whether maps and sets may not repeat a key or an element.
    private var strict: Bool { era >= .conway }

    // MARK: Entry points

    func checkTransaction() throws {
        let spans = try scanner.elements(ofArrayAt: 0)
        guard spans.count >= 3 else { return }
        try checkBody(at: spans[0].lowerBound)
        try checkWitnessSet(at: spans[1].lowerBound)
        if let last = spans.last, spans.count == 4 || spans.count == 3 {
            let auxiliary = spans.count == 4 ? last : spans[2]
            if try scanner.header(at: auxiliary.lowerBound).major != 7 {
                try checkAuxiliaryData(at: auxiliary.lowerBound)
            }
        }
    }

    func checkBody(at offset: Int) throws {
        for (key, value) in try record(at: offset, "transaction body") {
            switch key {
            case 0, 13, 14, 18: try checkSet(at: value)
            case 1:
                for output in try scanner.elements(ofArrayAt: value) {
                    try checkOutput(at: output.lowerBound)
                }
            case 16: try checkOutput(at: value)
            case 4: try checkSet(at: value, element: checkCertificate)
            case 20: try checkSet(at: value, element: checkProposal)
            case 6:
                // [{genesis key hash => protocol parameter update}, epoch]
                let spans = try scanner.elements(ofArrayAt: value)
                if let updates = spans.first {
                    try checkMap(at: updates.lowerBound, value: checkParameterUpdate)
                }
            default: try checkItem(at: value)
            }
        }
    }

    func checkWitnessSet(at offset: Int) throws {
        for (key, value) in try record(at: offset, "witness set") {
            switch key {
            case 0, 1, 2:
                // Key witnesses, native scripts and bootstrap witnesses may
                // repeat until protocol version 12.
                try checkElements(at: value, element: checkItem)
            case 4:
                // Datums may repeat until protocol version 12, and are Plutus
                // data, which may repeat a map key.
                break
            case 5:
                try checkRedeemers(at: value)
            default:
                try checkSet(at: value)
            }
        }
    }

    func checkAuxiliaryData(at offset: Int) throws {
        let start = try scanner.untagged(at: offset)
        let header = try scanner.header(at: offset)
        if header.major == 6 {
            // #6.259({0: metadata, 1: native scripts, 2–4: Plutus scripts})
            for (key, value) in try record(at: start, "auxiliary data") {
                if key == 0 {
                    try checkMetadata(at: value)
                } else {
                    try checkItem(at: value)
                }
            }
        } else if header.major == 4 {
            // [metadata, native scripts]
            let spans = try scanner.elements(ofArrayAt: offset)
            if let metadata = spans.first { try checkMetadata(at: metadata.lowerBound) }
            for span in spans.dropFirst() { try checkItem(at: span.lowerBound) }
        } else {
            try checkMetadata(at: offset)
        }
    }

    /// A block's `{* transaction_index => auxiliary_data}`.
    func checkAuxiliaryDataSet(at offset: Int) throws {
        try checkMap(at: offset, key: { _ in }, value: checkAuxiliaryData)
    }

    // MARK: Parts

    /// `{* label => metadatum}`: the labels are an ordinary map's keys; the
    /// metadata under them may repeat keys.
    private func checkMetadata(at offset: Int) throws {
        try checkMap(at: offset, key: { _ in }, value: { _ in })
    }

    private func checkOutput(at offset: Int) throws {
        if try scanner.header(at: offset).major == 5 {
            for (_, value) in try record(at: offset, "transaction output") {
                try checkItem(at: value)
            }
        } else {
            try checkItem(at: offset)
        }
    }

    private func checkRedeemers(at offset: Int) throws {
        if try scanner.header(at: offset).major == 5 {
            // {[tag, index] => [data, ex_units]}: a key may repeat until
            // protocol version 12; the data is Plutus data.
            for (key, value) in try scanner.entries(ofMapAt: offset) {
                try checkItem(at: key.lowerBound)
                let parts = try scanner.elements(ofArrayAt: value.lowerBound)
                for part in parts.dropFirst() { try checkItem(at: part.lowerBound) }
            }
        } else {
            // [* [tag, index, data, ex_units]]
            for redeemer in try scanner.elements(ofArrayAt: offset) {
                let parts = try scanner.elements(ofArrayAt: redeemer.lowerBound)
                for (index, part) in parts.enumerated() where index != 2 {
                    try checkItem(at: part.lowerBound)
                }
            }
        }
    }

    /// A certificate; a pool registration's owners are a set.
    private func checkCertificate(at offset: Int) throws {
        let spans = try scanner.elements(ofArrayAt: offset)
        for (index, span) in spans.enumerated() {
            if index == 7, try scanner.unsignedInteger(at: spans[0].lowerBound) == 3 {
                try checkSet(at: span.lowerBound)
            } else {
                try checkItem(at: span.lowerBound)
            }
        }
    }

    /// `[deposit, reward account, gov action, anchor]`.
    private func checkProposal(at offset: Int) throws {
        let spans = try scanner.elements(ofArrayAt: offset)
        for (index, span) in spans.enumerated() {
            if index == 2 {
                try checkGovernanceAction(at: span.lowerBound)
            } else {
                try checkItem(at: span.lowerBound)
            }
        }
    }

    private func checkGovernanceAction(at offset: Int) throws {
        let spans = try scanner.elements(ofArrayAt: offset)
        let kind = try spans.first.flatMap { try scanner.unsignedInteger(at: $0.lowerBound) }
        for (index, span) in spans.enumerated() {
            switch (kind, index) {
            case (0, 2): try checkParameterUpdate(at: span.lowerBound)
            case (4, 2): try checkSet(at: span.lowerBound)
            default: try checkItem(at: span.lowerBound)
            }
        }
    }

    private func checkParameterUpdate(at offset: Int) throws {
        for (_, value) in try record(at: offset, "protocol parameter update") {
            try checkItem(at: value)
        }
    }

    // MARK: Shapes

    /// A container ``checkItem(at:)`` is inside.
    private struct ItemFrame {
        /// Where the container starts.
        let start: Int
        /// Items left, or `nil` until a break.
        var remaining: UInt64?
        let isMap: Bool
        let isSet: Bool
        /// The container's major type: 4, 5 or 6.
        let major: UInt8
        /// An array's or a map's count, `nil` when indefinite; a tag's number.
        let argument: UInt64?
        /// Items read so far.
        var count = 0
        /// The spans of a map's keys or a set's elements, with the hashes of
        /// their values.
        var spans: [(span: Range<Int>, hash: Int)] = []
        /// The hashes of the items read so far, in order.
        var contents = Hasher()
        /// A tag's item, once read.
        var tagged: ValueHash?
    }

    /// The hash of an item's value, as ``value(in:)`` would read it.
    ///
    /// Built from the hashes of its parts as each completes, so a key nested
    /// inside other keys is hashed once rather than decoded again at every
    /// level. Items that read as the same value hash the same, however they
    /// were written: an integer's header width, a definite or indefinite
    /// string or map, a float's width, null or undefined.
    private struct ValueHash {
        /// The hash of the value.
        var value: Int
        /// For an array, the hash of its elements alone: a unit interval
        /// reads the same from a definite or an indefinite array.
        var elements: Int
    }

    /// Any item, its maps ordinary maps and its tag-258 arrays sets.
    ///
    /// One pass over the bytes, with the containers still open kept in an
    /// array: native scripts, for one, nest without a limit, and finding
    /// each element's end afresh at every level would take time quadratic
    /// in the depth. For the same reason keys and elements are compared by
    /// hashes built in that pass, and decoded only when two hashes match.
    private func checkItem(at offset: Int) throws {
        var stack: [ItemFrame] = []
        var position = offset
        var nextIsSet = false
        repeat {
            let start = position
            let header = try scanner.header(at: position)
            position = header.end
            let isSet = nextIsSet
            nextIsSet = false
            var completed: (span: Range<Int>, hash: ValueHash)?
            switch (header.major, header.argument) {
            case (2, _), (3, _):
                position = try scanner.end(ofItemAt: start)
                completed = (start..<position, leafHash(header, in: start..<position))
            case (4, let count):
                if let count, count > UInt64(scanner.bytes.count - position) { throw truncated(at: start) }
                stack.append(ItemFrame(
                    start: start, remaining: count, isMap: false, isSet: isSet,
                    major: 4, argument: count))
            case (5, let count):
                if let count, count > UInt64(scanner.bytes.count - position) { throw truncated(at: start) }
                stack.append(ItemFrame(
                    start: start, remaining: count.map { $0 * 2 }, isMap: true, isSet: false,
                    major: 5, argument: count))
            case (6, 24?):
                // Embedded CBOR — an inline datum or a script — is bytes here.
                position = try scanner.end(ofItemAt: start)
                completed = (start..<position, leafHash(header, in: start..<position))
            case (6, let tag):
                nextIsSet = tag == 258
                stack.append(ItemFrame(
                    start: start, remaining: 1, isMap: false, isSet: false,
                    major: 6, argument: tag))
            default:
                completed = (start..<position, leafHash(header, in: start..<position))
            }
            // Record what has completed in the container around it, and close
            // every container that is now complete.
            while true {
                if let (span, hash) = completed {
                    completed = nil
                    guard !stack.isEmpty else { break }
                    let index = stack.count - 1
                    if stack[index].isSet || (stack[index].isMap && stack[index].count % 2 == 0) {
                        stack[index].spans.append((span, hash.value))
                    }
                    if stack[index].major == 6 {
                        stack[index].tagged = hash
                    } else {
                        stack[index].contents.combine(hash.value)
                    }
                    stack[index].count += 1
                    if let remaining = stack[index].remaining { stack[index].remaining = remaining - 1 }
                }
                guard let top = stack.last else { break }
                if top.remaining == 0 {
                    // Done.
                } else if top.remaining == nil, try scanner.header(at: position).major == 7,
                          scanner.bytes[safe: position] == 0xFF {
                    position += 1
                } else {
                    break
                }
                stack.removeLast()
                try checkUnique(top)
                completed = (top.start..<position, containerHash(top))
            }
        } while !stack.isEmpty
    }

    /// From Conway, no key of a map and no element of a set may repeat.
    ///
    /// Only keys or elements whose hashes match are decoded and compared by
    /// value, so the check costs time linear in the bytes unless two of them
    /// really are equal.
    private func checkUnique(_ frame: ItemFrame) throws {
        guard strict, frame.isMap || frame.isSet, frame.spans.count > 1 else { return }
        var seen: [Int: [Range<Int>]] = [:]
        for (span, hash) in frame.spans {
            if let earlier = seen[hash] {
                let current = try value(in: span)
                for other in earlier where try value(in: other) == current {
                    throw CardanoCoreError.deserializeError(frame.isMap
                        ? "A map repeats a key, which the ledger rejects from Conway"
                        : "A set repeats an element, which the ledger rejects from Conway")
                }
            }
            seen[hash, default: []].append(span)
        }
    }

    /// The hash of a container's value, from the hashes of its items.
    private func containerHash(_ frame: ItemFrame) -> ValueHash {
        let elements = frame.contents.finalize()
        var hasher = Hasher()
        hasher.combine(frame.major)
        switch frame.major {
        case 4:
            // A definite and an indefinite array read as different values.
            hasher.combine(frame.argument == nil)
            hasher.combine(elements)
        case 5:
            // A map reads as the same value either way.
            hasher.combine(elements)
        default:
            hasher.combine(frame.argument)
            if frame.argument == UInt64(UnitInterval.tag) {
                hasher.combine(frame.tagged?.elements)
            } else {
                hasher.combine(frame.tagged?.value)
            }
        }
        return ValueHash(value: hasher.finalize(), elements: elements)
    }

    /// The hash of the value of an item that holds no other items: an
    /// integer, a string, a simple value or a float, or embedded CBOR.
    ///
    /// The item is rebuilt as the `CBOR` value the decoder reads and turned
    /// into a ``Primitive`` the way ``value(in:)`` turns it, so the two agree
    /// on which items are equal. That costs no more than the item's size.
    private func leafHash(_ header: CBORItemScanner.Header, in span: Range<Int>) -> ValueHash {
        var hasher = Hasher()
        if let leaf = leafCBOR(header, in: span), let primitive = try? Primitive.from(cbor: leaf) {
            hasher.combine(primitive)
        } else {
            hashRaw(span, into: &hasher)
        }
        let value = hasher.finalize()
        return ValueHash(value: value, elements: value)
    }

    /// The `CBOR` value the decoder reads from a leaf item, or `nil` when it
    /// would refuse it.
    private func leafCBOR(_ header: CBORItemScanner.Header, in span: Range<Int>) -> CBOR? {
        switch header.major {
        case 0:
            return header.argument.map { .unsignedInt($0) }
        case 1:
            return header.argument.map { .negativeInt($0) }
        case 2:
            guard let chunks = stringChunks(header, in: span) else { return nil }
            return header.argument == nil ? .indefiniteByteString(chunks) : .byteString(chunks[0])
        case 3:
            guard let chunks = stringChunks(header, in: span) else { return nil }
            var strings: [String] = []
            for chunk in chunks {
                let string = String(decoding: chunk, as: UTF8.self)
                guard string.utf8.elementsEqual(chunk) else { return nil }
                strings.append(string)
            }
            return header.argument == nil ? .indefiniteTextString(strings) : .textString(strings[0])
        case 6:
            // #6.24(bytes).
            guard let argument = header.argument,
                  let inner = try? scanner.header(at: header.end), inner.major == 2,
                  let bytes = leafCBOR(inner, in: header.end..<span.upperBound)
            else { return nil }
            return .tagged(argument, bytes)
        case 7:
            guard let argument = header.argument else { return nil }
            switch header.end - span.lowerBound {
            case 3: return .half(UInt16(truncatingIfNeeded: argument))
            case 5: return .float(Float(bitPattern: UInt32(truncatingIfNeeded: argument)))
            case 9: return .double(Double(bitPattern: argument))
            default:
                switch argument {
                case 20: return .boolean(false)
                case 21: return .boolean(true)
                case 22: return .null
                case 23: return .undefined
                default: return .simple(UInt8(truncatingIfNeeded: argument))
                }
            }
        default:
            return nil
        }
    }

    /// The bytes of a definite string as one chunk, or the chunks of an
    /// indefinite one; `nil` when the chunks are not well formed.
    private func stringChunks(_ header: CBORItemScanner.Header, in span: Range<Int>) -> [Data]? {
        let bytes = scanner.bytes
        if let length = header.argument {
            guard length <= UInt64(span.upperBound - header.end) else { return nil }
            return [bytes.subdata(in: header.end..<(header.end + Int(length)))]
        }
        var chunks: [Data] = []
        var position = header.end
        while position < span.upperBound, bytes[position] != 0xFF {
            guard let chunk = try? scanner.header(at: position), chunk.major == header.major,
                  let length = chunk.argument, length <= UInt64(span.upperBound - chunk.end)
            else { return nil }
            chunks.append(bytes.subdata(in: chunk.end..<(chunk.end + Int(length))))
            position = chunk.end + Int(length)
        }
        return chunks
    }

    /// An item the decoder would reject or read some other way: hashed by its
    /// bytes, so a matching hash still ends in a comparison by value.
    private func hashRaw(_ span: Range<Int>, into hasher: inout Hasher) {
        hasher.combine("raw")
        scanner.bytes[span].withUnsafeBytes { hasher.combine(bytes: $0) }
    }

    private func truncated(at offset: Int) -> CardanoCoreError {
        CardanoCoreError.deserializeError("Truncated CBOR at byte \(offset)")
    }

    private func checkElements(at offset: Int, element: (Int) throws -> Void) throws {
        let start = try scanner.untagged(at: offset)
        for span in try scanner.elements(ofArrayAt: start) {
            try element(span.lowerBound)
        }
    }

    /// A set, tagged 258 or not: from Conway, no element may repeat.
    private func checkSet(at offset: Int, element: ((Int) throws -> Void)? = nil) throws {
        for span in try setElements(at: offset) {
            try (element ?? checkItem)(span.lowerBound)
        }
    }

    /// The elements of a set, checked not to repeat from Conway.
    private func setElements(at offset: Int) throws -> [Range<Int>] {
        let start = try scanner.untagged(at: offset)
        let spans = try scanner.elements(ofArrayAt: start)
        if strict {
            var seen = Set<Primitive>()
            for span in spans where !seen.insert(try value(in: span)).inserted {
                throw CardanoCoreError.deserializeError(
                    "A set repeats an element, which the ledger rejects from Conway")
            }
        }
        return spans
    }

    /// An ordinary map: from Conway, no key may repeat.
    private func checkMap(
        at offset: Int,
        key: ((Int) throws -> Void)? = nil,
        value checkValue: ((Int) throws -> Void)? = nil
    ) throws {
        for entry in try mapEntries(at: offset) {
            try (key ?? checkItem)(entry.key.lowerBound)
            try (checkValue ?? checkItem)(entry.value.lowerBound)
        }
    }

    /// The entries of an ordinary map, checked not to repeat a key from Conway.
    private func mapEntries(at offset: Int) throws -> [(key: Range<Int>, value: Range<Int>)] {
        let entries = try scanner.entries(ofMapAt: offset)
        if strict {
            var seen = Set<Primitive>()
            for entry in entries where !seen.insert(try value(in: entry.key)).inserted {
                throw CardanoCoreError.deserializeError(
                    "A map repeats a key, which the ledger rejects from Conway")
            }
        }
        return entries
    }

    /// A sparse record's fields by number. No field may repeat, in any era.
    private func record(at offset: Int, _ name: String) throws -> [(key: UInt64, value: Int)] {
        var seen = Set<UInt64>()
        var fields: [(key: UInt64, value: Int)] = []
        for (key, value) in try scanner.entries(ofMapAt: offset) {
            guard let field = try scanner.unsignedInteger(at: key.lowerBound) else {
                throw CardanoCoreError.deserializeError("A \(name) field must be an unsigned integer")
            }
            guard seen.insert(field).inserted else {
                throw CardanoCoreError.deserializeError("A \(name) repeats field \(field)")
            }
            fields.append((field, value.lowerBound))
        }
        return fields
    }

    /// The value of the item in `span`, for comparing keys and elements as
    /// the ledger does — by value, not by how they were written.
    private func value(in span: Range<Int>) throws -> Primitive {
        let decoder = CBORDecoder.ledger()
        decoder.allowDuplicateMapKeys = true
        return try Primitive.from(
            cbor: decoder.decode(CBOR.self, from: scanner.bytes.subdata(in: span)))
    }
}
