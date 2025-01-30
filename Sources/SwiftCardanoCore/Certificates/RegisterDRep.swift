import Foundation
import PotentCBOR

/// DRep registration certificate
struct RegisterDRep: CertificateSerializable {
    var _payload: Data
    var _type: String
    var _description: String

    var type: String { get { return RegisterDRep.TYPE } }
    var description: String {
        get {
            switch self.drepCredential.credential {
                case .verificationKeyHash(_):
                    return "DRep Key Registration Certificate"
                case .scriptHash(_):
                    return "DRep Script Registration Certificate"
            }
        }
    }

    static var TYPE: String { CertificateType.conway.rawValue }
    static var DESCRIPTION: String { CertificateDescription.registerDRep.rawValue }
    static var CODE: CertificateCode { get { return .registerDRep } }
    
    let drepCredential: DRepCredential
    let coin: Coin
    let anchor: Anchor?
    
    /// Initialize a new `RegisterDRep` certificate
    /// - Parameters:
    ///  - drepCredential: The DRep credential
    ///  - coin: The coin
    ///  - anchor: The anchor
    init(drepCredential: DRepCredential, coin: Coin, anchor: Anchor? = nil) {
        self.drepCredential = drepCredential
        self.coin = coin
        self.anchor = anchor
        
        self._payload =  try! CBORSerialization.data(from:
                .array(
                    [
                        CBOR(integerLiteral: Self.CODE.rawValue),
                        try! CBOREncoder().encode(drepCredential).toCBOR,
                        try! CBOREncoder().encode(coin).toCBOR,
                        try! CBOREncoder().encode(anchor).toCBOR
                    ]
                )
        )
        self._type = Self.TYPE
        self._description = Self.DESCRIPTION
    }
    
    /// Initialize a new `RegisterDRep` certificate from its Text Envelope representation
    /// - Parameters:
    ///  - payload: The CBOR representation of the certificate
    ///  - type: The type of the certificate
    ///  - description: The description of the certificate
    init(payload: Data, type: String?, description: String?) {
        self._payload = payload
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
        
        let cbor = try! CBORDecoder().decode(RegisterDRep.self, from: payload)
        
        self.drepCredential = cbor.drepCredential
        self.coin = cbor.coin
        self.anchor = cbor.anchor
    }
    
    /// Initialize a new `RegisterDRep` certificate from its CBOR representation
    /// - Parameter decoder: The decoder
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)
        
        guard case Self.CODE.rawValue = code else {
            throw CardanoCoreError.deserializeError("Invalid RegisterDRep type: \(code)")
        }
        
        let drepCredential = try container.decode(DRepCredential.self)
        let coin = try container.decode(Coin.self)
        let anchor = try container.decodeIfPresent(Anchor.self)
        
        self.init(drepCredential: drepCredential, coin: coin, anchor: anchor)
    }
    
    /// Encode the `RegisterDRep` certificate
    /// - Parameter encoder: The encoder
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(Self.CODE.rawValue)
        try container.encode(drepCredential)
        try container.encode(coin)
        try container.encode(anchor)
    }
}
