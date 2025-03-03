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
    
    /// Initialize a new `StakeRegisterDelegate` certificate from its CBOR representation
    /// - Parameter decoder: The decoder
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)
        
        guard case Self.CODE.rawValue = code else {
            throw CardanoCoreError.deserializeError("Invalid StakeRegisterDelegate type: \(code)")
        }
        
        let stakeCredential = try container.decode(StakeCredential.self)
        let poolKeyHash = try container.decode(PoolKeyHash.self)
        let coin = try container.decode(Coin.self)
        
        self.init(stakeCredential: stakeCredential, poolKeyHash: poolKeyHash, coin: coin)
    }
    
    /// Initialize a new `StakeRegisterDelegate` certificate from its CBOR representation
    /// - Parameter encoder: The encoder
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(Self.CODE.rawValue)
        try container.encode(stakeCredential)
        try container.encode(poolKeyHash)
        try container.encode(coin)
    }
}

