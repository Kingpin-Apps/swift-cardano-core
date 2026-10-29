import CBORCodable
import Foundation

/// Writes Plutus data as CBOR without recursing.
///
/// Writing through ``PlutusData/toPrimitive()`` recurses once per level of
/// nesting, in frames large enough that a datum a few dozen constructors deep
/// overflows a cooperative thread's stack in an unoptimised build. This writes
/// the same bytes, keeping the containers still to write in an array.
enum PlutusDataWriter {
    private enum Step {
        case value(PlutusData)
        case bytes(Data)
    }

    static func encode(_ root: PlutusData) throws -> Data {
        var data = Data()
        var steps: [Step] = [.value(root)]
        let encoder = CBOREncoder()
        while let step = steps.popLast() {
            switch step {
            case .bytes(let bytes):
                data.append(bytes)
            case .value(.bigInt(let integer)):
                data.append(try encoder.encode(integer.toPrimitive()))
            case .value(.bytes(let bytes)):
                data.append(try encoder.encode(bytes.toPrimitive()))
            case .value(.array(let elements)):
                data.append(CBORItemScanner.definiteHeader(major: 4, count: elements.count))
                push(elements, onto: &steps)
            case .value(.indefiniteArray(let elements)):
                data.append(0x9F)
                steps.append(.bytes(Data([0xFF])))
                push(elements.getAll(), onto: &steps)
            case .value(.map(let pairs)):
                data.append(CBORItemScanner.definiteHeader(major: 5, count: pairs.count))
                push(pairs, onto: &steps)
            case .value(.indefiniteMap(let pairs)):
                data.append(0xBF)
                steps.append(.bytes(Data([0xFF])))
                push(pairs, onto: &steps)
            case .value(.constructor(let constr)):
                let form = constr.encodingForm
                if let compactTag = form.compactTag {
                    data.append(CBORItemScanner.head(major: 6, argument: compactTag))
                } else {
                    data.append(CBORItemScanner.head(major: 6, argument: 102))
                    if form.generalIndefinite {
                        data.append(0x9F)
                        steps.append(.bytes(Data([0xFF])))
                    } else {
                        data.append(CBORItemScanner.head(major: 4, argument: 2))
                    }
                    data.append(CBORItemScanner.head(major: 0, argument: form.alternative))
                }
                if form.indefinite {
                    data.append(0x9F)
                    steps.append(.bytes(Data([0xFF])))
                } else {
                    data.append(CBORItemScanner.definiteHeader(major: 4, count: constr.fields.count))
                }
                push(constr.fields, onto: &steps)
            }
        }
        return data
    }

    /// Queues `elements` to be written next, first to last.
    private static func push(_ elements: [PlutusData], onto steps: inout [Step]) {
        for element in elements.reversed() {
            steps.append(.value(element))
        }
    }

    /// Queues the pairs to be written next, each key before its value.
    private static func push(_ pairs: MapPairs<PlutusData, PlutusData>, onto steps: inout [Step]) {
        for pair in Array(pairs).reversed() {
            steps.append(.value(pair.value))
            steps.append(.value(pair.key))
        }
    }
}
