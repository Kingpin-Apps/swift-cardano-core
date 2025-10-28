import BigInt
import Foundation
import FractionNumber
import OrderedCollections
import PotentASN1
import PotentCBOR
@preconcurrency import PotentCodables
import SwiftNcal
import Testing

@testable import SwiftCardanoCore

@Suite("PlutusData Tests")
struct PlutusDataTests {
    @Test("Test MyTest PlutusData object")
    func testMyTest() throws {
        let myTest = try MyTest(a: 42, b: Data(), c: IndefiniteList<AnyValue>([]), d: [:])
        let encoded = try myTest.toCBORData()
        let decoded = try MyTest.fromCBOR(data: encoded)

        #expect(myTest == decoded)
        #expect(myTest.a == 42)
        #expect(MyTest.CONSTR_ID == 130)
    }

    @Test("Test BigTest PlutusData object")
    func testBigTest() throws {
        let myTest = try MyTest(a: 42, b: Data(), c: IndefiniteList<AnyValue>([]), d: [:])
        let bigTest = try BigTest(test: myTest)
        let encoded = try bigTest.toCBORData()
        let decoded = try BigTest.fromCBOR(data: encoded)

        #expect(bigTest == decoded)
        #expect(bigTest.test == myTest)
        #expect(BigTest.CONSTR_ID == 8)
    }

    @Test("Test LargestTest PlutusData object")
    func testLargestTest() throws {
        let largestTest = LargestTest()
        let encoded = try largestTest.toCBORData()
        let decoded = try LargestTest.fromCBOR(data: encoded)

        #expect(largestTest == decoded)
        #expect(LargestTest.CONSTR_ID == 9)
    }

    @Test("Test DictTest PlutusData object")
    func testDictTest() throws {
        let dict: OrderedDictionary<Int, LargestTest> = [1: LargestTest()]
        let dictTest = try DictTest(a: dict)
        let encoded = try dictTest.toCBORData()
        let decoded = try DictTest.fromCBOR(data: encoded)

        #expect(dictTest == decoded)
    }

    @Test("Test PlutusData with lists")
    func testListPlutusData() throws {
        let listTest = try ListTest(a: IndefiniteList<LargestTest>([LargestTest()]))
        let encoded = try listTest.toCBORData()
        let decoded = try ListTest.fromCBOR(data: encoded)

        #expect(listTest == decoded)
    }

    @Test("Test PlutusData JSON conversion")
    func testJSONConversion() throws {
        let myTest = try MyTest(a: 42, b: Data(), c: IndefiniteList<AnyValue>([]), d: [:])
        let jsonString = try myTest.toJSON()
        let decoded = try MyTest.fromJSON(jsonString!)

        #expect(myTest == decoded)
    }

    @Test("Test PlutusData dictionary conversion")
    func testDictionaryConversion() throws {
        let myTest = try MyTest(a: 42, b: Data(), c: IndefiniteList<AnyValue>([]), d: [:])
        let dict = try myTest.toDict()
        let decoded = try MyTest.fromDict(dict)

        #expect(myTest == decoded)
    }
}

@Suite("PlutusData Basic Tests")
struct PlutusDataBasicTests {
    @Test("Test PlutusData CBOR serialization")
    func testPlutusDataCBOR() throws {
        let keyHash = Data(hex: "c2ff616e11299d9094ce0a7eb5b7284b705147a822f4ffbd471f971a")
        let deadline = 1_643_235_300_000
        let myTest = try MyTest(
            a: 123,
            b: Data("1234".utf8),
            c: IndefiniteList<AnyValue>([4, 5, 6]),
            d: {
                var dict = OrderedDictionary<AnyValue, AnyValue>()
                dict[AnyValue.int64(1)] = AnyValue.data(Data("1".utf8))
                dict[AnyValue.int64(2)] = AnyValue.data(Data("2".utf8))
                return dict
            }()
        )
        let testa = MyTestType.bigTest(try BigTest(test: myTest))
        let testb = MyTestType.largestTest(LargestTest())

        let myVesting = try VestingParam(
            beneficiary: keyHash,
            deadline: deadline,
            testa: testa,
            testb: testb
        )
        
        let cborHex = try myVesting.toCBORHex(deterministic: true)

        let expectedCBOR =
            "d87a9f581cc2ff616e11299d9094ce0a7eb5b7284b705147a822f4ffbd471f971a1b0000017e9874d2a0581ed905019fd86682188284187b44313233349f040506ffa2014131024132ff44d9050280ff"
        
        #expect(cborHex == expectedCBOR)

        // Test two-way serialization
//        let decoded = try VestingParam.fromCBOR(data: Data(hex: expectedCBOR))
//        #expect(try decoded.toCBORHex() == expectedCBOR)
    }

    @Test("Test PlutusData JSON serialization", .disabled("JSON serialization is not deterministic"))
    func testPlutusDataJSON() throws {
        let keyHash = Data(hex: "c2ff616e11299d9094ce0a7eb5b7284b705147a822f4ffbd471f971a")
        let deadline = 1_643_235_300_000
        let myTest = try MyTest(
            a: 123,
            b: Data("1234".utf8),
            c: IndefiniteList<AnyValue>([4, 5, 6]),
            d: {
                var dict = OrderedDictionary<AnyValue, AnyValue>()
                dict[AnyValue.int64(1)] = AnyValue.data(Data("1".utf8))
                dict[AnyValue.int64(2)] = AnyValue.data(Data("2".utf8))
                return dict
            }()
        )
        let testa = MyTestType.bigTest(try BigTest(test: myTest))
        let testb = MyTestType.largestTest(LargestTest())

        let myVesting = try VestingParam(
            beneficiary: keyHash,
            deadline: deadline,
            testa: testa,
            testb: testb
        )
        
        let json = try myVesting.toJSON()

        let expectedJSON = "{\"constructor\":1,\"fields\":[{\"bytes\":\"c2ff616e11299d9094ce0a7eb5b7284b705147a822f4ffbd471f971a\"},{\"int\":1643235300000},{\"constructor\":8,\"fields\":[{\"constructor\":130,\"fields\":[{\"int\":123},{\"bytes\":\"31323334\"},{\"list\":[{\"int\":4},{\"int\":5},{\"int\":6}]},{\"map\":[{\"k\":{\"int\":1},\"v\":{\"bytes\":\"31\"}},{\"k\":{\"int\":2},\"v\":{\"bytes\":\"32\"}}]}]}]},{\"constructor\":9,\"fields\":[]}]}"

        #expect(json == expectedJSON)

        // Test two-way serialization
        let decoded = try VestingParam.fromJSON(expectedJSON)
        #expect(try decoded.toJSON() == expectedJSON)
    }
}

@Suite("PlutusData List Tests")
struct PlutusDataListTests {
    @Test("Test PlutusData JSON List serialization")
    func testPlutusDataJSONList() throws {
        let test = try ListTest(a: IndefiniteList<LargestTest>([
            LargestTest(),
            LargestTest()
        ]))
        let expectedJSON =
            "{\"constructor\":0,\"fields\":[{\"list\":[{\"constructor\":9,\"fields\":[]},{\"constructor\":9,\"fields\":[]}]}]}"

        #expect(try test.toJSON() == expectedJSON)

        // Test two-way serialization
        let decoded = try ListTest.fromJSON(expectedJSON)
        #expect(try decoded.toJSON() == expectedJSON)
    }

    @Test("Test PlutusData CBOR List serialization")
    func testPlutusDataCBORList() throws {
        let test = try ListTest(a: IndefiniteList<LargestTest>([
            LargestTest(),
            LargestTest()
        ]))
        let expectedCBOR = "d8799f82d9050280d9050280ff"

        #expect(try test.toCBORHex() == expectedCBOR)

        // Test two-way serialization
        let decoded = try ListTest.fromCBOR(data: Data(hex: expectedCBOR))
        let decodedCBOR = try decoded.toCBORHex()
        #expect(decodedCBOR == expectedCBOR)
    }
}

@Suite("PlutusData Dict Tests")
struct PlutusDataDictTests {
    @Test("Test PlutusData JSON Dict serialization")
    func testPlutusDataJSONDict() throws {
        let test = try DictTest(a: OrderedDictionary(uniqueKeysWithValues:[1: LargestTest()]))
        let json = try test.toJSON()

        let expectedJSON =
            "{\"constructor\":3,\"fields\":[{\"map\":[{\"k\":{\"int\":1},\"v\":{\"constructor\":9,\"fields\":[]}}]}]}"

        #expect(json == expectedJSON)

        // Test two-way serialization
        let decoded = try DictTest.fromJSON(expectedJSON)
        #expect(try decoded.toJSON() == expectedJSON)
    }

    @Test("Test PlutusData CBOR Dict serialization")
    func testPlutusDataCBORDict() throws {
        let test = try DictTest(a: OrderedDictionary(uniqueKeysWithValues: [
            0: LargestTest(),
            1: LargestTest(),
        ]))
        let expectedCBOR = "d87c9fa200d905028001d9050280ff"
        let CBORHex = try test.toCBORHex(deterministic: true)

        #expect(CBORHex == expectedCBOR)

        // Test two-way serialization
        let decoded = try DictTest.fromCBOR(data: Data(hex: expectedCBOR))
        #expect(try decoded.toCBORHex(deterministic: true) == expectedCBOR)
    }
}

@Suite("PlutusData Error Tests")
struct PlutusDataErrorTests {
    @Test("Test PlutusData wrong constructor")
    func testPlutusDataWrongConstructor() throws {
        let wrongJSON =
            "{\"constructor\":129,\"fields\":[{\"int\":123},{\"bytes\":\"31323334\"},{\"list\":[{\"int\":4},{\"int\":5},{\"int\":6}]},{\"map\":[{\"v\":{\"bytes\":\"31\"},\"k\":{\"int\":1}},{\"v\":{\"bytes\":\"32\"},\"k\":{\"int\":2}}]}]}"

        #expect(throws: CardanoCoreError.self) {
            _ = try MyTest.fromJSON(wrongJSON)
        }
    }

    @Test("Test PlutusData wrong data structure")
    func testPlutusDataWrongDataStructure() throws {
        let wrongJSON =
            "{\"constructor\":130,\"fields\":[{\"int\":123},{\"bytes\":\"31323334\"},{\"wrong_list\":[{\"int\":4},{\"int\":5},{\"int\":6}]},{\"map\":[{\"v\":{\"bytes\":\"31\"},\"k\":{\"int\":1}},{\"v\":{\"bytes\":\"32\"},\"k\":{\"int\":2}}]}]}"

        #expect(throws: CardanoCoreError.self) {
            _ = try MyTest.fromJSON(wrongJSON)
        }
    }
}

@Suite("PlutusData Hash Tests")
struct PlutusDataHashTests {
    @Test("Test PlutusData hash")
    func testPlutusDataHash() throws {
        let unit = SwiftCardanoCore.Unit()
        let expectedHash = "923918e403bf43c34b4ef6b48eb2ee04babed17320d8d1b9ff9ad086e86f44ec"
        let payload = try unit.toPlutusData().hash().payload.toHex
        #expect(payload == expectedHash)
    }
}
