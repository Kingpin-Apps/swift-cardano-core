import Foundation
import OrderedCollections

public struct UpdateCommittee: GovernanceAction {
    public static var code: GovActionCode { get { .updateCommittee } }
    
    public let id: GovActionID?
    public let coldCredentials: Set<CommitteeColdCredential>
    public let credentialEpochs: [CommitteeColdCredential: UInt64] // committee_cold_credential => epoch_no
    public let interval: UnitInterval
    
    public init(id: GovActionID?, coldCredentials: Set<CommitteeColdCredential>, credentialEpochs: [CommitteeColdCredential: UInt64], interval: UnitInterval) {
        self.id = id
        self.coldCredentials = coldCredentials
        self.credentialEpochs = credentialEpochs
        self.interval = interval
    }
    
    // Codable goes through `init(from: Primitive)` and `toPrimitive()`, the
    // default for a `CBORSerializable`, so `toCBORData()` writes the CDDL's form.

    public init(from primitive: Primitive) throws {
        guard case let .list(elements) = primitive, elements.count == 5 else {
            throw CardanoCoreError.deserializeError("Invalid UpdateCommittee primitive")
        }
        let code = try elements[0].integer("UpdateCommittee code", as: Int.self)
        guard code == Self.code.rawValue else {
            throw CardanoCoreError.deserializeError("Invalid UpdateCommittee primitive")
        }
        
        // Parse optional id
        if elements[1] == .null {
            self.id = nil
        } else {
            self.id = try GovActionID(from: elements[1])
        }
        
        // `set<committee_cold_credential>`: `#6.258([* a]) / [* a]`, the array
        // of either definite or indefinite length. A tag around anything but
        // an array is not a set.
        let credentialsList: [Primitive]
        switch elements[2] {
        case .list(let l): credentialsList = l
        case .indefiniteList(let l): credentialsList = l.getAll()
        case .cborTag(let t) where t.tag == 258:
            switch t.value {
            case .list(let l): credentialsList = l
            case .indefiniteList(let l): credentialsList = l.getAll()
            default:
                throw CardanoCoreError.deserializeError(
                    "UpdateCommittee: a #6.258 set must wrap an array, got \(t.value)")
            }
        default:
            throw CardanoCoreError.deserializeError("Invalid coldCredentials in UpdateCommittee")
        }
        var coldCredentials: Set<CommitteeColdCredential> = []
        for credentialPrimitive in credentialsList {
            let credential = try CommitteeColdCredential(from: credentialPrimitive)
            coldCredentials.insert(credential)
        }
        self.coldCredentials = coldCredentials

        // Parse credentialEpochs dictionary (orderedDict or dict)
        let credentialEpochsPairs: [(Primitive, Primitive)]
        switch elements[3] {
        case .dict(let d): credentialEpochsPairs = d.map { ($0.key, $0.value) }
        case .orderedDict(let d): credentialEpochsPairs = d.map { ($0.key, $0.value) }
        default:
            throw CardanoCoreError.deserializeError("Invalid credentialEpochs in UpdateCommittee")
        }
        var credentialEpochs: [CommitteeColdCredential: UInt64] = [:]
        for (keyPrimitive, valuePrimitive) in credentialEpochsPairs {
            let credential = try CommitteeColdCredential(from: keyPrimitive)
            let epochValue = try valuePrimitive.integer("UpdateCommittee epoch", as: EpochNumber.self)
            credentialEpochs[credential] = epochValue
        }
        self.credentialEpochs = credentialEpochs
        
        // Parse interval
        self.interval = try UnitInterval(from: elements[4])
    }
    
    public func toPrimitive() throws -> Primitive {
        // Both collections are unordered in Swift, so they are put in the
        // ledger's own credential order on the way out. Writing a `Set` or a
        // `Dictionary` in iteration order instead gives different bytes from one
        // run to the next, and a different hash for the body they sit in.
        let removed = coldCredentials
            .sorted { CredentialType.ledgerOrder($0.credential, $1.credential) }
        let added = credentialEpochs
            .sorted { CredentialType.ledgerOrder($0.key.credential, $1.key.credential) }

        var epochs = OrderedDictionary<Primitive, Primitive>()
        for (credential, epoch) in added {
            epochs[try credential.toPrimitive()] = .uint(epoch)
        }

        return .list([
            .int(Int64(Self.code.rawValue)),
            try id?.toPrimitive() ?? .null,
            // The CDDL's `set` is a `#6.258` tag around the elements.
            .orderedSet(try OrderedSet(try removed.map { try $0.toPrimitive() })),
            .orderedDict(epochs),
            try interval.toPrimitive()
        ])
    }
}
