import Foundation

/// A class that holds a cryptographic key and some metadata. e.g. signing key, verification key.
class Key: PayloadCBORSerializable {
    class var TYPE: String  { return "" }
    class var DESCRIPTION: String { return "" }

    internal var _payload: Data
    internal var _type: String
    internal var _description: String
    
    required init(payload: Data) {
        self._payload = payload
        self._type = Self.TYPE
        self._description = Self.DESCRIPTION
    }
    
    required init(
        payload: Data,
        type: String? = nil,
        description: String? = nil
    ) {
        self._payload = payload
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
    }
}
