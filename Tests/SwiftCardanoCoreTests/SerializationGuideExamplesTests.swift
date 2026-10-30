import Foundation
import Testing
import SwiftCardanoCore

/// A type of the reader's own, as the Serialization guide implements it.
struct CustomData: CBORSerializable {
    let value: Int
    let text: String

    init(value: Int, text: String) {
        self.value = value
        self.text = text
    }

    init(from primitive: Primitive) throws {
        guard case let .list(elements) = primitive,
              elements.count == 2,
              case let .string(stringValue) = elements[1] else {
            throw CardanoCoreError.deserializeError("Invalid CustomData format")
        }

        self.value = try elements[0].integer("CustomData value")
        self.text = stringValue
    }

    func toPrimitive() throws -> Primitive {
        return .list([
            .integer(value),
            .string(text)
        ])
    }
}

/// A Plutus data type of the reader's own, as the Serialization guide
/// implements it.
// A datum with three fields: constructor 0 of an integer, bytes and a list
struct MyPlutusData: PlutusDataProtocol {
    let field1: Int64
    let field2: Data
    let field3: [Int64]

    init(field1: Int64, field2: Data, field3: [Int64]) {
        self.field1 = field1
        self.field2 = field2
        self.field3 = field3
    }

    init(from plutusData: PlutusData) throws {
        guard case let .constructor(constr) = plutusData,
              constr.tag == 0,
              constr.fields.count == 3,
              case let .bigInt(.int(field1)) = constr.fields[0],
              case let .bytes(field2) = constr.fields[1],
              case let .array(list) = constr.fields[2] else {
            throw CardanoCoreError.deserializeError("Invalid MyPlutusData: \(plutusData)")
        }
        self.field1 = field1
        self.field2 = field2.data
        self.field3 = try list.map { element in
            guard case let .bigInt(.int(value)) = element else {
                throw CardanoCoreError.deserializeError("Invalid MyPlutusData list element: \(element)")
            }
            return value
        }
    }

    func toPlutusData() throws -> PlutusData {
        .constructor(Constr(tag: 0, fields: [
            .bigInt(.int(field1)),
            .bytes(try Bytes(from: field2)),
            .array(NestedList(field3.map { .bigInt(.int($0)) })),
        ]))
    }
}

/// The code examples of the Serialization guide (`Serialization.md`),
/// compiled and run so that the guide stays true to the API. Each test holds
/// one example as the guide shows it.
///
/// The module is imported without `@testable`, so the examples see only the
/// public API, as a reader of the guide does.
@Suite("Serialization guide examples")
struct SerializationGuideExamplesTests {
    // Stand-ins for values the guide assumes the reader already has.
    let paymentKeyPair = try! PaymentKeyPair.generate()
    var txBody: TransactionBody {
        TransactionBody(
            inputs: .list([TransactionInput(transactionId: TransactionId(payload: Data(repeating: 1, count: 32)), index: 0)]),
            outputs: [TransactionOutput(
                address: try! Address.fromBech32("addr_test1vr2p8st5t5cxqglyjky7vk98k7jtfhdpvhl4e97cezuhn0cqcexl7"),
                amount: Value(coin: 2_000_000))],
            fee: 200_000)
    }
    var witnessSet: TransactionWitnessSet {
        TransactionWitnessSet(vkeyWitnesses: .list([VerificationKeyWitness(
            vkey: .verificationKey(paymentKeyPair.verificationKey),
            signature: try! paymentKeyPair.signingKey.sign(data: txBody.hash()))]))
    }
    var hex: String {
        try! Transaction(transactionBody: txBody, transactionWitnessSet: witnessSet).toCBORHex()
    }
    let poolKeyPair = try! StakePoolKeyPair.generate()
    var poolKeyHash: PoolKeyHash { try! poolKeyPair.verificationKey.poolKeyHash() }
    let vrfKeyHash = try! VRFKeyPair.generate().verificationKey.hash()
    let rewardAccountHash = RewardAccountHash(payload: Data([0xE0]) + Data(repeating: 2, count: 28))
    let ownerKeyHash = VerificationKeyHash(payload: Data(repeating: 2, count: 28))
    let relay = Relay.singleHostName(try! SingleHostName(port: 3001, dnsName: "relay.example.com"))
    let poolMetadata = try! PoolMetadata(
        url: Url("https://example.com/pool.json"),
        poolMetadataHash: PoolMetadataHash(payload: Data(repeating: 1, count: 32)))

    @Test func basicCBOROperations() throws {
        // Serialize to CBOR data
        let address = try Address.fromBech32("addr_test1vr2p8st5t5cxqglyjky7vk98k7jtfhdpvhl4e97cezuhn0cqcexl7")
        let cborData = try address.toCBORData()
        let cborHex = try address.toCBORHex()

        print("CBOR bytes: \(cborData.toHex)")
        print("CBOR hex: \(cborHex)")

        // Deserialize from CBOR
        let restoredAddress = try Address.fromCBOR(data: cborData)
        let addressFromHex = try Address.fromCBORHex(cborHex)
        #expect(restoredAddress == address)
        #expect(addressFromHex == address)
    }

    @Test func transactionSerialization() throws {
        // Create and serialize a complete transaction
        let transaction = Transaction(
            transactionBody: txBody,
            transactionWitnessSet: witnessSet,
            valid: true
        )

        // Serialize for submission
        let txCBOR = try transaction.toCBORData()
        let txHex = try transaction.toCBORHex()

        // Calculate transaction hash
        let txHash = transaction.id
        print("Transaction Hash: \(txHash?.payload.toHex ?? "unknown")")
        _ = (txCBOR, txHex)
    }

    @Test func encodingIsDeterministicAndFaithful() throws {
        let original = try Transaction.fromCBORHex(hex)

        // The same bytes back, including in another process.
        #expect(try original.toCBORHex() == hex)
    }

    @Test func handlingDecodingErrors() throws {
        func decodeTransaction(_ cborHex: String) -> Transaction? {
            do {
                return try Transaction.fromCBORHex(cborHex)
            } catch CardanoCoreError.invalidArgument(let message) {
                print("Not hex: \(message ?? "")")
            } catch CardanoCoreError.deserializeError(let message) {
                print("Not a transaction: \(message ?? "")")
            } catch {
                print("Decoding failed: \(error)")
            }
            return nil
        }

        #expect(decodeTransaction(hex) != nil)
        #expect(decodeTransaction("not hex") == nil)
        #expect(decodeTransaction("80") == nil) // an empty CBOR array

        // Each failure is the case the example catches.
        #expect(throws: CardanoCoreError.invalidArgument("Invalid hex string: not hex")) {
            try Transaction.fromCBORHex("not hex")
        }
        let error = #expect(throws: CardanoCoreError.self) {
            try Transaction.fromCBORHex("80")
        }
        guard case .deserializeError = error else {
            Issue.record("Expected deserializeError, got \(String(describing: error))")
            return
        }
    }

    @Test func customCBOREncoding() throws {
        // Usage
        let customData = CustomData(value: 42, text: "Hello")
        let serialized = try customData.toCBORData()
        let deserialized = try CustomData.fromCBOR(data: serialized)
        #expect(deserialized == customData)

        // The type's own error reaches the caller of fromCBOR unchanged.
        let wrongShape = try Primitive.list([.string("Hello")]).toCBORData()
        #expect(throws: CardanoCoreError.deserializeError("Invalid CustomData format")) {
            try CustomData.fromCBOR(data: wrongShape)
        }
    }

    @Test func workingWithPrimitive() throws {
        // Create dynamic CBOR content
        let dynamicValue = Primitive.orderedDict([
            .string("name"): .string("Alice"),
            .string("age"): .uint(30),
            .string("tokens"): .list([
                .string("TokenA"),
                .string("TokenB")
            ])
        ])

        let dynamicCBOR = try dynamicValue.toCBORData()
        let restored = try Primitive.fromCBOR(data: dynamicCBOR)
        #expect(try restored.toCBORData() == dynamicCBOR)
    }

    @Test func primitiveToAnyValue() throws {
        let restored = Primitive.orderedDict([.string("name"): .string("Alice")])

        let anyValue: AnyValue = restored.toAnyValue()
        print("As AnyValue: \(anyValue)")

        #expect(Primitive.string("Alice").toAnyValue() == AnyValue.string("Alice"))
        #expect(Primitive.list([.uint(1)]).toAnyValue() == AnyValue.array([.uint64(1)]))
    }

    @Test func transactionMetadataJSON() throws {
        // Create metadata with JSON-compatible structure
        let metadata = try Metadata([
            1: .text("Hello Cardano!"),
            2: .map([
                .text("name"): .text("My NFT"),
                .text("description"): .text("A beautiful NFT"),
                .text("image"): .text("ipfs://QmHash...")
            ]),
            3: .list([
                .int(1),
                .int(2),
                .int(3)
            ])
        ])

        // Convert to JSON for external APIs
        let jsonString = try metadata.toJSON()!
        print("Metadata JSON: \(jsonString)")

        // Parse from JSON
        let parsedMetadata = try Metadata.fromJSON(jsonString)
        #expect(parsedMetadata == metadata)
    }

    @Test func plutusDataJSON() throws {
        // Convert PlutusData to/from JSON (cardano-cli's detailed schema)
        let plutusData = PlutusData.constructor(Constr(tag: 0, fields: [
            .bigInt(.int(42)),
            .bytes(try Bytes(from: Data("hello".utf8))),
            .array([.bigInt(.int(1)), .bigInt(.int(2)), .bigInt(.int(3))]),
        ]))

        let plutusJSON = try plutusData.toJSON()!
        let fromJSON = try PlutusData.fromJSON(plutusJSON)
        #expect(fromJSON == plutusData)
    }

    @Test func yourOwnPlutusDataTypes() throws {
        let myData = MyPlutusData(field1: 42, field2: Data("hello".utf8), field3: [1, 2, 3])

        // JSON (cardano-cli's detailed schema) and back
        let myJSON = try myData.toJSON()!
        let myFromJSON = try MyPlutusData.fromJSON(myJSON)
        #expect(myFromJSON == myData)

        // CBOR and the datum hash, as for any Plutus data
        let myCBOR = try myData.toCBORData()
        let myFromCBOR = try MyPlutusData.fromCBOR(data: myCBOR)
        let myDatumHash = try myData.hash()

        #expect(myFromJSON.field1 == 42)
        #expect(myFromJSON.field2 == Data("hello".utf8))
        #expect(myFromJSON.field3 == [1, 2, 3])
        #expect(myFromCBOR == myData)
        #expect(myFromCBOR.field3 == [1, 2, 3])
        // The same JSON and CBOR as the PlutusData it converts to.
        let plutusData = try myData.toPlutusData()
        #expect(myJSON == (try plutusData.toJSON()))
        #expect(myCBOR == (try plutusData.toCBORData()))
        #expect(myDatumHash == (try MyPlutusData(from: plutusData).hash()))
        #expect(myData != MyPlutusData(field1: 43, field2: Data("hello".utf8), field3: [1, 2, 3]))
        // Plutus data of another shape is rejected with the type's own error.
        let otherJSON = try PlutusData.constructor(Constr(tag: 1, fields: [])).toJSON()!
        let error = #expect(throws: CardanoCoreError.self) {
            try MyPlutusData.fromJSON(otherJSON)
        }
        guard case .deserializeError = error else {
            Issue.record("Expected deserializeError, got \(String(describing: error))")
            return
        }
    }

    @Test(.disabled("Writes a transaction file to the working directory"))
    func transactionFileOperations() throws {
        // Save transaction to file
        let transaction = Transaction(
            transactionBody: txBody,
            transactionWitnessSet: witnessSet,
            valid: true
        )

        // Save to JSON file (Cardano CLI compatible)
        try transaction.save(to: "my-transaction.tx")
        print("Transaction saved successfully")

        // Load transaction from file
        let loadedTransaction = try Transaction.load(from: "my-transaction.tx")
        print("Transaction loaded: \(loadedTransaction.id?.payload.toHex ?? "unknown")")

        // Verify integrity
        #expect(transaction.id == loadedTransaction.id)
    }

    @Test(.disabled("Writes address files to the working directory"))
    func addressFileOperations() throws {
        // Save different address types
        let paymentAddr = try Address.fromBech32("addr_test1vr2p8st5t5cxqglyjky7vk98k7jtfhdpvhl4e97cezuhn0cqcexl7")
        let stakeAddr = try Address.fromBech32("stake_test1uqevw2xnsc0pvn9t9r9c7qryfqfeerchgrlm3ea2nefr9hqp8n5xl")
        let scriptAddr = try Address(paymentPart: .scriptHash(scriptHash), network: .testnet)

        // Save addresses to files
        try paymentAddr.save(to: "payment.addr")
        try stakeAddr.save(to: "stake.addr")
        try scriptAddr.save(to: "script.addr")

        // Load addresses from files
        let loadedPayment = try Address.load(from: "payment.addr")
        let loadedStake = try Address.load(from: "stake.addr")
        let loadedScript = try Address.load(from: "script.addr")

        // Verify addresses match
        #expect(paymentAddr == loadedPayment)
        #expect(stakeAddr == loadedStake)
        #expect(scriptAddr == loadedScript)
    }
    let scriptHash = ScriptHash(payload: Data(repeating: 4, count: 28))

    @Test func addressExamplesParse() throws {
        // The addresses of the address file example are valid.
        _ = try Address.fromBech32("stake_test1uqevw2xnsc0pvn9t9r9c7qryfqfeerchgrlm3ea2nefr9hqp8n5xl")
    }

    @Test(.disabled("Writes a metadata file to the working directory"))
    func metadataFileOperations() throws {
        // Create rich metadata
        let nftMetadata = try Metadata([
            721: .map([
                .text("policy_id"): .text("b8b8b8b8b8b8b8b8b8b8b8b8b8b8b8b8b8b8b8b8b8b8b8b8b8b8"),
                .text("asset_name"): .map([
                    .text("name"): .text("My Amazing NFT"),
                    .text("description"): .text("A unique digital collectible"),
                    .text("image"): .text("ipfs://QmHash123..."),
                    .text("attributes"): .list([
                        .map([
                            .text("trait_type"): .text("Rarity"),
                            .text("value"): .text("Epic")
                        ]),
                        .map([
                            .text("trait_type"): .text("Color"),
                            .text("value"): .text("Blue")
                        ])
                    ])
                ])
            ])
        ])

        // Save metadata to file
        try nftMetadata.saveJSON(to: "nft-metadata.json")

        // Load and verify metadata
        let loadedMetadata = try Metadata.loadJSON(from: "nft-metadata.json")
        let originalJSON = try nftMetadata.toJSON()
        let loadedJSON = try loadedMetadata.toJSON()

        // JSON should be identical
        #expect(originalJSON == loadedJSON)
    }

    @Test(.disabled("Writes a certificate file to the working directory"))
    func certificateFileOperations() throws {
        // Create stake pool registration certificate
        let poolParams = PoolParams(
            poolOperator: poolKeyHash,
            vrfKeyHash: vrfKeyHash,
            pledge: Coin(1000000000), // 1000 ADA
            cost: Coin(340000000),    // 340 ADA
            margin: UnitInterval(numerator: 1, denominator: 20), // 5%
            rewardAccount: rewardAccountHash,
            poolOwners: .list([ownerKeyHash]),
            relays: [relay],
            poolMetadata: poolMetadata
        )

        let poolRegistration = try PoolRegistration(poolParams: poolParams)

        // Save certificate to file
        try poolRegistration.save(to: "pool-registration.cert")

        // Load certificate from file
        let loadedCert = try PoolRegistration.load(from: "pool-registration.cert")
        _ = loadedCert
    }
}
