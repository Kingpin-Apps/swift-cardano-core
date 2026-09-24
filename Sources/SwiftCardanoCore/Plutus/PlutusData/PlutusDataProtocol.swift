import OrderedCollections

protocol PlutusDataProtocol: Serializable {
    init(from plutusData: PlutusData) throws
    
    func toPlutusData() throws -> PlutusData
}

extension PlutusDataProtocol {
    public init(from primitive: Primitive) throws {
        let plutusData = try PlutusData(from: primitive)
        try self.init(from: plutusData)
    }
    
    public init(from dict: OrderedDictionary<Primitive, Primitive>) throws {
        let plutusData = try PlutusData.fromDict(.orderedDict(dict))
        try self.init(from: plutusData)
    }
    
    public func hash() throws -> DatumHash {
        let plutusData = try self.toPlutusData()
        return try datumHash(datum: .plutusData(plutusData))
    }
    
    public func toPrimitive() throws -> Primitive {
        return try self.toPlutusData().toPrimitive()
    }
    
    public func toJSON() throws -> String? {
        let plutusData = try self.toPlutusData()
        return try plutusData.toJSON()
    }
    
    public func toDict() throws -> Primitive {
        let plutusData = try self.toPlutusData()
        return try plutusData.toDict()
    }
    
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

