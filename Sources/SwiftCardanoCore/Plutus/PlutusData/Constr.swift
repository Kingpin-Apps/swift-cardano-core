import BigInt
import Foundation
import OrderedCollections

#if canImport(CryptoKit)
    import CryptoKit
#elseif canImport(Crypto)
    import Crypto
#endif

/// A constructor value: a tag (unsigned integer) and zero-or-more fields.
public struct Constr: Serializable, CustomStringConvertible, Sendable {
    /// Constructor tag (aka: constructor index)
    /// In CDDL the constructors may be encoded with a CBOR constructor tag.
    public let tag: UInt64?
    /// Fields of the constructor
    public let fields: [PlutusData]

    /// Whether the fields are written as an indefinite-length array. A
    /// constructor without fields is written `[]` either way, unless it was
    /// decoded from `[_ ]`.
    public var useIndefiniteList: Bool? { didSet { writtenIndefinite = nil } }

    /// How the fields were written, when this was decoded and
    /// ``useIndefiniteList`` has not been changed since. A datum's hash is
    /// taken over its bytes, and the ledger accepts either form, so a decoded
    /// constructor is written back in the form it was read in.
    var writtenIndefinite: Bool? = nil
    /// Whether this was decoded from the general form, `#6.102([tag, fields])`,
    /// which the ledger accepts for any constructor tag.
    var writtenGeneral = false

    public init(tag: UInt64?, fields: [PlutusData] = [], useIndefiniteList: Bool? = nil) {
        self.tag = tag
        self.fields = fields
        self.useIndefiniteList = useIndefiniteList ?? true
    }

    /// The fields of a constructor as written, and whether they were written
    /// as an indefinite-length array.
    private static func fields(of primitive: Primitive) throws -> (fields: [Primitive], indefinite: Bool) {
        switch primitive {
            case .list(let list): return (list, false)
            case .indefiniteList(let list): return (list.getAll(), true)
            default:
                throw CardanoCoreError.deserializeError("Expected array of fields but got: \(primitive)")
        }
    }

    public static var constrID: Int {
        let detString = try! idMap(cls: Self.self, skipConstructor: true)
        let detHash = SHA256.hash(data: Data(detString.utf8)).map { String(format: "%02x", $0) }
            .joined()
        let num = BigInt(detHash, radix: 16)
        let calc = num! % (1 << 32)

        return Int(calc)
    }

    public static var CONSTR_ID: Int {
        return Self.constrID
    }

    public var description: String {
        "Constr(tag: \(String(describing: tag)), fields: \(fields))"
    }

    // MARK: - CBORSerializable

    public static var preservesEncoding: Bool { true }

    public init(from primitive: Primitive) throws {
        guard case .cborTag(let cborTag) = primitive else {
            throw CardanoCoreError.deserializeError("Invalid Constr type")
        }

        if cborTag.tag == 102 {
            guard case .list(let valueArray) = cborTag.value,
                valueArray.count == 2,
                case .uint(let tag) = valueArray[0]
            else {
                throw CardanoCoreError.deserializeError(
                    "Invalid CBORTag format for PlutusData. Expected array of length 2 with integer tag but got: \(cborTag)"
                )
            }

            let (fields, indefinite) = try Self.fields(of: valueArray[1])
            self.tag = UInt64(tag)
            self.fields = try fields.map { try PlutusData(from: $0) }
            self.useIndefiniteList = indefinite
            self.writtenIndefinite = indefinite
            self.writtenGeneral = true
        } else {
            let constructorID: UInt64
            if 121 <= cborTag.tag && cborTag.tag < 128 {
                constructorID = cborTag.tag - 121
            } else if 1280 <= cborTag.tag && cborTag.tag < 1536 {
                constructorID = cborTag.tag - 1280 + 7
            } else {
                throw CardanoCoreError.deserializeError(
                    "Invalid constructor tag for PlutusData: \(cborTag.tag)")
            }

            let (fields, indefinite) = try Self.fields(of: cborTag.value)
            self.tag = constructorID
            self.fields = try fields.map { try PlutusData(from: $0) }
            self.useIndefiniteList = indefinite
            self.writtenIndefinite = indefinite
        }
    }

    public func toPrimitive() throws -> Primitive {
        let calculatedTag = getTag(constrID: Int(self.tag!))

        let primitives = try fields.map {
            try $0.toPrimitive(isRoot: false)
        }

        let indefinite = writtenIndefinite ?? (useIndefiniteList != false && !primitives.isEmpty)
        let toEncode: Primitive = indefinite
            ? .indefiniteList(IndefiniteList<Primitive>(primitives)) : .list(primitives)

        if let calculatedTag, !writtenGeneral {
            return .cborTag(
                CBORTag(tag: UInt64(calculatedTag), value: toEncode)
            )
        } else {
            let tagToUse = self.tag ?? UInt64(Self.CONSTR_ID)

            return .cborTag(
                CBORTag(tag: 102, value: .list([.uint(tagToUse), toEncode]))
            )
        }
    }

    // MARK: - JSONSerializable

    public static func fromDict(_ data: Primitive) throws -> Constr {
        guard case .orderedDict(let orderedDict) = data else {
            throw CardanoCoreError.deserializeError("Invalid Constr dict format")
        }
        // Handle both .int and .uint for constructor field
        let tagValue: UInt64
        if case .uint(let tag) = orderedDict[.string("constructor")] {
            tagValue = UInt64(tag)
        } else if case .int(let tag) = orderedDict[.string("constructor")] {
            tagValue = UInt64(tag)
        } else {
            throw CardanoCoreError.deserializeError(
                "Invalid Constr dict: missing or invalid constructor field")
        }

        guard case .list(let fieldsArray) = orderedDict[.string("fields")] else {
            throw CardanoCoreError.deserializeError(
                "Invalid Constr dict: missing or invalid fields")
        }

        let fields = try fieldsArray.map {
            guard case .orderedDict(let fieldDict) = $0 else {
                throw CardanoCoreError.deserializeError("Invalid Constr field dict")
            }
            return try PlutusData.fromDict(.orderedDict(fieldDict))
        }
        return Constr(tag: tagValue, fields: fields)
    }

    public func toDict() throws -> Primitive {
        var data: OrderedDictionary<Primitive, Primitive> = [:]
        data[.string("constructor")] = .uint(self.tag ?? UInt64(Self.CONSTR_ID))
        data[.string("fields")] = .list(
            try self.fields.map { field in
                try Primitive.fromAny(field.toDict())
            }
        )
        return .orderedDict(data)
    }

}
