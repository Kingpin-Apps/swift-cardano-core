import Foundation
import PotentCBOR

struct VKey: VerificationKey {
    var _payload: Data
    var _type: String
    var _description: String

    static var TYPE: String { "" }
    static var DESCRIPTION: String { "Verification Key" }
    
    init(payload: Data, type: String?, description: String?) {
        if let payloadData = try? CBORDecoder().decode(Data.self, from: payload) {
            self._payload = payloadData
        } else {
            self._payload = payload
        }
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
    }
}

struct SKey: SigningKey {
    var _payload: Data
    var _type: String
    var _description: String

    static var TYPE: String { "" }
    static var DESCRIPTION: String { "Signing Key" }
    
    init(payload: Data, type: String?, description: String?) {
        if let payloadData = try? CBORDecoder().decode(Data.self, from: payload) {
            self._payload = payloadData
        } else {
            self._payload = payload
        }
        
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
    }
}


struct ExtendedVKey: ExtendedVerificationKey {
    var _payload: Data
    var _type: String
    var _description: String

    static var TYPE: String { "" }
    static var DESCRIPTION: String { "Extended Verification Key" }
    
    init(payload: Data, type: String?, description: String?) {
        if let payloadData = try? CBORDecoder().decode(Data.self, from: payload) {
            self._payload = payloadData
        } else {
            self._payload = payload
        }
        
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
    }
}

struct ExtendedSKey: ExtendedSigningKey {
    var _payload: Data
    var _type: String
    var _description: String

    static var TYPE: String { "" }
    static var DESCRIPTION: String { "Extended Signing Key" }
    
    init(payload: Data, type: String?, description: String?) {
        if let payloadData = try? CBORDecoder().decode(Data.self, from: payload) {
            self._payload = payloadData
        } else {
            self._payload = payload
        }
        
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
    }
}
