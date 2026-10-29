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
    /// Whether the general form's `[tag, fields]` array was written with an
    /// indefinite length, which the ledger also accepts.
    var writtenGeneralIndefinite = false

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
            guard let valueArray = cborTag.value.arrayElements,
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
            if case .indefiniteList = cborTag.value { self.writtenGeneralIndefinite = true }
        } else {
            let constructorID: UInt64
            if 121 <= cborTag.tag && cborTag.tag < 128 {
                constructorID = cborTag.tag - 121
            } else if 1280 <= cborTag.tag && cborTag.tag <= 1400 {
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

    /// How this is written: under its compact tag, or — when there is none
    /// for its tag, or it was read in the general form — as
    /// `#6.102([alternative, fields])`; and whether the fields array is
    /// indefinite.
    var encodingForm: (compactTag: UInt64?, alternative: UInt64, indefinite: Bool, generalIndefinite: Bool) {
        // A tag beyond the compact ranges, or no tag at all, takes the
        // general form; `#6.102` carries any `UInt64`.
        let calculatedTag = self.tag.flatMap { Int(exactly: $0) }.flatMap { getTag(constrID: $0) }
        let indefinite = writtenIndefinite ?? (useIndefiniteList != false && !fields.isEmpty)
        let compactTag = writtenGeneral ? nil : calculatedTag.map { UInt64($0) }
        return (compactTag, self.tag ?? UInt64(Self.CONSTR_ID), indefinite, writtenGeneralIndefinite)
    }

    public func toPrimitive() throws -> Primitive {
        let form = encodingForm
        let primitives = try fields.map {
            try $0.toPrimitive(isRoot: false)
        }
        let toEncode: Primitive = form.indefinite
            ? .indefiniteList(IndefiniteList<Primitive>(primitives)) : .list(primitives)

        if let compactTag = form.compactTag {
            return .cborTag(CBORTag(tag: compactTag, value: toEncode))
        } else {
            let pair: [Primitive] = [.uint(form.alternative), toEncode]
            return .cborTag(
                CBORTag(tag: 102, value: form.generalIndefinite ? .indefiniteList(IndefiniteList(pair)) : .list(pair))
            )
        }
    }

    // MARK: - JSONSerializable

    public static func fromDict(_ data: Primitive) throws -> Constr {
        guard case .orderedDict(let orderedDict) = data else {
            throw CardanoCoreError.deserializeError("Invalid Constr dict format")
        }
        guard let constructor = orderedDict[.string("constructor")] else {
            throw CardanoCoreError.deserializeError(
                "Invalid Constr dict: missing or invalid constructor field")
        }
        let tagValue = try constructor.integer("Constr constructor", as: UInt64.self)

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
