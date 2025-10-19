import Foundation
import PotentCBOR

/// Stake Delegation Certificate
public struct StakeDelegation: CertificateSerializable {
    public var _payload: Data
    public var _type: String
    public var _description: String
    
    public var type: String { get { return StakeDelegation.TYPE } }
    public var description: String { get { return StakeDelegation.DESCRIPTION } }

    public static var TYPE: String { CertificateType.conway.rawValue }
    public static var DESCRIPTION: String { CertificateDescription.stakeDelegation.rawValue }
    public static var CODE: CertificateCode { get { return .stakeDelegation } }
    
    public let stakeCredential: StakeCredential
    public let poolKeyHash: PoolKeyHash
    
    /// Initialize StakeDelegation from stake credential and pool key hash
    /// - Parameters:
    ///  - stakeCredential: The stake credential
    ///  - poolKeyHash: The  pool key hash
    public init(stakeCredential: StakeCredential, poolKeyHash: PoolKeyHash) {
        self.stakeCredential = stakeCredential
        self.poolKeyHash = poolKeyHash
        
        self._payload =  try! CBORSerialization.data(from:
                .array(
                    [
                        CBOR(integerLiteral: Self.CODE.rawValue),
                        try! CBOREncoder().encode(stakeCredential).toCBOR,
                        try! CBOREncoder().encode(poolKeyHash).toCBOR
                    ]
                )
        )
        self._type = Self.TYPE
        self._description = Self.DESCRIPTION
    }
    
    /// Initialize StakeDelegation certificate from payload, type, and description
    /// - Parameters:
    ///   - payload: The payload of the certificate
    ///   - type: The type of the certificate
    ///   - description: The description of the certificate
    public init(payload: Data, type: String?, description: String?) {
        self._payload = payload
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
        
        let cbor = try! CBORDecoder().decode(StakeDelegation.self, from: payload)
        
        self.stakeCredential = cbor.stakeCredential
        self.poolKeyHash = cbor.poolKeyHash
    }
    
    public init(from primitive: Primitive) throws {
        guard case let .list(primitive) = primitive,
                primitive.count == 3,
              case let .uint(code) = primitive[0],
              code == Self.CODE.rawValue else {
            throw CardanoCoreError.deserializeError("Invalid StakeDelegation type")
        }
        let stakeCredential = try StakeCredential(from: primitive[1])
        let poolKeyHash = try PoolKeyHash(from: primitive[2])
        
        self.init(stakeCredential: stakeCredential, poolKeyHash: poolKeyHash)
    }

    public func toPrimitive() throws -> Primitive {
        return .list([
            .uint(UInt(Self.CODE.rawValue)),
            try stakeCredential.toPrimitive(),
            poolKeyHash.toPrimitive()
        ])
    }

}
