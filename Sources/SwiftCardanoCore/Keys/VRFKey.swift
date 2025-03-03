import Foundation
import SwiftNcal
import PotentCBOR

public struct VRFSigningKey: SigningKey {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public static var TYPE: String { "VrfSigningKey_PraosVRF" }
    public static var DESCRIPTION: String { "VRF Signing Key" }
    
    public init(payload: Data, type: String?, description: String?) {
        if let payloadData = try? CBORDecoder().decode(Data.self, from: payload) {
            self._payload = payloadData
        } else {
            self._payload = payload
        }
        
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
    }
    
    public func sign(data: Data) throws -> Data {
//        return try VRF.sign(data: data, with: self)?
        fatalError("Not implemented")
    }
    
    public func toVerificationKey<T>() throws -> T where T: VerificationKey {
//        return try VRFVerificationKey.fromSigningKey(self) as! T
        fatalError("Not implemented")
    }
    
    public  static func generate() throws -> Self {
        //        return try VRFSigningKey(from: VRF.generate())
        fatalError("Not implemented")
    }
}

public struct VRFVerificationKey: VerificationKey {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public static var TYPE: String { "VrfVerificationKey_PraosVRF" }
    public static var DESCRIPTION: String { "VRF Verification Key" }
    
    public init(payload: Data, type: String?, description: String?) {
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
    public func hash() throws -> VrfKeyHash {
        return VrfKeyHash(
            payload: try SwiftNcal.Hash().blake2b(
                data: payload,
                digestSize: VRF_KEY_HASH_SIZE,
                encoder: RawEncoder.self
            )
        )
    }
    
    public static func fromSigningKey<T>(_ key: any SigningKey) throws -> T where T: VerificationKey {
//        return try key.toVerificationKey()
        fatalError("Not implemented")
    }
}
