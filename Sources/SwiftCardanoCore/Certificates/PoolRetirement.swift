import Foundation
import PotentCBOR

/// Stake Pool Retirement Certificate
public struct PoolRetirement: CertificateSerializable {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public var type: String { get { return PoolRetirement.TYPE } }
    public var description: String { get { return PoolRetirement.DESCRIPTION } }

    public static var TYPE: String { CertificateType.conway.rawValue }
    public static var DESCRIPTION: String { CertificateDescription.poolRetirement.rawValue }
    public static var CODE: CertificateCode { get { return .poolRetirement } }
    
    public let poolKeyHash: PoolKeyHash
    public let epoch: Int
    
    /// Initialize a new PoolRetirement certificate
    /// - Parameters:
    ///   - poolKeyHash: The pool key hash
    ///   - epoch: The epoch
    public init(poolKeyHash: PoolKeyHash, epoch: Int) {
        self.poolKeyHash = poolKeyHash
        self.epoch = epoch
        
        self._payload =  try! CBORSerialization.data(from:
                .array(
                    [
                        CBOR(integerLiteral: Self.CODE.rawValue),
                        try! CBOREncoder().encode(poolKeyHash).toCBOR,
                        try! CBOREncoder().encode(epoch).toCBOR,
                    ]
                )
        )
        self._type = Self.TYPE
        self._description = Self.DESCRIPTION
    }
    
    /// Initialize a new PoolRetirement certificate from a CBOR payload
    /// - Parameters:
    ///   - payload: The payload of the certificate
    ///   - type: The type of the certificate
    ///   - description: The description of the certificate
    public init(payload: Data, type: String?, description: String?) {
        self._payload = payload
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
        
        let cbor = try! CBORDecoder().decode(Self.self, from: payload)
        
        self.poolKeyHash = cbor.poolKeyHash
        self.epoch = cbor.epoch
    }
    
    
    /// Initialize a new PoolRetirement certificate from CBOR
    /// - Parameter decoder: The decoder
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)
        
        guard case Self.CODE.rawValue = code else {
            throw CardanoCoreError.deserializeError("Invalid PoolRetirement type: \(code)")
        }
        
        let poolKeyHash = try container.decode(PoolKeyHash.self)
        let epoch = try container.decode(Int.self)
        
        self.init(poolKeyHash: poolKeyHash, epoch: epoch)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(Self.CODE.rawValue)
        try container.encode(poolKeyHash)
        try container.encode(epoch)
    }
}
