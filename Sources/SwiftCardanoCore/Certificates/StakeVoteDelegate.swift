import Foundation
import PotentCBOR
import OrderedCollections


/// Stake and Vote Delegation Certificate
public struct StakeVoteDelegate: CertificateSerializable {
    public var _payload: Data
    public var _type: String
    public var _description: String
    
    public var type: String { get { return StakeVoteDelegate.TYPE } }
    public var description: String { get { return StakeVoteDelegate.DESCRIPTION } }

    public static var TYPE: String { CertificateType.conway.rawValue }
    public static var DESCRIPTION: String { CertificateDescription.stakeVoteDelegate.rawValue }
    public static var CODE: CertificateCode { get { return .stakeVoteDelegate } }
    
    public let stakeCredential: StakeCredential
    public let poolKeyHash: PoolKeyHash
    public let drep: DRep
    
    public enum CodingKeys: String, CodingKey {
        case stakeCredential
        case poolKeyHash
        case drep
    }
    
    /// Initialize a new `StakeVoteDelegate` certificate
    /// - Parameters:
    ///   - stakeCredential: The stake credential
    ///   - poolKeyHash: The pool key hash
    ///   - drep: The DRep
    public init(stakeCredential: StakeCredential, poolKeyHash: PoolKeyHash, drep: DRep) {
        self.stakeCredential = stakeCredential
        self.poolKeyHash = poolKeyHash
        self.drep = drep
        
        self._payload =  try! CBORSerialization.data(from:
                .array(
                    [
                        CBOR(integerLiteral: Self.CODE.rawValue),
                        try! CBOREncoder().encode(stakeCredential).toCBOR,
                        try! CBOREncoder().encode(poolKeyHash).toCBOR,
                        try! CBOREncoder().encode(drep).toCBOR
                    ]
                )
        )
        
        self._type = Self.TYPE
        self._description = Self.DESCRIPTION
    }
    
    /// Initialize StakeVoteDelegate certificate from payload, type, and description
    /// - Parameters:
    ///   - payload: The payload of the certificate
    ///   - type: The type of the certificate
    ///   - description: The description of the certificate
    public init(payload: Data, type: String?, description: String?) {
        self._payload = payload
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
        
        let cbor = try! CBORDecoder().decode(StakeVoteDelegate.self, from: payload)
        
        self.stakeCredential = cbor.stakeCredential
        self.poolKeyHash = cbor.poolKeyHash
        self.drep = cbor.drep
    }
    
    // MARK: - CBORSerializable
    
    public init(from primitive: Primitive) throws {
        guard case let .list(primitive) = primitive,
              primitive.count == 4,
              case let .uint(code) = primitive[0],
              code == Self.CODE.rawValue else {
            throw CardanoCoreError.deserializeError("Invalid StakeVoteDelegate type")
        }
        
        let stakeCredential = try StakeCredential(from: primitive[1])
        let poolKeyHash = try PoolKeyHash(from: primitive[2])
        let drep = try DRep(from: primitive[3])
        
        self.init(stakeCredential: stakeCredential, poolKeyHash: poolKeyHash, drep: drep)
    }
    
    public func toPrimitive() throws -> Primitive {
        return .list([
            .uint(UInt(Self.CODE.rawValue)),
            try stakeCredential.toPrimitive(),
            poolKeyHash.toPrimitive(),
            try drep.toPrimitive()
        ])
    }
    
    // MARK: - JSONSerializable
    
    public static func fromDict(_ dict: Primitive) throws -> StakeVoteDelegate {
        guard case let .orderedDict(dictValue) = dict,
              let stakeCredentialPrimitive = dictValue[.string(CodingKeys.stakeCredential.rawValue)],
              case let .string(stakeCredentialHex) = stakeCredentialPrimitive else {
            throw CardanoCoreError.deserializeError("Invalid or missing stakeCredential in StakeVoteDelegate dict")
        }
        
        let stakeCredentialData = Data(hex: stakeCredentialHex)
        let stakeCredential = try StakeCredential(from: .bytes(stakeCredentialData))
        
        guard case let .string(poolId) = dictValue[.string(CodingKeys.poolKeyHash.rawValue)] else {
            throw CardanoCoreError.deserializeError("Missing poolKeyHash in StakeVoteDelegate dict")
        }
        
        let poolOperator = try PoolOperator(from: poolId)
        
        guard let drepPrimitive = dictValue[.string(CodingKeys.drep.rawValue)] else {
            throw CardanoCoreError.deserializeError("Missing drep in StakeVoteDelegate dict")
        }
        let drep = try DRep(from: drepPrimitive)
        
        return StakeVoteDelegate(
            stakeCredential: stakeCredential,
            poolKeyHash: poolOperator.poolKeyHash,
            drep: drep
        )
    }
    
    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        let poolOperator = PoolOperator(poolKeyHash: poolKeyHash)
        
        dict[.string(CodingKeys.stakeCredential.rawValue)] = .string(stakeCredential.credential.payload.toHex)
        dict[.string(CodingKeys.poolKeyHash.rawValue)] = .string(try poolOperator.id())
        dict[.string(CodingKeys.drep.rawValue)] = .string(try drep.id())
        return .orderedDict(dict)
    }
}
