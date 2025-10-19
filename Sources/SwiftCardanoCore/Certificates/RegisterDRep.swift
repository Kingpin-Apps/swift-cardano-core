import Foundation
import PotentCBOR

/// DRep registration certificate
public struct RegisterDRep: CertificateSerializable {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public var type: String { get { return RegisterDRep.TYPE } }
    public var description: String {
        get {
            switch self.drepCredential.credential {
                case .verificationKeyHash(_):
                    return "DRep Key Registration Certificate"
                case .scriptHash(_):
                    return "DRep Script Registration Certificate"
            }
        }
    }

    public static var TYPE: String { CertificateType.conway.rawValue }
    public static var DESCRIPTION: String { CertificateDescription.registerDRep.rawValue }
    public static var CODE: CertificateCode { get { return .registerDRep } }
    
    public let drepCredential: DRepCredential
    public let coin: Coin
    public let anchor: Anchor?
    
    /// Initialize a new `RegisterDRep` certificate
    /// - Parameters:
    ///  - drepCredential: The DRep credential
    ///  - coin: The coin
    ///  - anchor: The anchor
    public init(drepCredential: DRepCredential, coin: Coin, anchor: Anchor? = nil) {
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
    public init(payload: Data, type: String?, description: String?) {
        self._payload = payload
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
        
        let cbor = try! CBORDecoder().decode(RegisterDRep.self, from: payload)
        
        self.drepCredential = cbor.drepCredential
        self.coin = cbor.coin
        self.anchor = cbor.anchor
    }
    
    public init(from primitive: Primitive) throws {
        guard case let .list(primitive) = primitive,
              primitive.count == 4,
              case let .uint(code) = primitive[0],
              case let .uint(coin) = primitive[2],
              code == Self.CODE.rawValue else {
            throw CardanoCoreError.deserializeError("Invalid RegisterDRep type")
        }
        
        let drepCredential = try DRepCredential(from: primitive[1])
        let anchor = try? Anchor(from: primitive[3])
        
        self.init(drepCredential: drepCredential, coin: Coin(coin), anchor: anchor)
    }
    
    public func toPrimitive() throws -> Primitive {
        return .list([
            .uint(UInt(Self.CODE.rawValue)),
            try drepCredential.toPrimitive(),
            .int(Int(coin)),
            try anchor?.toPrimitive() ?? .null
        ])
    }
}
