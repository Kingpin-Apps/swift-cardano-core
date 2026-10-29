import Foundation
import OrderedCollections

// Shared reading and writing of certificate fields.
//
// Every certificate is a CBOR array whose first element is its code, a `uint`
// (CBOR major type 0, which decodes as `.uint`). The ledger reads the array
// with either a definite or an indefinite length.

extension CertificateSerializable {
    /// The fields of `primitive` after its code: the elements of the
    /// certificate array, checked to hold `count` elements in all and to
    /// start with this certificate's code.
    ///
    /// - Throws: When `primitive` is not an array, holds a different number of
    ///   elements, or starts with another code.
    static func certificateFields(_ primitive: Primitive, count: Int) throws -> [Primitive] {
        let elements: [Primitive]
        switch primitive {
        case .list(let list): elements = list
        case .indefiniteList(let list): elements = list.map { $0 }
        default:
            throw CardanoCoreError.deserializeError("\(Self.self): expected an array, got \(primitive)")
        }
        guard elements.count == count else {
            throw CardanoCoreError.deserializeError(
                "\(Self.self): expected \(count) elements, got \(elements.count)")
        }
        let code = try elements[0].integer("\(Self.self) code", as: UInt64.self)
        guard code == UInt64(Self.CODE.rawValue) else {
            throw CardanoCoreError.deserializeError(
                "\(Self.self): expected code \(Self.CODE.rawValue), got \(code)")
        }
        return Array(elements.dropFirst())
    }

    /// The code of this certificate, as it starts the certificate array.
    static var codePrimitive: Primitive { .uint(UInt64(Self.CODE.rawValue)) }

    /// The CBOR of this certificate, for `_payload`.
    ///
    /// The memberwise inits build their payload with this, so a field that
    /// fails to encode throws from the init rather than trapping.
    func encodedPayload() throws -> Data {
        try toCBORData()
    }
}

/// `anchor / nil`: `nil` for CBOR null, an anchor otherwise.
///
/// - Throws: When the value is neither null nor a valid anchor. A malformed
///   anchor is not read as "no anchor".
func optionalAnchor(_ primitive: Primitive) throws -> Anchor? {
    if case .null = primitive { return nil }
    return try checkedAnchor(primitive)
}

/// `anchor = [anchor_url : url, anchor_data_hash : hash32]`, with the hash
/// checked to be 32 bytes.
func checkedAnchor(_ primitive: Primitive) throws -> Anchor {
    return try checked(try Anchor(from: primitive))
}

/// `anchor` when its data hash is the 32 bytes a `hash32` is.
private func checked(_ anchor: Anchor) throws -> Anchor {
    guard anchor.anchorDataHash.payload.count == ANCHOR_DATA_HASH_SIZE else {
        throw CardanoCoreError.deserializeError(
            "Anchor data hash must be \(ANCHOR_DATA_HASH_SIZE) bytes, got \(anchor.anchorDataHash.payload.count)")
    }
    return anchor
}

/// An anchor's dict form, or `null` when there is none.
func optionalAnchorDict(_ anchor: Anchor?) throws -> Primitive {
    guard let anchor else { return .null }
    return try anchor.toDict()
}

/// The anchor in a certificate dict: absent and `null` both read as none.
func optionalAnchor(fromDict primitive: Primitive?) throws -> Anchor? {
    guard let primitive else { return nil }
    if case .null = primitive { return nil }
    return try checked(try Anchor.fromDict(primitive))
}

/// The value of `key` in a certificate dict.
func dictField(
    _ dict: Primitive, _ key: String, in type: String
) throws -> Primitive {
    guard case let .orderedDict(entries) = dict else {
        throw CardanoCoreError.deserializeError("\(type): expected a dict, got \(dict)")
    }
    guard let value = entries[.string(key)] else {
        throw CardanoCoreError.deserializeError("\(type): missing \(key)")
    }
    return value
}

/// The string value of `key` in a certificate dict.
func dictString(_ dict: Primitive, _ key: String, in type: String) throws -> String {
    guard case let .string(value) = try dictField(dict, key, in: type) else {
        throw CardanoCoreError.deserializeError("\(type): \(key) must be a string")
    }
    return value
}

extension StakeCredential {
    /// The dict form of a stake credential, which keeps whether it is a key
    /// hash or a script hash: `{"keyHash": hex}` or `{"scriptHash": hex}`, as
    /// the ledger writes a credential in JSON.
    func certificateDict() -> Primitive {
        switch credential {
        case .verificationKeyHash(let hash):
            return .orderedDict([.string("keyHash"): .string(hash.payload.toHex)])
        case .scriptHash(let hash):
            return .orderedDict([.string("scriptHash"): .string(hash.payload.toHex)])
        }
    }

    /// Reads ``certificateDict()``'s form.
    ///
    /// - Throws: When the dict does not hold exactly one of `keyHash` and
    ///   `scriptHash`, or the hash is not 28 bytes of hex.
    static func fromCertificateDict(_ primitive: Primitive) throws -> StakeCredential {
        guard case let .orderedDict(entries) = primitive, entries.count == 1,
              let (key, value) = entries.elements.first,
              case let .string(name) = key,
              case let .string(hex) = value,
              let payload = Data(hexString: hex) else {
            throw CardanoCoreError.deserializeError(
                "StakeCredential: expected {\"keyHash\": hex} or {\"scriptHash\": hex}, got \(primitive)")
        }
        switch name {
        case "keyHash":
            return StakeCredential(credential: .verificationKeyHash(try VerificationKeyHash.checked(payload)))
        case "scriptHash":
            return StakeCredential(credential: .scriptHash(try ScriptHash.checked(payload)))
        default:
            throw CardanoCoreError.deserializeError("StakeCredential: unknown credential kind \(name)")
        }
    }
}
