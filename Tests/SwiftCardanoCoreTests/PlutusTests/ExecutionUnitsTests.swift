import Testing
import Foundation
@testable import SwiftCardanoCore

@Suite("ExecutionUnits Tests")
struct ExecutionUnitsTests {
    
    @Test("Initialization creates ExecutionUnits with correct values")
    func testInitialization() {
        let units = ExecutionUnits(mem: 100, steps: 200)
        #expect(units.mem == 100)
        #expect(units.steps == 200)
    }
    
    @Test("ExecutionUnits can be encoded and decoded")
    func testCodingAndDecoding() throws {
        let original = ExecutionUnits(mem: 100, steps: 200)
        
        // Test encoding
        let encoder = JSONEncoder()
        let encoded = try encoder.encode(original)
        
        // Test decoding
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ExecutionUnits.self, from: encoded)
        
        #expect(decoded.mem == original.mem)
        #expect(decoded.steps == original.steps)
    }
    
    @Test("Addition operator combines ExecutionUnits correctly")
    func testAddition() {
        let units1 = ExecutionUnits(mem: 100, steps: 200)
        let units2 = ExecutionUnits(mem: 300, steps: 400)
        
        let sum = units1 + units2
        
        #expect(sum.mem == 400)
        #expect(sum.steps == 600)
    }
    
    @Test("isEmpty returns correct boolean value")
    func testIsEmpty() {
        let emptyUnits = ExecutionUnits(mem: 0, steps: 0)
        let nonEmptyUnits = ExecutionUnits(mem: 100, steps: 200)
        
        #expect(emptyUnits.isEmpty())
        #expect(!nonEmptyUnits.isEmpty())
    }
    
    @Test("Edge cases handle large and negative numbers")
    func testEdgeCases() {
        // Test with large numbers
        let largeUnits = ExecutionUnits(mem: Int.max - 1, steps: Int.max - 1)
        #expect(largeUnits.mem == Int.max - 1)
        #expect(largeUnits.steps == Int.max - 1)
        
        // Test with negative numbers (while this might not be a valid use case,
        // it's good to test how the struct handles it)
        let negativeUnits = ExecutionUnits(mem: -100, steps: -200)
        #expect(negativeUnits.mem == -100)
        #expect(negativeUnits.steps == -200)
    }
} 
