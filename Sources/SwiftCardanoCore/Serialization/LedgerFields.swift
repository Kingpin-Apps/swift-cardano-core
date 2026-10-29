import Foundation

/// The field numbers each era's ledger reads in its sparse records, from the
/// eras' CDDL (`eras/*/impl/cddl/data/*.cddl` in cardano-ledger). A field the
/// era does not define fails to decode there (`invalidField`).
enum LedgerFields {
    /// `transaction_body`.
    static func transactionBody(_ era: Era) -> Set<UInt64> {
        switch era {
        case .byron: return []
        case .shelley: return Set(0...7)
        case .allegra: return Set(0...8)
        case .mary: return Set(0...9)
        case .alonzo: return Set(0...9).union([11, 13, 14, 15])
        case .babbage: return Set(0...9).union([11]).union(13...18)
        case .conway: return Set(0...5).union(7...9).union([11]).union(13...22)
        }
    }

    /// `protocol_param_update`.
    static func protocolParamUpdate(_ era: Era) -> Set<UInt64> {
        switch era {
        case .byron: return []
        case .shelley, .allegra, .mary: return Set(0...16)
        case .alonzo: return Set(0...14).union(16...24)
        case .babbage: return Set(0...11).union([14]).union(16...24)
        case .conway: return Set(0...11).union(16...33)
        }
    }

    /// The unsigned-integer keys of a map, in any of its forms.
    static func keys(of primitive: Primitive) -> [UInt64] {
        let keys: [Primitive]
        switch primitive {
        case .dict(let map): keys = Array(map.keys)
        case .orderedDict(let map), .indefiniteDictionary(let map): keys = Array(map.keys)
        default: keys = []
        }
        return keys.compactMap { if case .uint(let key) = $0 { return key } else { return nil } }
    }

    /// Throws when `fields` holds one `era` does not define.
    static func check(_ fields: some Sequence<UInt64>, allowed: Set<UInt64>, era: Era, in record: String) throws {
        if let field = fields.first(where: { !allowed.contains($0) }) {
            throw CardanoCoreError.deserializeError("\(record) field \(field) is not defined in \(era)")
        }
    }
}
