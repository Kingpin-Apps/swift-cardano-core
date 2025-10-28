import Foundation
import OrderedCollections

public struct ScriptPubkey: NativeScriptable, Sendable {
    public static let TYPE = NativeScriptType.scriptPubkey
    public let keyHash: VerificationKeyHash
    
    public init(keyHash: VerificationKeyHash) {
        self.keyHash = keyHash
    }
    
    // MARK: - CBORSerializable
    
    public init(from primitive: Primitive) throws {
        guard case let .list(primitive) = primitive,
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
        return .list([
            .uint(UInt(Self.TYPE.rawValue)),
            keyHash.toPrimitive()
        ])
    }
    
    // MARK: - JSONSerializable
    
    public static func fromDict(_ dict: Primitive) throws -> ScriptPubkey {
        guard case let .orderedDict(dictValue) = dict,
              case let .string(keyHashDict) = dictValue[.string("keyHash")] else {
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
