import Foundation
import PotentCBOR
import FractionNumber

/// Stake Pool Registration Certificate
public struct PoolRegistration: CertificateSerializable {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public var type: String { get { return PoolRegistration.TYPE } }
    public  var description: String { get { return PoolRegistration.DESCRIPTION } }

    public static var TYPE: String { CertificateType.conway.rawValue }
    public static var DESCRIPTION: String { CertificateDescription.poolRegistration.rawValue }
    public static var CODE: CertificateCode { get { return .poolRegistration } }
    
    public let poolParams: PoolParams
    
    /// Initialize a new PoolRegistration certificate
    /// - Parameter poolParams: The pool parameters
    public init(poolParams: PoolParams) {
        self.poolParams = poolParams
        
        self._payload =  try! CBORSerialization.data(from:
                .array(
                    [
                        CBOR(integerLiteral: Self.CODE.rawValue),
                        try! CBOREncoder().encode(poolParams).toCBOR
                    ]
                )
        )
        self._type = Self.TYPE
        self._description = Self.DESCRIPTION
    }
    
    /// Initialize a new PoolRegistration certificate from a payload
    /// - Parameters:
    ///   - payload: The payload
    ///   - type: The type
    ///   - description: The description
    public init(payload: Data, type: String?, description: String?) {
        self._payload = payload
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
        
        let cbor = try! CBORDecoder().decode(Self.self, from: payload)
        self.poolParams = cbor.poolParams
    }
    
    /// Initialize a new PoolRegistration certificate from CBOR
    /// - Parameter decoder: The decoder
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)
        
        guard case Self.CODE.rawValue = code else {
            throw CardanoCoreError.deserializeError("Invalid PoolRegistration type: \(code)")
        }
        
        // Check if the next element is a nested array
        let poolParams: PoolParams
        do {
            poolParams = try container.decode(PoolParams.self)
        } catch {
            poolParams = PoolParams(
                poolOperator: try container.decode(PoolKeyHash.self),
                vrfKeyHash: try container.decode(VrfKeyHash.self),
                pledge: try container.decode(Int.self),
                cost: try container.decode(Int.self),
                margin: try container.decode(UnitInterval.self),
                rewardAccount: try container.decode(RewardAccountHash.self),
                poolOwners: try container.decode(CBORSet<VerificationKeyHash>.self),
                relays: try container.decode([Relay].self),
                poolMetadata: try container.decode(PoolMetadata.self),
                id: nil
            )
        }
        
        self.init(poolParams: poolParams)
    }
    
    /// The encode function
    /// - Parameter encoder: The encoder
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(Self.CODE.rawValue)
        
        try container.encode(poolParams.poolOperator)
        try container.encode(poolParams.vrfKeyHash)
        try container.encode(poolParams.pledge)
        try container.encode(poolParams.cost)
        
        try container.encode(poolParams.margin)
        
        try container.encode(poolParams.rewardAccount)
        try container.encode(poolParams.poolOwners)
        try container.encode(poolParams.relays)
        try container.encode(poolParams.poolMetadata)
    }
}
