import Foundation
import PotentCBOR

/// Holds a cryptographic key and some metadata for a verification key.
public struct VKey: VerificationKey {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public static var TYPE: String { "" }
    public static var DESCRIPTION: String { "Verification Key" }
    
    public init(payload: Data, type: String?, description: String?) {
        // For verification keys, we should almost always use raw bytes
        // Only try CBOR decoding if the payload looks like it might be CBOR-encoded
        // and is significantly larger than expected key sizes (32 or 64 bytes)
        let actualPayload: Data
        
        if payload.count > 70 && payload.count > 32 && payload.count > 64 {
            // Only try CBOR decoding for significantly larger payloads that might be wrapped
            if let payloadData = try? CBORDecoder().decode(Data.self, from: payload) {
                actualPayload = payloadData
            } else {
                actualPayload = payload
            }
        } else {
            // For payloads that are around the expected key size, use them directly
            actualPayload = payload
        }
        
        self._payload = actualPayload
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
    }
}

/// Holds a cryptographic key and some metadata for a signing key.
public struct SKey: SigningKey {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public static var TYPE: String { "" }
    public static var DESCRIPTION: String { "Signing Key" }
    
    public init(payload: Data, type: String?, description: String?) {
        if let payloadData = try? CBORDecoder().decode(Data.self, from: payload) {
            self._payload = payloadData
        } else {
            self._payload = payload
        }
        
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
    }
}


/// Holds a cryptographic key and some metadata for an extended verification key.
public struct ExtendedVKey: ExtendedVerificationKey {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public static var TYPE: String { "" }
    public static var DESCRIPTION: String { "Extended Verification Key" }
    
    public init(payload: Data, type: String?, description: String?) {
        let actualPayload: Data
        if let payloadData = try? CBORDecoder().decode(Data.self, from: payload) {
            actualPayload = payloadData
        } else {
            actualPayload = payload
        }
        
        self._payload = actualPayload
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
    }
}

/// Holds a cryptographic key and some metadata for an extended signing key.
public struct ExtendedSKey: ExtendedSigningKey {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public static var TYPE: String { "" }
    public static var DESCRIPTION: String { "Extended Signing Key" }
    
    public init(payload: Data, type: String?, description: String?) {
        if let payloadData = try? CBORDecoder().decode(Data.self, from: payload) {
            self._payload = payloadData
        } else {
            self._payload = payload
        }
        
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
    }
}
