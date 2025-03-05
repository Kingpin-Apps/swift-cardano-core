import Foundation

// MARK: - Pointer Address
/// Pointer address.
///
/// It refers to a point of the chain containing a stake key registration certificate.
///
/// - Parameters:
///  - slot: Slot in which the staking certificate was posted.
///  - txIndex: The transaction index (within that slot).
///  - certIndex: A (delegation) certificate index (within that transaction).
public struct PointerAddress: Codable, Equatable, Sendable {
    /// The slot in which the staking certificate was posted.
    public var slot: Int { get { return _slot } }
    private let _slot: Int
    
    /// The transaction index (within that slot).
    public var txIndex: Int { get { return _txIndex } }
    private let _txIndex: Int
    
    /// The delegation certificate index (within that transaction).
    public var certIndex: Int { get { return _certIndex } }
    private let _certIndex: Int
    
    /// Initialize a new PointerAddress.
    /// - Parameters:
    ///   - slot: The slot in which the staking certificate was posted.
    ///   - txIndex: The transaction index (within that slot).
    ///   - certIndex: The delegation certificate index (within that transaction). 
    public init(slot: Int, txIndex: Int, certIndex: Int) {
        self._slot = slot
        self._txIndex = txIndex
        self._certIndex = certIndex
    }

    private func encodeInt(_ n: Int) -> Data {
        var n = n
        var output = [UInt8]()
        output.append(UInt8(n & 0x7F))
        n >>= 7
        while n > 0 {
            output.append(0x80 | UInt8(n & 0x7F))
            n >>= 7
        }
        return Data(output.reversed())
    }
    
    /// Encode the pointer address to bytes.
    ///
    /// The encoding follows [CIP-0019#Pointers](https://github.com/cardano-foundation/CIPs/tree/master/CIP-0019#pointers).
    /// - Returns: Encoded bytes.
    public func encode() -> Data {
        return encodeInt(slot) + encodeInt(txIndex) + encodeInt(certIndex)
    }
    
    /// Decode bytes into a PointerAddress.
    /// - Parameter data: The data to be decoded.
    /// - Returns: Decoded pointer address.
    public static func decode(_ data: Data) throws -> PointerAddress {
        var ints = [Int]()
        var curInt = 0
        for byte in data {
            curInt |= Int(byte & 0x7F)
            if byte & 0x80 == 0 {
                ints.append(curInt)
                curInt = 0
            } else {
                curInt <<= 7
            }
        }

        guard ints.count == 3 else {
            throw CardanoCoreError.decodingError("Error in decoding data \(data) into a PointerAddress")
        }

        return PointerAddress(slot: ints[0], txIndex: ints[1], certIndex: ints[2])
    }

    // MARK: - Equatable

    public static func == (lhs: PointerAddress, rhs: PointerAddress) -> Bool {
        return lhs.slot == rhs.slot &&
               lhs.txIndex == rhs.txIndex &&
               lhs.certIndex == rhs.certIndex
    }

    // MARK: - CustomStringConvertible

    var description: String {
        return "PointerAddress(\(slot), \(txIndex), \(certIndex))"
    }
}
