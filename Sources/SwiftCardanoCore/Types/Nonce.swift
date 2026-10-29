import Foundation

/// The ledger's `Nonce`: the neutral nonce, or a nonce holding a 32-byte hash.
///
/// In CBOR it is `nonce = [0] / [1, bytes .size 32]` (the Shelley to Babbage
/// CDDL; `EncCBOR Nonce` in
/// `libs/cardano-ledger-core/src/Cardano/Ledger/BaseTypes.hs`). Protocol
/// parameter updates carry one as `extra_entropy` until Babbage.
public struct Nonce: CBORSerializable, CustomStringConvertible, Sendable {
    /// The size of a nonce's hash.
    public static let hashSize = 32

    /// The nonce's hash, or `nil` for the neutral nonce.
    public let hash: Data?

    /// `NeutralNonce`.
    public static let neutral = Nonce(unchecked: nil)

    /// Whether this is the neutral nonce.
    public var isNeutral: Bool { hash == nil }

    /// A nonce holding `hash`.
    ///
    /// - Throws: Unless `hash` is 32 bytes.
    public init(hash: Data) throws {
        guard hash.count == Self.hashSize else {
            throw CardanoCoreError.valueError(
                "A nonce hash must be \(Self.hashSize) bytes, got \(hash.count)")
        }
        self.hash = hash
    }

    private init(unchecked hash: Data?) {
        self.hash = hash
    }

    public var description: String {
        hash.map { "Nonce(\($0.toHex))" } ?? "NeutralNonce"
    }

    // MARK: - CBOR

    /// Reads `[0]` or `[1, hash32]`, with a definite or an indefinite length,
    /// as the ledger does (`decodeRecordSum`).
    public init(from primitive: Primitive) throws {
        let elements: [Primitive]
        switch primitive {
        case .list(let list): elements = list
        case .indefiniteList(let list): elements = list.getAll()
        default:
            throw CardanoCoreError.deserializeError("Nonce: expected an array, got \(primitive)")
        }
        guard let first = elements.first else {
            throw CardanoCoreError.deserializeError("Nonce: empty array")
        }
        switch try first.integer("Nonce tag", as: UInt64.self) {
        case 0:
            guard elements.count == 1 else {
                throw CardanoCoreError.deserializeError(
                    "Nonce: NeutralNonce is [0], got \(elements.count) elements")
            }
            self = .neutral
        case 1:
            guard elements.count == 2 else {
                throw CardanoCoreError.deserializeError(
                    "Nonce: a nonce is [1, hash], got \(elements.count) elements")
            }
            let hash: Data
            switch elements[1] {
            case .bytes(let bytes): hash = bytes
            case .byteArray(let bytes): hash = Data(bytes)
            case .byteString(let bytes): hash = bytes.bytes
            default:
                throw CardanoCoreError.deserializeError("Nonce: the hash must be bytes, got \(elements[1])")
            }
            do {
                try self.init(hash: hash)
            } catch {
                throw CardanoCoreError.deserializeError(
                    "Nonce: the hash must be \(Self.hashSize) bytes, got \(hash.count)")
            }
        case let tag:
            throw CardanoCoreError.deserializeError("Nonce: unknown tag \(tag)")
        }
    }

    public func toPrimitive() throws -> Primitive {
        guard let hash else { return .list([.uint(0)]) }
        return .list([.uint(1), .bytes(hash)])
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey { case tag, contents }

    /// CBOR as ``toPrimitive()`` writes it. JSON as Shelley genesis files
    /// write it, `{"tag": "NeutralNonce"}` or `{"tag": "Nonce", "contents":
    /// hex}`; the ledger's current `null` or bare hex string is read too.
    public init(from decoder: Decoder) throws {
        guard String(describing: type(of: decoder)).contains("JSONDecoder") else {
            let primitive = try Primitive.decode(from: decoder, preservingEncoding: false)
            try self.init(from: primitive)
            return
        }
        if let single = try? decoder.singleValueContainer() {
            if single.decodeNil() {
                self = .neutral
                return
            }
            if let hex = try? single.decode(String.self) {
                self = try Self.fromHex(hex)
                return
            }
        }
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(String.self, forKey: .tag) {
        case "NeutralNonce":
            self = .neutral
        case "Nonce":
            self = try Self.fromHex(try c.decode(String.self, forKey: .contents))
        case let tag:
            throw CardanoCoreError.deserializeError("Nonce: unknown tag \(tag)")
        }
    }

    public func encode(to encoder: Encoder) throws {
        guard String(describing: type(of: encoder)).contains("JSONEncoder") else {
            var container = encoder.singleValueContainer()
            try container.encode(try toPrimitive())
            return
        }
        var c = encoder.container(keyedBy: CodingKeys.self)
        if let hash {
            try c.encode("Nonce", forKey: .tag)
            try c.encode(hash.toHex, forKey: .contents)
        } else {
            try c.encode("NeutralNonce", forKey: .tag)
        }
    }

    private static func fromHex(_ hex: String) throws -> Nonce {
        guard hex.count == 2 * hashSize, let bytes = Data(hexString: hex), bytes.count == hashSize else {
            throw CardanoCoreError.deserializeError("Nonce: \(hex) is not a 32-byte hex hash")
        }
        return try Nonce(hash: bytes)
    }
}
