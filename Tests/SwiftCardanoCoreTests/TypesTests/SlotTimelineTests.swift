import Foundation
import Testing

@testable import SwiftCardanoCore

/// The built-in timelines are checked against real blocks, on both sides of every
/// boundary, rather than against constants copied from somewhere.
///
/// Getting this wrong is quiet rather than loud: a script sees a validity interval
/// it can still reason about, just at the wrong time, so a deadline check passes
/// or fails for the wrong reason.
@Suite("Slot timeline")
struct SlotTimelineTests {

    @Test(
        "Mainnet's slots land on the times its blocks actually have",
        arguments: [
            // Byron, on twenty-second slots, up to the last one before the fork.
            (UInt64(4_492_798), Int64(1_596_059_051)),
            (UInt64(4_492_799), Int64(1_596_059_071)),
            // Shelley onwards, on one-second slots.
            (UInt64(4_492_800), Int64(1_596_059_091)),
            (UInt64(4_492_840), Int64(1_596_059_131)),
            (UInt64(198_657_810), Int64(1_790_224_101)),
        ]
    )
    func mainnetMatchesRealBlocks(slot: UInt64, seconds: Int64) {
        #expect(SlotTimeline.mainnet.milliseconds(forSlot: slot) == seconds * 1000)
    }

    @Test("The system start is slot zero")
    func systemStart() {
        #expect(SlotTimeline.mainnet.milliseconds(forSlot: 0) == 1_506_203_091_000)
        #expect(SlotTimeline.preprod.milliseconds(forSlot: 0) == 1_654_041_600_000)
        #expect(SlotTimeline.preview.milliseconds(forSlot: 0) == 1_666_656_000_000)
    }

    @Test(
        "The test networks' slots land on the times their blocks actually have",
        arguments: [
            (SlotTimeline.preprod, UInt64(134_540_959), Int64(1_790_224_159)),
            (SlotTimeline.preview, UInt64(123_568_093), Int64(1_790_224_093)),
        ]
    )
    func testNetworksMatchRealBlocks(timeline: SlotTimeline, slot: UInt64, seconds: Int64) {
        #expect(timeline.milliseconds(forSlot: slot) == seconds * 1000)
    }

    /// Reading a present-day slot with the Shelley slot length from the *system*
    /// start — the obvious mistake — is out by about two and a half years.
    @Test("A single-era reading of mainnet would be wrong by years")
    func theMistakeThisPrevents() {
        let naive = SlotTimeline(
            systemStart: Date(timeIntervalSince1970: 1_506_203_091), slotLengthMilliseconds: 1_000
        )
        let slot: UInt64 = 198_657_810
        let difference = SlotTimeline.mainnet.milliseconds(forSlot: slot)
            - naive.milliseconds(forSlot: slot)
        #expect(difference == 85_363_200_000)  // 988 days
    }

    @Test("A chain with one slot length needs no eras spelled out")
    func singleEra() {
        let timeline = SlotTimeline(
            systemStart: Date(timeIntervalSince1970: 1_700_000_000), slotLengthMilliseconds: 500
        )
        #expect(timeline.milliseconds(forSlot: 0) == 1_700_000_000_000)
        #expect(timeline.milliseconds(forSlot: 10) == 1_700_000_005_000)
        #expect(timeline.slot(atMilliseconds: 1_700_000_005_000) == 10)
    }

    @Test("A slot maps back from its time")
    func roundTrip() {
        for slot: UInt64 in [0, 1, 4_492_799, 4_492_800, 198_657_810] {
            let milliseconds = SlotTimeline.mainnet.milliseconds(forSlot: slot)
            #expect(SlotTimeline.mainnet.slot(atMilliseconds: milliseconds) == slot)
        }
    }

    @Test("The node's own era history gives the same answers")
    func fromEraHistory() throws {
        let url = try #require(Bundle.module.url(
            forResource: "data/mainnet-era-history", withExtension: "json"
        ))
        struct Envelope: Codable { let cborHex: String }
        let envelope = try JSONDecoder().decode(Envelope.self, from: try Data(contentsOf: url))
        let timeline = try SlotTimeline(
            systemStart: Date(timeIntervalSince1970: 1_506_203_091),
            eraHistory: try #require(Data(hexString: envelope.cborHex))
        )

        // The history names every hard fork, so it has more eras than the
        // built-in timeline needs — but they agree on every slot.
        #expect(timeline.eras.count > SlotTimeline.mainnet.eras.count)
        for slot: UInt64 in [0, 4_492_799, 4_492_800, 16_588_800, 198_657_810] {
            #expect(
                timeline.milliseconds(forSlot: slot)
                    == SlotTimeline.mainnet.milliseconds(forSlot: slot),
                "slot \(slot)"
            )
        }
    }

    @Test("An ill-formed timeline is refused")
    func illFormed() {
        #expect(throws: CardanoCoreError.self) { try SlotTimeline(eras: []) }
        #expect(throws: CardanoCoreError.self) {
            try SlotTimeline(eras: [
                .init(startSlot: 5, startMilliseconds: 0, slotLengthMilliseconds: 1_000)
            ])
        }
        #expect(throws: CardanoCoreError.self) {
            try SlotTimeline(eras: [
                .init(startSlot: 0, startMilliseconds: 0, slotLengthMilliseconds: 1_000),
                .init(startSlot: 0, startMilliseconds: 1, slotLengthMilliseconds: 1_000),
            ])
        }
        #expect(throws: CardanoCoreError.self) {
            try SlotTimeline(eras: [
                .init(startSlot: 0, startMilliseconds: 0, slotLengthMilliseconds: 0)
            ])
        }
    }
}
