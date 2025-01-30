import Foundation
import PotentCBOR

/// Un-Register a stake credential with an optional refund amount
struct Unregister: CertificateSerializable {
    var _payload: Data
    var _type: String
    var _description: String
    
    var type: String { get { return Unregister.TYPE } }
    var description: String { get { return Unregister.DESCRIPTION } }

    static var TYPE: String { CertificateType.conway.rawValue }
    static var DESCRIPTION: String { CertificateDescription.unregister.rawValue }
    static var CODE: CertificateCode { get { return .unregister } }
    
    let stakeCredential: StakeCredential
    let coin: Coin
    
    /// Initialize a new `Unregister` certificate
    /// - Parameters:
    ///   - stakeCredential: The stake credential
    ///   - coin: The coin
    init(stakeCredential: StakeCredential, coin: Coin) {
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
    init(payload: Data, type: String?, description: String?) {
        self._payload = payload
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
        
        let cbor = try! CBORDecoder().decode(Unregister.self, from: payload)
        
        self.stakeCredential = cbor.stakeCredential
        self.coin = cbor.coin
    }
    
    /// Initialize a new `Unregister` certificate from its Text Envelope representation
    /// - Parameter decoder: The decoder
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)
        
        guard case Self.CODE.rawValue = code else {
            throw CardanoCoreError.deserializeError("Invalid Unregister type: \(code)")
        }
        
        let stakeCredential = try container.decode(StakeCredential.self)
        let coin = try container.decode(Coin.self)
        
        self.init(stakeCredential: stakeCredential, coin: coin)
    }
    
    /// Encode the `Unregister` certificate
    /// - Parameter encoder: The encoder
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(Self.CODE.rawValue)
        try container.encode(stakeCredential)
        try container.encode(coin)
    }
}

