import Testing
import Foundation
import CBORCodable
import OrderedCollections
@testable import SwiftCardanoCore

// MARK: - Test Data Helpers

struct MockCBORSerializable: Serializable {
    let value: Int
    
    init(_ value: Int) {
        self.value = value
    }
    
    init(from primitive: Primitive) throws {
        guard case let .int(intValue) = primitive else {
            throw CardanoCoreError.deserializeError("Expected int primitive")
        }
        self.value = Int(intValue)
    }

    func toPrimitive() throws -> Primitive {
        return .int(Int64(value))
    }

    static func fromDict(_ primitive: Primitive) throws -> MockCBORSerializable {
        guard case let .orderedDict(dict) = primitive else {
            throw CardanoCoreError.deserializeError("Expected orderedDict primitive")
        }
        guard case let .int(intValue)? = dict[.string("value")] else {
            throw CardanoCoreError.deserializeError("Expected 'value' key with int primitive")
        }
        return MockCBORSerializable(Int(intValue))
    }

    func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        dict[.string("value")] = .int(Int64(value))
        return .orderedDict(dict)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(value)
    }
}

struct ListOrOrderedSetTests {
    
    // MARK: - Initialization Tests
    
    @Test("Test ListOrOrderedSet list initialization")
    func testListInitialization() async throws {
        let elements = [MockCBORSerializable(1), MockCBORSerializable(2), MockCBORSerializable(3)]
        let listOrSet = ListOrOrderedSet.list(elements)
        
        #expect(listOrSet.count == 3)
        #expect(listOrSet.asArray == elements)
    }
    
    // MARK: - Property Tests
    
    @Test("Test ListOrOrderedSet count property")
    func testCount() async throws {
        let elements = [MockCBORSerializable(1), MockCBORSerializable(2)]
        
        let listVersion = ListOrOrderedSet.list(elements)
        #expect(listVersion.count == 2)
    }
    
    @Test("Test ListOrOrderedSet asArray property")
    func testAsArray() async throws {
        let elements = [MockCBORSerializable(1), MockCBORSerializable(2), MockCBORSerializable(3)]
        
        let listVersion = ListOrOrderedSet.list(elements)
        #expect(listVersion.asArray == elements)
    }
    
    // MARK: - CBOR Serialization Tests
    
    @Test("Test ListOrOrderedSet CBOR serialization with list")
    func testCBORSerializationList() async throws {
        let elements = [MockCBORSerializable(1), MockCBORSerializable(2), MockCBORSerializable(3)]
        let original = ListOrOrderedSet.list(elements)
        
        let primitive = try original.toPrimitive()
        let decoded = try ListOrOrderedSet<MockCBORSerializable>(from: primitive)
        
        #expect(decoded.count == original.count)
        #expect(decoded.asArray == original.asArray)
    }
    
    // Skip orderedSet CBOR serialization test
    
    @Test("Test ListOrOrderedSet CBOR deserialization from list primitive")
    func testCBORDeserializationFromList() async throws {
        let listPrimitive = Primitive.list([.int(1), .int(2), .int(3)])
        let decoded = try ListOrOrderedSet<MockCBORSerializable>(from: listPrimitive)
        
        #expect(decoded.count == 3)
        #expect(decoded.asArray.map { $0.value }.sorted() == [1, 2, 3])
    }
    
    @Test("Test ListOrOrderedSet CBOR deserialization with invalid primitive")
    func testCBORDeserializationInvalidPrimitive() async throws {
        let invalidPrimitive = Primitive.int(123)
        
        #expect(throws: CardanoCoreError.self) {
            try ListOrOrderedSet<MockCBORSerializable>(from: invalidPrimitive)
        }
    }
    
    // MARK: - Functionality Tests
    
    @Test("Test ListOrOrderedSet contains method")
    func testContains() async throws {
        let elements = [MockCBORSerializable(1), MockCBORSerializable(2), MockCBORSerializable(3)]
        let target = MockCBORSerializable(2)
        let nonExistent = MockCBORSerializable(99)
        
        let listVersion = ListOrOrderedSet.list(elements)
        #expect(listVersion.contains(target))
        #expect(!listVersion.contains(nonExistent))
    }
    
    @Test("Test ListOrOrderedSet append method with list")
    func testAppendToList() async throws {
        let elements = [MockCBORSerializable(1), MockCBORSerializable(2)]
        var listOrSet = ListOrOrderedSet.list(elements)
        let newElement = MockCBORSerializable(3)
        
        try listOrSet.append(newElement)
        
        #expect(listOrSet.count == 3)
        #expect(listOrSet.contains(newElement))
        
        // Should be a list with the new element appended
        if case let .list(array) = listOrSet {
            #expect(array.last == newElement)
        } else {
            Issue.record("Expected list case after append")
        }
    }
    
    // MARK: - Equatable and Hashable Tests
    
    @Test("Test ListOrOrderedSet equality")
    func testEquality() async throws {
        let elements1 = [MockCBORSerializable(1), MockCBORSerializable(2)]
        let elements2 = [MockCBORSerializable(1), MockCBORSerializable(2)]
        let elements3 = [MockCBORSerializable(1), MockCBORSerializable(3)]
        
        let list1 = ListOrOrderedSet.list(elements1)
        let list2 = ListOrOrderedSet.list(elements2)
        let list3 = ListOrOrderedSet.list(elements3)
        
        #expect(list1 == list2)
        #expect(list1 != list3)
    }
    
    @Test("Test ListOrOrderedSet hashable")
    func testHashable() async throws {
        let elements = [MockCBORSerializable(1), MockCBORSerializable(2)]
        
        let list1 = ListOrOrderedSet.list(elements)
        let list2 = ListOrOrderedSet.list(elements)
        
        // Same content should have same hash
        #expect(list1.hashValue == list2.hashValue)
        
        // Can be used in sets
        let set = Set([list1, list2])
        #expect(set.count == 1) // Should be deduplicated
    }
    
    // MARK: - Edge Cases
    
    @Test("Test ListOrOrderedSet with empty list")
    func testEmptyList() async throws {
        let emptyList = ListOrOrderedSet<MockCBORSerializable>.list([])
        
        #expect(emptyList.count == 0)
        #expect(emptyList.asArray.isEmpty)
        #expect(!emptyList.contains(MockCBORSerializable(1)))
    }
    
    @Test("Test ListOrOrderedSet with duplicate elements in list")
    func testListWithDuplicates() async throws {
        let duplicateElements = [MockCBORSerializable(1), MockCBORSerializable(1), MockCBORSerializable(2)]
        let listOrSet = ListOrOrderedSet.list(duplicateElements)
        
        #expect(listOrSet.count == 3) // List preserves duplicates
        #expect(listOrSet.asArray == duplicateElements)
    }
}

struct ListOrNonEmptyOrderedSetTests {
    
    // MARK: - Initialization Tests
    
    @Test("Test ListOrNonEmptyOrderedSet list initialization")
    func testListInitialization() async throws {
        let elements = [MockCBORSerializable(1), MockCBORSerializable(2), MockCBORSerializable(3)]
        let listOrSet = ListOrNonEmptyOrderedSet.list(elements)
        
        #expect(listOrSet.count == 3)
        #expect(listOrSet.asList == elements)
    }
    
    // MARK: - Property Tests
    
    @Test("Test ListOrNonEmptyOrderedSet count property")
    func testCount() async throws {
        let elements = [MockCBORSerializable(1), MockCBORSerializable(2)]
        
        let listVersion = ListOrNonEmptyOrderedSet.list(elements)
        #expect(listVersion.count == 2)
    }
    
    @Test("Test ListOrNonEmptyOrderedSet asList property")
    func testAsList() async throws {
        let elements = [MockCBORSerializable(1), MockCBORSerializable(2), MockCBORSerializable(3)]
        
        let listVersion = ListOrNonEmptyOrderedSet.list(elements)
        #expect(listVersion.asList == elements)
    }
    
    // MARK: - CBOR Serialization Tests
    
    @Test("Test ListOrNonEmptyOrderedSet CBOR serialization with list")
    func testCBORSerializationList() async throws {
        let elements = [MockCBORSerializable(1), MockCBORSerializable(2), MockCBORSerializable(3)]
        let original = ListOrNonEmptyOrderedSet.list(elements)
        
        let primitive = try original.toPrimitive()
        let decoded = try ListOrNonEmptyOrderedSet<MockCBORSerializable>(from: primitive)
        
        #expect(decoded.count == original.count)
        #expect(decoded.asList == original.asList)
    }
    
    // Skip nonEmptyOrderedSet CBOR serialization test
    
    @Test("Test ListOrNonEmptyOrderedSet CBOR deserialization from list primitive")
    func testCBORDeserializationFromList() async throws {
        let listPrimitive = Primitive.list([.int(1), .int(2), .int(3)])
        let decoded = try ListOrNonEmptyOrderedSet<MockCBORSerializable>(from: listPrimitive)
        
        #expect(decoded.count == 3)
        #expect(decoded.asList.map { $0.value }.sorted() == [1, 2, 3])
    }
    
    @Test("Test ListOrNonEmptyOrderedSet CBOR deserialization with invalid primitive")
    func testCBORDeserializationInvalidPrimitive() async throws {
        let invalidPrimitive = Primitive.int(123)
        
        #expect(throws: CardanoCoreError.self) {
            try ListOrNonEmptyOrderedSet<MockCBORSerializable>(from: invalidPrimitive)
        }
    }
    
    // MARK: - Functionality Tests
    
    @Test("Test ListOrNonEmptyOrderedSet contains method")
    func testContains() async throws {
        let elements = [MockCBORSerializable(1), MockCBORSerializable(2), MockCBORSerializable(3)]
        let target = MockCBORSerializable(2)
        let nonExistent = MockCBORSerializable(99)
        
        let listVersion = ListOrNonEmptyOrderedSet.list(elements)
        #expect(listVersion.contains(target))
        #expect(!listVersion.contains(nonExistent))
    }
    
    @Test("Test ListOrNonEmptyOrderedSet append method with list")
    func testAppendToList() async throws {
        let elements = [MockCBORSerializable(1), MockCBORSerializable(2)]
        var listOrSet = ListOrNonEmptyOrderedSet.list(elements)
        let newElement = MockCBORSerializable(3)
        
        try listOrSet.append(newElement)
        
        #expect(listOrSet.count == 3)
        #expect(listOrSet.contains(newElement))
        
        // Should be a list with the new element appended
        if case let .list(array) = listOrSet {
            #expect(array.last == newElement)
        } else {
            Issue.record("Expected list case after append")
        }
    }
    
    // Skip append to nonEmptyOrderedSet test
    
    // MARK: - Equatable and Hashable Tests
    
    @Test("Test ListOrNonEmptyOrderedSet equality")
    func testEquality() async throws {
        let elements1 = [MockCBORSerializable(1), MockCBORSerializable(2)]
        let elements2 = [MockCBORSerializable(1), MockCBORSerializable(2)]
        let elements3 = [MockCBORSerializable(1), MockCBORSerializable(3)]
        
        let list1 = ListOrNonEmptyOrderedSet.list(elements1)
        let list2 = ListOrNonEmptyOrderedSet.list(elements2)
        let list3 = ListOrNonEmptyOrderedSet.list(elements3)
        
        #expect(list1 == list2)
        #expect(list1 != list3)
    }
    
    @Test("Test ListOrNonEmptyOrderedSet hashable")
    func testHashable() async throws {
        let elements = [MockCBORSerializable(1), MockCBORSerializable(2)]
        
        let list1 = ListOrNonEmptyOrderedSet.list(elements)
        let list2 = ListOrNonEmptyOrderedSet.list(elements)
        
        // Same content should have same hash
        #expect(list1.hashValue == list2.hashValue)
        
        // Can be used in sets
        let set = Set([list1, list2])
        #expect(set.count == 1) // Should be deduplicated
    }
    
    // MARK: - Edge Cases
    
    @Test("Test ListOrNonEmptyOrderedSet with empty list")
    func testEmptyList() async throws {
        let emptyList = ListOrNonEmptyOrderedSet<MockCBORSerializable>.list([])
        
        #expect(emptyList.count == 0)
        #expect(emptyList.asList.isEmpty)
        #expect(!emptyList.contains(MockCBORSerializable(1)))
    }
    
    @Test("Test ListOrNonEmptyOrderedSet with duplicate elements in list")
    func testListWithDuplicates() async throws {
        let duplicateElements = [MockCBORSerializable(1), MockCBORSerializable(1), MockCBORSerializable(2)]
        let listOrSet = ListOrNonEmptyOrderedSet.list(duplicateElements)
        
        #expect(listOrSet.count == 3) // List preserves duplicates
        #expect(listOrSet.asList == duplicateElements)
    }
    
    @Test("Test ListOrNonEmptyOrderedSet deserialization with empty list primitive")
    func testDeserializationEmptyListPrimitive() async throws {
        let emptyListPrimitive = Primitive.list([])
        
        let decoded = try ListOrNonEmptyOrderedSet<MockCBORSerializable>(from: emptyListPrimitive)
        #expect(decoded.count == 0)
        #expect(decoded.asList.isEmpty)
    }
}


// MARK: - Canonical (deterministic) set encoding

/// Regression tests for the non-deterministic set encoding that produced
/// invalid vkey witnesses on multi-input transactions: `SetTaggable.elements`
/// is a Swift `Set`, so encoding it directly yielded per-process-random byte
/// order — the tx-body hash a witness was signed over could differ from the
/// serialized body, and the ledger rejected it (`InvalidWitnessesUTXOW`).
@Suite struct SetCanonicalEncodingTests {
    // 32-byte transaction id (64 hex chars).
    static let txid = String(repeating: "ab", count: 32)

    @Test
    func testOrderedSetCanonicalElementsAreByteSorted() throws {
        let in0 = try TransactionInput(from: Self.txid, index: 0)
        let in1 = try TransactionInput(from: Self.txid, index: 1)
        let in2 = try TransactionInput(from: Self.txid, index: 2)

        let set = try OrderedSet([in2, in0, in1])
        let ordered = set.canonicalElements

        #expect(ordered.count == 3)
        for i in 1..<ordered.count {
            #expect(
                try ordered[i - 1].toCBORData().lexicographicallyPrecedes(ordered[i].toCBORData()),
                "canonicalElements must be sorted by CBOR bytes"
            )
        }
    }

    @Test
    func testOrderedSetEncodingIsStable() throws {
        let in0 = try TransactionInput(from: Self.txid, index: 0)
        let in1 = try TransactionInput(from: Self.txid, index: 1)
        let in2 = try TransactionInput(from: Self.txid, index: 2)

        // A set keeps the order it was given, and encodes the same way every
        // time. That order is what makes a decoded body re-encode to the bytes
        // it came from, and so keep its hash.
        let a = try OrderedSet([in2, in0, in1])
        let b = try OrderedSet([in0, in1, in2])
        #expect(try a.toCBORData() == a.toCBORData())
        #expect(try a.toCBORData() != b.toCBORData())

        // A Swift `Set` has no order of its own, so one built from it comes out
        // canonical rather than in whatever order the Set happened to iterate.
        let fromSet = try OrderedSet(Set([in2, in0, in1]))
        #expect(fromSet.elementsOrdered == [in0, in1, in2])
    }
}

// MARK: - Ordering determinism

/// A tagged set keeps the order its elements were given in, because that order
/// is part of what it means: the ledger reads a transaction's certificates and
/// proposals in the order they were written, and re-encoding them in any other
/// order changes the body's hash. The order also has to be stable — the elements
/// are backed by a Swift `Set`, whose iteration order is randomised per process,
/// so anything reading straight from that would give a different element order,
/// and a different element *index*, on every run.
@Suite("Tagged set ordering is deterministic")
struct TaggedSetOrderingTests {

    private func input(_ idByte: UInt8, index: UInt16 = 0) -> TransactionInput {
        TransactionInput(
            transactionId: TransactionId(payload: Data(repeating: idByte, count: 32)),
            index: index
        )
    }

    @Test("asArray keeps the order the elements were given in")
    func orderedSetAsArrayKeepsItsOrder() throws {
        let elements = [input(0xCC), input(0xAA), input(0xBB)]
        let set = try OrderedSet(elements)
        let value = ListOrOrderedSet.orderedSet(set)

        #expect(value.asArray == set.elementsOrdered)
        #expect(value.asArray.map { $0.transactionId.payload.first } == [0xCC, 0xAA, 0xBB])
    }

    @Test("asList keeps the order for non-empty ordered sets")
    func nonEmptyOrderedSetAsListKeepsItsOrder() throws {
        let elements = [input(0xCC), input(0xAA), input(0xBB)]
        let set = NonEmptyOrderedSet(elements)
        let value = ListOrNonEmptyOrderedSet.nonEmptyOrderedSet(set)

        #expect(value.asList == set.elementsOrdered)
        #expect(value.asList.map { $0.transactionId.payload.first } == [0xCC, 0xAA, 0xBB])
    }

    /// The order has to survive the trip a transaction actually takes: decoded
    /// into a `Primitive` and read back out. Losing it there changes the bytes
    /// of the body the set sits in, and so changes the transaction's hash.
    @Test("A set round-trips without changing its bytes")
    func roundTripKeepsTheBytes() throws {
        let set = try OrderedSet([input(0xCC), input(0xAA), input(0xBB)])
        let encoded = try set.toCBORData()

        let throughPrimitive = try OrderedSet<TransactionInput>(from: try set.toPrimitive())
        #expect(throughPrimitive.elementsOrdered == set.elementsOrdered)
        #expect(try throughPrimitive.toCBORData() == encoded)

        let throughCBOR = try OrderedSet<TransactionInput>.fromCBOR(data: encoded)
        #expect(throughCBOR.elementsOrdered == set.elementsOrdered)
        #expect(try throughCBOR.toCBORData() == encoded)
    }

    /// A set holds its elements as themselves, so encoding one has to reach for
    /// each element's CBOR. Reaching for its JSON instead put *field names* on
    /// the wire: a set of inputs came out as a list of
    /// `{"transactionId": …, "index": …}` maps, which nothing could read back.
    @Test("A set's elements go on the wire in their own CBOR form")
    func elementsKeepTheirCBORForm() throws {
        let element = input(0xAA, index: 1)
        let set = try OrderedSet([element])
        let encoded = try set.toCBORData().toHex
        #expect(encoded == "d9010281" + (try element.toCBORData().toHex))
    }

    @Test("asArray agrees with the subscript at every index")
    func asArrayAgreesWithSubscript() throws {
        let set = try OrderedSet([input(0xCC), input(0xAA), input(0xBB)])
        let value = ListOrOrderedSet.orderedSet(set)
        for index in 0..<value.count {
            #expect(value.asArray[index] == value[index])
        }
    }

    @Test("asList agrees with the subscript at every index")
    func asListAgreesWithSubscript() throws {
        let set = NonEmptyOrderedSet([input(0xCC), input(0xAA), input(0xBB)])
        let value = ListOrNonEmptyOrderedSet.nonEmptyOrderedSet(set)
        for index in 0..<value.count {
            #expect(value.asList[index] == value[index])
        }
    }

    @Test("repeated reads return the same order")
    func repeatedReadsAreStable() throws {
        let set = try OrderedSet([input(0x03), input(0x01), input(0x02), input(0x04)])
        let value = ListOrOrderedSet.orderedSet(set)
        let first = value.asArray
        for _ in 0..<20 {
            #expect(value.asArray == first)
        }
    }

    @Test("first is the first element in order, not an arbitrary one")
    func firstFollowsTheOrder() throws {
        let set = try OrderedSet([input(0xCC), input(0xAA), input(0xBB)])
        #expect(set.first == set.elementsOrdered.first)
        #expect(set.first?.transactionId.payload.first == 0xCC)
    }
}
