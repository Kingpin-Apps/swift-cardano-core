import Foundation
import PotentCBOR


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
    
    /// Initialize a new `StakeVoteDelegate` certificate from its Text Envelope representation
    /// - Parameter decoder: The decoder
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)
        
        guard case Self.CODE.rawValue = code else {
            throw CardanoCoreError.deserializeError("Invalid StakeVoteDelegate type: \(code)")
        }
        
        let stakeCredential = try container.decode(StakeCredential.self)
        let poolKeyHash = try container.decode(PoolKeyHash.self)
        let drep = try container.decode(DRep.self)
        
        self.init(stakeCredential: stakeCredential, poolKeyHash: poolKeyHash, drep: drep)
    }
    
    /// Encode the `StakeVoteDelegate` certificate
    /// - Parameter encoder: The encoder
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(Self.CODE.rawValue)
        try container.encode(stakeCredential)
        try container.encode(poolKeyHash)
        try container.encode(drep)
    }
}
