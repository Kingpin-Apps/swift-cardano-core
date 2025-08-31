import Foundation
import PotentCBOR
import Testing

@testable import SwiftCardanoCore

@Suite("Transaction Tests")
struct TransactionTests {
    // Test data
    let transactionId = try! TransactionId(
        from: .string("732bfd67e66be8e8288349fcaaa2294973ef6271cc189a239bb431275401b8e5")
    )
    let address = try! Address(
        from: .string("stake_test1upyz3gk6mw5he20apnwfn96cn9rscgvmmsxc9r86dh0k66gswf59n")
    )
    let amount = Value(coin: 1_000_000)
    let verificationKey = VKey(payload: Data(repeating: 0x01, count: 64))
    let signature = Data(repeating: 0x03, count: 64)

    @Test("Test initialization with required parameters")
    func testRequiredParametersInitialization() throws {
        let input = TransactionInput(transactionId: transactionId, index: 0)
        let output = TransactionOutput(address: address, amount: amount)
        let fee = Coin(100000)

        let body = TransactionBody(
            inputs: .orderedSet(try OrderedSet([input])),
            outputs: [output],
            fee: fee
        )

        let vkeyWitness = VerificationKeyWitness(
            vkey: .verificationKey(verificationKey),
            signature: signature
        )

        let witnessSet = TransactionWitnessSet<Never>(
            vkeyWitnesses: .nonEmptyOrderedSet(
                NonEmptyOrderedSet<VerificationKeyWitness>(
                    [vkeyWitness]
                )
            ),
            nativeScripts: nil,
            bootstrapWitness: nil,
            plutusV1Script: nil,
            plutusV2Script: nil,
            plutusData: nil,
            redeemers: nil
        )

        let transaction = Transaction(
            transactionBody: body,
            transactionWitnessSet: witnessSet
        )

        #expect(transaction.transactionBody == body)
        #expect(transaction.transactionWitnessSet == witnessSet)
        #expect(transaction.valid == true)
        #expect(transaction.auxiliaryData == nil)
        #expect(transaction.id == body.id)
    }

    @Test("Test initialization with all parameters")
    func testAllParametersInitialization() throws {
        let input = TransactionInput(transactionId: transactionId, index: 0)
        let output = TransactionOutput(address: address, amount: amount)
        let fee = Coin(100000)

        let body = TransactionBody(
            inputs: .orderedSet(try OrderedSet([input])),
            outputs: [output],
            fee: fee
        )

        let vkeyWitness = VerificationKeyWitness(
            vkey: .verificationKey(verificationKey),
            signature: signature
        )

        let witnessSet = TransactionWitnessSet<Never>(
            vkeyWitnesses: .nonEmptyOrderedSet(NonEmptyOrderedSet<VerificationKeyWitness>(
                [vkeyWitness]
            )),
            nativeScripts: nil,
            bootstrapWitness: nil,
            plutusV1Script: nil,
            plutusV2Script: nil,
            plutusData: nil,
            redeemers: nil
        )

        let auxiliaryData = try AuxiliaryData(data: .metadata(Metadata([1: .int(42)])))

        let transaction = Transaction(
            transactionBody: body,
            transactionWitnessSet: witnessSet,
            valid: false,
            auxiliaryData: auxiliaryData
        )

        #expect(transaction.transactionBody == body)
        #expect(transaction.transactionWitnessSet == witnessSet)
        #expect(transaction.valid == false)
        #expect(transaction.auxiliaryData == auxiliaryData)
        #expect(transaction.id == body.id)
    }

    @Test("Test Codable conformance")
    func testCodable() throws {
        let input = TransactionInput(transactionId: transactionId, index: 0)
        let output = TransactionOutput(address: address, amount: amount)
        let fee = Coin(100000)

        let body = TransactionBody(
            inputs: .orderedSet(try OrderedSet([input])),
            outputs: [output],
            fee: fee
        )

        let vkeyWitness = VerificationKeyWitness(
            vkey: .verificationKey(verificationKey),
            signature: signature
        )

        let witnessSet = TransactionWitnessSet<Never>(
            vkeyWitnesses: .nonEmptyOrderedSet(NonEmptyOrderedSet<VerificationKeyWitness>(
                [vkeyWitness]
            )),
            nativeScripts: nil,
            bootstrapWitness: nil,
            plutusV1Script: nil,
            plutusV2Script: nil,
            plutusData: nil,
            redeemers: nil
        )

        let auxiliaryData = try AuxiliaryData(
            data: .metadata(Metadata([1: .int(42)]))
        )

        let originalTransaction = Transaction(
            transactionBody: body,
            transactionWitnessSet: witnessSet,
            valid: false,
            auxiliaryData: auxiliaryData
        )

        let encodedData = try originalTransaction.toCBORData()
        let decodedTransaction = try Transaction<Never>.fromCBOR(data: encodedData)

        #expect(decodedTransaction == originalTransaction)
        #expect(decodedTransaction.transactionBody == originalTransaction.transactionBody)
        #expect(
            decodedTransaction.transactionWitnessSet == originalTransaction.transactionWitnessSet)
        #expect(decodedTransaction.valid == originalTransaction.valid)
        #expect(decodedTransaction.auxiliaryData == originalTransaction.auxiliaryData)
        #expect(decodedTransaction.id == originalTransaction.id)
    }

    @Test("Test transaction ID generation")
    func testTransactionId() throws {
        let input = TransactionInput(transactionId: transactionId, index: 0)
        let output = TransactionOutput(address: address, amount: amount)
        let fee = Coin(100000)

        let body = TransactionBody(
            inputs: .orderedSet(try OrderedSet([input])),
            outputs: [output],
            fee: fee
        )

        let vkeyWitness = VerificationKeyWitness(
            vkey: .verificationKey(verificationKey),
            signature: signature
        )

        let witnessSet = TransactionWitnessSet<Never>(
            vkeyWitnesses: .nonEmptyOrderedSet(NonEmptyOrderedSet<VerificationKeyWitness>(
                [vkeyWitness]
            )),
            nativeScripts: nil,
            bootstrapWitness: nil,
            plutusV1Script: nil,
            plutusV2Script: nil,
            plutusData: nil,
            redeemers: nil
        )

        let transaction = Transaction(
            transactionBody: body,
            transactionWitnessSet: witnessSet
        )

        let id = transaction.id
        #expect(id?.payload.count == TRANSACTION_HASH_SIZE)
        #expect(id == body.id)
    }
    
    // MARK: - PyCardano Converted Tests
    
    @Test("Test TransactionInput creation and CBOR encoding")
    func testTransactionInput() throws {
        let txIdHex = "732bfd67e66be8e8288349fcaaa2294973ef6271cc189a239bb431275401b8e5"
        let txId = try TransactionId(from: .string(txIdHex))
        let txIn = TransactionInput(transactionId: txId, index: 0)
        
        let expectedCBORHex = "825820732bfd67e66be8e8288349fcaaa2294973ef6271cc189a239bb431275401b8e500"
        let actualCBORHex = try txIn.toCBORHex()
        
        #expect(actualCBORHex == expectedCBORHex)
        #expect(try checkTwoWayCBOR(serializable: txIn))
    }
    
    @Test("Test TransactionInput is hashable")
    func testHashableTransactionInput() throws {
        var myInputs: [TransactionInput: Int] = [:]
        let txIdHex1 = "732bfd67e66be8e8288349fcaaa2294973ef6271cc189a239bb431275401b8e5"
        let txIdHex2 = "732bfd67e66be8e8288349fcaaa2294973ef6271cc189a239bb431275401b8e5"
        let txId1 = try TransactionId(from: .string(txIdHex1))
        let txId2 = try TransactionId(from: .string(txIdHex2))
        let txIn1 = TransactionInput(transactionId: txId1, index: 0)
        let txIn2 = TransactionInput(transactionId: txId2, index: 0)
        
        #expect(txIn1 == txIn2)
        myInputs[txIn1] = 1
        #expect(myInputs[txIn1] == 1)
    }
    
    @Test("Test TransactionOutput creation and CBOR encoding")
    func testTransactionOutput() throws {
        let addr = try Address(from: .string("addr_test1vrm9x2zsux7va6w892g38tvchnzahvcd9tykqf3ygnmwtaqyfg52x"))
        let output = TransactionOutput(address: addr, amount: Value(coin: 100_000_000_000))
        
        let expectedCBORHex = "82581d60f6532850e1bccee9c72a9113ad98bcc5dbb30d2ac960262444f6e5f41b000000174876e800"
        let actualCBORHex = try output.toCBORHex()
        
        #expect(actualCBORHex == expectedCBORHex)
        #expect(try checkTwoWayCBOR(serializable: output))
    }
    
    @Test("Test TransactionOutput with string address")
    func testTransactionOutputStringAddress() throws {
        let addrString = "addr_test1vrm9x2zsux7va6w892g38tvchnzahvcd9tykqf3ygnmwtaqyfg52x"
        let output = try TransactionOutput(from: addrString, amount: 100_000_000_000)
        
        let expectedCBORHex = "82581d60f6532850e1bccee9c72a9113ad98bcc5dbb30d2ac960262444f6e5f41b000000174876e800"
        let actualCBORHex = try output.toCBORHex()
        
        #expect(actualCBORHex == expectedCBORHex)
        #expect(try checkTwoWayCBOR(serializable: output))
    }
    
    @Test("Test TransactionOutput with inline datum")
    func testTransactionOutputInlineDatum() throws {
        let addr = try Address(from: .string("addr_test1vrm9x2zsux7va6w892g38tvchnzahvcd9tykqf3ygnmwtaqyfg52x"))
        let datum = try Datum(from: .int(42))
        var output = TransactionOutput(address: addr, amount: Value(coin: 100_000_000_000))
        output.datum = datum
        output.postAlonzo = true
        
        let expectedCBORHex = "a300581d60f6532850e1bccee9c72a9113ad98bcc5dbb30d2ac960262444f6e5f4011b000000174876e800028201d81842182a"
        let actualCBORHex = try output.toCBORHex()
        
        #expect(actualCBORHex == expectedCBORHex)
        #expect(try checkTwoWayCBOR(serializable: output))
    }
    
    @Test("Test invalid TransactionOutput with negative amount")
    func testInvalidTransactionOutput() throws {
        let addr = try Address(from: .string("addr_test1vrm9x2zsux7va6w892g38tvchnzahvcd9tykqf3ygnmwtaqyfg52x"))
        let output = TransactionOutput(address: addr, amount: Value(coin: -1))
        
        #expect(throws: (any Error).self) {
            try output.validate()
        }
        
        // Test with negative token amount
        let scriptHashSize = 28 // SCRIPT_HASH_SIZE equivalent
        let scriptHashBytes = Data(repeating: 0x01, count: scriptHashSize)
        let scriptHash = ScriptHash(payload: scriptHashBytes)
        
        let asset = Asset([AssetName(from: "TestToken1"): -10_000_000, AssetName(from: "TestToken2"): 20_000_000])
        let multiAsset = MultiAsset([scriptHash: asset])
        let valueWithNegativeTokens = Value(coin: 100, multiAsset: multiAsset)
        let outputWithNegativeTokens = TransactionOutput(address: addr, amount: valueWithNegativeTokens)
        
        #expect(throws: (any Error).self) {
            try outputWithNegativeTokens.validate()
        }
    }
    
    @Test("Test TransactionBody creation and CBOR encoding")
    func testTransactionBody() throws {
        let txBody = try makeTransactionBody()
        
        let expectedCBORHex = "a50081825820732bfd67e66be8e8288349fcaaa2294973ef6271cc189a239bb431275401b8e500018282581d60f6532850e1bccee9c72a9113ad98bcc5dbb30d2ac960262444f6e5f41b000000174876e80082581d60f6532850e1bccee9c72a9113ad98bcc5dbb30d2ac960262444f6e5f41b000000ba43b4b7f7021a000288090d800e80"
        let actualCBORHex = try txBody.toCBORHex()
        
        #expect(actualCBORHex == expectedCBORHex)
        #expect(try checkTwoWayCBOR(serializable: txBody))
    }
    
    @Test("Test full transaction CBOR deserialization")
    func testFullTransactionDeserialization() throws {
        let txCBORHex = "84a70081825820b35a4ba9ef3ce21adcd6879d08553642224304704d206c74d3ffb3e6eed3ca28000d80018182581d60cc30497f4ff962f4c1dca54cceefe39f86f1d7179668009f8eb71e598200a1581cec8b7d1dd0b124e8333d3fa8d818f6eac068231a287554e9ceae490ea24f5365636f6e6454657374746f6b656e1a009896804954657374746f6b656e1a00989680021a000493e00e8009a1581cec8b7d1dd0b124e8333d3fa8d818f6eac068231a287554e9ceae490ea24f5365636f6e6454657374746f6b656e1a009896804954657374746f6b656e1a00989680075820592a2df0e091566969b3044626faa8023dabe6f39c78f33bed9e105e55159221a200828258206443a101bdb948366fc87369336224595d36d8b0eee5602cba8b81a024e584735840846f408dee3b101fda0f0f7ca89e18b724b7ca6266eb29775d3967d6920cae7457accb91def9b77571e15dd2ede38b12cf92496ce7382fa19eb90ab7f73e49008258205797dc2cc919dfec0bb849551ebdf30d96e5cbe0f33f734a87fe826db30f7ef95840bdc771aa7b8c86a8ffcbe1b7a479c68503c8aa0ffde8059443055bf3e54b92f4fca5e0b9ca5bb11ab23b1390bb9ffce414fa398fc0b17f4dc76fe9f7e2c99c09018182018482051a075bcd1582041a075bcd0c8200581c9139e5c0a42f0f2389634c3dd18dc621f5594c5ba825d9a8883c66278200581c835600a2be276a18a4bebf0225d728f090f724f4c0acd591d066fa6ff5d90103a100a11902d1a16b7b706f6c6963795f69647da16d7b706f6c6963795f6e616d657da66b6465736372697074696f6e6a3c6f7074696f6e616c3e65696d6167656a3c72657175697265643e686c6f636174696f6ea367617277656176656a3c6f7074696f6e616c3e6568747470736a3c6f7074696f6e616c3e64697066736a3c72657175697265643e646e616d656a3c72657175697265643e667368613235366a3c72657175697265643e64747970656a3c72657175697265643e"
        
        let tx = try Transaction<Never>.fromCBORHex(txCBORHex)
        print(tx)
        #expect(try checkTwoWayCBOR(serializable: tx))
    }
    
    @Test("Test MultiAsset creation and operations")
    func testMultiAsset() throws {
        let scriptHashSize = 28 // SCRIPT_HASH_SIZE equivalent
        let scriptHashBytes = Data(repeating: 0x01, count: scriptHashSize)
        let scriptHash = ScriptHash(payload: scriptHashBytes)
        
        let asset = Asset([
            AssetName(from: "TestToken1"): 10_000_000,
            AssetName(from: "TestToken2"): 20_000_000
        ])
        let multiAsset = MultiAsset([scriptHash: asset])
        let value = Value(coin: 100, multiAsset: multiAsset)
        
        // Test primitive serialization/deserialization
        let primitive = value.toPrimitive()
        let restoredValue = try Value(from: primitive)
        
        #expect(value == restoredValue)
        #expect(try checkTwoWayCBOR(serializable: value))
    }
    
    @Test("Test MultiAsset addition")
    func testMultiAssetAddition() throws {
        let scriptHashSize = 28
        let scriptHash1 = ScriptHash(payload: Data(repeating: 0x01, count: scriptHashSize))
        let scriptHash2 = ScriptHash(payload: Data(repeating: 0x02, count: scriptHashSize))
        
        let multiAssetA = MultiAsset([
            scriptHash1: Asset([
                AssetName(from: "Token1"): 1,
                AssetName(from: "Token2"): 2
            ])
        ])
        
        let multiAssetB = MultiAsset([
            scriptHash1: Asset([
                AssetName(from: "Token1"): 10,
                AssetName(from: "Token2"): 20
            ]),
            scriptHash2: Asset([
                AssetName(from: "Token1"): 1,
                AssetName(from: "Token2"): 2
            ])
        ])
        
        let expectedResult = MultiAsset([
            scriptHash1: Asset([
                AssetName(from: "Token1"): 11,
                AssetName(from: "Token2"): 22
            ]),
            scriptHash2: Asset([
                AssetName(from: "Token1"): 1,
                AssetName(from: "Token2"): 2
            ])
        ])
        
        let result = multiAssetA + multiAssetB
        let unionResult = multiAssetA.union(multiAssetB)
        
        #expect(result == expectedResult)
        #expect(unionResult == expectedResult)
        
        // Verify original objects unchanged
        #expect(multiAssetA == MultiAsset([
            scriptHash1: Asset([
                AssetName(from: "Token1"): 1,
                AssetName(from: "Token2"): 2
            ])
        ]))
    }
    
    @Test("Test MultiAsset subtraction")
    func testMultiAssetSubtraction() throws {
        let scriptHashSize = 28
        let scriptHash1 = ScriptHash(payload: Data(repeating: 0x01, count: scriptHashSize))
        let scriptHash2 = ScriptHash(payload: Data(repeating: 0x02, count: scriptHashSize))
        
        let multiAssetA = MultiAsset([
            scriptHash1: Asset([
                AssetName(from: "Token1"): 1,
                AssetName(from: "Token2"): 2
            ])
        ])
        
        let multiAssetB = MultiAsset([
            scriptHash1: Asset([
                AssetName(from: "Token1"): 10,
                AssetName(from: "Token2"): 20
            ]),
            scriptHash2: Asset([
                AssetName(from: "Token1"): 1,
                AssetName(from: "Token2"): 2
            ])
        ])
        
        let expectedBMinusA = MultiAsset([
            scriptHash1: Asset([
                AssetName(from: "Token1"): 9,
                AssetName(from: "Token2"): 18
            ]),
            scriptHash2: Asset([
                AssetName(from: "Token1"): 1,
                AssetName(from: "Token2"): 2
            ])
        ])
        
        let expectedAMinusB = MultiAsset([
            scriptHash1: Asset([
                AssetName(from: "Token1"): -9,
                AssetName(from: "Token2"): -18
            ]),
            scriptHash2: Asset([
                AssetName(from: "Token1"): -1,
                AssetName(from: "Token2"): -2
            ])
        ])
        
        let resultBMinusA = multiAssetB - multiAssetA
        let resultAMinusB = multiAssetA - multiAssetB
        
        #expect(resultBMinusA == expectedBMinusA)
        #expect(resultAMinusB == expectedAMinusB)
    }
    
    @Test("Test Asset comparison")
    func testAssetComparison() throws {
        let assetA = Asset([AssetName(from: "Token1"): 1, AssetName(from: "Token2"): 2])
        let assetB = Asset([AssetName(from: "Token1"): 1, AssetName(from: "Token2"): 3])
        let assetC = Asset([
            AssetName(from: "Token1"): 1,
            AssetName(from: "Token2"): 2,
            AssetName(from: "Token3"): 3
        ])
        let assetD = Asset([AssetName(from: "Token3"): 1, AssetName(from: "Token4"): 2])
        
        let unionResult = assetA.union(assetB)
        let expectedUnion = Asset([AssetName(from: "Token1"): 2, AssetName(from: "Token2"): 5])
        
        #expect(unionResult == expectedUnion)
        #expect(assetA == assetA)
        #expect(assetA < assetB)
        #expect(assetA <= assetB)
        #expect(!(assetB <= assetA))
        #expect(assetB > assetA)
        #expect(assetB >= assetA)
        #expect(assetA != assetB)
        #expect(assetA < assetC)
        #expect(assetA <= assetC)
        #expect(!(assetC <= assetA))
        #expect(assetC > assetA)
        #expect(assetC >= assetA)
        #expect(assetA != assetC)
        
        // Test incomparable assets
        #expect(!(assetA == assetD))
        #expect(!(assetA <= assetD))
        #expect(!(assetD <= assetA))
    }
    
    @Test("Test MultiAsset comparison")
    func testMultiAssetComparison() throws {
        let scriptHashSize = 28
        let scriptHash1 = ScriptHash(payload: Data(repeating: 0x01, count: scriptHashSize))
        let scriptHash2 = ScriptHash(payload: Data(repeating: 0x02, count: scriptHashSize))
        
        let multiAssetA = MultiAsset([
            scriptHash1: Asset([AssetName(from: "Token1"): 1, AssetName(from: "Token2"): 2])
        ])
        
        let multiAssetB = MultiAsset([
            scriptHash1: Asset([
                AssetName(from: "Token1"): 1,
                AssetName(from: "Token2"): 2,
                AssetName(from: "Token3"): 3
            ])
        ])
        
        let multiAssetC = MultiAsset([
            scriptHash1: Asset([AssetName(from: "Token1"): 1, AssetName(from: "Token2"): 3]),
            scriptHash2: Asset([AssetName(from: "Token1"): 1, AssetName(from: "Token2"): 2])
        ])
        
        let multiAssetD = MultiAsset([
            scriptHash2: Asset([AssetName(from: "Token1"): 1, AssetName(from: "Token2"): 2])
        ])
        
        #expect(multiAssetA != multiAssetB)
        #expect(multiAssetA <= multiAssetB)
        #expect(multiAssetA < multiAssetC)
        #expect(multiAssetB > multiAssetA)
        #expect(multiAssetB >= multiAssetA)
        #expect(!(multiAssetB <= multiAssetA))
        #expect(multiAssetA != multiAssetC)
        #expect(multiAssetA <= multiAssetC)
        #expect(multiAssetC > multiAssetA)
        #expect(multiAssetC >= multiAssetA)
        #expect(!(multiAssetC <= multiAssetA))
        #expect(multiAssetA != multiAssetD)
        #expect(!(multiAssetA <= multiAssetD))
        #expect(!(multiAssetD <= multiAssetA))
    }
    
    @Test("Test Value operations")
    func testValues() throws {
        let scriptHashSize = 28
        let scriptHash1String = String(repeating: "1", count: scriptHashSize * 2) // hex string
        let scriptHash2String = String(repeating: "2", count: scriptHashSize * 2) // hex string
        
        let scriptHash1 = ScriptHash(payload: Data(hexString: scriptHash1String)!)
        let scriptHash2 = ScriptHash(payload: Data(hexString: scriptHash2String)!)
        
        let valueA = Value(coin: 1, multiAsset: MultiAsset([
            scriptHash1: Asset([AssetName(from: "Token1"): 1, AssetName(from: "Token2"): 2])
        ]))
        
        let valueB = Value(coin: 11, multiAsset: MultiAsset([
            scriptHash1: Asset([AssetName(from: "Token1"): 11, AssetName(from: "Token2"): 22])
        ]))
        
        let valueC = Value(coin: 11, multiAsset: MultiAsset([
            scriptHash1: Asset([AssetName(from: "Token1"): 11, AssetName(from: "Token2"): 22]),
            scriptHash2: Asset([AssetName(from: "Token1"): 11, AssetName(from: "Token2"): 22])
        ]))
        
        let valueE = Value(coin: 1000)
        let intValue = 1000
        
        #expect(valueE.coin >= intValue)
        #expect(valueA != valueB)
        #expect(valueA <= valueB)
        #expect(valueA < valueB)
        #expect(valueB > valueA)
        #expect(valueB >= valueA)
        #expect(!(valueB <= valueA))
        #expect(valueA <= valueC)
        #expect(valueC > valueA)
        #expect(valueC >= valueA)
        #expect(!(valueC <= valueA))
        #expect(valueB <= valueC)
        #expect(!(valueC <= valueB))
        
        let expectedBMinusA = Value(coin: 10, multiAsset: MultiAsset([
            scriptHash1: Asset([AssetName(from: "Token1"): 10, AssetName(from: "Token2"): 20])
        ]))
        #expect(valueB - valueA == expectedBMinusA)
        
        let expectedCMinusA = Value(coin: 10, multiAsset: MultiAsset([
            scriptHash1: Asset([AssetName(from: "Token1"): 10, AssetName(from: "Token2"): 20]),
            scriptHash2: Asset([AssetName(from: "Token1"): 11, AssetName(from: "Token2"): 22])
        ]))
        #expect(valueC - valueA == expectedCMinusA)
        
        let expectedAPlus100 = Value(coin: 101, multiAsset: MultiAsset([
            scriptHash1: Asset([AssetName(from: "Token1"): 1, AssetName(from: "Token2"): 2])
        ]))
        #expect(valueA + Value(coin: 100) == expectedAPlus100)
        
        let expectedAMinusC = Value(coin: -10, multiAsset: MultiAsset([
            scriptHash1: Asset([AssetName(from: "Token1"): -10, AssetName(from: "Token2"): -20]),
            scriptHash2: Asset([AssetName(from: "Token1"): -11, AssetName(from: "Token2"): -22])
        ]))
        #expect(valueA - valueC == expectedAMinusC)
        
        let result = valueA.union(valueB)
        let expectedUnion = Value(coin: 12, multiAsset: MultiAsset([
            scriptHash1: Asset([AssetName(from: "Token1"): 12, AssetName(from: "Token2"): 24])
        ]))
        #expect(result == expectedUnion)
        
        let valueF = Value(coin: 1)
        let intD = 10_000_000
        #expect(valueF.coin <= intD)
    }
    
    @Test("Test zero value handling")
    func testZeroValue() throws {
        let policyId = Data(hexString: "a39a5998f2822dfc9111e447038c3cfffa883ed1b9e357be9cd60dfe")!
        let scriptHash = ScriptHash(payload: policyId)
        
        let nftOutput = Value(
            coin: 10_000_000,
            multiAsset: MultiAsset([
                scriptHash: Asset([AssetName(from: "MY_NFT_1"): 0])
            ])
        )
        
        #expect(nftOutput.multiAsset.count == 0)
    }
    
    @Test("Test empty multiasset handling")
    func testEmptyMultiasset() throws {
        let policyId = Data(hexString: "a39a5998f2822dfc9111e447038c3cfffa883ed1b9e357be9cd60dfe")!
        let scriptHash = ScriptHash(payload: policyId)
        
        let nftOutput = Value(
            coin: 10_000_000,
            multiAsset: MultiAsset([scriptHash: Asset([:])])
        )
        
        #expect(nftOutput.multiAsset.count == 0)
    }
    
    @Test("Test add empty asset handling")
    func testAddEmpty() throws {
        let policyId = Data(hexString: "a39a5998f2822dfc9111e447038c3cfffa883ed1b9e357be9cd60dfe")!
        let scriptHash = ScriptHash(payload: policyId)
        
        let valueWithAsset = Value(
            coin: 10_000_000,
            multiAsset: MultiAsset([
                scriptHash: Asset([AssetName(from: "MY_NFT_1"): 100])
            ])
        )
        
        let valueToSubtract = Value(
            coin: 5,
            multiAsset: MultiAsset([
                scriptHash: Asset([AssetName(from: "MY_NFT_1"): 100])
            ])
        )
        
        let nftOutput = valueWithAsset - valueToSubtract
        #expect(nftOutput.multiAsset.count == 0)
    }
    
    @Test("Test zero value pop")
    func testZeroValuePop() throws {
        let policyId = Data(hexString: "a39a5998f2822dfc9111e447038c3cfffa883ed1b9e357be9cd60dfe")!
        let scriptHash = ScriptHash(payload: policyId)
        
        let nftOutput = Value(
            coin: 10_000_000,
            multiAsset: MultiAsset([
                scriptHash: Asset([
                    AssetName(from: "MY_NFT_1"): 0,
                    AssetName(from: "MY_NFT_2"): 1
                ])
            ])
        )
        
        #expect(nftOutput.multiAsset.count == 1)
        #expect(nftOutput.multiAsset[scriptHash]?.count == 1)
    }
    
    @Test("Test empty multiasset pop")
    func testEmptyMultiassetPop() throws {
        let policyId1 = Data(hexString: "a39a5998f2822dfc9111e447038c3cfffa883ed1b9e357be9cd60dfe")!
        let policyId2 = Data(hexString: "b39a5998f2822dfc9111e447038c3cfffa883ed1b9e357be9cd60dfe")!
        let scriptHash1 = ScriptHash(payload: policyId1)
        let scriptHash2 = ScriptHash(payload: policyId2)
        
        let nftOutput = Value(
            coin: 10_000_000,
            multiAsset: MultiAsset([
                scriptHash1: Asset([:]),
                scriptHash2: Asset([AssetName(from: "MY_NFT_1"): 1])
            ])
        )
        
        #expect(nftOutput.multiAsset.count == 1)
    }
    
    @Test("Test add empty pop")
    func testAddEmptyPop() throws {
        let policyId = Data(hexString: "a39a5998f2822dfc9111e447038c3cfffa883ed1b9e357be9cd60dfe")!
        let scriptHash = ScriptHash(payload: policyId)
        
        let valueWithAssets = Value(
            coin: 10_000_000,
            multiAsset: MultiAsset([
                scriptHash: Asset([
                    AssetName(from: "MY_NFT_1"): 100,
                    AssetName(from: "MY_NFT_2"): 100
                ])
            ])
        )
        
        let valueToSubtract = Value(
            coin: 5,
            multiAsset: MultiAsset([
                scriptHash: Asset([AssetName(from: "MY_NFT_1"): 100])
            ])
        )
        
        let nftOutput = valueWithAssets - valueToSubtract
        #expect(nftOutput.multiAsset.count == 1)
        #expect(nftOutput.multiAsset[scriptHash]?.count == 1)
    }
    
    @Test("Test out of bound asset")
    func testOutOfBoundAsset() throws {
        let scriptHashSize = 28
        let scriptHash = ScriptHash(payload: Data(repeating: 0x01, count: scriptHashSize))
        
        // Create asset with very large amount (equivalent to 1 << 64 in Python)
        let largeAmount = Int.max
        let asset = Asset([AssetName(from: "abc"): largeAmount])
        
        // Asset creation should be okay for regular asset
        #expect(asset.count == 1)
        
        // But not okay when minting (this would need to be tested in TransactionBody validation)
        let txBody = TransactionBody(
            inputs: .orderedSet(try OrderedSet([TransactionInput(transactionId: transactionId, index: 0)])),
            outputs: [TransactionOutput(address: address, amount: amount)],
            fee: 100_000,
            mint: MultiAsset([scriptHash: asset])
        )
        
        // Note: The validation for out-of-bounds values during minting
        // should be handled in the TransactionBody validation
        #expect(throws: (any Error).self) {
            try txBody.validate()
        }
    }
}
