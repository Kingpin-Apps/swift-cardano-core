import Foundation
import PotentCBOR

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
}
