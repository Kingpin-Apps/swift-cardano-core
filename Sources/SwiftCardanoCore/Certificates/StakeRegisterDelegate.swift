import Foundation
import PotentCBOR

public struct StakeRegisterDelegate: CertificateSerializable {
    public var _payload: Data
    public var _type: String
    public var _description: String
    
    public var type: String { get { return StakeRegisterDelegate.TYPE } }
    public var description: String { get { return StakeRegisterDelegate.DESCRIPTION } }

    public static var TYPE: String { CertificateType.conway.rawValue }
    public static var DESCRIPTION: String { CertificateDescription.stakeRegisterDelegate.rawValue }
    public static var CODE: CertificateCode { get { return .stakeRegisterDelegate } }
    
    public let stakeCredential: StakeCredential
    public let poolKeyHash: PoolKeyHash
    public let coin: Coin
    
    /// Initialize a new `StakeRegisterDelegate` certificate
    /// - Parameters:
    ///   - stakeCredential: The stake credential
    ///   - poolKeyHash: The pool key hash
    ///   - coin: The coin
    public init(stakeCredential: StakeCredential, poolKeyHash: PoolKeyHash, coin: Coin) {
        self.stakeCredential = stakeCredential
        self.poolKeyHash = poolKeyHash
        self.coin = coin
        
        self._payload =  try! CBORSerialization.data(from:
                .array(
                    [
                        CBOR(integerLiteral: Self.CODE.rawValue),
                        try! CBOREncoder().encode(stakeCredential).toCBOR,
                        try! CBOREncoder().encode(poolKeyHash).toCBOR,
                        try! CBOREncoder().encode(coin).toCBOR
                    ]
                )
        )
        self._type = Self.TYPE
        self._description = Self.DESCRIPTION
    }
    
    /// Initialize `StakeRegisterDelegate` certificate from payload, type, and description
    /// - Parameters:
    ///   - payload: The payload of the certificate
    ///   - type: The type of the certificate
    ///   - description: The description of the certificate
    public init(payload: Data, type: String?, description: String?) {
        self._payload = payload
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
        
        let cbor = try! CBORDecoder().decode(StakeRegisterDelegate.self, from: payload)
        
        self.stakeCredential = cbor.stakeCredential
        self.poolKeyHash = cbor.poolKeyHash
        self.coin = cbor.coin
    }
    
    public init(from primitive: Primitive) throws {
        guard case let .list(elements) = primitive else {
            throw CardanoCoreError.deserializeError("Invalid StakeRegisterDelegate: not an array")
        }
        
        guard elements.count == 4 else {
            throw CardanoCoreError.deserializeError("Invalid StakeRegisterDelegate: wrong number of elements")
        }
        
        guard case let .uint(code) = elements[0], code == Self.CODE.rawValue else {
            throw CardanoCoreError.deserializeError("Invalid StakeRegisterDelegate: invalid type code")
        }
        
        let stakeCredential = try StakeCredential(from: elements[1])
        let poolKeyHash = try PoolKeyHash(from: elements[2])
        let coin: Coin
        
        if case let .uint(coinValue) = elements[3] {
            coin = Coin(coinValue)
        } else {
            throw CardanoCoreError.deserializeError("Invalid StakeRegisterDelegate: invalid coin value")
        }
        
        self.init(stakeCredential: stakeCredential, poolKeyHash: poolKeyHash, coin: coin)
    }

    public func toPrimitive() throws -> Primitive {
        return .list([
            .uint(UInt(Self.CODE.rawValue)),
            try stakeCredential.toPrimitive(),
            poolKeyHash.toPrimitive(),
            .int(Int(coin))
        ])
    }
}

