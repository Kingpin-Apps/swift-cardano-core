import Foundation
import PotentCBOR

/// Un-Register a stake credential with an optional refund amount
public struct Unregister: CertificateSerializable {
    public var _payload: Data
    public var _type: String
    public var _description: String
    
    public var type: String { get { return Unregister.TYPE } }
    public var description: String { get { return Unregister.DESCRIPTION } }

    public static var TYPE: String { CertificateType.conway.rawValue }
    public static var DESCRIPTION: String { CertificateDescription.stakeDeregistration.rawValue }
    public static var CODE: CertificateCode { get { return .unregister } }
    
    public let stakeCredential: StakeCredential
    public let coin: Coin
    
    /// Initialize a new `Unregister` certificate
    /// - Parameters:
    ///   - stakeCredential: The stake credential
    ///   - coin: The coin
    public init(stakeCredential: StakeCredential, coin: Coin) {
        self.stakeCredential = stakeCredential
        self.coin = coin
        
        self._payload =  try! CBORSerialization.data(from:
                .array(
                    [
                        CBOR(integerLiteral: Self.CODE.rawValue),
                        try! CBOREncoder().encode(stakeCredential).toCBOR,
                        try! CBOREncoder().encode(coin).toCBOR
                    ]
                )
        )
        
        self._type = Self.TYPE
        self._description = Self.DESCRIPTION
    }
    
    /// Initialize `Unregister` certificate from payload, type, and description
    /// - Parameters:
    ///   - payload: The payload of the certificate
    ///   - type: The type of the certificate
    ///   - description: The description of the certificate
    public init(payload: Data, type: String?, description: String?) {
        self._payload = payload
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
        
        let cbor = try! CBORDecoder().decode(Unregister.self, from: payload)
        
        self.stakeCredential = cbor.stakeCredential
        self.coin = cbor.coin
    }
    
    public init(from primitive: Primitive) throws {
        guard case let .list(primitive) = primitive,
              primitive.count == 3,
              case let .uint(code) = primitive[0],
              case let .uint(coin) = primitive[2],
              code == Self.CODE.rawValue else {
            throw CardanoCoreError.deserializeError("Invalid Unregister type")
        }
        
        let stakeCredential = try StakeCredential(from: primitive[1])
        
        self.init(stakeCredential: stakeCredential, coin: Coin(coin))
    }
    
    public func toPrimitive() throws -> Primitive {
        return .list([
            .uint(UInt(Self.CODE.rawValue)),
            try stakeCredential.toPrimitive(),
            .int(Int(coin))
        ])
    }
}

