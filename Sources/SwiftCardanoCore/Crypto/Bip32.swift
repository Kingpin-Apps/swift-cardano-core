//
//  Created by Hareem Adderley on 01/07/2024 AT 4:14 PM
//  Copyright © 2024 Kingpin Apps. All rights reserved.
//

import Clibsodium
import CryptoSwift
import Foundation
import SwiftNcal
import BigInt
import SwiftMnemonic
#if canImport(CryptoKit)
import CryptoKit
#elseif canImport(Crypto)
import Crypto
#endif

public let SUPPORTED_MNEMONIC_LANGS = Language.allCases.filter { $0 != .unsupported }

public enum BIP32Error: Error, Equatable {
    case invalidMnemonic(String)
    case invalidEntropy(String)
    case invalidPath(String)
    case derivationFailed(String)
}

public class BIP32ED25519PrivateKey {
    var privateKey: Data
    var chainCode: Data
    var publicKey: Data
    var left: Data
    var right: Data

    private let sodium = Sodium()

    public init(privateKey: Data, chainCode: Data) throws {
        self.privateKey = privateKey
        self.chainCode = chainCode
        self.left = privateKey.prefix(32)
        self.right = privateKey.suffix(32)
        self.publicKey = try sodium.cryptoScalarmult.ed25519BaseNoclamp(n: self.left)
    }

    public func sign(message: Data) throws -> Data {
        let r = try sodium.cryptoCore.ed25519ScalarReduce(
            Data(SHA512.hash(data: self.right + message))
        )

        let R = try sodium.cryptoScalarmult.ed25519BaseNoclamp(n: r)

        let hram = try sodium.cryptoCore.ed25519ScalarReduce(
            Data(SHA512.hash(data: R + self.publicKey + message))
        )

        let S = try sodium.cryptoCore.ed25519ScalarAdd(
            try sodium.cryptoCore.ed25519ScalarMul(hram, self.left),
            r
        )

        return R + S
    }
}

public class BIP32ED25519PublicKey {
    public var publicKey: Data
    public var chainCode: Data

    private let sodium = Sodium()

    public init(publicKey: Data, chainCode: Data) {
        self.publicKey = publicKey
        self.chainCode = chainCode
    }

    public static func fromPrivateKey(privateKey: BIP32ED25519PrivateKey) -> BIP32ED25519PublicKey {
        return BIP32ED25519PublicKey(
            publicKey: privateKey.publicKey, chainCode: privateKey.chainCode)
    }

    public func verify(signature: Data, message: Data) throws -> Data {
        return try sodium.cryptoSign
            .open(signed: signature + message, pk: self.publicKey)
    }
}

public func Fk(message: Data, secret: Data) throws -> Data {
    return try Data(
        HMAC(
            key: secret.byteArray,
            variant: .sha2(.sha512)
        ).authenticate(message.byteArray)
    )
}

public class HDWallet {
    public var rootXPrivateKey: Data
    public var rootPublicKey: Data
    public var rootChainCode: Data
    public var xPrivateKey: Data
    public var publicKey: Data
    public var chainCode: Data
    public var path: String
    public var seed: Data?
    public var mnemonic: String?
    public var passphrase: String?
    public var entropy: String?
    
    private let sodium = Sodium()
    
    // Helper functions for little-endian byte conversion
    private func intFromBytesLittleEndian(_ data: Data) -> BigInt {
        var result = BigInt(0)
        var base = BigInt(1)
        for byte in data {
            result += BigInt(byte) * base
            base *= 256
        }
        return result
    }
    
    private func intToBytesLittleEndian(_ value: BigInt, length: Int) -> Data {
        var result = Data(count: length)
        var val = value
        // Handle the case where value might be negative or larger than what fits in length bytes
        for i in 0..<length {
            result[i] = UInt8(val % 256)
            val /= 256
            // If val becomes 0, we can break early
            if val == 0 { break }
        }
        return result
    }

    public init(
        rootXPrivateKey: Data, rootPublicKey: Data, rootChainCode: Data, xPrivateKey: Data,
        publicKey: Data, chainCode: Data, path: String, seed: Data?, mnemonic: String?,
        passphrase: String?, entropy: String?
    ) {
        self.rootXPrivateKey = rootXPrivateKey
        self.rootPublicKey = rootPublicKey
        self.rootChainCode = rootChainCode
        self.xPrivateKey = xPrivateKey
        self.publicKey = publicKey
        self.chainCode = chainCode
        self.path = path
        self.seed = seed
        self.mnemonic = mnemonic
        self.passphrase = passphrase
        self.entropy = entropy
    }

    public static func fromSeed(
        seed: String, entropy: String? = nil, passphrase: String? = nil, mnemonic: String? = nil
    ) throws -> HDWallet {
        let seedData = Data(hex: seed)
        let seedModified = tweakBits(seed: seedData)

        let kL = seedModified.prefix(32)
        let c = seedModified.suffix(from: 64)  // Changed from suffix(32)
        let A = try Sodium().cryptoScalarmult.ed25519BaseNoclamp(n: kL)

        return HDWallet(
            rootXPrivateKey: seedModified.prefix(64),
            rootPublicKey: A,
            rootChainCode: c,
            xPrivateKey: seedModified.prefix(64),
            publicKey: A,
            chainCode: c,
            path: "m",
            seed: seedModified,
            mnemonic: mnemonic,
            passphrase: passphrase,
            entropy: entropy
        )
    }

    public static func fromMnemonic(mnemonic: String, passphrase: String = "") throws -> HDWallet {
        guard try isMnemonic(mnemonic: mnemonic) else {
            throw CardanoCoreError.invalidDataError("Invalid mnemonic words.")
        }

        
        let normalizedMnemonic = mnemonic.decomposedStringWithCompatibilityMapping
        
        let _mnemonic = try Mnemonic(from: normalizedMnemonic.components(separatedBy: " "))
        let seed = HDWallet.generateSeed(passphrase: passphrase, entropy: _mnemonic.entropy)

        return try HDWallet.fromSeed(
            seed: seed.hexEncodedString(),
            entropy: _mnemonic.entropy.hexEncodedString(),
            passphrase: passphrase,
            mnemonic: normalizedMnemonic
        )
    }

    public static func fromEntropy(entropy: String, passphrase: String = "") throws -> HDWallet {
        guard isEntropy(entropy: entropy) else {
            throw CardanoCoreError.invalidDataError("Invalid entropy")
        }

        let seed = generateSeed(passphrase: passphrase, entropy: Data(hex: entropy))
        return try fromSeed(seed: seed.hexEncodedString(), entropy: entropy)
    }

    public static func generateSeed(passphrase: String, entropy: Data) -> Data {
        return Data(try! PKCS5.PBKDF2(
            password: Array(passphrase.utf8),
            salt: entropy.byteArray,
            iterations: 4096,
            keyLength: 96,
            variant: .sha2(.sha512)
        ).calculate())
    }

    public static func tweakBits(seed: Data) -> Data {
        var seedArray = seed.byteArray
        seedArray[0] &= 0b11111000
        seedArray[31] &= 0b00011111
        seedArray[31] |= 0b01000000
        return Data(seedArray)
    }

    /// Create a new instance of HDWallet
    public func copyHDWallet() -> HDWallet {
        return HDWallet(
            rootXPrivateKey: self.rootXPrivateKey,
            rootPublicKey: self.rootPublicKey,
            rootChainCode: self.rootChainCode,
            xPrivateKey: self.xPrivateKey,
            publicKey: self.publicKey,
            chainCode: self.chainCode,
            path: self.path,
            seed: self.seed,
            mnemonic: self.mnemonic,
            passphrase: self.passphrase,
            entropy: self.entropy
        )
    }

    public func derive(fromPath path: String, isPrivate: Bool = true) throws -> HDWallet {
        guard path.hasPrefix("m/") else {
            throw BIP32Error.invalidPath(
                "Bad path, please insert like this type of path \"m/0\'/0\"!")
        }
        
        // Validate path format more strictly
        let pathWithoutPrefix = String(path.dropFirst(2)) // Remove "m/"
        
        // Check for invalid patterns
        if pathWithoutPrefix.isEmpty {
            throw BIP32Error.invalidPath("Empty path after m/")
        }
        if pathWithoutPrefix.contains("//") {
            throw BIP32Error.invalidPath("Path contains double slashes")
        }
        if pathWithoutPrefix.hasSuffix("/") {
            throw BIP32Error.invalidPath("Path cannot end with /")
        }

        var derivedWallet = self.copyHDWallet()
        for index in pathWithoutPrefix.split(separator: "/") {
            if index.isEmpty {
                throw BIP32Error.invalidPath("Empty path segment")
            }
            
            if index.last == "'" {
                guard let idx = Int(index.dropLast()) else {
                    throw BIP32Error.invalidPath("Invalid hardened index: \(index)")
                }
                derivedWallet = try derivedWallet.derive(
                    index: idx, isPrivate: isPrivate, hardened: true)
            } else {
                guard let idx = Int(index) else {
                    throw BIP32Error.invalidPath("Invalid index: \(index)")
                }
                derivedWallet = try derivedWallet.derive(
                    index: idx, isPrivate: isPrivate, hardened: false)
            }
        }

        return derivedWallet
    }

    public func derive(index: Int, isPrivate: Bool = true, hardened: Bool = false) throws -> HDWallet {
        guard !self.rootXPrivateKey.isEmpty && !self.rootPublicKey.isEmpty else {
            throw CardanoCoreError.invalidDataError("Missing root keys. Can't do derivation.")
        }

        let index = hardened ? index + (1 << 31) : index

        if isPrivate {
            let privateNode = (
                self.xPrivateKey.prefix(32), self.xPrivateKey.suffix(32), self.publicKey,
                self.chainCode, self.path
            )
            return try derivePrivateChildKeyByIndex(privateNode: privateNode, index: index)
        } else {
            let publicNode = (self.publicKey, self.chainCode, self.path)
            return try derivePublicChildKeyByIndex(
                publicNode: publicNode,
                index: index
            )
        }
    }

    /**
     Derive private child keys from parent node.

     PROCESS:
       1. encode i 4-bytes little endian, il = encode_U32LE(i)
       2. if i is less than 2^31
            - compute Z   = HMAC-SHA512(key=c, Data=0x02 | A | il )
            - compute c_  = HMAC-SHA512(key=c, Data=0x03 | A | il )
          else
            - compute Z   = HMAC-SHA512(key=c, Data=0x00 | kL | kR | il )
            - compute c_  = HMAC-SHA512(key=c, Data=0x01 | kL | kR | il )
       3. ci = lowest_32bytes(c_)
       4. set ZL = highest_28bytes(Z)
          set ZR = lowest_32bytes(Z)
       5. compute kL_i:
             zl_  = LEBytes_to_int(ZL)
             kL_  = LEBytes_to_int(kL)
             kLi_ = zl_*8 + kL_
             if kLi_ % order == 0: child does not exist
             kL_i = int_to_LEBytes(kLi_)
       6. compute kR_i
             zr_  = LEBytes_to_int(ZR)
             kR_  = LEBytes_to_int(kR)
             kRi_ = (zr_ + kRn_) % 2^256
             kR_i = int_to_LEBytes(kRi_)
       7. compute A
             A = kLi_.G
       8. return ((kL_i,kR_i), A_i, c)

     Args:
         private_pnode: ((kLP,kRP), AP, cP). (kLP,kRP) is 64 bytes parent private eddsa key,
             AP is 32 bytes parent public key, cP is 32 bytes parent chain code.
         index: child index to compute (hardened if >= 0x80000000)

     Returns:
         HDWallet with child node derived.
     */
    public func derivePrivateChildKeyByIndex(privateNode: (Data, Data, Data, Data, String), index: Int) throws -> HDWallet {
        let (kLP, kRP, AP, cP, path) = privateNode
        assert(0 <= index && index < (1 << 32))

        let iBytes = Data(withUnsafeBytes(of: UInt32(index).littleEndian, Array.init))

        // compute Z, c
        let Z: Data
        let c: Data
        if index < (1 << 31) {
            // regular child
            Z = Data(try! HMAC(key: cP.byteArray, variant: .sha2(.sha512)).authenticate((Data([0x02]) + AP + iBytes).byteArray))
            c = Data(try! HMAC(key: cP.byteArray, variant: .sha2(.sha512)).authenticate((Data([0x03]) + AP + iBytes).byteArray).suffix(32))
        } else {
            // hardened child
            Z = Data(try! HMAC(key: cP.byteArray, variant: .sha2(.sha512)).authenticate((Data([0x00]) + kLP + kRP + iBytes).byteArray))
            c = Data(try! HMAC(key: cP.byteArray, variant: .sha2(.sha512)).authenticate((Data([0x01]) + kLP + kRP + iBytes).byteArray).suffix(32))
        }

        let ZL = Z.prefix(28)  // Python: Z[:28]
        let ZR = Z.suffix(from: 32)  // Python: Z[32:]

        
        // Compute kL_i
        let ZLint = intFromBytesLittleEndian(ZL)
        let kLPint = intFromBytesLittleEndian(kLP)
        let kLn = ZLint * 8 + kLPint
        
        // Compute kR_i - the modulo 2^256 is handled by limiting to 32 bytes
        let ZRint = intFromBytesLittleEndian(Data(ZR))
        let kRPint = intFromBytesLittleEndian(kRP)
        let kRn = (ZRint + kRPint) 
        
        let kL = intToBytesLittleEndian(kLn, length: 32)
        let kR = intToBytesLittleEndian(kRn, length: 32)

        // compute A
        let A = try sodium.cryptoScalarmult.ed25519BaseNoclamp(n: kL)

        // compute path
        let newPath = path + "/" + String(index)

        return HDWallet(
            rootXPrivateKey: self.rootXPrivateKey,
            rootPublicKey: self.rootPublicKey,
            rootChainCode: self.rootChainCode,
            xPrivateKey: kL + kR,
            publicKey: A,
            chainCode: c,
            path: newPath,
            seed: self.seed,
            mnemonic: self.mnemonic,
            passphrase: self.passphrase,
            entropy: self.entropy
        )
    }

    public func derivePublicChildKeyByIndex(publicNode: (Data, Data, String), index: Int) throws -> HDWallet {
        let (AP, cP, path) = publicNode
        let iBytes = Data(withUnsafeBytes(of: UInt32(index).littleEndian, Array.init))

        guard index < (1 << 31) else {
            throw CardanoCoreError.invalidDataError("Cannot derive hardened index with public key")
        }

        let Z = Data(try! HMAC(key: cP.byteArray, variant: .sha2(.sha512)).authenticate((Data([0x02]) + AP + iBytes).byteArray))
        let c = Data(try! HMAC(key: cP.byteArray, variant: .sha2(.sha512)).authenticate((Data([0x03]) + AP + iBytes).byteArray).suffix(32))

        let ZL = Z.prefix(28)  // Python: Z[:28]
        
        let ZLint = intFromBytesLittleEndian(ZL)
        
        let scaledZL = intToBytesLittleEndian(8 * ZLint, length: 32)

        let A = try sodium.cryptoCore.ed25519Add(
            AP, try sodium.cryptoScalarmult.ed25519BaseNoclamp(n: scaledZL))

        let newPath = path + "/" + String(index)

        return HDWallet(
            rootXPrivateKey: self.rootXPrivateKey,
            rootPublicKey: self.rootPublicKey,
            rootChainCode: self.rootChainCode,
            xPrivateKey: self.xPrivateKey,
            publicKey: A,
            chainCode: c,
            path: newPath,
            seed: self.seed,
            mnemonic: self.mnemonic,
            passphrase: self.passphrase,
            entropy: self.entropy
        )
    }

    public static func generateMnemonic(language: Language = .english, wordCount: WordCount = .twentyFour) throws -> [String] {
        guard SUPPORTED_MNEMONIC_LANGS.contains(language) else {
            throw CardanoCoreError.invalidLanguage(
                "Invalid language, use only the following languages: \(SUPPORTED_MNEMONIC_LANGS)"
            )
        }
        
        let mnemonic = try Mnemonic(language: language)

        return try mnemonic.generate(wordCount: wordCount)
    }

    public static func isMnemonic(mnemonic: String, language: Language = .english) throws -> Bool {
        guard SUPPORTED_MNEMONIC_LANGS.contains(language) else {
            throw CardanoCoreError.invalidLanguage(
                "Invalid language, use only the following languages: \(SUPPORTED_MNEMONIC_LANGS)"
            )
        }
        
        return try Mnemonic(language: language).check(mnemonic: mnemonic)
    }

    public static func isEntropy(entropy: String) -> Bool {
        let entropyData = Data(hex: entropy)
        return [16, 20, 24, 28, 32].contains(entropyData.count)
    }
}
