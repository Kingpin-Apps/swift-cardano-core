import CBORCodable
import Foundation

/// The ledger's rules for a repeated map key or set element, applied to the
/// bytes of a transaction or of one of its parts.
///
/// Decoding keeps a repeated key's later value and a repeated set element
/// once, which is how the ledger reads them before Conway. The rules here then
/// reject what the ledger rejects (`cardano-ledger-binary` and the era
/// decoders, protocol versions 9 to 11):
///
/// - A sparse record — a transaction body, witness set, output, Alonzo
///   auxiliary data or protocol-parameter update — may not repeat a field, in
///   any era.
/// - From Conway, an ordinary map may not repeat a key, and a set may not
///   repeat an element.
/// - Except, in Conway, the key witnesses, bootstrap witnesses, native scripts
///   and datums of a witness set, which may repeat (each kept once), and the
///   redeemer map, which may repeat a key (the later one kept).
/// - Plutus data and metadatum maps may repeat a key in every era: the ledger
///   reads them as lists of pairs.
struct LedgerDuplicateRules {
    let scanner: CBORItemScanner
    let era: Era

    init(_ bytes: Data, era: Era) {
        scanner = CBORItemScanner(bytes)
        self.era = era
    }

    /// Whether maps and sets may not repeat a key or an element.
    private var strict: Bool { era >= .conway }

    // MARK: Entry points

    func checkTransaction() throws {
        let spans = try scanner.elements(ofArrayAt: 0)
        guard spans.count >= 3 else { return }
        try checkBody(at: spans[0].lowerBound)
        try checkWitnessSet(at: spans[1].lowerBound)
        if let last = spans.last, spans.count == 4 || spans.count == 3 {
            let auxiliary = spans.count == 4 ? last : spans[2]
            if try scanner.header(at: auxiliary.lowerBound).major != 7 {
                try checkAuxiliaryData(at: auxiliary.lowerBound)
            }
        }
    }

    func checkBody(at offset: Int) throws {
        for (key, value) in try record(at: offset, "transaction body") {
            switch key {
            case 0, 13, 14, 18: try checkSet(at: value)
            case 1:
                for output in try scanner.elements(ofArrayAt: value) {
                    try checkOutput(at: output.lowerBound)
                }
            case 16: try checkOutput(at: value)
            case 4: try checkSet(at: value, element: checkCertificate)
            case 20: try checkSet(at: value, element: checkProposal)
            case 6:
                // [{genesis key hash => protocol parameter update}, epoch]
                let spans = try scanner.elements(ofArrayAt: value)
                if let updates = spans.first {
                    try checkMap(at: updates.lowerBound, value: checkParameterUpdate)
                }
            default: try checkItem(at: value)
            }
        }
    }

    func checkWitnessSet(at offset: Int) throws {
        for (key, value) in try record(at: offset, "witness set") {
            switch key {
            case 0, 1, 2:
                // Key witnesses, native scripts and bootstrap witnesses may
                // repeat until protocol version 12.
                try checkElements(at: value, element: checkItem)
            case 4:
                // Datums may repeat until protocol version 12, and are Plutus
                // data, which may repeat a map key.
                break
            case 5:
                try checkRedeemers(at: value)
            default:
                try checkSet(at: value)
            }
        }
    }

    func checkAuxiliaryData(at offset: Int) throws {
        let start = try scanner.untagged(at: offset)
        let header = try scanner.header(at: offset)
        if header.major == 6 {
            // #6.259({0: metadata, 1: native scripts, 2–4: Plutus scripts})
            for (key, value) in try record(at: start, "auxiliary data") {
                if key == 0 {
                    try checkMetadata(at: value)
                } else {
                    try checkItem(at: value)
                }
            }
        } else if header.major == 4 {
            // [metadata, native scripts]
            let spans = try scanner.elements(ofArrayAt: offset)
            if let metadata = spans.first { try checkMetadata(at: metadata.lowerBound) }
            for span in spans.dropFirst() { try checkItem(at: span.lowerBound) }
        } else {
            try checkMetadata(at: offset)
        }
    }

    /// A block's `{* transaction_index => auxiliary_data}`.
    func checkAuxiliaryDataSet(at offset: Int) throws {
        try checkMap(at: offset, key: { _ in }, value: checkAuxiliaryData)
    }

    // MARK: Parts

    /// `{* label => metadatum}`: the labels are an ordinary map's keys; the
    /// metadata under them may repeat keys.
    private func checkMetadata(at offset: Int) throws {
        try checkMap(at: offset, key: { _ in }, value: { _ in })
    }

    private func checkOutput(at offset: Int) throws {
        if try scanner.header(at: offset).major == 5 {
            for (_, value) in try record(at: offset, "transaction output") {
                try checkItem(at: value)
            }
        } else {
            try checkItem(at: offset)
        }
    }

    private func checkRedeemers(at offset: Int) throws {
        if try scanner.header(at: offset).major == 5 {
            // {[tag, index] => [data, ex_units]}: a key may repeat until
            // protocol version 12; the data is Plutus data.
            for (key, value) in try scanner.entries(ofMapAt: offset) {
                try checkItem(at: key.lowerBound)
                let parts = try scanner.elements(ofArrayAt: value.lowerBound)
                for part in parts.dropFirst() { try checkItem(at: part.lowerBound) }
            }
        } else {
            // [* [tag, index, data, ex_units]]
            for redeemer in try scanner.elements(ofArrayAt: offset) {
                let parts = try scanner.elements(ofArrayAt: redeemer.lowerBound)
                for (index, part) in parts.enumerated() where index != 2 {
                    try checkItem(at: part.lowerBound)
                }
            }
        }
    }

    /// A certificate; a pool registration's owners are a set.
    private func checkCertificate(at offset: Int) throws {
        let spans = try scanner.elements(ofArrayAt: offset)
        for (index, span) in spans.enumerated() {
            if index == 7, try scanner.unsignedInteger(at: spans[0].lowerBound) == 3 {
                try checkSet(at: span.lowerBound)
            } else {
                try checkItem(at: span.lowerBound)
            }
        }
    }

    /// `[deposit, reward account, gov action, anchor]`.
    private func checkProposal(at offset: Int) throws {
        let spans = try scanner.elements(ofArrayAt: offset)
        for (index, span) in spans.enumerated() {
            if index == 2 {
                try checkGovernanceAction(at: span.lowerBound)
            } else {
                try checkItem(at: span.lowerBound)
            }
        }
    }

    private func checkGovernanceAction(at offset: Int) throws {
        let spans = try scanner.elements(ofArrayAt: offset)
        let kind = try spans.first.flatMap { try scanner.unsignedInteger(at: $0.lowerBound) }
        for (index, span) in spans.enumerated() {
            switch (kind, index) {
            case (0, 2): try checkParameterUpdate(at: span.lowerBound)
            case (4, 2): try checkSet(at: span.lowerBound)
            default: try checkItem(at: span.lowerBound)
            }
        }
    }

    private func checkParameterUpdate(at offset: Int) throws {
        for (_, value) in try record(at: offset, "protocol parameter update") {
            try checkItem(at: value)
        }
    }

    // MARK: Shapes

    /// Any item, its maps ordinary maps and its tag-258 arrays sets.
    private func checkItem(at offset: Int) throws {
        let header = try scanner.header(at: offset)
        switch header.major {
        case 4:
            try checkElements(at: offset, element: checkItem)
        case 5:
            try checkMap(at: offset, key: checkItem, value: checkItem)
        case 6 where header.argument == 258:
            try checkSet(at: offset)
        case 6 where header.argument == 24:
            // Embedded CBOR — an inline datum or a script — is bytes here.
            break
        case 6:
            try checkItem(at: header.end)
        default:
            break
        }
    }

    private func checkElements(at offset: Int, element: (Int) throws -> Void) throws {
        let start = try scanner.untagged(at: offset)
        for span in try scanner.elements(ofArrayAt: start) {
            try element(span.lowerBound)
        }
    }

    /// A set, tagged 258 or not: from Conway, no element may repeat.
    private func checkSet(at offset: Int, element: ((Int) throws -> Void)? = nil) throws {
        let start = try scanner.untagged(at: offset)
        let spans = try scanner.elements(ofArrayAt: start)
        if strict {
            var seen = Set<Primitive>()
            for span in spans where !seen.insert(try value(in: span)).inserted {
                throw CardanoCoreError.deserializeError(
                    "A set repeats an element, which the ledger rejects from Conway")
            }
        }
        for span in spans {
            try (element ?? checkItem)(span.lowerBound)
        }
    }

    /// An ordinary map: from Conway, no key may repeat.
    private func checkMap(
        at offset: Int,
        key: ((Int) throws -> Void)? = nil,
        value checkValue: ((Int) throws -> Void)? = nil
    ) throws {
        let entries = try scanner.entries(ofMapAt: offset)
        if strict {
            var seen = Set<Primitive>()
            for entry in entries where !seen.insert(try value(in: entry.key)).inserted {
                throw CardanoCoreError.deserializeError(
                    "A map repeats a key, which the ledger rejects from Conway")
            }
        }
        for entry in entries {
            try (key ?? checkItem)(entry.key.lowerBound)
            try (checkValue ?? checkItem)(entry.value.lowerBound)
        }
    }

    /// A sparse record's fields by number. No field may repeat, in any era.
    private func record(at offset: Int, _ name: String) throws -> [(key: UInt64, value: Int)] {
        var seen = Set<UInt64>()
        var fields: [(key: UInt64, value: Int)] = []
        for (key, value) in try scanner.entries(ofMapAt: offset) {
            guard let field = try scanner.unsignedInteger(at: key.lowerBound) else {
                throw CardanoCoreError.deserializeError("A \(name) field must be an unsigned integer")
            }
            guard seen.insert(field).inserted else {
                throw CardanoCoreError.deserializeError("A \(name) repeats field \(field)")
            }
            fields.append((field, value.lowerBound))
        }
        return fields
    }

    /// The value of the item in `span`, for comparing keys and elements as
    /// the ledger does — by value, not by how they were written.
    private func value(in span: Range<Int>) throws -> Primitive {
        let decoder = CBORDecoder()
        decoder.allowDuplicateMapKeys = true
        return try Primitive.from(
            cbor: decoder.decode(CBOR.self, from: scanner.bytes.subdata(in: span)))
    }
}
