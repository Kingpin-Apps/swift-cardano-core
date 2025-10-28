import Foundation
import PotentCBOR
import OrderedCollections

public struct StakeVoteRegisterDelegate: CertificateSerializable {
    public var _payload: Data
    public var _type: String
    public var _description: String
    
    public var type: String { get { return StakeVoteRegisterDelegate.TYPE } }
    public var description: String { get { return StakeVoteRegisterDelegate.DESCRIPTION } }

    public static var TYPE: String { CertificateType.conway.rawValue }
    public static var DESCRIPTION: String { CertificateDescription.voteRegisterDelegate.rawValue }
    public static var CODE: CertificateCode { get { return .stakeVoteRegisterDelegate } }
    
    public let stakeCredential: StakeCredential
    public let poolKeyHash: PoolKeyHash
    public let drep: DRep
    public let coin: Coin
    
    public enum CodingKeys: String, CodingKey {
        case stakeCredential
        case poolKeyHash
        case drep
        case coin
    }
    
    /// Initialize a new `StakeVoteRegisterDelegate` certificate
    /// - Parameters:
    ///   - stakeCredential: The stake credential
    ///   - poolKeyHash: The pool key hash
    ///   - drep: The DRep
    ///   - coin: The coin
    public init(
        stakeCredential: StakeCredential,
        poolKeyHash: PoolKeyHash,
        drep: DRep,
        coin: Coin
    ) {
        self.stakeCredential = stakeCredential
        self.poolKeyHash = poolKeyHash
        self.drep = drep
        self.coin = coin
        
        self._payload =  try! CBORSerialization.data(from:
                .array(
                    [
                        CBOR(integerLiteral: Self.CODE.rawValue),
                        try! CBOREncoder().encode(stakeCredential).toCBOR,
                        try! CBOREncoder().encode(poolKeyHash).toCBOR,
                        try! CBOREncoder().encode(drep).toCBOR,
                        try! CBOREncoder().encode(coin).toCBOR
                    ]
                )
        )
        
        self._type = Self.TYPE
        self._description = Self.DESCRIPTION
    }
    
    /// Initialize StakeVoteRegisterDelegate certificate from payload, type, and description
    /// - Parameters:
    ///   - payload: The payload of the certificate
    ///   - type: The type of the certificate
    ///   - description: The description of the certificate
    public init(payload: Data, type: String?, description: String?) {
        self._payload = payload
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
        
        let cbor = try! CBORDecoder().decode(StakeVoteRegisterDelegate.self, from: payload)
        
        self.stakeCredential = cbor.stakeCredential
        self.poolKeyHash = cbor.poolKeyHash
        self.drep = cbor.drep
        self.coin = cbor.coin
    }
    
    // MARK: - CBORSerializable
    
    public init(from primitive: Primitive) throws {
        guard case let .list(primitive) = primitive,
              primitive.count == 5,
              case let .uint(code) = primitive[0],
              case let .uint(coin) = primitive[4],
              code == Self.CODE.rawValue else {
            throw CardanoCoreError.deserializeError("Invalid StakeVoteRegisterDelegate type")
        }
        
        let stakeCredential = try StakeCredential(from: primitive[1])
        let poolKeyHash = try PoolKeyHash(from: primitive[2])
        let drep = try DRep(from: primitive[3])
        
        self.init(
            stakeCredential: stakeCredential,
            poolKeyHash: poolKeyHash,
            drep: drep,
            coin: Coin(coin)
        )
    }
    
    public func toPrimitive() throws -> Primitive {
        return .list([
            .uint(UInt(Self.CODE.rawValue)),
            try stakeCredential.toPrimitive(),
            poolKeyHash.toPrimitive(),
            try drep.toPrimitive(),
            .int(Int(coin))
        ])
    }
    
    // MARK: - JSONSerializable
    
    public static func fromDict(_ dict: Primitive) throws -> StakeVoteRegisterDelegate {
        guard case let .orderedDict(dictValue) = dict,
              let stakeCredentialPrimitive = dictValue[.string(CodingKeys.stakeCredential.rawValue)],
              case let .string(stakeCredentialHex) = stakeCredentialPrimitive else {
            throw CardanoCoreError.deserializeError("Invalid or missing stakeCredential in StakeVoteRegisterDelegate dict")
        }
        
        let stakeCredentialData = Data(hex: stakeCredentialHex)
        let stakeCredential = try StakeCredential(from: .bytes(stakeCredentialData))
        
        guard case let .string(poolId) = dictValue[.string(CodingKeys.poolKeyHash.rawValue)] else {
            throw CardanoCoreError.deserializeError("Missing poolKeyHash in StakeVoteRegisterDelegate dict")
        }
        
        let poolOperator = try PoolOperator(from: poolId)
        
        guard case let .string(drepPrimitive) = dictValue[.string(CodingKeys.drep.rawValue)] else {
            throw CardanoCoreError.deserializeError("Missing drep in StakeVoteRegisterDelegate dict")
        }
        let drep = try DRep(from: drepPrimitive)
        
        guard let coinPrimitive = dictValue[.string(CodingKeys.coin.rawValue)],
              case let .int(coinValue) = coinPrimitive else {
            throw CardanoCoreError.deserializeError("Invalid or missing coin in StakeVoteRegisterDelegate dict")
        }
        let coin = Coin(coinValue)
        
        return StakeVoteRegisterDelegate(
            stakeCredential: stakeCredential,
            poolKeyHash: poolOperator.poolKeyHash,
            drep: drep,
            coin: coin
        )
    }
    
    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        let poolOperator = PoolOperator(poolKeyHash: poolKeyHash)
        
        dict[.string(CodingKeys.stakeCredential.rawValue)] = .string(stakeCredential.credential.payload.toHex)
        dict[.string(CodingKeys.poolKeyHash.rawValue)] = .string(try poolOperator.id())
        dict[.string(CodingKeys.drep.rawValue)] = .string(try drep.id())
        dict[.string(CodingKeys.coin.rawValue)] = .int(Int(coin))
        
        return .orderedDict(dict)
    }
}
