import Foundation
import CryptoKit
import SwiftNcal

class SigningKey: Key {
    func sign(data: Data) throws -> Data {
        let signingKey = try SwiftNcal.SigningKey(seed: payload)
        let signedMessage = try signingKey.sign(message: data)
        return signedMessage.getSignature
    }
    
    
    func toVerificationKey<T>() throws -> T where T: VerificationKey {
        let signingKey = try SwiftNcal.SigningKey(seed: payload)
        return T(
            payload: signingKey.verifyKey.bytes,
            type: type.replacingOccurrences(of: "Signing", with: "Verification"),
            description: description.replacingOccurrences(of: "Signing", with: "Verification")
        )
    }

    
    static func generate() throws -> Self {
        let signingKey = try SwiftNcal.SigningKey.generate()
        return Self(payload: signingKey.bytes)
    }
}

class ExtendedSigningKey: Key {
    func sign(data: Data) throws -> Data {
        guard payload.count >= 160 else {
            throw CardanoCoreError.valueError("Invalid payload size for ExtendedSigningKey. Expected size >= 160, but got \(payload.count).")
        }
        
        let privateKey = try BIP32ED25519PrivateKey(
            privateKey: payload.prefix(64),  // First 64 bytes
            chainCode: payload.suffix(from: 96)  // From byte 96 onwards
        )
        
        let signedMessage = try privateKey.sign(message: data)
        return signedMessage
    }

    func toVerificationKey() -> ExtendedVerificationKey {
        return ExtendedVerificationKey(
            payload: payload[64...95],  // Bytes 64 to 95
            type: type.replacingOccurrences(of: "Signing", with: "Verification"),
            description: description.replacingOccurrences(of: "Signing", with: "Verification")
        )
    }

    static func fromHDWallet(_ hdwallet: HDWallet) throws -> ExtendedSigningKey {
        let payload = hdwallet.xPrivateKey + hdwallet.publicKey + hdwallet.chainCode
        
        return Self(
            payload: payload,
            type: "PaymentExtendedSigningKeyShelley_ed25519_bip32",
            description: "Payment Signing Key"
        )
    }
}
