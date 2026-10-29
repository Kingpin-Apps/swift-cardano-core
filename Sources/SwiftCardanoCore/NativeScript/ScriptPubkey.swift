import Foundation
import OrderedCollections

public struct ScriptPubkey: NativeScriptable, Sendable {
    public static let TYPE = NativeScriptType.scriptPubkey
    public let keyHash: VerificationKeyHash

    /// The bytes this script was decoded from, when it was decoded on its
    /// own or as a whole script of a transaction; its encoding and hash are
    /// taken over them, as the ledger takes them, while they are kept.
    public internal(set) var originalCBOR: Data? = nil
    
    public init(keyHash: VerificationKeyHash) {
        self.keyHash = keyHash
    }
    
    // MARK: - CBORSerializable
    
    public init(from primitive: Primitive) throws {
        guard let primitive = primitive.arrayElements,
              primitive.count == 2 else {
            throw CardanoCoreError.deserializeError("Invalid ScriptPubkey type")
        }
        guard case let .uint(type) = primitive[0],
              type == Self.TYPE.rawValue else {
            throw CardanoCoreError.deserializeError("Invalid ScriptPubkey type")
        }
        self.keyHash = try VerificationKeyHash(from: primitive[1])
    }

    public func toPrimitive() throws -> Primitive {
        if let originalCBOR { return .cborSimpleValue(.encoded(originalCBOR)) }
        return .list([
            .uint(UInt64(Self.TYPE.rawValue)),
            keyHash.toPrimitive()
        ])
    }
    
    // MARK: - JSONSerializable
    
    public static func fromDict(_ dict: Primitive) throws -> ScriptPubkey {
        guard case let .orderedDict(dictValue) = dict else {
            throw CardanoCoreError.decodingError("Invalid ScriptPubkey dict format")
        }
        
        guard let keyHashPrimitive = dictValue[.string("keyHash")],
              case let .string(keyHashDict) = keyHashPrimitive else {
            throw CardanoCoreError.decodingError("Invalid ScriptPubkey keyHash")
        }
        
        guard let keyHashData = Data(hexString: keyHashDict) else {
            throw CardanoCoreError.decodingError("Invalid hex string for keyHash")
        }
        
        let keyHash = VerificationKeyHash(
            payload: keyHashData
        )
        
        return ScriptPubkey(keyHash: keyHash)
    }
    
    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        dict[.string("type")] = .string(Self.TYPE.description())
        dict[.string("keyHash")] = .string(keyHash.payload.toHex)
        return .orderedDict(dict)
    }

}

extension ScriptPubkey {
    /// Equal when they are the same script, however each was written.
    public static func == (lhs: ScriptPubkey, rhs: ScriptPubkey) -> Bool {
        lhs.keyHash == rhs.keyHash
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(keyHash)
    }
}
