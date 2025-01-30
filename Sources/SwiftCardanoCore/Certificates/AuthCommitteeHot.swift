import Foundation
import PotentCBOR


/// Auth Committee Hot Key Registration Certificate
struct AuthCommitteeHot: CertificateSerializable {
    var _payload: Data
    var _type: String
    var _description: String

    var type: String { get { return AuthCommitteeHot.TYPE } }
    var description: String { get { return AuthCommitteeHot.DESCRIPTION } }

    static var TYPE: String { CertificateType.conway.rawValue }
    static var DESCRIPTION: String { CertificateDescription.authCommitteeHot.rawValue }
    static var CODE: CertificateCode { get { return .authCommitteeHot } }
    
    let committeeColdCredential: CommitteeColdCredential
    let committeeHotCredential: CommitteeHotCredential
    
    /// Initialize AuthCommitteeHot from committeeColdCredential and committeeHotCredential
    /// - Parameters:
    ///   - committeeColdCredential: The cold key credential of the committee
    ///   - committeeHotCredential: The hot key credential of the committee
    init(committeeColdCredential: CommitteeColdCredential,
         committeeHotCredential: CommitteeHotCredential) {
        self.committeeColdCredential = committeeColdCredential
        self.committeeHotCredential = committeeHotCredential
        
        self._payload =  try! CBORSerialization.data(from:
                .array(
                    [
                        CBOR(integerLiteral: Self.CODE.rawValue),
                        try! CBOREncoder().encode(committeeColdCredential).toCBOR,
                        try! CBOREncoder().encode(committeeHotCredential).toCBOR
                    ]
                )
        )
        self._type = Self.TYPE
        self._description = Self.DESCRIPTION
    }
    
    /// Initialize AuthCommitteeHot certificate from payload, type, and description
    /// - Parameters:
    ///   - payload: The payload of the certificate
    ///   - type: The type of the certificate
    ///   - description: The description of the certificate
    init(payload: Data, type: String?, description: String?) {
        self._payload = payload
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
        
        let cbor = try! CBORDecoder().decode(AuthCommitteeHot.self, from: payload)
        
        self.committeeColdCredential = cbor.committeeColdCredential
        self.committeeHotCredential = cbor.committeeHotCredential
    }

    
    /// Initialize AuthCommitteeHot certificate from CBOR
    /// - Parameter decoder: The decoder to use
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)
        
        guard case Self.CODE.rawValue = code else {
            throw CardanoCoreError.deserializeError("Invalid AuthCommitteeHot type: \(code)")
        }
        
        let committeeColdCredential = try container.decode(CommitteeColdCredential.self)
        let committeeHotCredential = try container.decode(CommitteeHotCredential.self)
        
        self.init(
            committeeColdCredential: committeeColdCredential,
            committeeHotCredential: committeeHotCredential
        )
    }
    
    /// Encode AuthCommitteeHot to CBOR
    /// - Parameter encoder: The encoder to use
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(Self.CODE.rawValue)
        try container.encode(committeeColdCredential)
        try container.encode(committeeHotCredential)
    }
}
