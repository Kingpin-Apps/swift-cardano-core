import OrderedCollections

/// The default "Unit type" with a 0 constructor ID
public struct Unit: PlutusDataProtocol {
    /// The constructor index of the unit value, 0.
    public static let CONSTR_ID: UInt64 = 0
    
    /// Creates the unit value.
    public init() {}
    
    /// Reads the unit value from Plutus data.
    ///
    /// - Parameter plutusData: A constructor whose tag is 0 (or 121) and that has no fields.
    /// - Throws: When `plutusData` is anything else.
    public init(from plutusData: PlutusData) throws {
        let expectedTag = UInt64(getTag(constrID: Int(Self.CONSTR_ID)) ?? 0)
        guard case let .constructor(constr) = plutusData,
              constr.tag == expectedTag || constr.tag == Self.CONSTR_ID,
              constr.fields.isEmpty else {
            throw CardanoCoreError.deserializeError("Invalid Unit PlutusData")
        }
    }
    
    /// The unit value as Plutus data: constructor 0 with no fields.
    ///
    /// - Returns: The Plutus data.
    public func toPlutusData() throws -> PlutusData {
        return PlutusData.constructor(Constr(tag: 0, fields: []))
    }
    
    // MARK: - JSONSerializable
    
    public func toDict() throws -> Primitive {
        return .orderedDict([:  ])
    }
    
    public static func fromDict(_ dict: Primitive) throws -> Unit {
        return self.init()
    }
}
