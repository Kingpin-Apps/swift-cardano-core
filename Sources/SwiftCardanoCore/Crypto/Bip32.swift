//
//  Created by Hareem Adderley on 01/07/2024 AT 4:14 PM
//  Copyright © 2024 Kingpin Apps. All rights reserved.
//

import Clibsodium
import CryptoSwift
import Foundation
import SwiftNcal
import Bip39
import CryptoKit
import BigInt
import SwiftMnemonic

let SUPPORTED_MNEMONIC_LANGS = [
    "english",
    "french",
    "italian",
    "japanese",
    "chinese_simplified",
    "chinese_traditional",
    "korean",
    "spanish",
]

enum BIP32Error: Error, Equatable {
    case invalidMnemonic(String)
    case invalidEntropy(String)
    case invalidPath(String)
    case derivationFailed(String)
}

class BIP32ED25519PrivateKey {
    var privateKey: Data
    var chainCode: Data
    var publicKey: Data
    var left: Data
    var right: Data

    private let sodium = Sodium()

    init(privateKey: Data, chainCode: Data) throws {
        self.privateKey = privateKey
        self.chainCode = chainCode
        self.left = privateKey.prefix(32)
        self.right = privateKey.suffix(32)
        self.publicKey = try sodium.cryptoScalarmult.ed25519BaseNoclamp(n: self.left)
    }

    func sign(message: Data) throws -> Data {
        let hash = Hash()

        let r = try sodium.cryptoCore.ed25519ScalarReduce(
            hash.sha512(message: self.right + message)
        )

        let R = try sodium.cryptoScalarmult.ed25519BaseNoclamp(n: r)

        let hram = try sodium.cryptoCore.ed25519ScalarReduce(
            hash.sha512(message: R + self.publicKey + message)
        )

        let S = try sodium.cryptoCore.ed25519ScalarAdd(
            try sodium.cryptoCore.ed25519ScalarMul(hram, self.left),
            r
        )

        return R + S
    }
}

class BIP32ED25519PublicKey {
    var publicKey: Data
    var chainCode: Data

    private let sodium = Sodium()

    init(publicKey: Data, chainCode: Data) {
        self.publicKey = publicKey
        self.chainCode = chainCode
    }

    static func fromPrivateKey(privateKey: BIP32ED25519PrivateKey) -> BIP32ED25519PublicKey {
        return BIP32ED25519PublicKey(
            publicKey: privateKey.publicKey, chainCode: privateKey.chainCode)
    }

    func verify(signature: Data, message: Data) throws -> Data {
        return try sodium.cryptoSign
            .open(signed: signature + message, pk: self.publicKey)
    }
}

func Fk(message: Data, secret: Data) throws -> Data {
    return try Data(
        HMAC(
            key: secret.bytes,
            variant: .sha2(.sha512)
        ).authenticate(message.bytes)
    )
}

class HDWallet {
    var rootXPrivateKey: Data
    var rootPublicKey: Data
    var rootChainCode: Data
    var xPrivateKey: Data
    var publicKey: Data
    var chainCode: Data
    var path: String
    var seed: Data?
    var mnemonic: String?
    var passphrase: String?
    var entropy: String?
    
    private let sodium = Sodium()

    init(
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

    static func fromSeed(
        seed: String, entropy: String? = nil, passphrase: String? = nil, mnemonic: String? = nil
    ) throws -> HDWallet {
        let seedData = Data(hex: seed)
        let seedModified = tweakBits(seed: seedData)

        let kL = seedModified.prefix(32)
        let c = seedModified.suffix(32)
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

    static func fromMnemonic(mnemonic: String, passphrase: String = "") throws -> HDWallet {
        guard try isMnemonic(mnemonic: mnemonic) else {
            throw CardanoException.invalidDataException("Invalid mnemonic words.")
        }

        let _mnemonic = try! Mnemonic(mnemonic: mnemonic.components(separatedBy: " "))
        let entropy = Data(_mnemonic.entropy)
        let seed = HDWallet.generateSeed(passphrase: passphrase, entropy: entropy)

        return try HDWallet.fromSeed(
            seed: seed.hexEncodedString(),
            entropy: entropy.hexEncodedString(),
            passphrase: passphrase,
            mnemonic: mnemonic
        )
    }

    static func fromEntropy(entropy: String, passphrase: String = "") throws -> HDWallet {
        guard isEntropy(entropy: entropy) else {
            throw CardanoException.invalidDataException("Invalid entropy")
        }

        let seed = generateSeed(passphrase: passphrase, entropy: Data(hex: entropy))
        return try fromSeed(seed: seed.hexEncodedString(), entropy: entropy)
    }

    static func generateSeed(passphrase: String, entropy: Data) -> Data {
        return Data(try! PKCS5.PBKDF2(
            password: Array(passphrase.utf8),
            salt: entropy.bytes,
            iterations: 4096,
            keyLength: 96,
            variant: .sha2(.sha512)
        ).calculate())
    }

    static func tweakBits(seed: Data) -> Data {
        var seedArray = seed.bytes
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

    func derive(fromPath path: String, isPrivate: Bool = true) throws -> HDWallet {
        guard path.hasPrefix("m/") else {
            throw BIP32Error.invalidPath(
                "Bad path, please insert like this type of path \"m/0\'/0\"!")
        }

        var derivedWallet = self.copyHDWallet()
        for index in path.dropFirst(2).split(separator: "/") {
            if index.last == "'" {
                let idx = Int(index.dropLast())! + (1 << 31)
                derivedWallet = try derivedWallet.derive(
                    index: idx, isPrivate: isPrivate, hardened: true)
            } else {
                let idx = Int(index)!
                derivedWallet = try derivedWallet.derive(
                    index: idx, isPrivate: isPrivate, hardened: false)
            }
        }

        return derivedWallet
    }

    func derive(index: Int, isPrivate: Bool = true, hardened: Bool = false) throws -> HDWallet {
        guard !self.rootXPrivateKey.isEmpty && !self.rootPublicKey.isEmpty else {
            throw CardanoException.invalidDataException("Missing root keys. Can't do derivation.")
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
    func derivePrivateChildKeyByIndex(privateNode: (Data, Data, Data, Data, String), index: Int) throws -> HDWallet {
        let (kLP, kRP, AP, cP, path) = privateNode
        assert(0 <= index && index < (1 << 32))

        let iBytes = withUnsafeBytes(of: index.littleEndian, Array.init)

        // compute Z, c
        let Z: Data
        let c: Data
        if index < (1 << 31) {
            // regular child
            Z = Data(try! HMAC(key: cP.bytes, variant: .sha2(.sha512)).authenticate(Data([0x02]) + AP + iBytes))
            c = Data(try! HMAC(key: cP.bytes, variant: .sha2(.sha512)).authenticate(Data([0x03]) + AP + iBytes).suffix(32))
        } else {
            // hardened child
            Z = Data(try! HMAC(key: cP.bytes, variant: .sha2(.sha512)).authenticate(Data([0x00]) + kLP + kRP + iBytes))
            c = Data(try! HMAC(key: cP.bytes, variant: .sha2(.sha512)).authenticate(Data([0x01]) + kLP + kRP + iBytes).suffix(32))
        }

        let ZL = Z.prefix(28)
        let ZR = Z.suffix(32)

        // compute kL_i
        let kLn = (BigInt(Data(ZL)) * 8 + BigInt(Data(kLP))).modulus(BigInt(1 << 256))

        // compute kR_i
        let kRn = (BigInt(Data(ZR)) + BigInt(Data(kRP))).modulus(BigInt(1 << 256))

        let kL = kLn.serialize()
        let kR = kRn.serialize()

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

    func derivePublicChildKeyByIndex(publicNode: (Data, Data, String), index: Int) throws -> HDWallet {
        let (AP, cP, path) = publicNode
        let iBytes = withUnsafeBytes(of: index.littleEndian, Array.init)

        guard index < (1 << 31) else {
            throw CardanoException.invalidDataException("Cannot derive hardened index with public key")
        }

        let Z = Data(try! HMAC(key: cP.bytes, variant: .sha2(.sha512)).authenticate(Data([0x02]) + AP + iBytes))
        let c = Data(try! HMAC(key: cP.bytes, variant: .sha2(.sha512)).authenticate(Data([0x03]) + AP + iBytes).suffix(32))

        let ZL = Z.prefix(28)
        let ZLint = BigInt(Data(ZL))

        let A = try sodium.cryptoCore.ed25519Add(
            AP, try sodium.cryptoScalarmult
                .ed25519BaseNoclamp(n: (8 * ZLint).serialize()))

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

    static func generateMnemonic(language: Language = .english, wordCount: WordCount = .twentyFour) throws -> [String] {
        guard SUPPORTED_MNEMONIC_LANGS.contains(language.rawValue) else {
            throw CardanoException.invalidLanguage(
                "Invalid language, use only this options english, french, italian, spanish, chinese_simplified, chinese_traditional, japanese or korean languages."
            )
        }
        
        let mnemonic = try Mnemonic(language: .english)

        return try mnemonic.generate(wordCount: wordCount)
    }

    static func isMnemonic(mnemonic: String, language: Language = .english) throws -> Bool {
        guard SUPPORTED_MNEMONIC_LANGS.contains(language.rawValue) else {
            throw CardanoException.invalidLanguage(
                "Invalid language, use only this options english, french, italian, spanish, chinese_simplified, chinese_traditional, japanese or korean languages."
            )
        }
        
        return try Mnemonic(language: language).check(mnemonic: mnemonic)
    }

    static func isEntropy(entropy: String) -> Bool {
        let entropyData = Data(hex: entropy)
        return [16, 20, 24, 28, 32].contains(entropyData.count)
    }
}
