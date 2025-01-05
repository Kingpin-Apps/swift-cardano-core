import Foundation
import CryptoKit
import SwiftNcal

// MARK: - Key Protocol
/// A class that holds a cryptographic key and some metadata. e.g. signing key, verification key.
protocol Key: CBORSerializable {
    
    static var KEY_TYPE: String { get }
    static var DESCRIPTION: String { get }
    
    var payload: Data { get set }
    var keyType: String { get set }
    var description: String { get set }
    
    func toPrimitive() -> Data
    static func fromPrimitive(_ value: Data) -> Self
    func toJSON() -> String?
    static func fromJSON(_ json: String, validateType: Bool) throws -> Self
    func save(to path: String) throws
    static func load(from path: String) throws -> Self
}

extension Key {
    static var KEY_TYPE: String { "" }
    static var DESCRIPTION: String { "" }
    
    init(payload: Data, keyType: String? = nil, description: String? = nil) {
        self.payload = payload
        self.keyType = keyType ?? Self.KEY_TYPE
        self.description = description ?? Self.DESCRIPTION
    }
    
    func toPrimitive() -> Data {
        return payload
    }
    
    static func fromPrimitive(_ value: Data) -> Self {
        return Self(payload: value)
    }
    
    /// Serialize the key to JSON.
    ///
    /// The json output has three fields: "type", "description", and "cborHex".
    /// - Returns: JSON representation of the key.
    func toJSON() throws -> String? {
        let dict: [String: String] = [
            "type": keyType,
            "description": description,
            "cborHex": try toCBORHex()!
        ]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: dict) else {
            return nil
        }
        return String(data: jsonData, encoding: .utf8)
    }
    
    /// Restore a key from a JSON string.
    /// - Parameters:
    ///   - json: JSON string.
    ///   - validateType:  Checks whether the type specified in json object is the same as the class's default type.
    /// - Returns: The key restored from JSON.
    static func fromJSON(_ json: String, validateType: Bool = false) throws -> Self {
        guard let data = json.data(using: .utf8),
              let dict = try JSONSerialization.jsonObject(with: data) as? [String: String],
              let cborHex = dict["cborHex"],
              let cborData = Data(hex: cborHex) else {
            throw CardanoException.valueError("Invalid JSON")
        }
        
        if validateType, dict["type"] != KEY_TYPE {
            throw CardanoException.invalidKeyTypeException("Expect key type: \(KEY_TYPE), but got \(dict["type"] ?? "")")
        }
        
        let k = try Self.fromCBOR(cborData)
        
        return Self(
            payload: k!.payload,
            keyType: dict["type"] ?? "",
            description: dict["description"] ?? ""
        )
    }
    
    func save(to path: String) throws {
        if FileManager.default.fileExists(atPath: path) {
            throw CardanoException.ioError("File already exists: \(path)")
        }
        
        if let jsonString = toJSON() {
            try jsonString.write(toFile: path, atomically: true, encoding: .utf8)
        }
    }
    
    static func load(from path: String) throws -> Self {
        let jsonString = try String(contentsOfFile: path)
        return try fromJSON(jsonString)
    }
    
    func toCBOR() -> Data {
        return payload
    }
    
    // Convert to raw bytes
    func toBytes() -> Data {
        return payload
    }
    
    // Equality check
    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.payload == rhs.payload &&
               lhs.description == rhs.description &&
               lhs.keyType == rhs.keyType
    }
    
    // String representation (equivalent to __repr__)
    func description() -> String {
        return toJSON() ?? "Invalid JSON representation"
    }
    
    // Hash function
    func hash(into hasher: inout Hasher) {
        hasher.combine(payload)
    }
}

// MARK: - SigningKey
protocol SigningKey: Key {
    func sign(data: Data) -> Data
    func toVerificationKey() -> VerificationKey
    static func generate() -> SigningKey
}

extension SigningKey {    
    func sign(data: Data) throws -> Data {
        let privateKey = try SwiftNcal.SigningKey(seed: payload)
        let signedMessage = try privateKey.sign(message: data)
        return signedMessage.getSignature
    }
    
    func toVerificationKey() -> VerificationKey {
        let publicKey = Curve25519.Signing.PrivateKey(rawRepresentation: payload).publicKey
        return VerificationKey(payload: publicKey.rawRepresentation,
                               keyType: keyType.replacingOccurrences(of: "Signing", with: "Verification"),
                               description: description.replacingOccurrences(of: "Signing", with: "Verification"))
    }
    
    static func generate() -> SigningKey {
        let privateKey = Curve25519.Signing.PrivateKey()
        return SigningKey(payload: privateKey.rawRepresentation)
    }
}

// MARK: - VerificationKey
struct VerificationKey: Key {
    var payload: Data
    var keyType: String
    var description: String
    
    static let KEY_TYPE = "VerificationKey"
    static let DESCRIPTION = "Verification Key"
    
    init(payload: Data, keyType: String = VerificationKey.KEY_TYPE, description: String = VerificationKey.DESCRIPTION) {
        self.payload = payload
        self.keyType = keyType
        self.description = description
    }
    
    func hash() -> VerificationKeyHash {
        return VerificationKeyHash(payload: SHA256.hash(data: payload).prefix(28))
    }
}

// MARK: - Extended Keys
struct ExtendedSigningKey: SigningKey {
    func toExtendedVerificationKey() -> ExtendedVerificationKey {
        return ExtendedVerificationKey(payload: payload.suffix(32))
    }
}

struct ExtendedVerificationKey: VerificationKey {}

struct PaymentSigningKey: SigningKey {
    var payload: Data

    var keyType: String

    var description: String
}

// MARK: - KeyPair
struct KeyPair {
    let signingKey: SigningKey
    let verificationKey: VerificationKey
    
    static func generate() -> KeyPair {
        let signingKey = SigningKey.generate()
        return KeyPair(signingKey: signingKey,
                       verificationKey: signingKey.toVerificationKey())
    }
}

// MARK: - Utility Extensions
extension Data {
    func toHex() -> String {
        map { String(format: "%02x", $0) }.joined()
    }
    
    init?(hex: String) {
        let bytes = stride(from: 0, to: hex.count, by: 2).map {
            hex.index(hex.startIndex, offsetBy: $0)..<hex.index(hex.startIndex, offsetBy: $0 + 2)
        }.compactMap { UInt8(hex[$0], radix: 16) }
        self.init(bytes)
    }
}
