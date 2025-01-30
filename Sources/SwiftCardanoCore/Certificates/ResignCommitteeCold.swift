import Foundation
import PotentCBOR

/// Resign Committee Cold certificate
struct ResignCommitteeCold: CertificateSerializable {
    var _payload: Data
    var _type: String
    var _description: String

    var type: String { get { return ResignCommitteeCold.TYPE } }
    var description: String { get { return ResignCommitteeCold.DESCRIPTION } }

    static var TYPE: String { CertificateType.conway.rawValue }
    static var DESCRIPTION: String { CertificateDescription.resignCommitteeCold.rawValue }
    static var CODE: CertificateCode { get { return .resignCommitteeCold } }
    
    let committeeColdCredential: CommitteeColdCredential
    let anchor: Anchor?
    
    /// Initialize a new `ResignCommitteeCold` certificate
    /// - Parameters:
    ///   - committeeColdCredential: The committee cold credential
    ///   - anchor: The anchor
    init(committeeColdCredential: CommitteeColdCredential, anchor: Anchor? = nil) {
        self.committeeColdCredential = committeeColdCredential
        self.anchor = anchor
        
        self._payload =  try! CBORSerialization.data(from:
                .array(
                    [
                        CBOR(integerLiteral: Self.CODE.rawValue),
                        try! CBOREncoder().encode(committeeColdCredential).toCBOR,
                        try! CBOREncoder().encode(anchor).toCBOR
                    ]
                )
        )
        self._type = Self.TYPE
        self._description = Self.DESCRIPTION
    }
    
    /// Initialize ResignCommitteeCold certificate from payload, type, and description
    /// - Parameters:
    ///   - payload: The payload of the certificate
    ///   - type: The type of the certificate
    ///   - description: The description of the certificate
    init(payload: Data, type: String?, description: String?) {
        self._payload = payload
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
        
        let cbor = try! CBORDecoder().decode(ResignCommitteeCold.self, from: payload)
        
        self.committeeColdCredential = cbor.committeeColdCredential
        self.anchor = cbor.anchor
    }

    /// Initialize ResignCommitteeCold certificate from CBOR
    /// - Parameter decoder: The decoder to use
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)
        
        guard case Self.CODE.rawValue = code else {
            throw CardanoCoreError.deserializeError("Invalid ResignCommitteeCold type: \(code)")
        }
        
        let committeeColdCredential = try container.decode(CommitteeColdCredential.self)
        let anchor = try container.decodeIfPresent(Anchor.self)
        
        self.init(committeeColdCredential: committeeColdCredential, anchor: anchor)
    }
    
    /// Encode ResignCommitteeCold certificate to CBOR
    /// - Parameter encoder: The encoder to use
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(Self.CODE.rawValue)
        try container.encode(committeeColdCredential)
        try container.encode(anchor)
    }
}

