import BigInt
import Foundation
import FractionNumber
import OrderedCollections
import PotentASN1
import PotentCBOR
import PotentCodables
import SwiftNcal
import Testing

@testable import SwiftCardanoCore

// Test classes that inherit from PlutusData
public final class MyTest: PlutusData {
    override public class var CONSTR_ID: Int { return 130 }

    public var a: Int
    public var b: Data
    public var c: IndefiniteList<AnyValue>
    public var d: OrderedDictionary<AnyValue, AnyValue>

    public required init() {
        self.a = 0
        self.b = Data()
        self.c = IndefiniteList<AnyValue>([])
        self.d = [:]
        super.init()
    }

    public init(a: Int, b: Data, c: IndefiniteList<AnyValue>, d: OrderedDictionary<AnyValue, AnyValue>) throws {
        self.a = a
        self.b = b
        self.c = c
        self.d = d
        try super.init(fields: [a, b, c, d])
    }

    required public init(fields: [Any]) throws {
        guard fields.count == 4 else {
            throw CardanoCoreError.invalidArgument("Invalid fields count for MyTest: \(fields.count), expected 4")
        }
        
        // Handle the 'a' field - could be Int directly or wrapped in AnyValue
        if let a = fields[0] as? AnyValue {
            if let aValue = a.uint64Value {
                self.a = Int(aValue)
            } else if let aValue = a.int64Value {
                self.a = Int(aValue)
            } else {
                throw CardanoCoreError.invalidArgument("Invalid field type for MyTest.a (AnyValue): \(a)")
            }
        } else if let a = fields[0] as? Int {
            self.a = a
        } else if let a = fields[0] as? Int64 {
            self.a = Int(a)
        } else if let a = fields[0] as? UInt64 {
            self.a = Int(a)
        } else {
            throw CardanoCoreError.invalidArgument("Invalid field type for MyTest.a: \(type(of: fields[0]))")
        }
        
        // Handle the 'b' field - could be Data directly or wrapped in AnyValue
        if let b = fields[1] as? AnyValue {
            guard let bData = b.dataValue else {
                throw CardanoCoreError.invalidArgument("Invalid field type for MyTest.b (AnyValue): \(b)")
            }
            self.b = bData
        } else if let b = fields[1] as? Data {
            self.b = b
        } else {
            throw CardanoCoreError.invalidArgument("Invalid field type for MyTest.b: \(type(of: fields[1]))")
        }
        
        // Handle the 'c' field - could be Array/IndefiniteList directly or wrapped in AnyValue
        if let c = fields[2] as? AnyValue {
            self.c = IndefiniteList<AnyValue>(c.indefiniteArrayValue ?? c.arrayValue ?? [])
        } else if let c = fields[2] as? [Any] {
            // Helper to unwrap Optional values that may be boxed as `Any`
            func unwrapOptional(_ value: Any) -> Any? {
                let mirror = Mirror(reflecting: value)
                guard mirror.displayStyle == .optional else { return value }
                return mirror.children.first?.value
            }

            // Convert raw array to AnyValue array
            let anyValueArray: [AnyValue] = c.compactMap { value in
                guard let v = unwrapOptional(value) else { return nil }

                if let intValue = v as? Int {
                    return .uint64(UInt64(intValue))
                } else if let intValue = v as? Int64 {
                    return .int64(intValue)
                } else if let intValue = v as? UInt64 {
                    return .uint64(intValue)
                } else if let dataValue = v as? Data {
                    return .data(dataValue)
                } else if let stringValue = v as? String {
                    return .string(stringValue)
                } else if let anyValue = v as? AnyValue {
                    return anyValue
                } else {
                    return try? AnyValue.wrapped(v)
                }
            }
            self.c = IndefiniteList<AnyValue>(anyValueArray)
        } else if let c = fields[2] as? IndefiniteList<AnyValue> {
            self.c = c
        } else {
            throw CardanoCoreError.invalidArgument("Invalid field type for MyTest.c: \(type(of: fields[2]))")
        }
        
        // Handle the 'd' field - could be Dictionary/OrderedDictionary directly or wrapped in AnyValue
        if let d = fields[3] as? AnyValue, let dDict = d.dictionaryValue {
            self.d = OrderedDictionary(uniqueKeysWithValues: dDict.map { ($0.key, $0.value) })
        } else if let d = fields[3] as? [AnyHashable: Any] {
            var orderedDict = OrderedDictionary<AnyValue, AnyValue>()
            for (key, value) in d {
                // Convert key to AnyValue
                let anyKey: AnyValue
                if let intKey = key.base as? Int {
                    anyKey = .int64(Int64(intKey))
                } else {
                    // Replace AnyValue(from: key.base) with proper initialization
                    anyKey = try! AnyValue.wrapped(key.base)
                }
                
                // Convert value to AnyValue
                let anyValue: AnyValue
                if let dataValue = value as? Data {
                    anyValue = .data(dataValue)
                } else if let stringValue = value as? String {
                    anyValue = .string(stringValue)
                } else {
                    // Replace AnyValue(from: value) with proper initialization
                    anyValue = try! AnyValue.wrapped(value)
                }
                
                orderedDict[anyKey] = anyValue
            }
            self.d = orderedDict
        } else if let d = fields[3] as? OrderedDictionary<AnyValue, AnyValue> {
            self.d = d
        } else {
            throw CardanoCoreError.invalidArgument("Invalid field type for MyTest.d: \(type(of: fields[3]))")
        }

        try super.init(fields: [self.a, self.b, self.c, self.d])
    }
}

public final class BigTest: PlutusData {
    override public class var CONSTR_ID: Int { return 8 }

    public var test: MyTest

    public required init() {
        self.test = MyTest()
        super.init()
    }

    public init(test: MyTest) throws {
        self.test = test
        try super.init(fields: [test])
    }

    required public init(fields: [Any]) throws {
        guard fields.count == 1,
            let test = fields[0] as? AnyValue
        else {
            throw CardanoCoreError.invalidArgument("Invalid fields for BigTest: \(fields)")
        }
        self.test = try MyTest(fields: test.arrayValue![1].arrayValue ?? test.arrayValue!)
        try super.init(fields: [self.test])
    }
}

public final class LargestTest: PlutusData {
    override public class var CONSTR_ID: Int { return 9 }

    public required init() {
        super.init()
    }

    //    public init() throws {
    //        try super.init(fields: [])
    //    }

    required public init(fields: [Any]) throws {
        guard fields.isEmpty else {
            throw CardanoCoreError.invalidArgument("Invalid fields for LargestTest: \(fields)")
        }
        try super.init(fields: fields)
    }
}

public final class DictTest: PlutusData {
    override public class var CONSTR_ID: Int { return 3 }

    public var a: OrderedDictionary<Int, LargestTest>

    public required init() {
        self.a = OrderedDictionary(uniqueKeysWithValues: [0: LargestTest()])
        super.init()
    }

    public init(a: OrderedDictionary<Int, LargestTest>) throws {
        self.a = a
        let newMap = OrderedDictionary(
            uniqueKeysWithValues:
                try a.map { key, value in
                    (
                        AnyValue(integerLiteral: key),
                        AnyValue.array(try value.fields.map { try AnyValue.wrapped($0) })
                    )
                })
        try super.init(fields: [newMap])
    }

    required public init(fields: [Any]) throws {
        guard fields.count == 1,
            let a = fields[0] as? AnyValue
        else {
            throw CardanoCoreError.invalidArgument("Invalid fields for DictTest: \(fields)")
        }
        self.a = OrderedDictionary(
            uniqueKeysWithValues: a.dictionaryValue!.map { key, value in
                (Int(key.int64Value!), try! LargestTest(fields: value.arrayValue!))
            })

        let field = OrderedDictionary(
            uniqueKeysWithValues: a.dictionaryValue!.map { key, value in
                (key, value)
            })
        try super.init(fields: [field])
    }
}

public final class ListTest: PlutusData {
    override public class var CONSTR_ID: Int { return 0 }

    public var a: IndefiniteList<LargestTest>

    public required init() {
        self.a = IndefiniteList([LargestTest()])
        super.init()
    }

    public init(a: IndefiniteList<LargestTest>) throws {
        self.a = a
        let field = try a.map {
            AnyValue.array(try $0.fields.map { try AnyValue.wrapped($0) })
        }
        try super.init(fields: [field])
    }

    required public init(fields: [Any]) throws {
        guard fields.count == 1,
            let a = fields[0] as? AnyValue
        else {
            throw CardanoCoreError.invalidArgument("Invalid fields for ListTest: \(fields)")
        }
        self.a = IndefiniteList<LargestTest>(
            a.arrayValue!.map { _ in LargestTest() }
        )
        let field = a.arrayValue!.map { $0 }
        try super.init(fields: [field])
    }
}

public enum MyTestType {
    case bigTest(BigTest)
    case largestTest(LargestTest)
}

public final class VestingParam: PlutusData {
    override public class var CONSTR_ID: Int { return 1 }

    public var beneficiary: Data
    public var deadline: Int
    public var testa: MyTestType
    public var testb: MyTestType

    public required init() {
        self.beneficiary = Data()
        self.deadline = 0
        self.testa = .bigTest(BigTest())
        self.testb = .largestTest(LargestTest())
        super.init()
    }

    public init(beneficiary: Data, deadline: Int, testa: MyTestType, testb: MyTestType) throws {
        self.beneficiary = beneficiary
        self.deadline = deadline
        self.testa = testa
        self.testb = testb
        
        let anyA: PlutusData
        let anyB: PlutusData
        
        switch testa {
            case .bigTest(let test):
                anyA = test
            case .largestTest(let test):
                anyA = test
        }
        
        switch testb {
            case .bigTest(let test):
                anyB = test
            case .largestTest(let test):
                anyB = test
        }
        
        try super.init(fields: [beneficiary, deadline, anyA, anyB])
    }

    required public init(fields: [Any]) throws {
        guard fields.count == 4,
            let beneficiary = fields[0] as? AnyValue,
            let deadline = fields[1] as? AnyValue,
            let testa = fields[2] as? AnyValue,
            let testb = fields[3] as? AnyValue
        else {
            throw CardanoCoreError.invalidArgument("Invalid fields for VestingParam: \(fields)")
        }
        self.beneficiary = beneficiary.dataValue ?? Data()
        self.deadline = Int(
            deadline.int64Value ?? Int64(deadline.uint64Value ?? 0)
        )
        
        let testaInit: Any
        let testbInit: Any
        
        if testa.count == 0 {
            testaInit = LargestTest()
            self.testa = .largestTest(testaInit as! LargestTest)
        } else {
            testaInit = try BigTest(fields: testa.arrayValue!)
            self.testa = .bigTest(testaInit as! BigTest)
        }
        
        if testb.arrayValue?.count == 0 {
            testbInit = LargestTest()
            self.testb = .largestTest(testbInit as! LargestTest)
        } else {
            testbInit = try BigTest(fields: testb.arrayValue!)
            self.testb = .bigTest(testbInit as! BigTest)
        }
        
        try super.init(fields: [self.beneficiary, self.deadline, testaInit, testbInit])
    }
}

public final class MyRedeemer: Redeemer<MyTest> {
    public init(data: MyTest) throws {
        super.init(data: data)
    }

    required init(from primitive: Primitive) throws {
        try super.init(from: primitive)
    }
}
