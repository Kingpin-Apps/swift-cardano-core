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
public struct MyTest: PlutusDataProtocol {
    public static var CONSTR_ID: UInt64 { return 130 }

    public var a: Int
    public var b: Data
    public var c: IndefiniteList<AnyValue>
    public var d: OrderedDictionary<AnyValue, AnyValue>

    public init() {
        self.a = 0
        self.b = Data()
        self.c = IndefiniteList<AnyValue>([])
        self.d = [:]
//        super.init()
    }
    
    public init(from plutusData: PlutusData) throws {
        let expectedTag = UInt64(getTag(constrID: Int(MyTest.CONSTR_ID)) ?? 0)
        guard case .constructor(let constr) = plutusData,
              constr.tag == expectedTag || constr.tag == MyTest.CONSTR_ID,
              constr.fields.count == 4
        else {
            throw CardanoCoreError.invalidArgument("Invalid PlutusData for MyTest: \(plutusData)")
        }
        
        // Parse field 'a'
        if case .bigInt(let bigIntA) = constr.fields[0],
           case .int(let intA) = bigIntA {
            self.a = Int(intA)
        } else {
            throw CardanoCoreError.invalidArgument("Invalid field type for MyTest.a: \(constr.fields[0])")
        }
        
        // Parse field 'b'
        if case .bytes(let boundedBytesB) = constr.fields[1] {
            self.b = boundedBytesB.bytes
        } else {
            throw CardanoCoreError.invalidArgument("Invalid field type for MyTest.b: \(constr.fields[1])")
        }
        
        // Parse field 'c'
        if case .indefiniteArray(let arrayC) = constr.fields[2] {
            self.c = IndefiniteList<AnyValue>(try arrayC.map { try AnyValue(from: $0.toPrimitive()) })
        } else if case .array(let arrayC) = constr.fields[2] {
            self.c = IndefiniteList<AnyValue>(try arrayC.map { try AnyValue(from: $0.toPrimitive()) })
        } else {
            throw CardanoCoreError.invalidArgument("Invalid field type for MyTest.c: \(constr.fields[2])")
        }
        
        // Parse field 'd'
        if case .map(let mapD) = constr.fields[3] {
            var orderedDict = OrderedDictionary<AnyValue, AnyValue>()
            for (key, value) in mapD {
                let anyKey = try AnyValue(from: key.toPrimitive())
                let anyValue = try AnyValue(from: value.toPrimitive())
                orderedDict[anyKey] = anyValue
            }
            self.d = orderedDict
        } else {
            throw CardanoCoreError.invalidArgument("Invalid field type for MyTest.d: \(constr.fields[3])")
        }
    }
    
    public func toPlutusData() throws -> PlutusData {
        return .constructor(
            Constr(
                tag: MyTest.CONSTR_ID,
                fields: [
                    .bigInt(.int(Int64(a))),
                    .bytes(try BoundedBytes(bytes: b)),
                    .indefiniteArray( IndefiniteList<PlutusData>(
                            try c.map { try PlutusData(from: $0.toPrimitive())
                        }
                    )),
                    .map(OrderedDictionary(
                        uniqueKeysWithValues: try d.map {
                        (try PlutusData(from: $0.key.toPrimitive()), try PlutusData(from: $0.value.toPrimitive()))
                        }
                    ))
                ]
            )
        )
    }

    public init(a: Int, b: Data, c: IndefiniteList<AnyValue>, d: OrderedDictionary<AnyValue, AnyValue>) throws {
        self.a = a
        self.b = b
        self.c = c
        self.d = d
//        try super.init(fields: [a, b, c, d])
    }

//    public init(fields: [Any]) throws {
//        guard fields.count == 4 else {
//            throw CardanoCoreError.invalidArgument("Invalid fields count for MyTest: \(fields.count), expected 4")
//        }
//        
//        // Handle the 'a' field - could be Int directly or wrapped in AnyValue
//        if let a = fields[0] as? AnyValue {
//            if let aValue = a.uint64Value {
//                self.a = Int(aValue)
//            } else if let aValue = a.int64Value {
//                self.a = Int(aValue)
//            } else {
//                throw CardanoCoreError.invalidArgument("Invalid field type for MyTest.a (AnyValue): \(a)")
//            }
//        } else if let a = fields[0] as? Int {
//            self.a = a
//        } else if let a = fields[0] as? Int64 {
//            self.a = Int(a)
//        } else if let a = fields[0] as? UInt64 {
//            self.a = Int(a)
//        } else {
//            throw CardanoCoreError.invalidArgument("Invalid field type for MyTest.a: \(type(of: fields[0]))")
//        }
//        
//        // Handle the 'b' field - could be Data directly or wrapped in AnyValue
//        if let b = fields[1] as? AnyValue {
//            guard let bData = b.dataValue else {
//                throw CardanoCoreError.invalidArgument("Invalid field type for MyTest.b (AnyValue): \(b)")
//            }
//            self.b = bData
//        } else if let b = fields[1] as? Data {
//            self.b = b
//        } else {
//            throw CardanoCoreError.invalidArgument("Invalid field type for MyTest.b: \(type(of: fields[1]))")
//        }
//        
//        // Handle the 'c' field - could be Array/IndefiniteList directly or wrapped in AnyValue
//        if let c = fields[2] as? AnyValue {
//            self.c = IndefiniteList<AnyValue>(c.indefiniteArrayValue ?? c.arrayValue ?? [])
//        } else if let c = fields[2] as? [Any] {
//            // Helper to unwrap Optional values that may be boxed as `Any`
//            func unwrapOptional(_ value: Any) -> Any? {
//                let mirror = Mirror(reflecting: value)
//                guard mirror.displayStyle == .optional else { return value }
//                return mirror.children.first?.value
//            }
//
//            // Convert raw array to AnyValue array
//            let anyValueArray: [AnyValue] = c.compactMap { value in
//                guard let v = unwrapOptional(value) else { return nil }
//
//                if let intValue = v as? Int {
//                    return .uint64(UInt64(intValue))
//                } else if let intValue = v as? Int64 {
//                    return .int64(intValue)
//                } else if let intValue = v as? UInt64 {
//                    return .uint64(intValue)
//                } else if let dataValue = v as? Data {
//                    return .data(dataValue)
//                } else if let stringValue = v as? String {
//                    return .string(stringValue)
//                } else if let anyValue = v as? AnyValue {
//                    return anyValue
//                } else {
//                    return try? AnyValue.wrapped(v)
//                }
//            }
//            self.c = IndefiniteList<AnyValue>(anyValueArray)
//        } else if let c = fields[2] as? IndefiniteList<AnyValue> {
//            self.c = c
//        } else {
//            throw CardanoCoreError.invalidArgument("Invalid field type for MyTest.c: \(type(of: fields[2]))")
//        }
//        
//        // Handle the 'd' field - could be Dictionary/OrderedDictionary directly or wrapped in AnyValue
//        if let d = fields[3] as? AnyValue, let dDict = d.dictionaryValue {
//            self.d = OrderedDictionary(uniqueKeysWithValues: dDict.map { ($0.key, $0.value) })
//        } else if let d = fields[3] as? [AnyHashable: Any] {
//            var orderedDict = OrderedDictionary<AnyValue, AnyValue>()
//            for (key, value) in d {
//                // Convert key to AnyValue
//                let anyKey: AnyValue
//                if let intKey = key.base as? Int {
//                    anyKey = .int64(Int64(intKey))
//                } else {
//                    // Replace AnyValue(from: key.base) with proper initialization
//                    anyKey = try! AnyValue.wrapped(key.base)
//                }
//                
//                // Convert value to AnyValue
//                let anyValue: AnyValue
//                if let dataValue = value as? Data {
//                    anyValue = .data(dataValue)
//                } else if let stringValue = value as? String {
//                    anyValue = .string(stringValue)
//                } else {
//                    // Replace AnyValue(from: value) with proper initialization
//                    anyValue = try! AnyValue.wrapped(value)
//                }
//                
//                orderedDict[anyKey] = anyValue
//            }
//            self.d = orderedDict
//        } else if let d = fields[3] as? OrderedDictionary<AnyValue, AnyValue> {
//            self.d = d
//        } else {
//            throw CardanoCoreError.invalidArgument("Invalid field type for MyTest.d: \(type(of: fields[3]))")
//        }
//
////        try super.init(fields: [self.a, self.b, self.c, self.d])
//    }
}

public struct BigTest: PlutusDataProtocol {
    public static let CONSTR_ID: UInt64 = 8

    public var test: MyTest
    
    public init(from plutusData: PlutusData) throws {
        let expectedTag = UInt64(getTag(constrID: Int(BigTest.CONSTR_ID))!)
        guard case .constructor(let constr) = plutusData,
              constr.tag == expectedTag || constr.tag == BigTest.CONSTR_ID,
              constr.fields.count == 1
        else {
            throw CardanoCoreError.invalidArgument("Invalid PlutusData for BigTest: \(plutusData)")
        }
        
        self.test = try MyTest(from: constr.fields[0])
    }
    
    public func toPlutusData() throws -> PlutusData {
        return .constructor(
            Constr(
                tag: BigTest.CONSTR_ID,
                fields: [
                    try test.toPlutusData()
                ]
            )
        )
    }

    public init() {
        self.test = MyTest()
//        super.init()
    }

    public init(test: MyTest) throws {
        self.test = test
//        try super.init(fields: [test])
    }

//    required public init(fields: [Any]) throws {
//        guard fields.count == 1,
//            let test = fields[0] as? AnyValue
//        else {
//            throw CardanoCoreError.invalidArgument("Invalid fields for BigTest: \(fields)")
//        }
//        self.test = try MyTest(fields: test.arrayValue![1].arrayValue ?? test.arrayValue!)
//        try super.init(fields: [self.test])
//    }
}

public struct LargestTest: PlutusDataProtocol {
    public static let CONSTR_ID: UInt64 = 9
    
    public init(from plutusData: PlutusData) throws {
        let expectedTag = UInt64(getTag(constrID: Int(LargestTest.CONSTR_ID))!)
        guard case .constructor(let constr) = plutusData,
              constr.tag == expectedTag || constr.tag == LargestTest.CONSTR_ID,
              constr.fields.isEmpty
        else {
            throw CardanoCoreError.invalidArgument("Invalid PlutusData for LargestTest: \(plutusData)")
        }
    }
    
    public func toPlutusData() throws -> PlutusData {
        return PlutusData.constructor(
            Constr(
                tag: LargestTest.CONSTR_ID,
                fields: []
            )
        )
    }

    public init() {}

    //    public init() throws {
    //        try super.init(fields: [])
    //    }

//    required public init(fields: [Any]) throws {
//        guard fields.isEmpty else {
//            throw CardanoCoreError.invalidArgument("Invalid fields for LargestTest: \(fields)")
//        }
//        try super.init(fields: fields)
//    }
}

public struct DictTest: PlutusDataProtocol {
    public static let CONSTR_ID: UInt64 = 3

    public var a: OrderedDictionary<Int, LargestTest>
    
    public init(from plutusData: PlutusData) throws {
        let expectedTag = UInt64(getTag(constrID: Int(DictTest.CONSTR_ID))!)
        guard case .constructor(let constr) = plutusData,
              constr.tag == expectedTag || constr.tag == DictTest.CONSTR_ID,
              constr.fields.count == 1,
              case .map(let mapA) = constr.fields[0]
        else {
            throw CardanoCoreError.invalidArgument("Invalid PlutusData for DictTest: \(plutusData)")
        }
        
        self.a = OrderedDictionary<Int, LargestTest>(
            uniqueKeysWithValues:
                try mapA.map { key, value in
                    guard case .bigInt(let bigIntKey) = key,
                            case .int(let intKey) = bigIntKey
                    else {
                        throw CardanoCoreError.invalidArgument("Invalid key type for DictTest.a: \(key)")
                    }
                    return (
                        Int(intKey),
                        try LargestTest(from: value)
                    )
                })
    }
    
    public func toPlutusData() throws -> PlutusData {
        let newMap = OrderedDictionary<PlutusData, PlutusData>(
            uniqueKeysWithValues:
                try a.map { key, value in
                    (
                        .bigInt(.int(Int64(key))),
                        try value.toPlutusData()
                    )
                })
        return PlutusData.constructor(
            Constr(
                tag: DictTest.CONSTR_ID,
                fields: [
                    .map(newMap)
                ]
            )
        )
    }

    public init() {
        self.a = OrderedDictionary(uniqueKeysWithValues: [0: LargestTest()])
//        super.init()
    }

    public init(a: OrderedDictionary<Int, LargestTest>) throws {
        self.a = a
//        let newMap = OrderedDictionary(
//            uniqueKeysWithValues:
//                a.map { key, value in
//                    (
//                        AnyValue(integerLiteral: key),
//                        value.toAnyValue()
//                    )
//                })
//        try super.init(fields: [newMap])
//    }

//    required public init(fields: [Any]) throws {
//        guard fields.count == 1,
//            let a = fields[0] as? AnyValue
//        else {
//            throw CardanoCoreError.invalidArgument("Invalid fields for DictTest: \(fields)")
//        }
//        self.a = OrderedDictionary(
//            uniqueKeysWithValues: a.dictionaryValue!.map { key, value in
//                (Int(key.int64Value!), try! LargestTest(fields: value.arrayValue!))
//            })
//
//        let field = OrderedDictionary(
//            uniqueKeysWithValues: a.dictionaryValue!.map { key, value in
//                (key, value)
//            })
//        try super.init(fields: [field])
    }
}

public struct ListTest: PlutusDataProtocol {
    public static let CONSTR_ID: UInt64 = 0 

    public var a: IndefiniteList<LargestTest>
    
    public init(from plutusData: PlutusData) throws {
        let expectedTag = UInt64(getTag(constrID: Int(ListTest.CONSTR_ID)) ?? 0)
        guard case .constructor(let constr) = plutusData,
              constr.tag == expectedTag || constr.tag == ListTest.CONSTR_ID,
              constr.fields.count == 1,
              case .array(let arrayA) = constr.fields[0]
        else {
            throw CardanoCoreError.invalidArgument("Invalid PlutusData for ListTest: \(plutusData)")
        }
        
        self.a = IndefiniteList<LargestTest>(
            try arrayA.map { try LargestTest(from: $0) }
        )
    }
    
    public func toPlutusData() throws -> PlutusData {
        return PlutusData.constructor(
            Constr(
                tag: ListTest.CONSTR_ID,
                fields: [
                    .array(try a.map { try $0.toPlutusData() })
                ]
            )
        )
    }


    public init() {
        self.a = IndefiniteList([LargestTest()])
//        super.init()
    }

    public init(a: IndefiniteList<LargestTest>) throws {
        self.a = a
//        let field = try a.map {
//            AnyValue.array(try $0.fields.map { try AnyValue.wrapped($0) })
//        }
//        try super.init(fields: [field])
    }

//    required public init(fields: [Any]) throws {
//        guard fields.count == 1,
//            let a = fields[0] as? AnyValue
//        else {
//            throw CardanoCoreError.invalidArgument("Invalid fields for ListTest: \(fields)")
//        }
//        self.a = IndefiniteList<LargestTest>(
//            a.arrayValue!.map { _ in LargestTest() }
//        )
//        let field = a.arrayValue!.map { $0 }
//        try super.init(fields: [field])
//    }
}

public enum MyTestType: Equatable, Hashable {
    case bigTest(BigTest)
    case largestTest(LargestTest)
}

public struct VestingParam: PlutusDataProtocol {
    public static let CONSTR_ID: UInt64 = 1

    public var beneficiary: Data
    public var deadline: Int
    public var testa: MyTestType
    public var testb: MyTestType
    
    public init(from plutusData: PlutusData) throws {
        let expectedTag = UInt64(getTag(constrID: Int(VestingParam.CONSTR_ID)) ?? 0)
        guard case .constructor(let constr) = plutusData,
              constr.tag == expectedTag || constr.tag == VestingParam.CONSTR_ID,
              constr.fields.count == 4
        else {
            throw CardanoCoreError.invalidArgument("Invalid PlutusData for VestingParam: \(plutusData)")
        }
        
        // Parse beneficiary
        if case .bytes(let boundedBytesBeneficiary) = constr.fields[0] {
            self.beneficiary = boundedBytesBeneficiary.bytes
        } else {
            throw CardanoCoreError.invalidArgument("Invalid field type for VestingParam.beneficiary: \(constr.fields[0])")
        }
        
        // Parse deadline
        if case .bigInt(let bigIntDeadline) = constr.fields[1],
           case .int(let intDeadline) = bigIntDeadline {
            self.deadline = Int(intDeadline)
        } else {
            throw CardanoCoreError.invalidArgument("Invalid field type for VestingParam.deadline: \(constr.fields[1])")
        }
        
        // Parse testa
        let testaField = constr.fields[2]
        if case .constructor(let testaConstr) = testaField {
            switch testaConstr.tag {
                case BigTest.CONSTR_ID:
                    self.testa = .bigTest(try BigTest(from: testaField))
                case LargestTest.CONSTR_ID:
                    self.testa = .largestTest(try LargestTest(from: testaField))
                default:
                    throw CardanoCoreError
                        .invalidArgument(
                            "Invalid constructor tag for VestingParam.testa: \(String(describing: testaConstr.tag))"
                        )
            }
        } else {
            throw CardanoCoreError.invalidArgument("Invalid field type for VestingParam.testa: \(testaField)")
        }
        
        // Parse testb
        let testbField = constr.fields[3]
        if case .constructor(let testbConstr) = testbField {
            switch testbConstr.tag {
                case BigTest.CONSTR_ID:
                    self.testb = .bigTest(try BigTest(from: testbField))
                case LargestTest.CONSTR_ID:
                    self.testb = .largestTest(try LargestTest(from: testbField))
                default:
                    throw CardanoCoreError
                        .invalidArgument(
                            "Invalid constructor tag for VestingParam.testb: \(String(describing: testbConstr.tag))"
                        )
            }
        } else {
            throw CardanoCoreError.invalidArgument("Invalid field type for VestingParam.testb: \(testbField)")
        }
    }
    
    public func toPlutusData() throws -> PlutusData {
        var anyA: PlutusData
        var anyB: PlutusData
        
        switch testa {
            case .bigTest(let test):
                anyA = try test.toPlutusData()
                if case let .constructor(constr) = anyA {
                    var newFields: [PlutusData] = []
                    
                    for var field in constr.fields {
                        if case var .constructor(innerConstr) = field {
                            innerConstr.useIndefiniteList = false
                            field = .constructor(innerConstr)
                        }
                        newFields.append(field)
                    }
                    anyA = .constructor(
                        Constr(
                            tag: constr.tag,
                            fields: newFields
                        )
                    )
                }
            case .largestTest(let test):
                anyA = try test.toPlutusData()
        }
        
        switch testb {
            case .bigTest(let test):
                anyB = try test.toPlutusData()
                if case let .constructor(constr) = anyB {
                    var newFields: [PlutusData] = []
                    
                    for var field in constr.fields {
                        if case var .constructor(innerConstr) = field {
                            innerConstr.useIndefiniteList = false
                            field = .constructor(innerConstr)
                        }
                        newFields.append(field)
                    }
                    anyB = .constructor(
                        Constr(
                            tag: constr.tag,
                            fields: newFields
                        )
                    )
                }
            case .largestTest(let test):
                anyB = try test.toPlutusData()
        }
        
        return .constructor(
            Constr(
                tag: VestingParam.CONSTR_ID,
                fields: [
                    .bytes(try BoundedBytes(bytes: beneficiary)),
                    .bigInt(.int(Int64(deadline))),
                    anyA,
                    anyB
                ]
            )
        )
        
    }

    public init() {
        self.beneficiary = Data()
        self.deadline = 0
        self.testa = .bigTest(BigTest())
        self.testb = .largestTest(LargestTest())
//        super.init()
    }

    public init(beneficiary: Data, deadline: Int, testa: MyTestType, testb: MyTestType) throws {
        self.beneficiary = beneficiary
        self.deadline = deadline
        self.testa = testa
        self.testb = testb
        
//        let anyA: PlutusData
//        let anyB: PlutusData
//        
//        switch testa {
//            case .bigTest(let test):
//                anyA = try test.toPlutusData()
//            case .largestTest(let test):
//                anyA = try test.toPlutusData()
//        }
//        
//        switch testb {
//            case .bigTest(let test):
//                anyB = try test.toPlutusData()
//            case .largestTest(let test):
//                anyB = try test.toPlutusData()
//        }
        
//        try super.init(fields: [beneficiary, deadline, anyA, anyB])
    }

//    required public init(fields: [Any]) throws {
//        guard fields.count == 4,
//            let beneficiary = fields[0] as? AnyValue,
//            let deadline = fields[1] as? AnyValue,
//            let testa = fields[2] as? AnyValue,
//            let testb = fields[3] as? AnyValue
//        else {
//            throw CardanoCoreError.invalidArgument("Invalid fields for VestingParam: \(fields)")
//        }
//        self.beneficiary = beneficiary.dataValue ?? Data()
//        self.deadline = Int(
//            deadline.int64Value ?? Int64(deadline.uint64Value ?? 0)
//        )
//        
//        let testaInit: Any
//        let testbInit: Any
//        
//        if testa.count == 0 {
//            testaInit = LargestTest()
//            self.testa = .largestTest(testaInit as! LargestTest)
//        } else {
//            testaInit = try BigTest(fields: testa.arrayValue!)
//            self.testa = .bigTest(testaInit as! BigTest)
//        }
//        
//        if testb.arrayValue?.count == 0 {
//            testbInit = LargestTest()
//            self.testb = .largestTest(testbInit as! LargestTest)
//        } else {
//            testbInit = try BigTest(fields: testb.arrayValue!)
//            self.testb = .bigTest(testbInit as! BigTest)
//        }
//        
////        try super.init(fields: [self.beneficiary, self.deadline, testaInit, testbInit])
//    }
}

public final class MyRedeemer: Redeemer {
    public init(data: MyTest) throws {
        super.init(data: try data.toPlutusData())
    }

    required init(from primitive: Primitive) throws {
        try super.init(from: primitive)
    }
}
