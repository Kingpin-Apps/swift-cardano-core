import Testing
import Foundation
import PotentCBOR
@testable import SwiftCardanoCore

// MARK: - Test Data Helpers

struct MockCBORSerializable: CBORSerializable, Hashable, Equatable {
    let value: Int
    
    init(_ value: Int) {
        self.value = value
    }
    
    init(from primitive: Primitive) throws {
        guard case let .int(intValue) = primitive else {
            throw CardanoCoreError.deserializeError("Expected int primitive")
        }
        self.value = intValue
    }
    
    func toPrimitive() throws -> Primitive {
        return .int(value)
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

