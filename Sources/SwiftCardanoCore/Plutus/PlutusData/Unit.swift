import OrderedCollections

/// The default "Unit type" with a 0 constructor ID
public struct Unit: PlutusDataProtocol {
    public static let CONSTR_ID: UInt64 = 0
    
    public init() {}
    
    public init(from plutusData: PlutusData) throws {
        let expectedTag = UInt64(getTag(constrID: Int(Self.CONSTR_ID)) ?? 0)
        guard case let .constructor(constr) = plutusData,
              constr.tag == expectedTag || constr.tag == Self.CONSTR_ID,
              constr.fields.isEmpty else {
            throw CardanoCoreError.deserializeError("Invalid Unit PlutusData")
        }
    }
    
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
