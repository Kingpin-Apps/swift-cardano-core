import Foundation
import OrderedCollections

/// `invalid_before` (code 4): valid only from `slot` onwards. cardano-cli JSON type `"after"`.
public struct BeforeScript: NativeScriptable {
    public static let TYPE = NativeScriptType.invalidBefore
    public let slot: SlotNumber

    /// The bytes this script was decoded from, when it was decoded on its
    /// own or as a whole script of a transaction; its encoding and hash are
    /// taken over them, as the ledger takes them, while they are kept.
    public internal(set) var originalCBOR: Data? = nil

    public init (slot: SlotNumber) {
        self.slot = slot
    }

    // MARK: - CBORSerializable

    public init(from primitive: Primitive) throws {
        guard let primitive = primitive.arrayElements,
                primitive.count == 2,
                case let .uint(code) = primitive[0],
                code == Self.TYPE.rawValue,
              case let .uint(slot) = primitive[1] else {
            throw CardanoCoreError.deserializeError("Invalid BeforeScript type")
        }
        self.slot = SlotNumber(slot)
    }

    public func toPrimitive() throws -> Primitive {
        if let originalCBOR { return .cborSimpleValue(.encoded(originalCBOR)) }
        return .list([.uint(UInt64(Self.TYPE.rawValue)), .uint(slot)])
    }

    // MARK: - JSONSerializable

    public static func fromDict(_ dict: Primitive) throws -> BeforeScript {
        guard case let .orderedDict(dictValue) = dict else {
            throw CardanoCoreError.decodingError("Invalid BeforeScript dict format")
        }

        if let typePrimitive = dictValue[.string("type")] {
            guard case let .string(type) = typePrimitive, type == Self.TYPE.description() else {
                throw CardanoCoreError.decodingError("Invalid BeforeScript type: \(typePrimitive)")
            }
        }

        guard let slotPrimitive = dictValue[.string("slot")] else {
            throw CardanoCoreError.decodingError("Missing slot in BeforeScript")
        }

        let slot = try slotPrimitive.integer("BeforeScript slot", as: SlotNumber.self)

        return BeforeScript(slot: slot)
    }

    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        dict[.string("type")] = .string(Self.TYPE.description())
        dict[.string("slot")] = .uint(slot)
        return .orderedDict(dict)
    }
}

extension BeforeScript {
    /// Equal when they are the same script, however each was written.
    public static func == (lhs: BeforeScript, rhs: BeforeScript) -> Bool {
        lhs.slot == rhs.slot
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(slot)
    }
}
