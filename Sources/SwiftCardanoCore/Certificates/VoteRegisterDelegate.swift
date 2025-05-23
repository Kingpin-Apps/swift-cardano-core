import Foundation
import PotentCBOR

public struct VoteRegisterDelegate: CertificateSerializable {
    public var _payload: Data
    public var _type: String
    public var _description: String
    
    public var type: String { get { return VoteRegisterDelegate.TYPE } }
    public var description: String { get { return VoteRegisterDelegate.DESCRIPTION } }

    public static var TYPE: String { CertificateType.conway.rawValue }
    public static var DESCRIPTION: String { CertificateDescription.voteRegisterDelegate.rawValue }
    public static var CODE: CertificateCode { get { return .voteRegisterDelegate } }
    
    public let stakeCredential: StakeCredential
    public let drep: DRep
    public let coin: Coin
    
    /// Initialize a new `VoteRegisterDelegate` certificate
    /// - Parameters:
    ///  - stakeCredential: The stake credential
    ///  - drep: The DRep
    ///  - coin: The coin
    public init(stakeCredential: StakeCredential, drep: DRep, coin: Coin) {
        self.stakeCredential = stakeCredential
        self.drep = drep
        self.coin = coin
        
        self._payload =  try! CBORSerialization.data(from:
                .array(
                    [
                        CBOR(integerLiteral: Self.CODE.rawValue),
                        try! CBOREncoder().encode(stakeCredential).toCBOR,
                        try! CBOREncoder().encode(drep).toCBOR,
                        try! CBOREncoder().encode(coin).toCBOR
                    ]
                )
        )
        self._type = Self.TYPE
        self._description = Self.DESCRIPTION
    }
    
    /// Initialize a new `VoteRegisterDelegate` certificate from its Text Envelope representation
    /// - Parameters:
    ///  - payload: The CBOR representation of the certificate
    ///  - type: The type of the certificate
    ///  - description: The description of the certificate
    public init(payload: Data, type: String?, description: String?) {
        self._payload = payload
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
        
        let cbor = try! CBORDecoder().decode(VoteRegisterDelegate.self, from: payload)
        
        self.stakeCredential = cbor.stakeCredential
        self.drep = cbor.drep
        self.coin = cbor.coin
    }
    
    /// Initialize a new `VoteRegisterDelegate` certificate from its CBOR representation
    /// - Parameter decoder: The decoder
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)
        
        guard case Self.CODE.rawValue = code else {
            throw CardanoCoreError.deserializeError("Invalid VoteRegisterDelegate type: \(code)")
        }
        
        let stakeCredential = try container.decode(StakeCredential.self)
        let drep = try container.decode(DRep.self)
        let coin = try container.decode(Coin.self)
        
        self.init(stakeCredential: stakeCredential, drep: drep, coin: coin)
    }
    
    /// Encode the `VoteRegisterDelegate` certificate
    /// - Parameter encoder: The encoder
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(Self.CODE.rawValue)
        try container.encode(stakeCredential)
        try container.encode(drep)
        try container.encode(coin)
    }
}
