import Foundation
import PotentCBOR
import OrderedCollections

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
    
    public enum CodingKeys: String, CodingKey {
        case stakeCredential
        case poolKeyHash
        case coin
    }
    
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
    
    // MARK: - CBORSerializable
    
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
    
    // MARK: - JSONSerializable
    
    public static func fromDict(_ dict: Primitive) throws -> StakeRegisterDelegate {
        guard case let .orderedDict(orderedDict) = dict else {
            throw CardanoCoreError.deserializeError("Invalid StakeRegisterDelegate dict format")
        }
        guard let stakeCredentialPrimitive = orderedDict[.string(CodingKeys.stakeCredential.rawValue)],
              case let .string(stakeCredentialHex) = stakeCredentialPrimitive else {
            throw CardanoCoreError.deserializeError("Invalid or missing stakeCredential in StakeRegisterDelegate dict")
        }
        
        let stakeCredentialData = Data(hex: stakeCredentialHex)
        let stakeCredential = try StakeCredential(from: .bytes(stakeCredentialData))
        
        guard case let .string(poolId) = orderedDict[.string(CodingKeys.poolKeyHash.rawValue)] else {
            throw CardanoCoreError.deserializeError("Missing keys in PoolRetirement dictionary")
        }
        
        let poolOperator = try PoolOperator(from: poolId)
        
        guard let coinPrimitive = orderedDict[.string(CodingKeys.coin.rawValue)],
              case let .int(coinValue) = coinPrimitive else {
            throw CardanoCoreError.deserializeError("Invalid or missing coin in StakeRegisterDelegate dict")
        }
        let coin = Coin(coinValue)
        
        return StakeRegisterDelegate(
            stakeCredential: stakeCredential,
            poolKeyHash: poolOperator.poolKeyHash,
            coin: coin
        )
    }

    
    public func toDict() throws -> Primitive {
        var dict = OrderedCollections.OrderedDictionary<Primitive, Primitive>()
        let poolOperator = PoolOperator(poolKeyHash: poolKeyHash)
        
        dict[.string(CodingKeys.stakeCredential.rawValue)] =
            .string(stakeCredential.credential.payload.toHex)
        dict[.string(CodingKeys.poolKeyHash.rawValue)] = .string(try poolOperator.id())
        dict[.string(CodingKeys.coin.rawValue)] = .int(Int(coin))
        
        return .orderedDict(dict)
    }
}

