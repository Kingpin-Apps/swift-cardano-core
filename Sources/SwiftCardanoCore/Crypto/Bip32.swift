//
//  Created by Hareem Adderley on 01/07/2024 AT 4:14 PM
//  Copyright © 2024 Kingpin Apps. All rights reserved.
//

import Clibsodium
import CryptoSwift
import Foundation
import SwiftNaCl
import BigInt
import SwiftMnemonic
#if canImport(CryptoKit)
import CryptoKit
#elseif canImport(Crypto)
import Crypto
#endif

/// The BIP-39 wordlist languages that ``HDWallet/generateMnemonic(language:wordCount:)``
/// and ``HDWallet/isMnemonic(mnemonic:language:)`` accept.
public let SUPPORTED_MNEMONIC_LANGS = Language.allCases.filter { $0 != .unsupported }

/// An error from HD wallet path parsing or derivation.
public enum BIP32Error: Error, Equatable {
    /// The mnemonic phrase is not valid.
    case invalidMnemonic(String)
    /// The entropy is not valid.
    case invalidEntropy(String)
    /// The derivation path is not valid, for example because it does not start with `m/`.
    case invalidPath(String)
    /// A child key could not be derived.
    case derivationFailed(String)
}

/// A BIP32-Ed25519 extended private key: a 64-byte extended secret (`kL` then `kR`)
/// and a 32-byte chain code.
public class BIP32ED25519PrivateKey {
    var privateKey: Data
    var chainCode: Data
    var publicKey: Data
    var left: Data
    var right: Data

    private let sodium = Sodium()

    /// Creates the key and computes its public key from the first 32 bytes, without clamping.
    /// - Parameters:
    ///   - privateKey: The 64-byte extended private key.
    ///   - chainCode: The 32-byte chain code.
    /// - Throws: When the public key cannot be computed.
    public init(privateKey: Data, chainCode: Data) throws {
        self.privateKey = privateKey
        self.chainCode = chainCode
        self.left = privateKey.prefix(32)
        self.right = privateKey.suffix(32)
        self.publicKey = try sodium.cryptoScalarmult.ed25519BaseNoclamp(n: self.left)
    }

    /// Signs a message with Ed25519, using the extended key directly instead of hashing a seed.
    /// - Parameter message: The message to sign.
    /// - Returns: The 64-byte signature, `R` followed by `S`.
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

/// A BIP32-Ed25519 public key with its chain code.
public class BIP32ED25519PublicKey {
    /// The 32-byte Ed25519 public key.
    public var publicKey: Data
    /// The 32-byte chain code.
    public var chainCode: Data

    private let sodium = Sodium()

    /// Creates a public key from its bytes and chain code.
    /// - Parameters:
    ///   - publicKey: The 32-byte Ed25519 public key.
    ///   - chainCode: The 32-byte chain code.
    public init(publicKey: Data, chainCode: Data) {
        self.publicKey = publicKey
        self.chainCode = chainCode
    }

    /// The public key and chain code of an extended private key.
    /// - Parameter privateKey: The extended private key.
    /// - Returns: Its public key.
    public static func fromPrivateKey(privateKey: BIP32ED25519PrivateKey) -> BIP32ED25519PublicKey {
        return BIP32ED25519PublicKey(
            publicKey: privateKey.publicKey, chainCode: privateKey.chainCode)
    }

    /// Checks an Ed25519 signature made by this key.
    /// - Parameters:
    ///   - signature: The 64-byte signature.
    ///   - message: The signed message.
    /// - Returns: The message, when the signature is valid.
    /// - Throws: When the signature is not valid.
    public func verify(signature: Data, message: Data) throws -> Data {
        return try sodium.cryptoSign
            .open(signed: signature + message, pk: self.publicKey)
    }
}

/// HMAC-SHA512 of a message.
/// - Parameters:
///   - message: The data to authenticate.
///   - secret: The HMAC key.
/// - Returns: The 64-byte MAC.
public func Fk(message: Data, secret: Data) throws -> Data {
    return try Data(
        HMAC(
            key: secret.byteArray,
            variant: .sha2(.sha512)
        ).authenticate(message.byteArray)
    )
}

/// A node of a BIP32-Ed25519 hierarchical deterministic wallet, as Cardano wallets use it.
/// The root comes from BIP-39 entropy by PBKDF2-HMAC-SHA512 and bit clamping
/// (see ``generateSeed(passphrase:entropy:)`` and ``tweakBits(seed:)``);
/// child nodes come from ``derive(fromPath:isPrivate:)``, for example along a
/// CIP-1852 path such as `m/1852'/1815'/0'/0/0`.
public class HDWallet {
    /// The 64-byte extended private key of the root node.
    public var rootXPrivateKey: Data
    /// The 32-byte public key of the root node.
    public var rootPublicKey: Data
    /// The 32-byte chain code of the root node.
    public var rootChainCode: Data
    /// The 64-byte extended private key of this node. Public derivation does not change it.
    public var xPrivateKey: Data
    /// The 32-byte public key of this node.
    public var publicKey: Data
    /// The 32-byte chain code of this node.
    public var chainCode: Data
    /// The path of this node, such as `m` for the root. Each index is written as a
    /// number, with hardened indices including the `0x80000000` bit.
    public var path: String
    /// The clamped 96-byte seed the root was made from, when known.
    public var seed: Data?
    /// The mnemonic phrase the wallet was made from, NFKD-normalized, when known.
    public var mnemonic: String?
    /// The BIP-39 passphrase the wallet was made with, when known.
    public var passphrase: String?
    /// The BIP-39 entropy the wallet was made from, as hex, when known.
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

    /// Creates a wallet node from its keys and metadata.
    /// - Parameters:
    ///   - rootXPrivateKey: The 64-byte extended private key of the root node.
    ///   - rootPublicKey: The 32-byte public key of the root node.
    ///   - rootChainCode: The 32-byte chain code of the root node.
    ///   - xPrivateKey: The 64-byte extended private key of this node.
    ///   - publicKey: The 32-byte public key of this node.
    ///   - chainCode: The 32-byte chain code of this node.
    ///   - path: The derivation path of this node.
    ///   - seed: The seed the root was made from, if known.
    ///   - mnemonic: The mnemonic phrase, if known.
    ///   - passphrase: The BIP-39 passphrase, if known.
    ///   - entropy: The BIP-39 entropy as hex, if known.
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

    /// Builds a root wallet from a 96-byte seed given as hex.
    /// - Parameters:
    ///   - seed: The 96-byte seed, as hex.
    ///   - entropy: Optional companion BIP-39 entropy (hex), stored in the wallet.
    ///   - passphrase: Optional BIP-39 passphrase, stored in the wallet.
    ///   - mnemonic: Optional companion BIP-39 mnemonic, stored in the wallet.
    /// - Returns: The root wallet node, at path `m`.
    /// - Throws: `CardanoCoreError.invalidDataError` when `seed` is not valid
    ///   even-length hex or is not 96 bytes.
    public static func fromSeed(
        seed: String, entropy: String? = nil, passphrase: String? = nil, mnemonic: String? = nil
    ) throws -> HDWallet {
        guard seed.count % 2 == 0,
              seed.allSatisfy(\.isHexDigit),
              let seedData = Data(hexString: seed) else {
            throw CardanoCoreError.invalidDataError("Seed is not valid hex")
        }
        return try fromSeed(
            seedData: seedData,
            entropy: entropy,
            passphrase: passphrase,
            mnemonic: mnemonic
        )
    }

    /// Build an `HDWallet` from a 96-byte seed already in `Data` form,
    /// skipping the hex round-trip that the `seed: String` overload
    /// performs.
    ///
    /// Prefer this variant when constructing a wallet from a derived
    /// master key (Ledger / Daedalus / arbitrary BIP32-ED25519 seed)
    /// rather than from a user-supplied hex string. Swift `String`
    /// values aren't zeroed on deallocation, so a 64-byte private
    /// scalar hex-encoded into a `String` lingers in the heap for the
    /// caller's process lifetime; passing the raw `Data` keeps the
    /// secret material out of the string allocator entirely.
    ///
    /// - Parameters:
    ///   - seedData: 96-byte seed (BIP32-ED25519: 64-byte private +
    ///     32-byte chain code) — typically the output of an ICARUS /
    ///     Ledger / Daedalus master-key derivation.
    ///   - entropy: Optional companion BIP-39 entropy (hex) — purely
    ///     informational, propagated into the returned wallet.
    ///   - passphrase: Optional BIP-39 passphrase — purely
    ///     informational.
    ///   - mnemonic: Optional companion BIP-39 mnemonic — purely
    ///     informational.
    /// - Throws: `CardanoCoreError.invalidDataError` when `seedData` is not 96 bytes.
    public static func fromSeed(
        seedData: Data,
        entropy: String? = nil,
        passphrase: String? = nil,
        mnemonic: String? = nil
    ) throws -> HDWallet {
        guard seedData.count == 96 else {
            throw CardanoCoreError.invalidDataError(
                "A seed is 96 bytes, got \(seedData.count)")
        }
        let seedModified = try tweakBits(seed: seedData)

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

    /// The entropy a BIP-39 phrase encodes, in whichever language's wordlist
    /// it was written.
    ///
    /// Two wordlists can share words — simplified and traditional Chinese
    /// share many characters — so a phrase can fit more than one, and word
    /// matching alone cannot tell which. Cardano keys come from the entropy,
    /// so every wordlist that holds the phrase and passes its checksum is
    /// tried, and the phrase is read when they agree on the entropy.
    static func entropy(of words: [String]) throws -> Data {
        if let mnemonic = try? Mnemonic(from: words) {
            return mnemonic.entropy
        }
        var readings = Set<Data>()
        for language in Language.allCases where language != .unsupported {
            guard let wordlist = try? language.words(),
                  let entropy = try? Mnemonic.toEntropy(words, wordlist: wordlist)
            else { continue }
            readings.insert(entropy)
        }
        guard let entropy = readings.first else {
            throw CardanoCoreError.invalidDataError(
                "Invalid mnemonic words: no BIP-39 wordlist holds the phrase with a valid checksum")
        }
        guard readings.count == 1 else {
            throw CardanoCoreError.invalidDataError(
                "Ambiguous mnemonic: the phrase is valid in more than one wordlist with different entropy")
        }
        return entropy
    }

    /// Builds an HDWallet from a BIP-39 mnemonic phrase in any supported language.
    /// The language is detected from the wordlist, so the same call handles English,
    /// Japanese, Spanish, etc. Japanese phrases use `U+3000 IDEOGRAPHIC SPACE` as their
    /// canonical word separator; NFKD normalization collapses that to an ASCII space.
    /// When a phrase fits more than one wordlist, those wordlists must agree on its entropy.
    /// - Parameters:
    ///   - mnemonic: The mnemonic phrase.
    ///   - passphrase: The BIP-39 passphrase, empty by default.
    /// - Returns: The root wallet node, at path `m`.
    /// - Throws: `CardanoCoreError.invalidDataError` when no wordlist holds the phrase
    ///   with a valid checksum, or when wordlists read it as different entropy.
    public static func fromMnemonic(mnemonic: String, passphrase: String = "") throws -> HDWallet {
        let normalizedMnemonic = mnemonic.decomposedStringWithCompatibilityMapping
        let words = normalizedMnemonic
            .components(separatedBy: " ")
            .filter { !$0.isEmpty }

        // Any BIP-39 language, the checksum validated; see `entropy(of:)`.
        let entropy = try Self.entropy(of: words)

        let seed = HDWallet.generateSeed(passphrase: passphrase, entropy: entropy)

        return try HDWallet.fromSeed(
            seed: seed.hexEncodedString(),
            entropy: entropy.hexEncodedString(),
            passphrase: passphrase,
            mnemonic: normalizedMnemonic
        )
    }

    /// Builds a root wallet from BIP-39 entropy.
    /// - Parameters:
    ///   - entropy: The entropy as hex: 16, 20, 24, 28 or 32 bytes.
    ///   - passphrase: The BIP-39 passphrase, empty by default.
    /// - Returns: The root wallet node, at path `m`.
    /// - Throws: `CardanoCoreError.invalidDataError` when the entropy is not a valid length.
    public static func fromEntropy(entropy: String, passphrase: String = "") throws -> HDWallet {
        guard isEntropy(entropy: entropy) else {
            throw CardanoCoreError.invalidDataError("Invalid entropy")
        }

        let seed = generateSeed(passphrase: passphrase, entropy: Data(hex: entropy))
        return try fromSeed(seed: seed.hexEncodedString(), entropy: entropy)
    }

    /// The 96-byte seed for a root key: PBKDF2-HMAC-SHA512 with the passphrase as the
    /// password and the entropy as the salt, over 4096 iterations.
    /// - Parameters:
    ///   - passphrase: The BIP-39 passphrase.
    ///   - entropy: The BIP-39 entropy.
    /// - Returns: The 96-byte seed, before ``tweakBits(seed:)``.
    public static func generateSeed(passphrase: String, entropy: Data) -> Data {
        return Data(try! PKCS5.PBKDF2(
            password: Array(passphrase.utf8),
            salt: entropy.byteArray,
            iterations: 4096,
            keyLength: 96,
            variant: .sha2(.sha512)
        ).calculate())
    }

    /// Clamps a seed for use as an Ed25519 extended private key: clears the low three
    /// bits of byte 0, clears the top three bits of byte 31 and sets bit 6 of byte 31.
    /// - Parameter seed: The seed, at least 32 bytes.
    /// - Returns: The clamped seed.
    /// - Throws: `CardanoCoreError.invalidDataError` when the seed is shorter than 32 bytes.
    public static func tweakBits(seed: Data) throws -> Data {
        guard seed.count >= 32 else {
            throw CardanoCoreError.invalidDataError(
                "A seed to clamp is at least 32 bytes, got \(seed.count)")
        }
        var seedArray = seed.byteArray
        seedArray[0] &= 0b11111000
        seedArray[31] &= 0b00011111
        seedArray[31] |= 0b01000000
        return Data(seedArray)
    }

    /// A copy of this wallet node.
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

    /// Derives a descendant node along a path.
    /// - Parameters:
    ///   - path: A path that starts with `m/`, such as `m/1852'/1815'/0'/0/0`.
    ///     A trailing `'` marks a hardened index.
    ///   - isPrivate: Whether to derive from the private key (`true`) or the public key.
    ///     Public derivation cannot derive hardened indices.
    /// - Returns: The derived node.
    /// - Throws: ``BIP32Error/invalidPath(_:)`` when the path is malformed, or an error
    ///   when derivation fails.
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
                guard let idx = UInt32(index.dropLast()) else {
                    throw BIP32Error.invalidPath("Invalid hardened index: \(index)")
                }
                derivedWallet = try derivedWallet.derive(
                    index: idx, isPrivate: isPrivate, hardened: true)
            } else {
                guard let idx = UInt32(index) else {
                    throw BIP32Error.invalidPath("Invalid index: \(index)")
                }
                derivedWallet = try derivedWallet.derive(
                    index: idx, isPrivate: isPrivate, hardened: false)
            }
        }

        return derivedWallet
    }

    /// Derives a child node at one index.
    /// - Parameters:
    ///   - index: The child index, without the hardened bit.
    ///   - isPrivate: Whether to derive from the private key (`true`) or the public key.
    ///   - hardened: Whether to set the hardened bit (`0x80000000`) on `index`.
    /// - Returns: The child node.
    /// - Throws: `CardanoCoreError.invalidDataError` when the wallet has no root keys,
    ///   or when a hardened index is derived from the public key.
    public func derive(index: UInt32, isPrivate: Bool = true, hardened: Bool = false) throws -> HDWallet {
        guard !self.rootXPrivateKey.isEmpty && !self.rootPublicKey.isEmpty else {
            throw CardanoCoreError.invalidDataError("Missing root keys. Can't do derivation.")
        }

        let index = hardened ? index | 0x8000_0000 : index

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
    public func derivePrivateChildKeyByIndex(privateNode: (Data, Data, Data, Data, String), index: UInt32) throws -> HDWallet {
        let (kLP, kRP, AP, cP, path) = privateNode

        let iBytes = Data(withUnsafeBytes(of: index.littleEndian, Array.init))

        // compute Z, c
        let Z: Data
        let c: Data
        if index < 0x8000_0000 {
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

    /// Derives a non-hardened child node from a parent public key and chain code.
    /// - Parameters:
    ///   - publicNode: The parent public key, chain code and path.
    ///   - index: The child index, which must be below `0x80000000`.
    /// - Returns: The child node. Its extended private key is the parent's, unchanged.
    /// - Throws: `CardanoCoreError.invalidDataError` when `index` is hardened.
    public func derivePublicChildKeyByIndex(publicNode: (Data, Data, String), index: UInt32) throws -> HDWallet {
        let (AP, cP, path) = publicNode
        let iBytes = Data(withUnsafeBytes(of: index.littleEndian, Array.init))

        guard index < 0x8000_0000 else {
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

    /// A new random BIP-39 mnemonic phrase.
    /// - Parameters:
    ///   - language: The wordlist language, English by default.
    ///   - wordCount: The number of words, 24 by default.
    /// - Returns: The words of the phrase.
    /// - Throws: `CardanoCoreError.invalidLanguage` when the language is not supported.
    public static func generateMnemonic(language: Language = .english, wordCount: WordCount = .twentyFour) throws -> [String] {
        guard SUPPORTED_MNEMONIC_LANGS.contains(language) else {
            throw CardanoCoreError.invalidLanguage(
                "Invalid language, use only the following languages: \(SUPPORTED_MNEMONIC_LANGS)"
            )
        }
        
        let mnemonic = try Mnemonic(language: language)

        return try mnemonic.generate(wordCount: wordCount)
    }

    /// Whether a phrase is a valid BIP-39 mnemonic in a language.
    /// - Parameters:
    ///   - mnemonic: The mnemonic phrase.
    ///   - language: The wordlist language, English by default.
    /// - Returns: Whether the phrase is valid.
    /// - Throws: `CardanoCoreError.invalidLanguage` when the language is not supported.
    public static func isMnemonic(mnemonic: String, language: Language = .english) throws -> Bool {
        guard SUPPORTED_MNEMONIC_LANGS.contains(language) else {
            throw CardanoCoreError.invalidLanguage(
                "Invalid language, use only the following languages: \(SUPPORTED_MNEMONIC_LANGS)"
            )
        }
        
        return try Mnemonic(language: language).check(mnemonic: mnemonic)
    }

    /// Whether a hex string is BIP-39 entropy of a valid length: 16, 20, 24, 28 or 32 bytes.
    /// - Parameter entropy: The entropy as hex.
    /// - Returns: Whether the length is valid.
    public static func isEntropy(entropy: String) -> Bool {
        let entropyData = Data(hex: entropy)
        return [16, 20, 24, 28, 32].contains(entropyData.count)
    }
}
