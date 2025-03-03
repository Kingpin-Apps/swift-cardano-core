import Foundation
import PotentCBOR


public struct UnregisterDRep: CertificateSerializable {
    public var _payload: Data
    public var _type: String
    public var _description: String
    
    public var type: String { get { return UnregisterDRep.TYPE } }
    public var description: String { get { return UnregisterDRep.DESCRIPTION } }

    public static var TYPE: String { CertificateType.conway.rawValue }
    public static var DESCRIPTION: String { CertificateDescription.unRegisterDRep.rawValue }
    public static var CODE: CertificateCode { get { return .unRegisterDRep } }
    
    public let drepCredential: DRepCredential
    public let coin: Coin
    
    /// Initialize a new `UnregisterDRep` certificate
    /// - Parameters:
    ///  - drepCredential: The DRep credential
    ///  - coin: The coin
    public init(drepCredential: DRepCredential, coin: Coin) {
        self.drepCredential = drepCredential
        self.coin = coin
        
        self._payload =  try! CBORSerialization.data(from:
                .array(
                    [
                        CBOR(integerLiteral: Self.CODE.rawValue),
                        try! CBOREncoder().encode(drepCredential).toCBOR,
                        try! CBOREncoder().encode(coin).toCBOR
                    ]
                )
        )
        self._type = Self.TYPE
        self._description = Self.DESCRIPTION
    }
    
    /// Initialize a new `UnregisterDRep` certificate from its Text Envelope representation
    /// - Parameters:
    ///  - payload: The CBOR representation of the certificate
    ///  - type: The type of the certificate
    ///  - description: The description of the certificate
    public init(payload: Data, type: String?, description: String?) {
        self._payload = payload
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
        
        let cbor = try! CBORDecoder().decode(UnregisterDRep.self, from: payload)
        
        self.drepCredential = cbor.drepCredential
        self.coin = cbor.coin
    }
    
    /// Initialize a new `UnregisterDRep` certificate from its CBOR representation
    /// - Parameter decoder: The decoder
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)
        
        guard case Self.CODE.rawValue = code else {
            throw CardanoCoreError.deserializeError("Invalid UnregisterDRep type: \(code)")
        }
        
        let drepCredential = try container.decode(DRepCredential.self)
        let coin = try container.decode(Coin.self)
        
        self.init(drepCredential: drepCredential, coin: coin)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(Self.CODE.rawValue)
        try container.encode(drepCredential)
        try container.encode(coin)
    }
}
