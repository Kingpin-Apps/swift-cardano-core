import BigInt
import CryptoKit
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
        guard fields.count == 4,
            let a = fields[0] as? AnyValue,
            let b = fields[1] as? AnyValue,
            let c = fields[2] as? AnyValue,
            let d = fields[3] as? AnyValue
        else {
            throw CardanoCoreError.invalidArgument("Invalid fields for MyTest: \(fields)")
        }

        if let a = a.uint64Value {
            self.a = Int(a)
        } else if let a = a.int64Value {
            self.a = Int(a)
        } else {
            throw CardanoCoreError.invalidArgument("Invalid field type for MyTest.a: \(a)")
        }

        self.b = b.dataValue!
        self.c = IndefiniteList<AnyValue>(
            c.indefiniteArrayValue ?? c.arrayValue ?? []
        )
        self.d = OrderedDictionary(
            uniqueKeysWithValues: d.dictionaryValue!.map { key, value in
                (key, value)
            })

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
        //        self.data = try AnyValue.Encoder().encode(data)
        super.init(data: data)
    }

    public required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }
}
