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
    
    public init(from primitive: Primitive) throws {
        guard case let .list(primitive) = primitive,
              primitive.count == 4,
              case let .int(code) = primitive[0],
              case let .int(coin) = primitive[3],
              code == Self.CODE.rawValue else {
            throw CardanoCoreError.deserializeError("Invalid VoteRegisterDelegate type")
        }
        
        let stakeCredential = try StakeCredential(from: primitive[1])
        let drep = try DRep(from: primitive[2])
        
        self.init(stakeCredential: stakeCredential, drep: drep, coin: Coin(coin))
    }
    
    public func toPrimitive() throws -> Primitive {
        return .list([
            .int(Int(Self.CODE.rawValue)),
            try stakeCredential.toPrimitive(),
            try drep.toPrimitive(),
            .int(Int(coin))
        ])
    }
}
