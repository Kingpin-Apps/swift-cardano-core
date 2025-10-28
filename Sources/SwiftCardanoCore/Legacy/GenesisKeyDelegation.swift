import Foundation
import PotentCBOR
import OrderedCollections

public struct GenesisKeyDelegation: CertificateSerializable {
    public var _payload: Data
    public var _type: String
    public var _description: String
    
    public var type: String { get { return GenesisKeyDelegation.TYPE } }
    public var description: String { get { return GenesisKeyDelegation.DESCRIPTION } }

    public static var TYPE: String { CertificateType.shelley.rawValue }
    public static var DESCRIPTION: String { CertificateDescription.genesisKeyDelegation.rawValue }
    public static var CODE: CertificateCode { get { return .genesisKeyDelegation } }
    
    public let genesisHash: GenesisHash
    public let genesisDelegateHash: GenesisDelegateHash
    public let vrfKeyHash: VrfKeyHash
    
    public enum CodingKeys: String, CodingKey {
        case genesisHash
        case genesisDelegateHash
        case vrfKeyHash
    }
    
    /// Initialize a new `GenesisKeyDelegation` certificate
    /// - Parameters:
    ///  - genesisHash: The DRep credential
    ///  - genesisDelegateHash: The anchor
    ///  - vrfKeyHash: The anchor
    public init(genesisHash: GenesisHash, genesisDelegateHash: GenesisDelegateHash, vrfKeyHash: VrfKeyHash) {
        self.genesisHash = genesisHash
        self.genesisDelegateHash = genesisDelegateHash
        self.vrfKeyHash = vrfKeyHash
        
        self._payload =  try! CBORSerialization.data(from:
                .array(
                    [
                        CBOR(integerLiteral: Self.CODE.rawValue),
                        try! CBOREncoder().encode(genesisHash).toCBOR,
                        try! CBOREncoder().encode(genesisDelegateHash).toCBOR,
                        try! CBOREncoder().encode(vrfKeyHash).toCBOR
                    ]
                )
        )
        self._type = Self.TYPE
        self._description = Self.DESCRIPTION
    }
    
    /// Initialize a new `GenesisKeyDelegation` certificate from its Text Envelope representation
    /// - Parameters:
    ///  - payload: The CBOR representation of the certificate
    ///  - type: The type of the certificate
    ///  - description: The description of the certificate
    public init(payload: Data, type: String?, description: String?) {
        self._payload = payload
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
        
        let cbor = try! CBORDecoder().decode(GenesisKeyDelegation.self, from: payload)
        
        self.genesisHash = cbor.genesisHash
        self.genesisDelegateHash = cbor.genesisDelegateHash
        self.vrfKeyHash = cbor.vrfKeyHash
    }
    
    // MARK: - CBORSerializable
    
    public init(from primitive: Primitive) throws {
        guard case let .list(primitive) = primitive,
                primitive.count == 4,
                case let .int(code) = primitive[0],
                code == Self.CODE.rawValue,
              case .byteString(_) = primitive[1],
              case .byteString(_) = primitive[2],
              case .byteString(_) = primitive[3]
        else {
            throw CardanoCoreError.deserializeError("Invalid GenesisKeyDelegation type")
        }
        let genesisHash = try GenesisHash(from: primitive[1])
        let genesisDelegateHash = try GenesisDelegateHash(from: primitive[2])
        let vrfKeyHash = try VrfKeyHash(from: primitive[3])
        
        self.init(
            genesisHash: genesisHash,
            genesisDelegateHash: genesisDelegateHash,
            vrfKeyHash: vrfKeyHash
        )
    }

    public func toPrimitive() throws -> Primitive {
        return .list([
            .int(Int(Self.CODE.rawValue)),
            .bytes(genesisHash.payload),
            .bytes(genesisDelegateHash.payload),
            .bytes(vrfKeyHash.payload)
        ])
    }
    
    // MARK: - JSONSerializable
    
    public static func fromDict(_ dict: Primitive) throws -> GenesisKeyDelegation {
        guard case let .orderedDict(orderedDict) = dict else {
            throw CardanoCoreError.deserializeError("Invalid GenesisKeyDelegation dict format")
        }
        guard let genesisHashPrimitive = orderedDict[.string(CodingKeys.genesisHash.rawValue)],
              let genesisDelegateHashPrimitive = orderedDict[.string(CodingKeys.genesisDelegateHash.rawValue)],
              let vrfKeyHashPrimitive = orderedDict[.string(CodingKeys.vrfKeyHash.rawValue)],
              case let .string(genesisHashHex) = genesisHashPrimitive,
              case let .string(genesisDelegateHashHex) = genesisDelegateHashPrimitive,
              case let .string(vrfKeyHashHex) = vrfKeyHashPrimitive else {
            throw CardanoCoreError.deserializeError("Invalid GenesisKeyDelegation dictionary")
        }
        let genesisHashData = Data(hex: genesisHashHex)
        let genesisDelegateHashData = Data(hex: genesisDelegateHashHex)
        let vrfKeyHashData = Data(hex: vrfKeyHashHex)
        let genesisHash = GenesisHash(payload: genesisHashData)
        let genesisDelegateHash = GenesisDelegateHash(payload: genesisDelegateHashData)
        let vrfKeyHash = VrfKeyHash(payload: vrfKeyHashData)
        
        return GenesisKeyDelegation(
            genesisHash: genesisHash,
            genesisDelegateHash: genesisDelegateHash,
            vrfKeyHash: vrfKeyHash
        )
    }
    
    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        dict[.string(CodingKeys.genesisHash.rawValue)] = .string(genesisHash.payload.toHex)
        dict[.string(CodingKeys.genesisDelegateHash.rawValue)] = .string(genesisDelegateHash.payload.toHex)
        dict[.string(CodingKeys.vrfKeyHash.rawValue)] = .string(vrfKeyHash.payload.toHex)
        return .orderedDict(dict)
    }


}
