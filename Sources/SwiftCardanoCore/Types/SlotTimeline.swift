import Foundation

/// Turns a slot number into the POSIX time it begins at.
///
/// A chain's slots are not a uniform grid. Mainnet's Byron era ran on
/// twenty-second slots and everything from Shelley on runs on one-second slots,
/// so a slot is only linear in time *within* an era. Reading a present-day slot
/// as `systemStart + slot × slotLength` puts it about two and a half years early
/// — which is the sort of mistake that quietly defeats a script's deadline check
/// rather than failing loudly.
///
/// A Plutus script sees a transaction's validity interval as POSIX
/// milliseconds, so building its context needs one of these.
///
/// ```swift
/// let timeline = SlotTimeline.mainnet
/// timeline.milliseconds(forSlot: 4492800)  // 1596059091000
/// ```
///
/// The authoritative source for any network is the node's own era history —
/// ``init(systemStart:eraHistory:)`` reads what `cardano-cli query era-history`
/// writes. The built-in timelines below are checked against mainnet's era
/// history and against real blocks on either side of every boundary.
public struct SlotTimeline: Sendable, Hashable {

    /// A stretch of the chain over which every slot has the same length.
    public struct Era: Sendable, Hashable {
        /// The first slot of this era.
        public let startSlot: UInt64
        /// The POSIX time, in milliseconds, at which `startSlot` begins.
        public let startMilliseconds: Int64
        /// How long each of this era's slots lasts, in milliseconds.
        public let slotLengthMilliseconds: Int64

        public init(startSlot: UInt64, startMilliseconds: Int64, slotLengthMilliseconds: Int64) {
            self.startSlot = startSlot
            self.startMilliseconds = startMilliseconds
            self.slotLengthMilliseconds = slotLengthMilliseconds
        }
    }

    /// The eras, in ascending order of start slot. Never empty.
    public let eras: [Era]

    /// - Parameter eras: at least one era, ascending by start slot.
    public init(eras: [Era]) throws {
        guard let first = eras.first else {
            throw CardanoCoreError.valueError("A slot timeline needs at least one era.")
        }
        guard first.startSlot == 0 else {
            throw CardanoCoreError.valueError(
                "A slot timeline has to start at slot 0, but its first era starts at "
                + "\(first.startSlot)."
            )
        }
        for (earlier, later) in zip(eras, eras.dropFirst()) where later.startSlot <= earlier.startSlot {
            throw CardanoCoreError.valueError(
                "A slot timeline's eras have to ascend by start slot, but \(later.startSlot) "
                + "follows \(earlier.startSlot)."
            )
        }
        for era in eras where era.slotLengthMilliseconds <= 0 {
            throw CardanoCoreError.valueError(
                "A slot cannot last \(era.slotLengthMilliseconds) milliseconds."
            )
        }
        self.eras = eras
    }

    /// A chain whose slots have all been the same length since its first —
    /// a devnet, or any network that never had a Byron era.
    public init(systemStart: Date, slotLengthMilliseconds: Int64) {
        self.eras = [
            Era(
                startSlot: 0,
                startMilliseconds: Int64((systemStart.timeIntervalSince1970 * 1000).rounded()),
                slotLengthMilliseconds: slotLengthMilliseconds
            )
        ]
    }

    /// The POSIX time, in milliseconds, at which `slot` begins.
    ///
    /// A slot past the last era is read with that era's slot length. That is what
    /// a node does within its forecast horizon, and beyond the horizon nobody can
    /// say — a future hard fork could change the slot length.
    public func milliseconds(forSlot slot: UInt64) -> Int64 {
        let era = eras.last { $0.startSlot <= slot } ?? eras[0]
        let elapsed = Int64(slot) - Int64(era.startSlot)
        return era.startMilliseconds + elapsed * era.slotLengthMilliseconds
    }

    /// The slot that contains a POSIX time given in milliseconds.
    public func slot(atMilliseconds milliseconds: Int64) -> UInt64 {
        let era = eras.last { $0.startMilliseconds <= milliseconds } ?? eras[0]
        let elapsed = milliseconds - era.startMilliseconds
        return era.startSlot + UInt64(max(0, elapsed / era.slotLengthMilliseconds))
    }
}

// MARK: - The public networks

extension SlotTimeline {
    /// Mainnet: twenty-second Byron slots until the Shelley hard fork at slot
    /// 4,492,800, one-second slots since.
    ///
    /// Checked against the node's own era history and against the blocks either
    /// side of the boundary — slot 4,492,799 begins at 1596059071 and slot
    /// 4,492,800 at 1596059091.
    public static let mainnet = SlotTimeline(unchecked: [
        Era(startSlot: 0, startMilliseconds: 1_506_203_091_000, slotLengthMilliseconds: 20_000),
        Era(startSlot: 4_492_800, startMilliseconds: 1_596_059_091_000, slotLengthMilliseconds: 1_000),
    ])

    /// Pre-production: twenty-second Byron slots until slot 86,400, one-second
    /// slots since.
    public static let preprod = SlotTimeline(unchecked: [
        Era(startSlot: 0, startMilliseconds: 1_654_041_600_000, slotLengthMilliseconds: 20_000),
        Era(startSlot: 86_400, startMilliseconds: 1_655_769_600_000, slotLengthMilliseconds: 1_000),
    ])

    /// Preview, which has only ever had one-second slots.
    public static let preview = SlotTimeline(unchecked: [
        Era(startSlot: 0, startMilliseconds: 1_666_656_000_000, slotLengthMilliseconds: 1_000)
    ])

    /// For the built-ins, whose eras are known to be well formed.
    private init(unchecked eras: [Era]) {
        self.eras = eras
    }
}

// MARK: - Reading a node's era history

extension SlotTimeline {
    /// Read the era history a node reports, which is the authoritative answer for
    /// any network — including one this library has no built-in timeline for.
    ///
    /// The bytes are what `cardano-cli query era-history --out-file` writes: a
    /// list of era summaries, each `[start, end, parameters]`, where a bound is
    /// `[timeRelativeToSystemStartInPicoseconds, slot, epoch]` and the parameters
    /// begin with the epoch length and the slot length in milliseconds.
    ///
    /// - Parameters:
    ///   - systemStart: the chain's start, from its Byron genesis.
    ///   - eraHistory: the CBOR the node reports.
    public init(systemStart: Date, eraHistory: Data) throws {
        let startMilliseconds = Int64((systemStart.timeIntervalSince1970 * 1000).rounded())
        guard let summaries = (try Primitive.fromCBOR(data: eraHistory)).elementsOrNil else {
            throw CardanoCoreError.deserializeError(
                "An era history has to be a list of era summaries."
            )
        }

        var eras: [Era] = []
        for summary in summaries {
            guard let fields = summary.elementsOrNil, fields.count >= 3,
                  let start = fields[0].elementsOrNil, start.count >= 2,
                  let parameters = fields[2].elementsOrNil, parameters.count >= 2
            else {
                throw CardanoCoreError.deserializeError(
                    "An era summary has to be [start, end, parameters]."
                )
            }
            // A bound's time is relative to the system start and given in
            // *picoseconds*, which runs past `Int64` within the first few years
            // of a chain — so it is divided down before it is narrowed.
            let relativePicoseconds = try BigInteger(from: start[0]).value
            guard let slot = try? BigInteger(from: start[1]).value,
                  let slotLength = try? BigInteger(from: parameters[1]).value,
                  let startSlot = UInt64(exactly: slot),
                  let slotLengthMilliseconds = Int64(exactly: slotLength),
                  let relativeMilliseconds = Int64(exactly: relativePicoseconds / 1_000_000_000)
            else {
                throw CardanoCoreError.deserializeError(
                    "An era summary's start and slot length have to be integers in range."
                )
            }
            eras.append(
                Era(
                    startSlot: startSlot,
                    startMilliseconds: startMilliseconds + relativeMilliseconds,
                    slotLengthMilliseconds: slotLengthMilliseconds
                )
            )
        }
        try self.init(eras: eras)
    }
}

extension Primitive {
    /// The elements of a list, whether it was written definite or indefinite.
    fileprivate var elementsOrNil: [Primitive]? {
        switch self {
            case .list(let elements): return elements
            case .indefiniteList(let elements): return elements.getAll()
            default: return nil
        }
    }
}

// MARK: - Choosing a timeline for a chain

extension SlotTimeline {
    /// The known network magics.
    private enum NetworkMagic {
        static let mainnet = 764_824_073
        static let preprod = 1
        static let preview = 2
    }

    /// The timeline for whichever chain these genesis parameters describe, or
    /// `nil` when they do not say enough to be sure.
    ///
    /// Genesis alone cannot place a Byron-to-Shelley boundary: the slot lengths
    /// are in there but the epoch the hard fork happened at is not. So a chain
    /// that had a Byron era is recognised by its network magic, and any other
    /// chain gets a single-era timeline only when its genesis shows it has always
    /// used one slot length. Anything else returns `nil` rather than a guess —
    /// a wrong time makes a script's deadline check pass or fail for the wrong
    /// reason, which is worse than refusing to build the context at all.
    public static func forChain(genesis: GenesisParameters) -> SlotTimeline? {
        switch genesis.networkMagic {
            case NetworkMagic.mainnet: return .mainnet
            case NetworkMagic.preprod: return .preprod
            case NetworkMagic.preview: return .preview
            default: break
        }

        guard let systemStart = genesis.systemStart, let slotLength = genesis.slotLength else {
            return nil
        }
        let milliseconds = Int64(slotLength) * 1000
        // A chain with a Byron era whose slots were a different length needs its
        // fork slot, which is not in genesis.
        if let byron = genesis.byronGenesis,
           let byronMilliseconds = Int64(byron.blockVersionData.slotDuration),
           byronMilliseconds != milliseconds {
            return nil
        }
        return SlotTimeline(systemStart: systemStart, slotLengthMilliseconds: milliseconds)
    }
}
