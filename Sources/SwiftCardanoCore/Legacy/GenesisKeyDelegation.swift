import Foundation
import CBORCodable
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
    ///  - genesisHash: The genesis hash
    ///  - genesisDelegateHash: The genesis delegate hash
    ///  - vrfKeyHash: The verification key hash of the VRF key associated with the genesis delegate
    /// - Throws: When the certificate cannot be encoded for its payload.
    public init(genesisHash: GenesisHash, genesisDelegateHash: GenesisDelegateHash, vrfKeyHash: VrfKeyHash) throws {
        self.genesisHash = genesisHash
        self.genesisDelegateHash = genesisDelegateHash
        self.vrfKeyHash = vrfKeyHash
        self._payload = Data()
        self._type = Self.TYPE
        self._description = Self.DESCRIPTION
        self._payload = try encodedPayload()
    }
    
    /// Initialize a new `GenesisKeyDelegation` certificate from its Text Envelope representation
    /// - Parameters:
    ///  - payload: The CBOR representation of the certificate
    ///  - type: The type of the certificate
    ///  - description: The description of the certificate
    public init(payload: Data, type: String?, description: String?) throws {
        let decoded = try CBORDecoder().decode(Self.self, from: payload)
        self = decoded
        self._payload = payload
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
    }
    
    // MARK: - CBORSerializable
    
    /// `genesis_delegation_cert = (5, genesis_hash, genesis_delegate_hash, vrf_keyhash)`,
    /// with `genesis_hash` and `genesis_delegate_hash` 28 bytes and
    /// `vrf_keyhash` 32.
    public init(from primitive: Primitive) throws {
        let fields = try Self.certificateFields(primitive, count: 4)
        try self.init(
            genesisHash: try GenesisHash(from: fields[0]),
            genesisDelegateHash: try GenesisDelegateHash(from: fields[1]),
            vrfKeyHash: try VrfKeyHash(from: fields[2])
        )
    }

    public func toPrimitive() throws -> Primitive {
        return .list([
            Self.codePrimitive,
            genesisHash.toPrimitive(),
            genesisDelegateHash.toPrimitive(),
            vrfKeyHash.toPrimitive()
        ])
    }
    
    // MARK: - JSONSerializable
    
    public static func fromDict(_ dict: Primitive) throws -> GenesisKeyDelegation {
        let type = "GenesisKeyDelegation"
        return try GenesisKeyDelegation(
            genesisHash: try GenesisHash(
                from: .string(try dictString(dict, CodingKeys.genesisHash.rawValue, in: type))),
            genesisDelegateHash: try GenesisDelegateHash(
                from: .string(try dictString(dict, CodingKeys.genesisDelegateHash.rawValue, in: type))),
            vrfKeyHash: try VrfKeyHash(
                from: .string(try dictString(dict, CodingKeys.vrfKeyHash.rawValue, in: type)))
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
