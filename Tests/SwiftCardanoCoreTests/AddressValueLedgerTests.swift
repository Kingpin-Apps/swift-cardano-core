import BigInt
import Foundation
import OrderedCollections
import Testing
@testable import SwiftCardanoCore

/// Address, asset and value decoding against the ledger's own rules
/// (IntersectMBO/cardano-ledger):
///
/// - `libs/cardano-ledger-core/src/Cardano/Ledger/Address.hs`:
///   `fromCborBothAddr`, `fromCborBackwardsBothAddr`,
///   `decodeAddrStateLenientT`, `decodePtr`, `decodePtrLenient`;
/// - `libs/cardano-ledger-core/src/Cardano/Ledger/Credential.hs`:
///   `mkPtrNormalized`;
/// - `eras/mary/impl/src/Cardano/Ledger/Mary/Value.hs`: `decodeMaryValue`,
///   `decodeMultiAsset`, `decodeIntegerBounded64`.
///
/// Mainnet transactions are from Koios (`POST /api/v1/tx_cbor`).
@Suite struct AddressValueLedgerTests {

    func hex(_ string: String) throws -> Data {
        try #require(Data(hexString: string.replacingOccurrences(of: " ", with: "")))
    }

    let keyHash = String(repeating: "11", count: 28)
    let policy = String(repeating: "22", count: 28)

    /// Decodes `bytes` as an address under the rules of `era`.
    func address(_ bytes: Data, era: Era?) throws -> Address {
        try Era.$decoding.withValue(era) { try Address(from: .bytes(bytes)) }
    }

    // MARK: - Mainnet: an output address with bytes after it

    /// Mainnet transaction 369826b2… (block 6,203,514, slot 39,249,764,
    /// epoch 288, Mary). Output 0 is a 57-byte base address followed by 21
    /// bytes, which the ledger before Babbage ignored
    /// (`fromCborBackwardsBothAddr`).
    static let garbageAddressTxId = "369826b2f60b443d27966d222fa5bedc6b900326b77a09f15473d77f5ef2871c"
    static let garbageAddressTx = """
        83a40083825820bf4f8f6287993e17f785c949ef287416ba784198bb0ee12b2c7720cbffecd26f0082582052cf97\
        1bee4ba1b4e3b32b762e0bc3f7af83700bc8897eddbd77bd425dd28e8300825820bf4f8f6287993e17f785c949ef\
        287416ba784198bb0ee12b2c7720cbffecd26f01018282584e015bad085057ac10ecc7060f7ac41edd6f63068d89\
        63ef7d86ca58669e5ecf2d283418a60be5a848a2380eb721000da1e0bbf39733134beca4cb57afb0b35fc89c6306\
        1c9914e055001a518c75161a035377d082583901f4e9e89cc628b9204fd6e2f4ae3e875aa0591fc2eb45b721520d\
        2d22f4e9e89cc628b9204fd6e2f4ae3e875aa0591fc2eb45b721520d2d221a2c651d70021a00031570031a05f5e1\
        00a10083825820ec791e29bdb3157589872d3678db93f661d72ac18204759fa5e8d630eee1e66a58408944366b10\
        15ee38809356ec48a59277701d40772a232c7cbb1e9510f2c632537d16318ba30a06953401dc2bfd693a34dc73d4\
        82050e6ccdea5811d0e1e32507825820ec791e29bdb3157589872d3678db93f661d72ac18204759fa5e8d630eee1\
        e66a58408944366b1015ee38809356ec48a59277701d40772a232c7cbb1e9510f2c632537d16318ba30a06953401\
        dc2bfd693a34dc73d482050e6ccdea5811d0e1e32507825820ec791e29bdb3157589872d3678db93f661d72ac182\
        04759fa5e8d630eee1e66a58408944366b1015ee38809356ec48a59277701d40772a232c7cbb1e9510f2c632537d\
        16318ba30a06953401dc2bfd693a34dc73d482050e6ccdea5811d0e1e32507f6
        """

    @Test func mainnetAddressWithTrailingBytesDecodesBeforeBabbage() throws {
        let bytes = try hex(Self.garbageAddressTx)
        for era in [Era.shelley, .allegra, .mary, .alonzo] {
            let tx = try Transaction.fromCBOR(data: bytes, era: era)
            #expect(try tx.toCBORData() == bytes)
            #expect(tx.id?.payload.toHex == Self.garbageAddressTxId)
            #expect(tx.transactionBody.id.payload.toHex == Self.garbageAddressTxId)

            let output = tx.transactionBody.outputs[0]
            #expect(output.address.trailingBytes.count == 21)
            #expect(output.address.toBytes().count == 78)
            #expect(output.address.ledgerBytes.count == 57)
            #expect(!output.address.isLedgerCanonical)
            #expect(output.address.addressType == .keyKey)
            #expect(output.amount.coin == 55_801_808)
            // The address the ledger, and Koios, hold.
            #expect(try output.address.toBech32()
                == "addr1q9d66zzs27kppmx8qc8h43q7m4hkxp5d39377lvxefvxd8j7eukjsdqc5c97t2zg5guqadepqqx6rc9m7wtnxy6tajjq6r54x9")
        }
    }

    @Test func mainnetAddressWithTrailingBytesFailsFromBabbage() throws {
        let bytes = try hex(Self.garbageAddressTx)
        for era in [Era.babbage, .conway] {
            #expect(throws: (any Error).self) { _ = try Transaction.fromCBOR(data: bytes, era: era) }
        }
        // `fromCBOR(data:)` reads as the current era does.
        #expect(throws: (any Error).self) { _ = try Transaction.fromCBOR(data: bytes) }

        // It is the address that fails: the output on its own.
        let output = try hex(
            "82584e015bad085057ac10ecc7060f7ac41edd6f63068d8963ef7d86ca58669e5ecf2d283418a60be5a848a2380eb7"
                + "21000da1e0bbf39733134beca4cb57afb0b35fc89c63061c9914e055001a518c75161a035377d0")
        #expect(try TransactionOutput.fromCBOR(data: output, era: .alonzo).toCBORData() == output)
        #expect(throws: (any Error).self) { _ = try TransactionOutput.fromCBOR(data: output, era: .babbage) }
    }

    @Test func trailingBytesKeepTheAddressAndItsBytes() throws {
        let base = try hex("01 \(keyHash) \(keyHash)")
        let withTrailing = base + Data([0xde, 0xad])
        let address = try address(withTrailing, era: .alonzo)
        #expect(address.toBytes() == withTrailing)
        #expect(address.ledgerBytes == base)
        #expect(address.trailingBytes == Data([0xde, 0xad]))
        // The ledger holds the same address with or without the bytes.
        let clean = try self.address(base, era: nil)
        #expect(address == clean)
        #expect(address.hashValue == clean.hashValue)
        // Strict outside an era, and from Babbage.
        #expect(throws: (any Error).self) { _ = try self.address(withTrailing, era: nil) }
        #expect(throws: (any Error).self) { _ = try self.address(withTrailing, era: .babbage) }
        // Enterprise and pointer addresses too; reward addresses never.
        let enterprise = try hex("61 \(keyHash) 00")
        #expect(try self.address(enterprise, era: .mary).trailingBytes == Data([0]))
        #expect(throws: (any Error).self) { _ = try self.address(enterprise, era: .conway) }
        let pointer = try hex("41 \(keyHash) 01 02 03 ff")
        #expect(try self.address(pointer, era: .mary).trailingBytes == Data([0xff]))
        #expect(throws: (any Error).self) { _ = try self.address(pointer, era: .babbage) }
        #expect(throws: (any Error).self) { _ = try self.address(try hex("e1 \(keyHash) 00"), era: .shelley) }
        // A Byron address must use every byte in every era
        // (`decodeBootstrapAddress` reads it with `decodeFull'`).
        let byron = try Address(from: .string(
            "DdzFFzCqrht8QHTQXbWy2qoyPaqTN8BjyfKygGmpy9dtot1tvkBfCaVTnR22XCaaDVn3M1U6aiMShoCLzw6VWSwzQKhhJrM3YjYp3wyy"))
        #expect(try self.address(byron.toBytes(), era: .shelley) == byron)
        #expect(throws: (any Error).self) { _ = try self.address(byron.toBytes() + Data([0]), era: .shelley) }
        // Too short fails in every era (`decodeHash`).
        #expect(throws: (any Error).self) { _ = try self.address(try hex("01 \(keyHash) 1111"), era: .shelley) }
    }

    // MARK: - Mainnet: a pointer whose values do not fit

    /// Mainnet transaction 9a47e091… (block 5,567,164, slot 26,366,727,
    /// epoch 258, Mary). Output 0 pays 50 ADA to a pointer address whose
    /// pointer is written as (16292793057, 1011302, 20): the slot does not
    /// fit a Word32, so the ledger reads `Ptr 0 0 0` (`mkPtrNormalized`).
    static let pointerTxId = "9a47e091709e4fe1a8ba1291bc8cfd0c0ed0bb9220688b3ccfad5f2d961e8d8e"
    static let pointerTx = """
        83a4008182582037bd6f94819f37c2329f11304a96affa5ce0b7d67d4e9cf7aca40702dcca1c6c000182825826412813\
        b99a80cfb4024374bd0f502959485aa56e0648564ff805f2e51bbcd9819561bddc66141a02faf08082583901bd2470\
        1f80bd0f9e6b9157ef57a06479cd4943f7a7fa4c128f96b25793d37dcbec1468c268eb0752b538c2568d69a3bc983d\
        c5d9ffd269e91a030ca021021a0002901d031a01926e88a100818258204944ed7e9690285a0762b1f980125bb2c6d8\
        1a435baa5edea4779112235990ae58405283f2b0e79da5481fd843fd8f868f4b8074e160c9f790b708ea8f102f0cf9\
        5b1fa4c01c09a65e58dd971f433fc510e8c837b4510c2f65b30e9972c6eba7ff09f6
        """

    @Test func mainnetOversizedPointerIsNormalizedBeforeConway() throws {
        let bytes = try hex(Self.pointerTx)
        let written = try hex("412813b99a80cfb4024374bd0f502959485aa56e0648564ff805f2e51bbcd9819561bddc6614")
        for era in [Era.shelley, .allegra, .mary, .alonzo, .babbage] {
            let tx = try Transaction.fromCBOR(data: bytes, era: era)
            #expect(try tx.toCBORData() == bytes)
            #expect(tx.id?.payload.toHex == Self.pointerTxId)

            let address = tx.transactionBody.outputs[0].address
            guard case .pointerAddress(let pointer)? = address.stakingPart else {
                Issue.record("expected a pointer address")
                return
            }
            #expect(pointer == PointerAddress(slot: 0, txIndex: 0, certIndex: 0))
            #expect(pointer.isNormalized)
            #expect(pointer.writtenValues == (16_292_793_057, 1_011_302, 20))
            #expect(address.toBytes() == written)
            #expect(address.ledgerBytes == written.prefix(29) + Data([0, 0, 0]))
            #expect(address.trailingBytes.isEmpty)
            // Koios (db-sync) shows the address the ledger holds.
            #expect(try address.toBech32() == "addr1gy5p8wv6sr8mgqjrwj7s75pft9y94ftwqey9vnlcqhew2xcqqqqqfxmvv9")
            #expect(tx.transactionBody.outputs[0].amount.coin == 50_000_000)
        }
    }

    @Test func mainnetOversizedPointerFailsFromConway() throws {
        // `decodePtr`: the slot's five bytes start 0xbc, more than 32 bits.
        #expect(throws: (any Error).self) {
            _ = try Transaction.fromCBOR(data: try hex(Self.pointerTx), era: .conway)
        }
        let output = try hex(
            "825826412813b99a80cfb4024374bd0f502959485aa56e0648564ff805f2e51bbcd9819561bddc66141a02faf080")
        #expect(try TransactionOutput.fromCBOR(data: output, era: .babbage).toCBORData() == output)
        #expect(throws: (any Error).self) { _ = try TransactionOutput.fromCBOR(data: output, era: .conway) }
    }

    // MARK: - Pointer decoding rules

    func pointer(_ bytes: String, era: Era?) throws -> PointerAddress {
        try Era.$decoding.withValue(era) { try PointerAddress.decode(try hex(bytes)) }
    }

    @Test func legacyTestnetPointerOfWord64MaxValues() throws {
        // addr_test1grqe6lg9…c9wayvj, a legacy-testnet output reported in
        // Emurgo/cardano-serialization-lib#364: each value is 2^64 − 1.
        let bytes = try hex(
            "40c19d7d05e90eeb6394b53313fe79d47077de33068c6b813bbe5c9d56"
                + "81ffffffffffffffff7f81ffffffffffffffff7f81ffffffffffffffff7f")
        let address = try self.address(bytes, era: .alonzo)
        guard case .pointerAddress(let pointer)? = address.stakingPart else {
            Issue.record("expected a pointer address")
            return
        }
        #expect(pointer == PointerAddress(slot: 0, txIndex: 0, certIndex: 0))
        #expect(pointer.writtenValues == (UInt64.max, UInt64.max, UInt64.max))
        #expect(address.toBytes() == bytes)
        #expect(throws: (any Error).self) { _ = try self.address(bytes, era: .conway) }
    }

    @Test func lenientPointerWrapsAsWord64() throws {
        // 2^64 + 5 keeps its low 64 bits, 5, which fits: the ledger before
        // Conway reads slot 5, not `Ptr 0 0 0` (`decodeVariableLengthWord64`).
        let p = try pointer("82808080808080808005 01 02", era: .mary)
        #expect(p == PointerAddress(slot: 5, txIndex: 1, certIndex: 2))
        #expect(!p.isNormalized)
        #expect(p.encode() == (try hex("82808080808080808005 01 02")))
        #expect(p.ledgerBytes == (try hex("05 01 02")))
        #expect(throws: (any Error).self) { _ = try pointer("82808080808080808005 01 02", era: .conway) }
    }

    @Test func pointerFieldWidths() throws {
        // Word32 slot, Word16 indexes: the largest values in every era.
        let largest = try pointer("8fffffff7f 83ff7f 83ff7f", era: .conway)
        #expect(largest == PointerAddress(slot: .max, txIndex: .max, certIndex: .max))
        #expect(largest.originalBytes == nil)
        // One more fails from Conway and is normalized before it.
        for bytes in ["9080808000 00 00", "00 848000 00", "00 00 848000"] {
            #expect(throws: (any Error).self) { _ = try pointer(bytes, era: .conway) }
            let normalized = try pointer(bytes, era: .babbage)
            #expect(normalized == PointerAddress(slot: 0, txIndex: 0, certIndex: 0))
            #expect(normalized.isNormalized)
            #expect(normalized.encode() == (try hex(bytes)))
        }
        // Too many bytes fails from Conway even when the value is small.
        #expect(throws: (any Error).self) { _ = try pointer("808080808001 00 00", era: .conway) }
        #expect(try pointer("808080808001 00 00", era: .alonzo) == PointerAddress(slot: 1, txIndex: 0, certIndex: 0))
        // A pointer cut short fails in every era.
        #expect(throws: (any Error).self) { _ = try pointer("01 02", era: .shelley) }
        #expect(throws: (any Error).self) { _ = try pointer("01 02 83", era: .shelley) }
    }

    @Test func paddedPointerKeepsItsBytes() throws {
        // Leading 0x80 groups are accepted in every era, Conway included.
        let p = try pointer("8001 8002 03", era: .conway)
        #expect(p == PointerAddress(slot: 1, txIndex: 2, certIndex: 3))
        #expect(p.encode() == (try hex("8001 8002 03")))
        #expect(p.ledgerBytes == (try hex("01 02 03")))
        let address = try self.address(try hex("41 \(keyHash) 8001 8002 03"), era: nil)
        #expect(address.toBytes() == (try hex("41 \(keyHash) 8001 8002 03")))
        #expect(address.ledgerBytes == (try hex("41 \(keyHash) 01 02 03")))
        #expect(address == (try Address(from: .bytes(try hex("41 \(keyHash) 01 02 03")))))
    }

    @Test func cip19PointerVector() throws {
        // CIP-19 type-4 test vector: Ptr 2498243 27 3.
        let address = try Address(from: .string("addr1gx2fxv2umyhttkxyxp8x0dlpdt3k6cwng5pxj3jhsydzer5pnz75xxcrzqf96k"))
        guard case .pointerAddress(let p)? = address.stakingPart else {
            Issue.record("expected a pointer address")
            return
        }
        #expect(p == PointerAddress(slot: 2_498_243, txIndex: 27, certIndex: 3))
        #expect(address.isLedgerCanonical)
        #expect(try address.toBech32() == "addr1gx2fxv2umyhttkxyxp8x0dlpdt3k6cwng5pxj3jhsydzer5pnz75xxcrzqf96k")
    }

    // MARK: - Output addresses

    @Test func outputAddressMustBeAPaymentAddressInBytes() throws {
        // A reward address fails as an output address (its header's high bit).
        #expect(throws: (any Error).self) {
            _ = try TransactionOutput.fromCBOR(data: try hex("82 581d e1\(keyHash) 00"))
        }
        // A text string is not an address, even a valid Bech32 one.
        let bech32 = "addr_test1vr2p8st5t5cxqglyjky7vk98k7jtfhdpvhl4e97cezuhn0cqcexl7"
        let text = Data([0x82, 0x78, UInt8(bech32.utf8.count)]) + Data(bech32.utf8) + Data([0x00])
        #expect(throws: (any Error).self) { _ = try TransactionOutput.fromCBOR(data: text) }
        #expect(try TransactionOutput.fromCBOR(data: try hex("82 581d 61\(keyHash) 00")).amount.coin == 0)
    }

    @Test func outputShapesByEra() throws {
        let datumHash = String(repeating: "33", count: 32)
        let withDatum = try hex("83 581d 61\(keyHash) 00 5820\(datumHash)")
        #expect(throws: (any Error).self) { _ = try TransactionOutput.fromCBOR(data: withDatum, era: .mary) }
        #expect(try TransactionOutput.fromCBOR(data: withDatum, era: .alonzo).datumHash != nil)
        let map = try hex("a2 00 581d 61\(keyHash) 01 00")
        #expect(throws: (any Error).self) { _ = try TransactionOutput.fromCBOR(data: map, era: .alonzo) }
        #expect(try TransactionOutput.fromCBOR(data: map, era: .babbage).postAlonzo)
        // Before Mary an output holds only a coin.
        let multiAsset = try hex("82 581d 61\(keyHash) 82 00 a1 581c\(policy) a1 40 01")
        #expect(throws: (any Error).self) { _ = try TransactionOutput.fromCBOR(data: multiAsset, era: .allegra) }
        #expect(try TransactionOutput.fromCBOR(data: multiAsset, era: .mary).amount.multiAsset.count == 1)
    }

    // MARK: - Values

    @Test func outputCoinAndTokensUpToWord64Max() throws {
        // coin = uint and positive_coin = 1 .. max_word64.
        let bytes = try hex("82 581d 61\(keyHash) 82 1bffffffffffffffff a1 581c\(policy) a1 40 1bffffffffffffffff")
        let output = try TransactionOutput.fromCBOR(data: bytes)
        #expect(output.amount.coin == BigInt(UInt64.max))
        let name = try AssetName(payload: Data())
        #expect(output.amount.multiAsset[ScriptHash(payload: try hex(policy))]?[name] == BigInt(UInt64.max))
        #expect(try output.toCBORData() == bytes)
        try output.validate()

        // Encoded afresh, the amounts are written the same way.
        let rebuilt = TransactionOutput(address: output.address, amount: output.amount)
        #expect(try rebuilt.toCBORData() == bytes)

        // 2^64 and negatives fail.
        for amount in ["c249010000000000000000", "20", "3bffffffffffffffff"] {
            #expect(throws: (any Error).self) {
                _ = try TransactionOutput.fromCBOR(data: try hex("82 581d 61\(keyHash) 82 00 a1 581c\(policy) a1 40 \(amount)"))
            }
            #expect(throws: (any Error).self) {
                _ = try TransactionOutput.fromCBOR(data: try hex("82 581d 61\(keyHash) \(amount)"))
            }
        }
    }

    @Test func mintAmountsAreSignedInt64() throws {
        let mint = { (amount: String) throws -> MultiAsset in
            try MultiAsset.fromCBOR(data: try hex("a1 581c\(self.policy) a1 40 \(amount)"))
        }
        #expect(try mint("3b7fffffffffffffff").data.values.first?.data.values.first == BigInt(Int64.min))
        #expect(try mint("1b7fffffffffffffff").data.values.first?.data.values.first == BigInt(Int64.max))
        #expect(throws: (any Error).self) { _ = try mint("1b8000000000000000") }
        #expect(throws: (any Error).self) { _ = try mint("3b8000000000000000") }
    }

    @Test func zeroAmountsArePrunedBeforeConwayAndRefusedFromIt() throws {
        let zero = try hex("82 581d 61\(keyHash) 82 05 a1 581c\(policy) a1 40 00")
        let pruned = try TransactionOutput.fromCBOR(data: zero, era: .alonzo)
        #expect(pruned.amount.multiAsset.isEmpty)
        #expect(try pruned.toCBORData() == zero)
        #expect(throws: (any Error).self) { _ = try TransactionOutput.fromCBOR(data: zero, era: .conway) }

        let emptyAssets = try hex("82 581d 61\(keyHash) 82 05 a1 581c\(policy) a0")
        #expect(try TransactionOutput.fromCBOR(data: emptyAssets, era: .babbage).amount.multiAsset.isEmpty)
        #expect(throws: (any Error).self) { _ = try TransactionOutput.fromCBOR(data: emptyAssets, era: .conway) }
    }

    @Test func assetNamesAreAtMost32Bytes() throws {
        let name32 = String(repeating: "aa", count: 32)
        #expect(try MultiAsset.fromCBOR(data: try hex("a1 581c\(policy) a1 5820\(name32) 01")).count == 1)
        #expect(throws: (any Error).self) {
            _ = try MultiAsset.fromCBOR(data: try hex("a1 581c\(policy) a1 5821\(name32)aa 01"))
        }
    }

    @Test func conwayMintMayNotBeEmpty() throws {
        let input = "81 825820\(String(repeating: "00", count: 32)) 00"
        let body = try hex("a4 00 \(input) 01 80 02 00 09 a0")
        #expect(throws: (any Error).self) { _ = try TransactionBody.fromCBOR(data: body, era: .conway) }
        #expect(try TransactionBody.fromCBOR(data: body, era: .babbage).mint?.isEmpty == true)
    }

    // MARK: - Arithmetic

    @Test func valueArithmeticDoesNotOverflow() throws {
        let policyId = ScriptHash(payload: try hex(policy))
        let name = try AssetName(payload: Data())
        let most = Value(coin: UInt64.max, multiAsset: MultiAsset([policyId: Asset([name: BigInt(UInt64.max)])]))

        let sum = most + most
        #expect(sum.coin == BigInt(UInt64.max) * 2)
        #expect(sum.multiAsset[policyId]?[name] == BigInt(UInt64.max) * 2)
        #expect(sum - most == most)
        #expect((Value() - most).coin == -BigInt(UInt64.max))
        #expect(most + Coin.max == Value(coin: BigInt(UInt64.max) * 2, multiAsset: most.multiAsset))
        #expect(Value() - Coin.max == Value(coin: -BigInt(UInt64.max)))
        #expect(most <= sum)
        #expect(!(sum <= most))

        // A sum cannot be written in an output.
        let output = TransactionOutput(address: try Address(from: .bytes(try hex("61\(keyHash)"))), amount: sum)
        #expect(throws: (any Error).self) { try output.validate() }
    }

    @Test func valueJSONKeepsWideAmounts() throws {
        for coin in [BigInt(UInt64.max), BigInt(UInt64.max) * 3, -BigInt(UInt64.max) * 2] {
            let value = Value(coin: coin)
            let decoded = try JSONDecoder().decode(Value.self, from: try JSONEncoder().encode(value))
            #expect(decoded.coin == coin)
        }
        let policyId = ScriptHash(payload: try hex(policy))
        let name = try AssetName(payload: Data([0x41]))
        let multiAsset = MultiAsset([policyId: Asset([name: BigInt(UInt64.max)])])
        let json = String(decoding: try JSONEncoder().encode(multiAsset), as: UTF8.self)
        #expect(json.contains("18446744073709551615"))
    }
}

@Suite("Output amounts keep their tokens")
struct OutputAmountTests {
    let policy = String(repeating: "a1", count: 28)

    @Test("A Babbage output with tokens round-trips through JSON")
    func babbageJSON() throws {
        let hex = "a200581d60" + String(repeating: "aa", count: 28) + "01821a004c4b40a1581c"
            + policy + "a1416101"
        let output = try TransactionOutput.fromCBORHex(hex)
        let restored = try TransactionOutput.fromDict(try output.toDict())
        #expect(restored.amount == output.amount)
        #expect(!restored.amount.multiAsset.isEmpty)
    }

    @Test("A value written as an indefinite-length list decodes")
    func indefiniteValue() throws {
        let value = try Value.fromCBORHex("9f1a004c4b40a1581c" + policy + "a1416101ff")
        #expect(value.coin == 5_000_000)
        #expect(!value.multiAsset.isEmpty)
    }

    @Test("A policy id written as text is rejected")
    func textPolicyId() {
        let output = "a200581d60" + String(repeating: "aa", count: 28) + "01821a004c4b40a17838"
            + Data(policy.utf8).toHex + "a1416101"
        #expect(throws: (any Error).self) {
            try TransactionOutput.fromCBOR(data: output.hexStringToData, era: .conway)
        }
    }
}
