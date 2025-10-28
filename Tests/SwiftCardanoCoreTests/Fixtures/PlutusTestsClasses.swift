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
            self.b = boundedBytesB.data
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
                    .bytes(try Bytes(from: b)),
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
    }
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
    }

    public init(test: MyTest) throws {
        self.test = test
    }
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
    }

    public init(a: OrderedDictionary<Int, LargestTest>) throws {
        self.a = a
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
    }

    public init(a: IndefiniteList<LargestTest>) throws {
        self.a = a
    }
}

public enum MyTestType: Equatable, Hashable, Sendable {
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
            self.beneficiary = boundedBytesBeneficiary.data
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
                    .bytes(try Bytes(from: beneficiary)),
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
    }

    public init(beneficiary: Data, deadline: Int, testa: MyTestType, testb: MyTestType) throws {
        self.beneficiary = beneficiary
        self.deadline = deadline
        self.testa = testa
        self.testb = testb
    }
}

public struct MyRedeemer: RedeemerProtocol {
    public var tag: RedeemerTag?
    public var index: Int
    public var data: PlutusData
    public var exUnits: ExecutionUnits?

    public init(
        tag: RedeemerTag? = nil,
        index: Int = 0,
        data: PlutusData,
        exUnits: ExecutionUnits? = nil
    ) {
        self.tag = tag
        self.index = index
        self.data = data
        self.exUnits = exUnits
    }

    public init(myTest: MyTest) throws {
        self.init(data: try myTest.toPlutusData())
    }
}
