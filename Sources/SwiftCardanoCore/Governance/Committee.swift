import Foundation
import OrderedCollections

public struct CommitteeMember: CBORSerializable, CustomStringConvertible, CustomDebugStringConvertible, Sendable {
    public let coldCredential: CommitteeColdCredential
    public let epoch: EpochNumber
    
    public var description: String { "CommitteeMember(\(coldCredential), \(epoch))" }
    
    public var debugDescription: String { self.description }
    
    public init(from primitive: Primitive) throws {
        guard case let .orderedDict(dict) = primitive, dict.count == 1 else {
            throw CardanoCoreError.deserializeError("Expected a single-entry dictionary")
        }
        
        guard let credential = dict.keys.first else {
            throw CardanoCoreError.deserializeError("Expected a single-entry dictionary")
        }
        guard let epochPrimitive = dict[credential] else {
            throw CardanoCoreError.deserializeError("Expected a single-entry dictionary")
        }
        
        self.coldCredential = try CommitteeColdCredential(from: credential)
        self.epoch = try epochPrimitive.integer("CommitteeMember epoch", as: EpochNumber.self)
    }
    
    public func toPrimitive() throws -> Primitive {
        return .orderedDict(
            OrderedDictionary<Primitive, Primitive>(uniqueKeysWithValues: [
                try self.coldCredential.toPrimitive(): .integer(self.epoch)
            ])
        )
    }
}

/// The ledger's `Committee`, as Conway genesis holds it: each member's
/// expiry epoch (`EpochNo`, a `Word64`) and the quorum (a `UnitInterval`).
///
/// Members are keyed by their cold credential written as the ledger writes a
/// credential map key: `keyHash-<hex>` or `scriptHash-<hex>`.
public struct Committee: Codable, Equatable, Hashable, Sendable {
    public let members: [String: EpochNumber]
    public let threshold: UnitInterval

    public init(members: [String: EpochNumber], threshold: UnitInterval) {
        self.members = members
        self.threshold = threshold
    }

    private enum CodingKeys: String, CodingKey {
        case members, threshold
    }

    /// Reads the committee as the ledger's `FromJSON Committee` does; the
    /// quorum is a decimal such as `0.67`, read exactly, or a
    /// `{"numerator", "denominator"}` object.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let raw = try c.decode([String: EpochNumber].self, forKey: .members)
        var members: [String: EpochNumber] = [:]
        for (key, epoch) in raw {
            members[try GenesisCredential(text: key).text] = epoch
        }
        self.members = members
        self.threshold = try c.decodeUnitInterval(forKey: .threshold)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(members, forKey: .members)
        try c.encodeLedgerRational(threshold, forKey: .threshold)
    }

    // CBOR (cardano-ledger `EncCBOR Committee`):
    //   [{ * credential => epoch_no }, unit_interval]
    // The members map is a Haskell `Map`: keys in `Credential` order (script
    // hashes first), and an indefinite-length map past 23 entries.
    public init(from primitive: Primitive) throws {
        let f = try conwayList(primitive, count: 2, "Committee")
        let entries: [(Primitive, Primitive)]
        switch f[0] {
        case .orderedDict(let d), .indefiniteDictionary(let d): entries = d.elements.map { ($0.key, $0.value) }
        case .dict(let d): entries = Array(d)
        default:
            throw CardanoCoreError.deserializeError("Committee: expected a map of members, got \(f[0])")
        }
        var members: [String: EpochNumber] = [:]
        for (key, value) in entries {
            let credential = try GenesisCredential(from: key)
            guard members[credential.text] == nil else {
                throw CardanoCoreError.deserializeError("Committee: \(credential.text) appears more than once")
            }
            members[credential.text] = try value.integer("Committee member epoch", as: EpochNumber.self)
        }
        self.members = members
        self.threshold = try UnitInterval.ledgerCBOR(f[1], "Committee threshold")
    }

    public func toPrimitive() throws -> Primitive {
        var sorted: [(GenesisCredential, EpochNumber)] = []
        for (key, epoch) in members {
            sorted.append((try GenesisCredential(text: key), epoch))
        }
        sorted.sort { $0.0 < $1.0 }
        var map = OrderedDictionary<Primitive, Primitive>()
        for (credential, epoch) in sorted { map[credential.toPrimitive()] = .uint(epoch) }
        let membersPrim: Primitive = map.count <= 23 ? .orderedDict(map) : .indefiniteDictionary(map)
        return .list([membersPrim, threshold.ledgerPrimitive()])
    }
}
