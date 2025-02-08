import Foundation
import SwiftNcal
import PotentCBOR

struct VRFSigningKey: SigningKey {
    var _payload: Data
    var _type: String
    var _description: String

    static var TYPE: String { "VrfSigningKey_PraosVRF" }
    static var DESCRIPTION: String { "VRF Signing Key" }
    
    init(payload: Data, type: String?, description: String?) {
        if let payloadData = try? CBORDecoder().decode(Data.self, from: payload) {
            self._payload = payloadData
        } else {
            self._payload = payload
        }
        
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
    }
    
    func sign(data: Data) throws -> Data {
//        return try VRF.sign(data: data, with: self)?
        fatalError("Not implemented")
    }
    
    func toVerificationKey<T>() throws -> T where T: VerificationKey {
//        return try VRFVerificationKey.fromSigningKey(self) as! T
        fatalError("Not implemented")
    }
    
    static func generate() throws -> Self {
        //        return try VRFSigningKey(from: VRF.generate())
        fatalError("Not implemented")
    }
}

struct VRFVerificationKey: VerificationKey {
    var _payload: Data
    var _type: String
    var _description: String

    static var TYPE: String { "VrfVerificationKey_PraosVRF" }
    static var DESCRIPTION: String { "VRF Verification Key" }
    
    init(payload: Data, type: String?, description: String?) {
        if let payloadData = try? CBORDecoder().decode(Data.self, from: payload) {
            self._payload = payloadData
        } else {
            self._payload = payload
        }
        
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
    }
    
    /// Compute a blake2b hash from the key
    /// - Returns: Hash output in bytes.
    func hash() throws -> VrfKeyHash {
        return VrfKeyHash(
            payload: try SwiftNcal.Hash().blake2b(
                data: payload,
                digestSize: VRF_KEY_HASH_SIZE,
                encoder: RawEncoder.self
            )
        )
    }
    
    static func fromSigningKey<T>(_ key: any SigningKey) throws -> T where T: VerificationKey {
//        return try key.toVerificationKey()
        fatalError("Not implemented")
    }
}
