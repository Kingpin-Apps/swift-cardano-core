import OrderedCollections

/// A type that converts to and from ``PlutusData``.
///
/// A conforming type provides ``init(from:)-(PlutusData)`` and ``toPlutusData()``; the protocol extension builds the CBOR, dictionary and JSON conversions, the datum hash and equality on top of them.
public protocol PlutusDataProtocol: Serializable {
    /// Creates a value from Plutus data.
    ///
    /// - Parameter plutusData: The Plutus data.
    /// - Throws: When the Plutus data does not describe a value of this type.
    init(from plutusData: PlutusData) throws
    
    /// The value as Plutus data.
    ///
    /// - Returns: The Plutus data.
    /// - Throws: When the value cannot be converted.
    func toPlutusData() throws -> PlutusData

    /// The datum hash of the value. The default hashes a fresh encoding of
    /// ``toPlutusData()``; a type that keeps the bytes it was read from
    /// hashes those.
    ///
    /// - Returns: The datum hash.
    /// - Throws: When the value cannot be converted or hashed.
    func hash() throws -> DatumHash
}

extension PlutusDataProtocol {
    public init(from primitive: Primitive) throws {
        let plutusData = try PlutusData(from: primitive)
        try self.init(from: plutusData)
    }
    
    /// Creates a value from the dictionary form of its Plutus data.
    ///
    /// - Parameter dict: The dictionary form, as ``PlutusData/fromDict(_:)`` reads it.
    /// - Throws: When the dictionary is not valid Plutus data, or does not describe a value of this type.
    public init(from dict: OrderedDictionary<Primitive, Primitive>) throws {
        let plutusData = try PlutusData.fromDict(.orderedDict(dict))
        try self.init(from: plutusData)
    }
    
    /// The datum hash of the value's Plutus data.
    ///
    /// - Returns: The datum hash.
    /// - Throws: When the value cannot be converted or hashed.
    public func hash() throws -> DatumHash {
        let plutusData = try self.toPlutusData()
        return try datumHash(datum: .plutusData(plutusData))
    }
    
    public func toPrimitive() throws -> Primitive {
        return try self.toPlutusData().toPrimitive()
    }
    
    /// The value's Plutus data as JSON text.
    ///
    /// - Returns: The JSON text.
    /// - Throws: When the value cannot be converted.
    public func toJSON() throws -> String? {
        let plutusData = try self.toPlutusData()
        return try plutusData.toJSON()
    }
    
    public func toDict() throws -> Primitive {
        let plutusData = try self.toPlutusData()
        return try plutusData.toDict()
    }
    
    /// Creates a value from the JSON text of its Plutus data.
    ///
    /// - Parameter data: The JSON text.
    /// - Returns: The value.
    /// - Throws: When the text is not valid Plutus data JSON, or does not describe a value of this type.
    public static func fromJSON(_ data: String) throws -> Self {
        let plutusData = try PlutusData.fromJSON(data)
        return try Self.init(from: plutusData)
    }
    
    public static func fromDict(_ data: Primitive) throws -> Self {
        let plutusData = try PlutusData.fromDict(data)
        return try Self.init(from: plutusData)
    }
    
    /// Two values are equal when they describe the same Plutus data. Comparing
    /// the data itself rather than its rendered description keeps this in step
    /// with ``PlutusData``'s own value equality.
    public static func == (lhs: Self, rhs: Self) -> Bool {
        guard let lhsPlutus = try? lhs.toPlutusData(),
              let rhsPlutus = try? rhs.toPlutusData() else {
            return false
        }
        return lhsPlutus == rhsPlutus
    }
}

