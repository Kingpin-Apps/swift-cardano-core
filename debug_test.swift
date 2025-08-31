import Foundation
import Testing
@testable import SwiftCardanoCore

let addr = try! Address(from: .string("addr_test1vrm9x2zsux7va6w892g38tvchnzahvcd9tykqf3ygnmwtaqyfg52x"))
let datum = try! Datum(from: .int(42))
var output = TransactionOutput(address: addr, amount: Value(coin: 100_000_000_000))
output.datum = datum
output.postAlonzo = true

print("=== Original output ===")
print("Address: \(output.address)")
print("Amount: \(output.amount)")
print("Datum: \(output.datum)")
print("PostAlonzo: \(output.postAlonzo)")

// Serialize and deserialize
let cborData = try! output.toCBORData()
let restored = try! TransactionOutput.fromCBOR(data: cborData)

print("\n=== Restored output ===")
print("Address: \(restored.address)")
print("Amount: \(restored.amount)")
print("Datum: \(restored.datum)")
print("PostAlonzo: \(restored.postAlonzo)")

print("\n=== Equality checks ===")
print("Address equal: \(output.address == restored.address)")
print("Amount equal: \(output.amount == restored.amount)")
print("Datum equal: \(output.datum == restored.datum)")
print("PostAlonzo equal: \(output.postAlonzo == restored.postAlonzo)")
print("Overall equal: \(output == restored)")

// Check datum internals if they exist
if let origDatum = output.datum, let restDatum = restored.datum {
    print("\n=== Datum details ===")
    print("Original datum type: \(type(of: origDatum))")
    print("Restored datum type: \(type(of: restDatum))")
    
    switch (origDatum, restDatum) {
    case (.int(let orig), .int(let rest)):
        print("Original int: \(orig)")
        print("Restored int: \(rest)")
        print("Int values equal: \(orig == rest)")
    default:
        print("Different datum types or not integers")
    }
}
