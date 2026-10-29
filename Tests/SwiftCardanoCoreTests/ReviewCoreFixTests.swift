import CBORCodable
import Foundation
import SwiftKES
import SwiftNaCl
import Testing

@testable import SwiftCardanoCore

// Each test here failed before the fix it covers.

private func hex(_ string: String) -> Data {
    Data(hexString: string.replacingOccurrences(of: " ", with: ""))!
}

private func repeated(_ byte: String, _ count: Int) -> String {
    String(repeating: byte, count: count)
}

private func blake2b256(_ data: Data) throws -> Data {
    try Hash().blake2b(data: data, digestSize: 32, encoder: RawEncoder.self)
}

/// `[#6.258]`-tagged set of the given encoded elements.
private func taggedSet(_ elements: [String]) -> String {
    "d90102" + (CBORItemScanner.definiteHeader(major: 4, count: elements.count).toHex) + elements.joined()
}

private func inputHex(_ byte: String, _ index: UInt8 = 0) -> String {
    "825820" + repeated(byte, 32) + String(format: "%02x", index)
}

private func input(_ byte: UInt8, _ index: UInt16 = 0) -> TransactionInput {
    TransactionInput(transactionId: TransactionId(payload: Data(repeating: byte, count: 32)), index: index)
}

private func witnessHex(_ byte: String) -> String {
    "825820" + repeated(byte, 32) + "5840" + repeated("02", 64)
}

private func witness(_ byte: UInt8) throws -> VerificationKeyWitness {
    VerificationKeyWitness(
        vkey: .verificationKey(try VerificationKey(payload: Data(repeating: byte, count: 32))),
        signature: Data(repeating: 0x02, count: 64))
}

/// A Conway transaction whose inputs and vkey witnesses are `#6.258` sets.
private let conwayBody = "a3" + "00" + taggedSet([inputHex("11")]) + "01" + "80" + "02" + "1a00000001"
private let conwayWitnesses = "a1" + "00" + taggedSet([witnessHex("01")])
private let conwayTransaction = "84" + conwayBody + conwayWitnesses + "f5" + "f6"

// MARK: - 1. Set mutation

@Suite("Review fix 1: set mutation reaches the encoding")
struct ReviewSetMutationTests {
    let in0 = input(0x10), in1 = input(0x11), in2 = input(0x12), in3 = input(0x13)
    var h0: String { inputHex("10") }
    var h1: String { inputHex("11") }
    var h2: String { inputHex("12") }
    var h3: String { inputHex("13") }

    @Test("Every OrderedSet mutation is encoded, in order and deduplicated")
    func orderedSetMutations() throws {
        var set = try OrderedSet<TransactionInput>.fromCBOR(data: hex(taggedSet([h0, h1])))

        let r1 = set.append(in2)

        #expect(r1.inserted)
        #expect(try set.toCBORHex() == taggedSet([h0, h1, h2]))
        #expect(set.elementsOrdered == [in0, in1, in2])
        #expect(set.first == in0)

        let r2 = set.insert(in0)

        #expect(!r2.inserted)
        let r3 = set.insert(in3)
        #expect(r3.inserted)
        #expect(try set.toCBORHex() == taggedSet([h0, h1, h2, h3]))

        let r4 = set.remove(in1)

        #expect(r4 == in1)
        let r5 = set.remove(in1)
        #expect(r5 == nil)
        #expect(try set.toCBORHex() == taggedSet([h0, h2, h3]))

        set.append(contentsOf: [in2, in1, in1])
        #expect(try set.toCBORHex() == taggedSet([h0, h2, h3, h1]))
        #expect(set.count == 4)

        set.removeAll()
        #expect(set.isEmpty)
        #expect(try set.toCBORHex() == taggedSet([]))
        #expect(try set.toPrimitive() == OrderedSet<TransactionInput>([]).toPrimitive())
    }

    @Test("Setting elements or value keeps both views in step")
    func orderedSetSetters() throws {
        var set = try OrderedSet([in0, in1])
        set.elements = [in1, in2]
        #expect(set.elementsOrdered == [in1, in2])
        #expect(try set.toCBORHex() == taggedSet([h1, h2]))

        set.value = .list([try in3.toPrimitive(), try in0.toPrimitive(), try in3.toPrimitive()])
        #expect(set.elementsOrdered == [in3, in0])
        #expect(set.elements == [in3, in0])
    }

    @Test("Every NonEmptyOrderedSet mutation is encoded, in order and deduplicated")
    func nonEmptyOrderedSetMutations() throws {
        var set = try NonEmptyOrderedSet<TransactionInput>.fromCBOR(data: hex(taggedSet([h0, h1])))

        let r6 = set.append(in2)

        #expect(r6.inserted)
        let r7 = set.insert(in2)
        #expect(!r7.inserted)
        #expect(try set.toCBORHex() == taggedSet([h0, h1, h2]))

        let r8 = set.remove(in0)

        #expect(r8 == in0)
        #expect(try set.toCBORHex() == taggedSet([h1, h2]))
        #expect(set.first == in1)

        let removed = try set.safeRemove(in1)
        #expect(removed == in1)
        #expect(try set.toCBORHex() == taggedSet([h2]))

        // The last element stays: `remove` says so with nil, `safeRemove` throws.
        let r9 = set.remove(in2)
        #expect(r9 == nil)
        var copy = set
        #expect(throws: CardanoCoreError.self) { try copy.safeRemove(in2) }
        #expect(throws: CardanoCoreError.self) { try copy.safeRemove(in3) }
        #expect(try set.toCBORHex() == taggedSet([h2]))

        set.append(contentsOf: [in3, in0, in3])
        #expect(try set.toCBORHex() == taggedSet([h2, h3, h0]))

        // Replacing keeps the replaced element's place.
        let r10 = set.replace(in3, with: in1)
        #expect(r10)
        #expect(try set.toCBORHex() == taggedSet([h2, h1, h0]))
        let r11 = set.replace(in3, with: in1)
        #expect(!r11)
        let r12 = set.replace(in2, with: in0)
        #expect(!r12)
        let r13 = set.replace(in2, with: in2)
        #expect(r13)
        #expect(try set.toCBORHex() == taggedSet([h2, h1, h0]))
    }

    @Test("A NonEmptyOrderedSet cannot be emptied by setting its elements")
    func nonEmptyOrderedSetSetters() throws {
        var set = NonEmptyOrderedSet([in0, in1])
        set.elementsOrdered = [in2, in2, in1]
        #expect(try set.toCBORHex() == taggedSet([h2, h1]))
        set.elements = [in1]
        #expect(try set.toCBORHex() == taggedSet([h1]))
    }

    @Test("Appending through ListOrOrderedSet and ListOrNonEmptyOrderedSet is encoded")
    func throughListOrSet() throws {
        var inputs = try ListOrOrderedSet<TransactionInput>.fromCBOR(data: hex(taggedSet([h0])))
        try inputs.append(in1)
        try inputs.append(in0)
        #expect(try inputs.toCBORHex() == taggedSet([h0, h1]))
        #expect(inputs.asArray == [in0, in1])

        var collateral = try ListOrNonEmptyOrderedSet<TransactionInput>.fromCBOR(data: hex(taggedSet([h0])))
        try collateral.append(in1)
        try collateral.append(in1)
        #expect(try collateral.toCBORHex() == taggedSet([h0, h1]))
        #expect(collateral.asList == [in0, in1])

        // Indefinite-length sets are still sets.
        var indefinite = try ListOrOrderedSet<TransactionInput>.fromCBOR(data: hex("d901029f" + h0 + "ff"))
        try indefinite.append(in0)
        try indefinite.append(in1)
        #expect(try indefinite.toCBORHex() == "d901029f" + h0 + h1 + "ff")

        var indefiniteNonEmpty = try ListOrNonEmptyOrderedSet<TransactionInput>.fromCBOR(
            data: hex("d901029f" + h0 + "ff"))
        try indefiniteNonEmpty.append(in0)
        #expect(try indefiniteNonEmpty.toCBORHex() == "d901029f" + h0 + "ff")
    }

    @Test("A witness added to a decoded Conway transaction is encoded")
    func addingAWitnessToADecodedTransaction() throws {
        var tx = try Transaction.fromCBORHex(conwayTransaction)
        guard case .nonEmptyOrderedSet = tx.transactionWitnessSet.vkeyWitnesses else {
            Issue.record("expected a tagged witness set")
            return
        }
        try tx.transactionWitnessSet.vkeyWitnesses?.append(try witness(0x03))
        try tx.transactionBody.inputs.append(input(0x14))

        let encoded = try tx.toCBORHex()
        #expect(encoded.contains("00" + taggedSet([witnessHex("01"), witnessHex("03")])))
        #expect(encoded.contains("00" + taggedSet([inputHex("11"), inputHex("14")])))
        let decoded = try Transaction.fromCBORHex(encoded)
        #expect(decoded.transactionWitnessSet.vkeyWitnesses?.count == 2)
        #expect(decoded.transactionBody.inputs.count == 2)
    }
}

// MARK: - 2. Header body layout

@Suite("Review fix 2: a header body is written in its era's layout")
struct ReviewHeaderBodyLayoutTests {
    static let files = MainnetBlockTests.files

    @Test("A header body and header built from fields encode to the written bytes", arguments: files)
    func freshEncoding(file: String) throws {
        let (era, bytes) = try MainnetBlockTests.load("data/blocks", file)
        let block = try Block.fromCBOR(data: bytes, era: era)
        let scanner = CBORItemScanner(bytes)
        let headerSpan = try scanner.elements(ofArrayAt: 0)[0]
        let bodySpan = try scanner.elements(ofArrayAt: headerSpan.lowerBound)[0]
        let headerBytes = bytes.subdata(in: headerSpan)
        let bodyBytes = bytes.subdata(in: bodySpan)

        #expect(try scanner.elements(ofArrayAt: bodySpan.lowerBound).count == (era >= .babbage ? 10 : 15))

        let read = block.header.headerBody
        let fresh = HeaderBody(
            blockNumber: read.blockNumber, slot: read.slot, prevHash: read.prevHash,
            issuerVKey: read.issuerVKey, vrfVKey: read.vrfVKey, vrfResult: read.vrfResult,
            nonceVrf: read.nonceVrf, blockBodySize: read.blockBodySize, blockBodyHash: read.blockBodyHash,
            operationalCert: read.operationalCert, protocolVersion: read.protocolVersion)
        #expect(try fresh.toCBORData() == bodyBytes)
        #expect(try fresh.hash() == blake2b256(bodyBytes))

        var header = block.header
        header.originalCBOR = nil
        #expect(try header.toCBORData() == headerBytes)
        #expect(try header.hash() == block.hash())
        #expect(try Header(headerBody: fresh, bodySignature: header.bodySignature).toCBORData() == headerBytes)
    }

    @Test("The 11- and 14-element forms, which no era writes, are rejected")
    func strayLayouts() throws {
        guard case .list(let praos) = try makeHeaderBody().toPrimitive() else {
            Issue.record("expected a list")
            return
        }
        #expect(praos.count == 10)
        guard case .list(let cert) = praos[8], case .list(let version) = praos[9] else {
            Issue.record("expected nested operational cert and protocol version")
            return
        }
        let flat14 = Primitive.list(Array(praos[0...7]) + cert + version)
        #expect(throws: CardanoCoreError.self) { try HeaderBody(from: flat14) }
        let nested11 = Primitive.list(Array(praos[0...5]) + [praos[5]] + Array(praos[6...9]))
        #expect(throws: CardanoCoreError.self) { try HeaderBody(from: nested11) }
    }
}

// MARK: - 3. Indefinite-length records

@Suite("Review fix 3: records written as indefinite-length arrays decode")
struct ReviewIndefiniteRecordTests {
    @Test("Transaction parts")
    func transactionParts() throws {
        #expect(try TransactionInput.fromCBORHex("9f5820" + repeated("11", 32) + "00ff") == input(0x11))
        #expect(
            try VerificationKeyWitness.fromCBORHex("9f5820" + repeated("01", 32) + "5840" + repeated("02", 64) + "ff")
                == witness(0x01))
        let bootstrap = try BootstrapWitness.fromCBORHex(
            "9f5820" + repeated("01", 32) + "5840" + repeated("02", 64) + "5820" + repeated("03", 32) + "41a0ff")
        #expect(bootstrap.attributes == Data([0xa0]))

        let option = try DatumOption.fromCBORHex("9f005820" + repeated("aa", 32) + "ff")
        #expect(option.datum == .datumHash(DatumHash(payload: Data(repeating: 0xaa, count: 32))))
        #expect(try option.toCBORHex() == "9f005820" + repeated("aa", 32) + "ff")
    }

    @Test("Plutus parts")
    func plutusParts() throws {
        #expect(try ExecutionUnits.fromCBORHex("9f0102ff") == ExecutionUnits(mem: 1, steps: 2))
        let redeemer = try Redeemer.fromCBORHex("9f0000019f0102ffff")
        #expect(redeemer.exUnits == ExecutionUnits(mem: 1, steps: 2))
        #expect(try RedeemerKey.fromCBORHex("9f0103ff") == RedeemerKey(tag: .mint, index: 3))
        #expect(try RedeemerValue.fromCBORHex("9f01820102ff").exUnits == ExecutionUnits(mem: 1, steps: 2))
        #expect(try PlutusScript.fromCBORHex("9f024100ff") == .plutusV2Script(PlutusV2Script(data: Data([0]))))
        #expect(try ScriptType.fromCBORHex("9f034100ff") == .plutusV3Script(PlutusV3Script(data: Data([0]))))

        // Redeemers in a witness set, the list written indefinite inside.
        let witnesses = try TransactionWitnessSet.fromCBORHex("a105819f0000019f0102ffff")
        #expect(try witnesses.toCBORHex() == "a105819f0000019f0102ffff")
        guard case .list(let list) = witnesses.redeemers else {
            Issue.record("expected a redeemer list")
            return
        }
        #expect(list.first?.exUnits == ExecutionUnits(mem: 1, steps: 2))
    }

    @Test("Block parts")
    func blockParts() throws {
        let proof = repeated("05", 80)
        #expect(try VRFCert.fromCBORHex("9f4101" + "5850" + proof + "ff").output == Data([1]))

        let (era, bytes) = try MainnetBlockTests.load("data/blocks", "conway1.block")
        let block = try Block.fromCBOR(data: bytes, era: era)
        let scanner = CBORItemScanner(bytes)
        let headerSpan = try scanner.elements(ofArrayAt: 0)[0]
        let headerSpans = try scanner.elements(ofArrayAt: headerSpan.lowerBound)
        func indefinite(_ span: Range<Int>, nesting: Set<Int> = []) throws -> Data {
            let elements = try scanner.elements(ofArrayAt: span.lowerBound)
            var data = Data([0x9f])
            for (index, element) in elements.enumerated() {
                data += nesting.contains(index) ? try indefinite(element) : bytes.subdata(in: element)
            }
            return data + Data([0xff])
        }
        let body = try indefinite(headerSpans[0], nesting: [5, 8, 9])
        #expect(try HeaderBody.fromCBOR(data: body) == block.header.headerBody)

        let header = Data([0x9f]) + body + bytes.subdata(in: headerSpans[1]) + Data([0xff])
        let decoded = try Header.fromCBOR(data: header)
        #expect(decoded == block.header)
        #expect(try decoded.toCBORData() == header)
    }

    @Test("A transaction written indefinite keeps its bytes")
    func transaction() throws {
        let written = "9f" + conwayBody + conwayWitnesses + "f5f6" + "ff"
        let tx = try Transaction.fromCBORHex(written)
        #expect(try tx.toCBORHex() == written)
        #expect(tx.transactionBody == (try Transaction.fromCBORHex(conwayTransaction)).transactionBody)
    }
}

// MARK: - 4. Execution units

@Suite("Review fix 4: execution units are read as the ledger reads them")
struct ReviewExecutionUnitsTests {
    @Test("0 to Int64.max decode; negatives and anything above throw")
    func range() throws {
        let max = try ExecutionUnits.fromCBORHex("821b7fffffffffffffff00")
        #expect(max.mem == .max)
        #expect(throws: (any Error).self) { try ExecutionUnits.fromCBORHex("821b800000000000000000") }
        #expect(throws: (any Error).self) { try ExecutionUnits.fromCBORHex("822000") }
        #expect(throws: (any Error).self) {
            try ExecutionUnits(from: .list([.uint(UInt64(Int64.max) + 1), .uint(0)]))
        }
        #expect(throws: (any Error).self) { try ExecutionUnits(from: .list([.int(-1), .uint(0)])) }
        #expect(throws: (any Error).self) { try ExecutionUnits(mem: -1, steps: 0).toCBORData() }
    }

    @Test("Adding saturates instead of trapping")
    func addition() {
        let sum = ExecutionUnits(mem: .max, steps: 1) + ExecutionUnits(mem: 1, steps: 2)
        #expect(sum == ExecutionUnits(mem: .max, steps: 3))
        var total = ExecutionUnits(mem: 1, steps: .max)
        total += ExecutionUnits(mem: 1, steps: .max)
        #expect(total == ExecutionUnits(mem: 2, steps: .max))
    }
}

// MARK: - 5. Constructor tags

@Suite("Review fix 5: constructor tags stop at 1400")
struct ReviewConstructorTagTests {
    @Test("Tag 1401 is not a constructor on any path; 1400 is")
    func tagRange() throws {
        for tag: UInt64 in [1401, 1535] {
            let primitive = Primitive.cborTag(CBORTag(tag: tag, value: .list([])))
            #expect(throws: (any Error).self) { try PlutusData(from: primitive) }
            #expect(throws: (any Error).self) { try Constr(from: primitive) }
            #expect(throws: (any Error).self) { try getConstructorIDAndFields(value: .tagged(tag, .array([]))) }
        }
        let last = Primitive.cborTag(CBORTag(tag: 1400, value: .list([])))
        #expect(try Constr(from: last).tag == 127)
        #expect(try getConstructorIDAndFields(value: .tagged(1400, .array([]))).0 == 127)
    }
}

// MARK: - 6. Chunked inline datum

@Suite("Review fix 6: a chunked inline datum keeps its bytes")
struct ReviewChunkedDatumTests {
    @Test("The datum hash is taken over the joined chunks")
    func chunkedDatum() throws {
        // [1, #6.24((_ h'18', h'01'))]: the datum 1, written wide as 1801.
        let written = "8201d8185f411841" + "01ff"
        let option = try DatumOption.fromCBORHex(written)
        #expect(option.datumCBOR == Data([0x18, 0x01]))
        #expect(try option.inlineDatumHash()?.payload == blake2b256(Data([0x18, 0x01])))
        #expect(try option.toCBORHex() == written)
    }
}

// MARK: - 7. Redeemers hashing

@Suite("Review fix 7: equal redeemers hash alike")
struct ReviewRedeemersHashTests {
    @Test("A list and an indefinite list of the same data")
    func listForms() {
        let units = ExecutionUnits(mem: 1, steps: 2)
        let items: [PlutusData] = [.bigInt(.int(1)), .bytes(try! Bytes(from: Data([1])))]
        let a = Redeemers.list([Redeemer(tag: .spend, index: 0, data: .array(items), exUnits: units)])
        let b = Redeemers.list([
            Redeemer(tag: .spend, index: 0, data: .indefiniteArray(IndefiniteList(items)), exUnits: units)
        ])
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
        #expect(Set([a, b]).count == 1)
    }
}

// MARK: - 8. Codable keeps the kept bytes

@Suite("Review fix 8: encoding through Codable keeps the bytes as written")
struct ReviewCodableKeptBytesTests {
    @Test("A decoded transaction and its parts encode to their bytes, alone or nested")
    func transaction() throws {
        // The fee is 1 written in five bytes, and the metadata's 1 in two.
        let written = "84" + conwayBody + conwayWitnesses + "f5" + "a1001801"
        var tx = try Transaction.fromCBORHex(written)
        #expect(try CBOREncoder().encode(tx).toHex == written)
        #expect(try CBOREncoder().encode([tx]).toHex == "81" + written)
        #expect(try CBOREncoder().encode(tx.transactionBody).toHex == conwayBody)
        #expect(try CBOREncoder().encode(tx.transactionWitnessSet).toHex == conwayWitnesses)
        #expect(try CBOREncoder().encode(tx.auxiliaryData).toHex == "a1001801")

        // Changed, it still keeps the bytes of its unchanged parts.
        tx.valid = false
        #expect(try CBOREncoder().encode(tx).toHex == "84" + conwayBody + conwayWitnesses + "f4" + "a1001801")
        #expect(try CBOREncoder().encode(tx) == tx.toCBORData())
    }

    @Test("Witness datums kept while the rest of the witness set changes")
    func witnessSet() throws {
        var witnesses = try TransactionWitnessSet.fromCBORHex("a204811801" + "00" + taggedSet([witnessHex("01")]))
        try witnesses.vkeyWitnesses?.append(try witness(0x03))
        let encoded = try CBOREncoder().encode(witnesses)
        #expect(encoded == (try witnesses.toCBORData()))
        #expect(encoded.toHex.contains("04811801"))
    }

    @Test("Mainnet blocks and headers encode to their bytes", arguments: MainnetBlockTests.files)
    func blocks(file: String) throws {
        let (era, bytes) = try MainnetBlockTests.load("data/blocks", file)
        let block = try Block.fromCBOR(data: bytes, era: era)
        #expect(try CBOREncoder().encode(block) == bytes)
        #expect(try CBOREncoder().encode(block.header) == block.header.toCBORData())
    }

    @Test("Byron blocks encode to their bytes")
    func byronBlocks() throws {
        let directory = Bundle.module.resourceURL!.appendingPathComponent("data/byron")
        let files = try FileManager.default.contentsOfDirectory(atPath: directory.path)
            .filter { $0.hasSuffix(".block") }.sorted()
        #expect(!files.isEmpty)
        for file in files {
            let text = try String(contentsOf: directory.appendingPathComponent(file), encoding: .utf8)
            let bytes = text.trimmingCharacters(in: .whitespacesAndNewlines).hexStringToData
            let block = try ByronBlock.fromCBOR(data: bytes)
            #expect(try CBOREncoder().encode(block) == bytes)
            #expect(try CBOREncoder().encode(block.header) == block.header.toCBORData())
        }
    }
}

// MARK: - 9. Plutus data depth

@Suite("Review fix 9: a constructor is one level of Plutus nesting")
struct ReviewPlutusDepthTests {
    static let depth = PlutusDataReader.maxDepth

    /// `Constr 0 [Constr 0 [... 0]]`, `depth` constructors deep.
    static func nestedConstrs(_ depth: Int) -> Data {
        Data(Array(repeating: [UInt8(0xd8), 0x79, 0x81], count: depth).joined()) + Data([0x00])
    }

    /// Everything done with a decoded datum, on a cooperative thread.
    static func exercise(_ data: Data) async throws -> Data {
        try await Task.detached {
            let decoded = try PlutusData.fromCBOR(data: data)
            _ = try decoded.hash()
            var hasher = Hasher()
            hasher.combine(decoded)
            _ = decoded == decoded
            _ = decoded.debugDescription
            _ = try decoded.toDict()
            _ = try TransactionWitnessSet(plutusData: .list([decoded])).toCBORData()
            return try decoded.toCBORData()
        }.value
    }

    @Test("Constructors as deep as the limit decode, and everything done with them fits a small stack")
    func deepConstrs() async throws {
        let data = Self.nestedConstrs(Self.depth - 1)
        #expect(try await Self.exercise(data) == data)
        #expect(try PlutusData.fromCBOR(data: data).hash().payload == blake2b256(data))
        await #expect(throws: (any Error).self) {
            try await Task.detached { try PlutusData.fromCBOR(data: Self.nestedConstrs(Self.depth)) }.value
        }
    }

    @Test("Lists, maps and general-form constructors as deep as the limit")
    func deepOtherContainers() async throws {
        let arrays = Data(repeating: 0x81, count: Self.depth - 1) + Data([0x00])
        let maps = Data(Array(repeating: [UInt8(0xa1), 0x00], count: Self.depth - 1).joined()) + Data([0x00])
        // #6.102([300, [_ ...]]), an indefinite outer array too.
        let general = Data(Array(repeating: [UInt8(0xd8), 0x66, 0x9f, 0x19, 0x01, 0x2c, 0x9f], count: Self.depth - 1).joined())
            + Data([0x00]) + Data(repeating: 0xff, count: 2 * (Self.depth - 1))
        for data in [arrays, maps, general] {
            #expect(try await Self.exercise(data) == data)
        }
    }

    @Test("An inline datum as deep as the limit decodes inside a transaction")
    func deepInlineDatum() async throws {
        let datum = Self.nestedConstrs(Self.depth - 1)
        let output = "a3" + "00581d61" + repeated("22", 28) + "011a000f4240"
            + "028201d81859" + String(format: "%04x", datum.count) + datum.toHex
        let body = "a3" + "00" + taggedSet([inputHex("11")]) + "0181" + output + "02" + "1a00000001"
        let written = "84" + body + conwayWitnesses + "f5f6"
        let (encoded, hash) = try await Task.detached {
            var tx = try Transaction.fromCBORHex(written)
            let hash = try tx.transactionBody.outputs[0].datumOption?.inlineDatumHash()
            tx.valid = true
            return (try tx.toCBORHex(), hash)
        }.value
        #expect(encoded == written)
        #expect(try hash?.payload == blake2b256(datum))
    }
}

// MARK: - 10. Hashes do not trap

@Suite("Review fix 10: hashing a body or header throws rather than traps")
struct ReviewHashThrowsTests {
    @Test("A body's hash and id are those of its bytes, through a throwing API")
    func body() throws {
        let body = try Transaction.fromCBORHex(conwayTransaction).transactionBody
        #expect(try body.hash() == blake2b256(hex(conwayBody)))
        #expect(try body.id.payload == blake2b256(hex(conwayBody)))
        #expect(try Transaction.fromCBORHex(conwayTransaction).id?.payload == blake2b256(hex(conwayBody)))

        // Changed, the body is encoded afresh, and that encoding is hashed.
        var changed = body
        changed.fee = 2
        #expect(try changed.hash() == blake2b256(changed.toCBORData()))
    }

    @Test("A header's hash is that of its bytes, through a throwing API")
    func header() throws {
        let header = try makeHeader()
        #expect(try header.hash() == blake2b256(header.toCBORData()))
        #expect(try header.headerBody.hash() == blake2b256(header.headerBody.toCBORData()))
    }
}
