import Foundation
@preconcurrency import PotentCBOR
import CryptoSwift
import OrderedCollections
import SwiftBase58

// MARK: - ByronAddressType

/// The sub-type of a Byron era address.
public enum ByronAddressType: Int, Sendable, CaseIterable {
    /// Standard public key address.
    case pubKey = 0
    /// Script address.
    case script = 1
    /// Redemption address (used during the ADA voucher redemption period).
    case redeem = 2
}

extension ByronAddressType: CustomStringConvertible {
    public var description: String {
        switch self {
        case .pubKey: return "pubKey"
        case .script: return "script"
        case .redeem: return "redeem"
        }
    }
}

// MARK: - ByronAddressAttributes

/// Optional metadata embedded in a Byron address.
///
/// Corresponds to the `HD_address_attributes` map in CIP-0019.
public struct ByronAddressAttributes: Equatable, Sendable {
    /// Encrypted HD derivation path (attribute key 1).
    /// Stored as opaque bytes; decryption requires the root key.
    public let derivationPath: Data?

    /// Protocol magic number (attribute key 2).
    /// Present for testnet addresses; absent for mainnet.
    public let protocolMagic: UInt32?

    public init(derivationPath: Data? = nil, protocolMagic: UInt32? = nil) {
        self.derivationPath = derivationPath
        self.protocolMagic = protocolMagic
    }
}

// MARK: - ByronAddress

/// A Cardano Byron era address.
///
/// Byron addresses have the following structure, per [CIP-0019](https://github.com/cardano-foundation/CIPs/tree/master/CIP-0019):
///
/// - **On-chain / `toBytes()`**: raw CBOR encoding of `[payload_bytes, crc32_uint]`
/// - **Human-readable / `toBase58()`**: Base58 encoding of the on-chain bytes
/// - **payload_bytes**: CBOR encoding of `[root_28bytes, attributes_map, address_type_int]`
///
/// Network is inferred from attributes: mainnet if `protocolMagic` is absent, testnet if present.
public struct ByronAddress: CBORSerializable, CustomStringConvertible, Equatable, Hashable, Sendable {

    // MARK: Public Properties

    /// 28-byte Blake2b-224 root key hash.
    public let root: Data

    /// Byron address attributes (HD derivation path, protocol magic).
    public let attributes: ByronAddressAttributes

    /// Byron address sub-type (pubKey, script, or redeem).
    public let byronType: ByronAddressType

    /// Network inferred from `attributes.protocolMagic`.
    /// Mainnet if nil, testnet if present.
    public var network: NetworkId {
        attributes.protocolMagic != nil ? .testnet : .mainnet
    }

    // MARK: Private Storage

    /// Pre-computed raw CBOR bytes — returned by `toBytes()` without re-encoding.
    private let _rawBytes: Data

    // MARK: - Designated Initialiser (Private)

    private init(
        root: Data,
        attributes: ByronAddressAttributes,
        byronType: ByronAddressType,
        rawBytes: Data
    ) {
        self.root = root
        self.attributes = attributes
        self.byronType = byronType
        self._rawBytes = rawBytes
    }

    // MARK: - CBORSerializable

    /// Initialise a `ByronAddress` from a `Primitive`.
    ///
    /// Accepted forms:
    /// - `.string(base58String)` — Base58-encoded Byron address (human-readable form).
    /// - `.bytes(cborData)` — Raw CBOR bytes as stored on-chain.
    ///
    /// - Throws: `CardanoCoreError.decodingError` if Base58 decoding fails.
    /// - Throws: `CardanoCoreError.deserializeError` if the CBOR structure is invalid.
    /// - Throws: `CardanoCoreError.deserializeError` if the CRC32 checksum does not match.
    public init(from primitive: Primitive) throws {
        let rawBytes: Data

        switch primitive {
        case .string(let base58String):
            guard let decoded = Base58.base58Decode(base58String), !decoded.isEmpty else {
                throw CardanoCoreError.decodingError(
                    "Failed to Base58-decode Byron address: \(base58String)"
                )
            }
            rawBytes = Data(decoded)
        case .bytes(let data):
            rawBytes = data
        default:
            throw CardanoCoreError.valueError(
                "Byron address must be initialised from .bytes (CBOR) or .string (Base58)"
            )
        }

        // ── Outer CBOR: [payload_bytes, crc32_uint] ──────────────────────────────
        let outerCBOR: CBOR
        do {
            outerCBOR = try CBORDecoder().decode(CBOR.self, from: rawBytes)
        } catch {
            throw CardanoCoreError.deserializeError(
                "Could not CBOR-decode Byron address: \(error)"
            )
        }

        guard case .array(let outer) = outerCBOR, outer.count == 2 else {
            throw CardanoCoreError.deserializeError(
                "Byron address outer CBOR must be a 2-element array [payload, crc32]"
            )
        }

        // outer[0] is either a plain byteString (synthetic) or tag(24, byteString)
        // CIP-0019 on-chain addresses use CBOR tag 24 ("encoded CBOR data item").
        let payloadBytes: Data
        switch outer[0] {
        case .byteString(let bytes):
            payloadBytes = bytes
        case .tagged(_, let inner):
            guard case .byteString(let bytes) = inner else {
                throw CardanoCoreError.deserializeError(
                    "Byron address outer[0] tagged value must contain a byte string (payload)"
                )
            }
            payloadBytes = bytes
        default:
            throw CardanoCoreError.deserializeError(
                "Byron address outer[0] must be a byte string or tagged byte string (payload)"
            )
        }

        guard case .unsignedInt(let storedCRC) = outer[1] else {
            throw CardanoCoreError.deserializeError(
                "Byron address outer[1] must be an unsigned integer (CRC32)"
            )
        }

        // ── CRC32 verification ────────────────────────────────────────────────────
        let computedCRC = Checksum.crc32(Array(payloadBytes))
        guard computedCRC == UInt32(storedCRC) else {
            throw CardanoCoreError.deserializeError(
                "Byron address CRC32 mismatch: stored \(storedCRC), computed \(computedCRC)"
            )
        }

        // ── Inner CBOR: [root_bytes, attributes_map, address_type_uint] ──────────
        let innerCBOR: CBOR
        do {
            innerCBOR = try CBORDecoder().decode(CBOR.self, from: payloadBytes)
        } catch {
            throw CardanoCoreError.deserializeError(
                "Could not CBOR-decode Byron address payload: \(error)"
            )
        }

        guard case .array(let inner) = innerCBOR, inner.count == 3 else {
            throw CardanoCoreError.deserializeError(
                "Byron address payload must be a 3-element array [root, attributes, type]"
            )
        }

        // Root key hash — exactly 28 bytes
        guard case .byteString(let rootData) = inner[0], rootData.count == 28 else {
            throw CardanoCoreError.deserializeError(
                "Byron address root must be exactly 28 bytes"
            )
        }

        // Attributes map — both keys are optional per the CDDL
        var derivationPath: Data? = nil
        var protocolMagic: UInt32? = nil

        let attrElements: [(key: CBOR, value: CBOR)]
        switch inner[1] {
        case .map(let m):          attrElements = m.elements.map { ($0.key, $0.value) }
        case .indefiniteMap(let m): attrElements = m.elements.map { ($0.key, $0.value) }
        default:                   attrElements = []
        }

        for (key, value) in attrElements {
            guard case .unsignedInt(let k) = key,
                  case .byteString(let v) = value else { continue }
            switch k {
            case 1:
                // Derivation path — stored as opaque bytes (CBOR-encoded HD root)
                derivationPath = v
            case 2:
                // Protocol magic — stored as bytes containing a CBOR-encoded uint
                if let magicCBOR = try? CBORDecoder().decode(CBOR.self, from: v),
                   case .unsignedInt(let magic) = magicCBOR {
                    protocolMagic = UInt32(magic)
                }
            default:
                // Unknown attributes are silently ignored per CIP-0019
                break
            }
        }

        // Address sub-type
        guard case .unsignedInt(let typeInt) = inner[2],
              let byronType = ByronAddressType(rawValue: Int(typeInt)) else {
            throw CardanoCoreError.deserializeError(
                "Byron address type must be 0 (pubKey), 1 (script), or 2 (redeem)"
            )
        }

        self.init(
            root: rootData,
            attributes: ByronAddressAttributes(
                derivationPath: derivationPath,
                protocolMagic: protocolMagic
            ),
            byronType: byronType,
            rawBytes: rawBytes
        )
    }

    public func toPrimitive() -> Primitive {
        .bytes(toBytes())
    }

    // Override Codable to decode/encode as raw bytes, matching the Address pattern.
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let data = try container.decode(Data.self)
        try self.init(from: .bytes(data))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(toBytes())
    }

    // MARK: - Serialisation

    /// Raw CBOR bytes as stored on-chain: `CBOR([payload_bytes, crc32_uint])`.
    public func toBytes() -> Data {
        _rawBytes
    }

    /// Base58 representation of the on-chain bytes (human-readable form).
    public func toBase58() -> String {
        Base58.base58Encode(Array(_rawBytes))
    }

    /// Convenience factory: parse a Base58-encoded Byron address string.
    public static func fromBase58(_ string: String) throws -> ByronAddress {
        try ByronAddress(from: .string(string))
    }

    // MARK: - Construction (provisions for future full support)

    /// Create a `ByronAddress` from its decoded components.
    ///
    /// This encodes the components into valid CBOR and computes the CRC32 checksum,
    /// producing a fully round-trippable address. It is intended for testing and
    /// lightweight address construction.
    ///
    /// > Note: Full Byron address construction from a signing key (deriving the root
    /// > hash from a key pair and encrypting the HD derivation path) is not yet
    /// > implemented. That requires key-derivation logic beyond the scope of this method.
    ///
    /// - Parameters:
    ///   - root: A 28-byte Blake2b-224 root key hash.
    ///   - attributes: Optional HD derivation path and/or protocol magic.
    ///   - byronType: Address sub-type (default: `.pubKey`).
    /// - Throws: `CardanoCoreError.invalidAddressInputError` if `root` is not 28 bytes.
    /// - Throws: Encoding errors if CBOR serialisation fails.
    public static func create(
        root: Data,
        attributes: ByronAddressAttributes = ByronAddressAttributes(),
        byronType: ByronAddressType = .pubKey
    ) throws -> ByronAddress {
        guard root.count == 28 else {
            throw CardanoCoreError.invalidAddressInputError(
                "Byron address root must be exactly 28 bytes, got \(root.count)"
            )
        }

        // Build the attributes CBOR map
        var attrEntries: [(key: CBOR, value: CBOR)] = []
        if let dp = attributes.derivationPath {
            attrEntries.append((.unsignedInt(1), .byteString(dp)))
        }
        if let pm = attributes.protocolMagic {
            // Protocol magic is stored as bytes containing a CBOR-encoded uint
            let pmBytes = try CBOREncoder().encode(CBOR.unsignedInt(UInt64(pm)))
            attrEntries.append((.unsignedInt(2), .byteString(pmBytes)))
        }
        let attrMap = CBOR.map(
            OrderedDictionary(uniqueKeysWithValues: attrEntries)
        )

        // Encode inner payload: [root, attributes, type]
        let innerCBOR = CBOR.array([
            .byteString(root),
            attrMap,
            .unsignedInt(UInt64(byronType.rawValue))
        ])
        let payloadBytes = try CBOREncoder().encode(innerCBOR)

        // Compute CRC32 of the payload
        let crc32 = Checksum.crc32(Array(payloadBytes))

        // Encode outer structure: [tag(24, payload_bytes), crc32]
        // Per CIP-0019 and the Cardano on-chain format, the payload is wrapped in
        // CBOR tag 24 ("encoded CBOR data item") before being placed in the array.
        let outerCBOR = CBOR.array([
            .tagged(.encodedCBORDataItem, .byteString(payloadBytes)),
            .unsignedInt(UInt64(crc32))
        ])
        let rawBytes = try CBOREncoder().encode(outerCBOR)

        return ByronAddress(
            root: root,
            attributes: attributes,
            byronType: byronType,
            rawBytes: rawBytes
        )
    }

    // MARK: - CustomStringConvertible

    public var description: String {
        toBase58()
    }

    // MARK: - Equatable

    public static func == (lhs: ByronAddress, rhs: ByronAddress) -> Bool {
        lhs._rawBytes == rhs._rawBytes
    }

    // MARK: - Hashable

    public func hash(into hasher: inout Hasher) {
        hasher.combine(_rawBytes)
    }
}
