import Foundation
import PotentCBOR

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
    
    /// Initialize a new `GenesisKeyDelegation` certificate from its CBOR representation
    /// - Parameter decoder: The decoder
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)
        
        guard case Self.CODE.rawValue = code else {
            throw CardanoCoreError.deserializeError("Invalid GenesisKeyDelegation type: \(code)")
        }
        
        let genesisHash = try container.decode(GenesisHash.self)
        let genesisDelegateHash = try container.decode(GenesisDelegateHash.self)
        let vrfKeyHash = try container.decode(VrfKeyHash.self)
        
        self.init(genesisHash: genesisHash, genesisDelegateHash: genesisDelegateHash, vrfKeyHash: vrfKeyHash)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(Self.CODE.rawValue)
        try container.encode(genesisHash)
        try container.encode(genesisDelegateHash)
        try container.encode(vrfKeyHash)
    }
    
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

}
