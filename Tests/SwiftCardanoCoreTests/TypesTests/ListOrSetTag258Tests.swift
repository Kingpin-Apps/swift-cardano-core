import CBORCodable
import Foundation
import Testing

@testable import SwiftCardanoCore

/// Regression tests for CBOR tag `#6.258` (set) wrapping an **indefinite-length**
/// array.
///
/// Before the fix, `ListOrOrderedSet`/`ListOrNonEmptyOrderedSet` force-unwrapped
/// `tag.value.listValue!`, which is `nil` for anything that is not `.list`. A set
/// written as `d9 0102 9f … ff` therefore trapped (SIGTRAP) instead of decoding.
@Suite("Tag 258 wrapping an indefinite-length array")
struct ListOrSetTag258Tests {

    private func taggedIndefinite(_ values: [Int]) -> Primitive {
        .cborTag(
            CBORTag(
                tag: 258,
                value: .indefiniteList(IndefiniteList(values.map { Primitive.int(Int64($0)) }))
            )
        )
    }

    private func taggedDefinite(_ values: [Int]) -> Primitive {
        .cborTag(CBORTag(tag: 258, value: .list(values.map { Primitive.int(Int64($0)) })))
    }

    // MARK: - ListOrOrderedSet

    @Test("ListOrOrderedSet decodes a tag-258 indefinite array instead of trapping")
    func listOrOrderedSetDecodesIndefinite() throws {
        let decoded = try ListOrOrderedSet<MockCBORSerializable>(
            from: taggedIndefinite([1, 2, 3])
        )

        guard case .indefiniteOrderedSet(let list) = decoded else {
            Issue.record("Expected .indefiniteOrderedSet, got \(decoded)")
            return
        }
        #expect(list.count == 3)
        #expect(decoded.asArray.map(\.value) == [1, 2, 3])
    }

    @Test("ListOrOrderedSet re-encodes a tag-258 indefinite array unchanged")
    func listOrOrderedSetRoundTripsIndefinite() throws {
        let original = taggedIndefinite([1, 2, 3])
        let decoded = try ListOrOrderedSet<MockCBORSerializable>(from: original)

        #expect(try decoded.toPrimitive().toCBORData() == original.toCBORData())
    }

    @Test("ListOrOrderedSet still decodes a tag-258 definite array as an ordered set")
    func listOrOrderedSetDecodesDefinite() throws {
        let decoded = try ListOrOrderedSet<MockCBORSerializable>(from: taggedDefinite([1, 2, 3]))

        guard case .orderedSet = decoded else {
            Issue.record("Expected .orderedSet, got \(decoded)")
            return
        }
        #expect(decoded.asArray.map(\.value) == [1, 2, 3])
    }

    // MARK: - ListOrNonEmptyOrderedSet

    @Test("ListOrNonEmptyOrderedSet decodes a tag-258 indefinite array instead of trapping")
    func listOrNonEmptyDecodesIndefinite() throws {
        let decoded = try ListOrNonEmptyOrderedSet<MockCBORSerializable>(
            from: taggedIndefinite([7, 8])
        )

        guard case .indefiniteNonEmptyOrderedSet(let list) = decoded else {
            Issue.record("Expected .indefiniteNonEmptyOrderedSet, got \(decoded)")
            return
        }
        #expect(list.count == 2)
        #expect(decoded.asList.map(\.value) == [7, 8])
    }

    @Test("ListOrNonEmptyOrderedSet re-encodes a tag-258 indefinite array unchanged")
    func listOrNonEmptyRoundTripsIndefinite() throws {
        let original = taggedIndefinite([7, 8])
        let decoded = try ListOrNonEmptyOrderedSet<MockCBORSerializable>(from: original)

        #expect(try decoded.toPrimitive().toCBORData() == original.toCBORData())
    }

    // MARK: - Malformed input throws rather than trapping

    @Test("A non-258 tag throws")
    func wrongTagThrows() {
        let bad = Primitive.cborTag(CBORTag(tag: 259, value: .list([.int(1)])))
        #expect(throws: CardanoCoreError.self) {
            try ListOrOrderedSet<MockCBORSerializable>(from: bad)
        }
        #expect(throws: CardanoCoreError.self) {
            try ListOrNonEmptyOrderedSet<MockCBORSerializable>(from: bad)
        }
    }

    @Test("A tag 258 wrapping a non-list throws instead of trapping")
    func tag258AroundNonListThrows() {
        let bad = Primitive.cborTag(CBORTag(tag: 258, value: .int(42)))
        #expect(throws: CardanoCoreError.self) {
            try ListOrOrderedSet<MockCBORSerializable>(from: bad)
        }
        #expect(throws: CardanoCoreError.self) {
            try ListOrNonEmptyOrderedSet<MockCBORSerializable>(from: bad)
        }
    }

    // MARK: - Real mainnet transaction

    /// Mainnet tx `157e6e6c0707f35e8516081afc4669ba18df7ddc67d0eeb574e0c32c0bc9034c`.
    /// Its witness set carries `plutus_data` as `#6.258` around an indefinite-length
    /// array (`d9 0102 9f … ff`), which used to trap while decoding.
    static let mainnetTxWithIndefiniteSet =
        [
            "84a500d9010283825820206beee203afc3bb9603df3688462fe7e29dffe16722fc94479abc9ba45daefe01825820",
            "6c1512e256d47a67eef78dada62dcff9ddb4fb5c3d64a2979b0ec696ece65a6f01825820f8ad8dc5aa265d3b6fa8",
            "0b3e410666a4c69f74b7809fad09212d0c2d43fad53b04018483581d712c0f418d944902f96424cbc65283a18bd1",
            "6f29386a4912bda3d8f1f8821a003b8260a1581c279c909f348e533da5808898f87f9a14bb2c3dfbbacccd631d92",
            "7a3fa144534e454b1a0001ff785820b4bbf5a09d9a4eabf59b1b95ba8a7b2c34310d79060ef844fe7a0215069f04",
            "4082583901636d0d0118a8933ac167d4c448150bb325deaf7a4fdfb44adc7f2f5ae39b5f40aa85fbc121a625d777",
            "a776eca1cb4c923426949c997d8828821a001e8480a1581c279c909f348e533da5808898f87f9a14bb2c3dfbbacc",
            "cd631d927a3fa144534e454b1a0005926f82583901636d0d0118a8933ac167d4c448150bb325deaf7a4fdfb44adc",
            "7f2f5ae39b5f40aa85fbc121a625d777a776eca1cb4c923426949c997d8828821a001e8480a1581c279c909f348e",
            "533da5808898f87f9a14bb2c3dfbbacccd631d927a3fa144534e454b1a0005927082583901636d0d0118a8933ac1",
            "67d4c448150bb325deaf7a4fdfb44adc7f2f5ae39b5f40aa85fbc121a625d777a776eca1cb4c923426949c997d88",
            "281b000000030c3528d7021a0002e061031a0bd811c40b5820810cc16197b6791d211bc55d36c6ea1c772456473d",
            "d7b7e54b1f1fcdfe96269ba200d901028182582062e8297eae4d6a606981e93afec220dda426b38d38c3f504efe7",
            "ea44288a61945840c1d333204185cc5477bdea9103a5a1c464882eea995054f90bfe363112f64935ab7ef9ae400a",
            "78bd6467e95d2842731f84e6c43a6c82ce0343d15690dd99b40d04d901029fd8799f5838636d0d0118a8933ac167",
            "d4c448150bb325deaf7a4fdfb44adc7f2f5ae39b5f40aa85fbc121a625d777a776eca1cb4c923426949c997d8828",
            "d87d9f1a13036624fffffff5f6",
        ].joined()

    @Test("A real mainnet transaction with a tag-258 indefinite set decodes")
    func decodesRealMainnetTransaction() throws {
        let tx = try Transaction.fromCBORHex(Self.mainnetTxWithIndefiniteSet)

        #expect(tx.transactionWitnessSet.plutusData != nil)
    }

    @Test("A real mainnet transaction with a tag-258 indefinite set re-encodes byte-identically")
    func reEncodesRealMainnetTransactionUnchanged() throws {
        let hex = Self.mainnetTxWithIndefiniteSet
        let tx = try Transaction.fromCBORHex(hex)

        #expect(try tx.toCBORHex() == hex)
    }
}
