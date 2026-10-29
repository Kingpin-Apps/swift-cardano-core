@preconcurrency import BigInt
import Foundation

/// Reads Plutus data straight from its bytes.
///
/// The generic CBOR layer holds a map as a dictionary, so a map that repeats a
/// key — which the ledger accepts in Plutus data, where a map is a list of
/// pairs — would lose a pair on the way. This reads the bytes itself. It keeps
/// every pair, and how each list, map, byte string and constructor was
/// written, and it rejects what the ledger does not read as Plutus data: text
/// strings, floats, simple values and tags other than constructors and
/// bignums.
struct PlutusDataReader {
    let scanner: CBORItemScanner

    /// The deepest nesting read, as for the generic decoder.
    static let maxDepth = 128

    init(_ bytes: Data) {
        scanner = CBORItemScanner(bytes)
    }

    /// The datum that makes up all of the bytes.
    static func read(_ bytes: Data) throws -> PlutusData {
        let reader = PlutusDataReader(bytes)
        let (value, end) = try reader.read(at: 0, depth: 0)
        guard end == reader.scanner.bytes.count else {
            throw CardanoCoreError.deserializeError("Trailing bytes after PlutusData")
        }
        return value
    }

    /// The datum that starts at `offset`, and the offset just past it.
    func read(at offset: Int, depth: Int) throws -> (PlutusData, end: Int) {
        guard depth < Self.maxDepth else {
            throw CardanoCoreError.deserializeError("PlutusData nested deeper than \(Self.maxDepth)")
        }
        let header = try scanner.header(at: offset)
        switch (header.major, header.argument) {
        case (0, let value?):
            return (.bigInt(Self.integer(BigInt(value))), header.end)
        case (1, let value?):
            return (.bigInt(Self.integer(-1 - BigInt(value))), header.end)
        case (2, _):
            let (bytes, end) = try byteString(at: offset)
            return (.bytes(bytes), end)
        case (4, _):
            let (elements, end, indefinite) = try list(at: offset, depth: depth)
            return (indefinite ? .indefiniteArray(IndefiniteList(elements)) : .array(elements), end)
        case (5, _):
            return try map(at: offset, depth: depth)
        case (6, let tag?):
            return try tagged(tag, contentAt: header.end, depth: depth)
        default:
            throw CardanoCoreError.deserializeError(
                "Not Plutus data: CBOR major type \(header.major) at byte \(offset)")
        }
    }

    /// An integer, held as ``BigInteger/int(_:)`` when it fits.
    static func integer(_ value: BigInt) -> BigInteger {
        if let small = Int64(exactly: value) { return .int(small) }
        return value.sign == .plus ? .bigUInt(value.magnitude) : .bigNInt(value)
    }

    /// A byte string, definite or in chunks, keeping the chunks.
    private func byteString(at offset: Int) throws -> (Bytes, end: Int) {
        let header = try scanner.header(at: offset)
        guard header.major == 2 else {
            throw CardanoCoreError.deserializeError("Expected a byte string at byte \(offset)")
        }
        if let length = header.argument {
            let end = try scanner.end(ofItemAt: offset)
            _ = length
            return (try Bytes(from: scanner.bytes.subdata(in: header.end..<end)), end)
        }
        var chunks: [Data] = []
        var position = header.end
        while scanner.bytes[safe: position] != 0xFF {
            let chunk = try scanner.header(at: position)
            guard chunk.major == 2, chunk.argument != nil else {
                throw CardanoCoreError.deserializeError(
                    "A chunk of a byte string must be a definite byte string, at byte \(position)")
            }
            let end = try scanner.end(ofItemAt: position)
            chunks.append(scanner.bytes.subdata(in: chunk.end..<end))
            position = end
        }
        guard position < scanner.bytes.count else {
            throw CardanoCoreError.deserializeError("Truncated byte string at byte \(offset)")
        }
        return (.byteString(ByteString(chunks: chunks)), position + 1)
    }

    /// The elements of a list, and whether it was written indefinite.
    private func list(at offset: Int, depth: Int) throws -> ([PlutusData], end: Int, indefinite: Bool) {
        let header = try scanner.header(at: offset)
        guard header.major == 4 else {
            throw CardanoCoreError.deserializeError("Expected an array at byte \(offset)")
        }
        var elements: [PlutusData] = []
        var position = header.end
        if let count = header.argument {
            for _ in 0..<count {
                let (element, end) = try read(at: position, depth: depth + 1)
                elements.append(element)
                position = end
            }
            return (elements, position, false)
        }
        while try byte(at: position) != 0xFF {
            let (element, end) = try read(at: position, depth: depth + 1)
            elements.append(element)
            position = end
        }
        return (elements, position + 1, true)
    }

    /// A map, every pair kept in order.
    private func map(at offset: Int, depth: Int) throws -> (PlutusData, end: Int) {
        let header = try scanner.header(at: offset)
        var pairs = MapPairs<PlutusData, PlutusData>()
        var position = header.end
        func next() throws {
            let (key, keyEnd) = try read(at: position, depth: depth + 1)
            let (value, valueEnd) = try read(at: keyEnd, depth: depth + 1)
            pairs.append(key: key, value: value)
            position = valueEnd
        }
        if let count = header.argument {
            for _ in 0..<count { try next() }
            return (.map(pairs), position)
        }
        while try byte(at: position) != 0xFF { try next() }
        return (.indefiniteMap(pairs), position + 1)
    }

    /// A constructor or a bignum.
    private func tagged(_ tag: UInt64, contentAt offset: Int, depth: Int) throws -> (PlutusData, end: Int) {
        switch tag {
        case 2, 3:
            let (magnitude, end) = try byteString(at: offset)
            let value = BigInt(BigUInt(magnitude.data))
            return (.bigInt(Self.integer(tag == 2 ? value : -1 - value)), end)
        case 121...127, 1280...1400:
            let alternative = tag < 1280 ? tag - 121 : tag - 1280 + 7
            let (fields, end, indefinite) = try list(at: offset, depth: depth + 1)
            return (.constructor(Self.constr(alternative, fields, indefinite: indefinite, general: false)), end)
        case 102:
            // #6.102([alternative, [* plutus_data]])
            let spans = try scanner.elements(ofArrayAt: offset)
            guard spans.count == 2, let alternative = try scanner.unsignedInteger(at: spans[0].lowerBound)
            else {
                throw CardanoCoreError.deserializeError(
                    "A #6.102 constructor must be [alternative, fields], at byte \(offset)")
            }
            let (fields, fieldsEnd, indefinite) = try list(at: spans[1].lowerBound, depth: depth + 1)
            let end = try scanner.end(ofItemAt: offset)
            guard fieldsEnd == spans[1].upperBound else {
                throw CardanoCoreError.deserializeError("Malformed #6.102 constructor at byte \(offset)")
            }
            return (.constructor(Self.constr(alternative, fields, indefinite: indefinite, general: true)), end)
        default:
            throw CardanoCoreError.deserializeError("Not Plutus data: CBOR tag \(tag) at byte \(offset)")
        }
    }

    private static func constr(
        _ alternative: UInt64, _ fields: [PlutusData], indefinite: Bool, general: Bool
    ) -> Constr {
        var constr = Constr(tag: alternative, fields: fields, useIndefiniteList: indefinite)
        constr.writtenIndefinite = indefinite
        constr.writtenGeneral = general
        return constr
    }

    private func byte(at offset: Int) throws -> UInt8 {
        guard let byte = scanner.bytes[safe: offset] else {
            throw CardanoCoreError.deserializeError("Truncated PlutusData at byte \(offset)")
        }
        return byte
    }
}

extension Data {
    subscript(safe offset: Int) -> UInt8? {
        offset >= 0 && offset < count ? self[startIndex + offset] : nil
    }
}
