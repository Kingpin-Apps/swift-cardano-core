import Foundation
import PotentCBOR

/// Register a stake credential with an optional deposit amount.
public struct Register: CertificateSerializable {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public var type: String { get { return Register.TYPE } }
    public var description: String { get { return Register.DESCRIPTION } }

    public static var TYPE: String { CertificateType.conway.rawValue }
    public static var DESCRIPTION: String { CertificateDescription.stakeRegistration.rawValue }
    public static var CODE: CertificateCode { get { return .register } }
    
    public let stakeCredential: StakeCredential
    public let coin: Coin
    
    /// Initialize Register certificate
    /// - Parameters:
    ///   - stakeCredential: The stake credential to register
    ///   - coin: The coin to deposit
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
    
    /// Initialize Register certificate from payload, type, and description
    /// - Parameters:
    ///   - payload: The payload of the certificate
    ///   - type: The type of the certificate
    ///   - description: The description of the certificate
    public init(payload: Data, type: String?, description: String?) {
        self._payload = payload
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
        
        let cbor = try! CBORDecoder().decode(Register.self, from: payload)
        
        self.stakeCredential = cbor.stakeCredential
        self.coin = cbor.coin
    }
    
    
    /// Initialize Register certificate from CBOR
    /// - Parameter decoder: The decoder to use
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)
        
        guard case Self.CODE.rawValue = code else {
            throw CardanoCoreError.deserializeError("Invalid Register type: \(code)")
        }
        
        let stakeCredential = try container.decode(StakeCredential.self)
        let coin = try container.decode(Coin.self)
        
        self.init(stakeCredential: stakeCredential, coin: coin)
    }
    
    /// Encode the Register certificate to CBOR
    /// - Parameter encoder: The encoder to use
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(Self.CODE.rawValue)
        try container.encode(stakeCredential)
        try container.encode(coin)
    }
}
