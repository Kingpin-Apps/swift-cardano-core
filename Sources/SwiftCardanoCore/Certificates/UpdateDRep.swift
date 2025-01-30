import Foundation
import PotentCBOR

struct UpdateDRep: CertificateSerializable {
    var _payload: Data
    var _type: String
    var _description: String
    
    var type: String { get { return UpdateDRep.TYPE } }
    var description: String {
        get {
            switch self.drepCredential.credential {
                case .verificationKeyHash(_):
                    return "DRep Key Update Certificate"
                case .scriptHash(_):
                    return "DRep Script Update Certificate"
            }
        }
    }

    static var TYPE: String { CertificateType.conway.rawValue }
    static var DESCRIPTION: String { CertificateDescription.updateDRep.rawValue }
    static var CODE: CertificateCode { get { return .updateDRep } }
    
    let drepCredential: DRepCredential
    let anchor: Anchor?
    
    /// Initialize a new `UpdateDRep` certificate
    /// - Parameters:
    ///  - drepCredential: The DRep credential
    ///  - anchor: The anchor
    init(drepCredential: DRepCredential, anchor: Anchor? = nil) {
        self.drepCredential = drepCredential
        self.anchor = anchor
        
        self._payload =  try! CBORSerialization.data(from:
                .array(
                    [
                        CBOR(integerLiteral: Self.CODE.rawValue),
                        try! CBOREncoder().encode(drepCredential).toCBOR,
                        try! CBOREncoder().encode(anchor).toCBOR
                    ]
                )
        )
        self._type = Self.TYPE
        self._description = Self.DESCRIPTION
    }
    
    /// Initialize a new `UpdateDRep` certificate from its Text Envelope representation
    /// - Parameters:
    ///  - payload: The CBOR representation of the certificate
    ///  - type: The type of the certificate
    ///  - description: The description of the certificate
    init(payload: Data, type: String?, description: String?) {
        self._payload = payload
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
        
        let cbor = try! CBORDecoder().decode(UpdateDRep.self, from: payload)
        
        self.drepCredential = cbor.drepCredential
        self.anchor = cbor.anchor
    }
    
    /// Initialize a new `UpdateDRep` certificate from its CBOR representation
    /// - Parameter decoder: The decoder
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)
        
        guard case Self.CODE.rawValue = code else {
            throw CardanoCoreError.deserializeError("Invalid UpdateDRep type: \(code)")
        }
        
        let drepCredential = try container.decode(DRepCredential.self)
        let anchor = try container.decode(Anchor.self)
        
        self.init(drepCredential: drepCredential, anchor: anchor)
    }
    
    /// Encode the `UpdateDRep` certificate to the given encoder
    /// - Parameter encoder: The encoder
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(Self.CODE.rawValue)
        try container.encode(drepCredential)
        try container.encode(anchor)
    }
}
