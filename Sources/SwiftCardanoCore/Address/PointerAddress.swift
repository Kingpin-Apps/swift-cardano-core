import Foundation

// MARK: - Pointer Address
/// Pointer address.
///
/// It refers to a point of the chain containing a stake key registration certificate.
///
/// The fields are the ledger's `Ptr`: a `Word32` slot and `Word16` transaction
/// and certificate indexes (`Ptr`, `SlotNo32`,
/// `libs/cardano-ledger-core/src/Cardano/Ledger/Credential.hs`; `TxIx`,
/// `CertIx`, `libs/cardano-ledger-core/src/Cardano/Ledger/BaseTypes.hs`).
///
/// Each is written as a variable-length natural, seven bits a byte, most
/// significant group first (`putPtr`, `putVariableLengthWord64`, `Address.hs`).
/// A pointer read from bytes keeps those bytes when they are not the canonical
/// encoding of its fields — a padded group, or values the ledger replaced with
/// `Ptr 0 0 0` — so that it is written again exactly as it was read; see
/// ``originalBytes``.
///
/// - Parameters:
///  - slot: Slot in which the staking certificate was posted.
///  - txIndex: The transaction index (within that slot).
///  - certIndex: A (delegation) certificate index (within that transaction).
public struct PointerAddress: Codable, Hashable, Sendable, CustomStringConvertible {
    /// The slot in which the staking certificate was posted.
    public let slot: UInt32

    /// The transaction index (within that slot).
    public let txIndex: UInt16

    /// The delegation certificate index (within that transaction).
    public let certIndex: UInt16

    /// The bytes this pointer was read from, when they differ from
    /// ``ledgerBytes``; `nil` otherwise.
    ///
    /// They differ when a group was padded with leading `0x80` bytes, which
    /// every era accepts, or when a value did not fit its field and a ledger
    /// before Conway read the pointer as `Ptr 0 0 0` (``isNormalized``).
    public let originalBytes: Data?

    /// Initialize a new PointerAddress.
    /// - Parameters:
    ///   - slot: The slot in which the staking certificate was posted.
    ///   - txIndex: The transaction index (within that slot).
    ///   - certIndex: The delegation certificate index (within that transaction).
    public init(slot: UInt32, txIndex: UInt16, certIndex: UInt16) {
        self.slot = slot
        self.txIndex = txIndex
        self.certIndex = certIndex
        self.originalBytes = nil
    }

    private init(slot: UInt32, txIndex: UInt16, certIndex: UInt16, written: Data) {
        self.slot = slot
        self.txIndex = txIndex
        self.certIndex = certIndex
        let canonical = Self.canonicalBytes(slot: slot, txIndex: txIndex, certIndex: certIndex)
        self.originalBytes = written == canonical ? nil : written
    }

    // MARK: - Encoding

    /// One natural as the ledger writes it: seven bits a byte, most
    /// significant group first, the high bit set on every byte but the last
    /// (`putVariableLengthWord64`, `word64ToWord7s`, `Address.hs`).
    static func varint(_ value: UInt64) -> Data {
        var groups: [UInt8] = [UInt8(value & 0x7F)]
        var rest = value >> 7
        while rest > 0 {
            groups.append(0x80 | UInt8(rest & 0x7F))
            rest >>= 7
        }
        return Data(groups.reversed())
    }

    private static func canonicalBytes(slot: UInt32, txIndex: UInt16, certIndex: UInt16) -> Data {
        varint(UInt64(slot)) + varint(UInt64(txIndex)) + varint(UInt64(certIndex))
    }

    /// The pointer as the ledger writes it (`putPtr`, `Address.hs`), which is
    /// how the ledger keeps a decoded pointer address in its UTxO
    /// (`cAddrNormalized` in `fromCborBothAddr`).
    public var ledgerBytes: Data {
        Self.canonicalBytes(slot: slot, txIndex: txIndex, certIndex: certIndex)
    }

    /// Encode the pointer address to bytes: the bytes it was read from, or
    /// ``ledgerBytes`` for a pointer that was built or read in canonical form.
    ///
    /// The encoding follows [CIP-0019#Pointers](https://github.com/cardano-foundation/CIPs/tree/master/CIP-0019#pointers).
    /// - Returns: Encoded bytes.
    public func encode() -> Data {
        originalBytes ?? ledgerBytes
    }

    /// The three naturals as written, each read the way the ledger before
    /// Conway reads it: as a `Word64` that keeps only its low 64 bits
    /// (`decodeVariableLengthWord64`, `Address.hs`).
    public var writtenValues: (slot: UInt64, txIndex: UInt64, certIndex: UInt64) {
        guard let originalBytes else {
            return (UInt64(slot), UInt64(txIndex), UInt64(certIndex))
        }
        var offset = 0
        let bytes = [UInt8](originalBytes)
        // The bytes were read as three naturals once already, so these succeed.
        let s = (try? Self.readWord64(bytes, &offset)) ?? 0
        let t = (try? Self.readWord64(bytes, &offset)) ?? 0
        let c = (try? Self.readWord64(bytes, &offset)) ?? 0
        return (s, t, c)
    }

    /// Whether the written values did not fit a `Word32` slot and `Word16`
    /// indexes, so that the ledger before Conway read this pointer as
    /// `Ptr 0 0 0` (`mkPtrNormalized`, `Credential.hs`).
    public var isNormalized: Bool {
        let written = writtenValues
        return UInt32(exactly: written.slot) == nil
            || UInt16(exactly: written.txIndex) == nil
            || UInt16(exactly: written.certIndex) == nil
    }

    // MARK: - Decoding

    /// How the ledger reads a pointer.
    enum Rule {
        /// Before Conway (protocol version 9): each natural is read as a
        /// `Word64` of any number of bytes, its high bits shifted out, and a
        /// pointer whose slot does not fit a `Word32`, or whose index does not
        /// fit a `Word16`, is `Ptr 0 0 0` (`decodePtrLenient`,
        /// `decodeVariableLengthWord64`, `mkPtrNormalized`).
        case lenient
        /// From Conway: the slot is at most five bytes and 32 bits, each index
        /// at most three bytes and 16 bits, and anything else fails
        /// (`decodePtr`, `decodeVariableLengthWord32`,
        /// `decodeVariableLengthWord16`).
        case strict

        /// The rule of the era decoding follows (`fromCborBothAddr`: lenient
        /// below protocol version 9).
        static var current: Rule { Era.decodingRules >= .conway ? .strict : .lenient }
    }

    /// One natural as `decode7BitVarLength` folds it into a `Word64`: the
    /// shift drops the bits above 64 rather than failing.
    private static func readWord64(_ bytes: [UInt8], _ offset: inout Int) throws -> UInt64 {
        var acc: UInt64 = 0
        while true {
            guard offset < bytes.count else {
                throw CardanoCoreError.decodingError("Pointer: not enough bytes for decoding")
            }
            let byte = bytes[offset]
            offset += 1
            acc = (acc << 7) | UInt64(byte & 0x7F)
            if byte & 0x80 == 0 { return acc }
        }
    }

    /// One natural of at most `maxBytes` bytes. When all of them are used,
    /// the first byte must be the continuation bit and only the low bits
    /// `firstByteMask` leaves clear (`decodeVariableLengthWord16`: three
    /// bytes, `0b11111100`; `decodeVariableLengthWord32`: five bytes,
    /// `0b11110000`).
    private static func readBounded(
        _ bytes: [UInt8], _ offset: inout Int, maxBytes: Int, firstByteMask: UInt8, _ name: String
    ) throws -> UInt64 {
        let start = offset
        var acc: UInt64 = 0
        for index in 0..<maxBytes {
            guard offset < bytes.count else {
                throw CardanoCoreError.decodingError("Pointer \(name): not enough bytes for decoding")
            }
            let byte = bytes[offset]
            offset += 1
            acc = (acc << 7) | UInt64(byte & 0x7F)
            if byte & 0x80 == 0 {
                if index == maxBytes - 1, bytes[start] & firstByteMask != 0b1000_0000 {
                    throw CardanoCoreError.decodingError("Pointer \(name): more bits than its field holds")
                }
                return acc
            }
        }
        throw CardanoCoreError.decodingError("Pointer \(name): too many bytes")
    }

    /// Reads a pointer from the start of `bytes` under `rule`, returning it
    /// and the number of bytes it used. What follows is not looked at.
    static func read(_ bytes: Data, rule: Rule) throws -> (pointer: PointerAddress, consumed: Int) {
        let raw = [UInt8](bytes)
        var offset = 0
        let pointer: (UInt32, UInt16, UInt16)
        switch rule {
        case .lenient:
            let slot = try readWord64(raw, &offset)
            let txIndex = try readWord64(raw, &offset)
            let certIndex = try readWord64(raw, &offset)
            if let s = UInt32(exactly: slot), let t = UInt16(exactly: txIndex), let c = UInt16(exactly: certIndex) {
                pointer = (s, t, c)
            } else {
                pointer = (0, 0, 0)
            }
        case .strict:
            let slot = try readBounded(raw, &offset, maxBytes: 5, firstByteMask: 0b1111_0000, "slot")
            let txIndex = try readBounded(raw, &offset, maxBytes: 3, firstByteMask: 0b1111_1100, "transaction index")
            let certIndex = try readBounded(raw, &offset, maxBytes: 3, firstByteMask: 0b1111_1100, "certificate index")
            // The byte counts and first-byte masks bound each to its width.
            pointer = (
                UInt32(truncatingIfNeeded: slot),
                UInt16(truncatingIfNeeded: txIndex),
                UInt16(truncatingIfNeeded: certIndex)
            )
        }
        let written = Data(raw[0..<offset])
        return (
            PointerAddress(slot: pointer.0, txIndex: pointer.1, certIndex: pointer.2, written: written),
            offset
        )
    }

    /// Decode bytes into a PointerAddress, by the rules of the era decoding
    /// follows (``Era/decoding``; Conway when none is bound).
    /// - Parameter data: The data to be decoded: exactly one pointer.
    /// - Returns: Decoded pointer address.
    public static func decode(_ data: Data) throws -> PointerAddress {
        let (pointer, consumed) = try read(Data(data), rule: .current)
        guard consumed == data.count else {
            throw CardanoCoreError.decodingError(
                "Error in decoding data \(data.toHex) into a PointerAddress: \(data.count - consumed) bytes left over")
        }
        return pointer
    }

    // MARK: - Equatable

    /// Pointers are equal when the ledger reads them as the same `Ptr`,
    /// however they were written.
    public static func == (lhs: PointerAddress, rhs: PointerAddress) -> Bool {
        return lhs.slot == rhs.slot &&
               lhs.txIndex == rhs.txIndex &&
               lhs.certIndex == rhs.certIndex
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(slot)
        hasher.combine(txIndex)
        hasher.combine(certIndex)
    }

    // MARK: - CustomStringConvertible

    public var description: String {
        return "PointerAddress(\(slot), \(txIndex), \(certIndex))"
    }
}
