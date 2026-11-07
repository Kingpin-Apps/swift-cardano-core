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
/// A slot or a time too far out to represent converts to `nil`, never to a
/// wrapped value or a crash: a validity interval is often supplied by someone
/// else.
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

        /// Creates an era from its first slot, start time and slot length.
        ///
        /// - Parameters:
        ///   - startSlot: The first slot of the era.
        ///   - startMilliseconds: The POSIX time, in milliseconds, at which `startSlot` begins.
        ///   - slotLengthMilliseconds: How long each slot of the era lasts, in milliseconds.
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
    ///
    /// - Parameters:
    ///   - systemStart: The time slot 0 begins.
    ///   - slotLengthMilliseconds: How long each slot lasts, in milliseconds.
    /// - Throws: ``CardanoCoreError/valueError(_:)`` when the slot length is
    ///   not positive, or the system start is not a representable number of
    ///   milliseconds.
    public init(systemStart: Date, slotLengthMilliseconds: Int64) throws {
        try self.init(eras: [
            Era(
                startSlot: 0,
                startMilliseconds: try Self.milliseconds(since1970: systemStart),
                slotLengthMilliseconds: slotLengthMilliseconds
            )
        ])
    }

    /// The POSIX time, in milliseconds, at which `slot` begins, or `nil` when
    /// that time does not fit an `Int64`.
    ///
    /// A slot past the last era is read with that era's slot length. That is what
    /// a node does within its forecast horizon, and beyond the horizon nobody can
    /// say — a future hard fork could change the slot length.
    public func milliseconds(forSlot slot: UInt64) -> Int64? {
        let era = eras.last { $0.startSlot <= slot } ?? eras[0]
        // `era.startSlot <= slot`: the first era starts at slot 0.
        guard let elapsed = Int64(exactly: slot - era.startSlot) else { return nil }
        let (offset, multiplyOverflow) = elapsed.multipliedReportingOverflow(
            by: era.slotLengthMilliseconds)
        guard !multiplyOverflow else { return nil }
        let (time, addOverflow) = era.startMilliseconds.addingReportingOverflow(offset)
        return addOverflow ? nil : time
    }

    /// The slot that contains a POSIX time given in milliseconds, or `nil`
    /// when that slot does not fit a `UInt64`.
    ///
    /// A time before the system start is in slot 0.
    public func slot(atMilliseconds milliseconds: Int64) -> UInt64? {
        let era = eras.last { $0.startMilliseconds <= milliseconds } ?? eras[0]
        guard milliseconds > era.startMilliseconds else { return era.startSlot }
        // Both are `Int64`, and `milliseconds` is the larger, so the
        // difference fits a `UInt64`.
        let elapsed = UInt64(bitPattern: milliseconds &- era.startMilliseconds)
        // Every initializer checks the slot length is positive.
        let (slot, overflow) = era.startSlot.addingReportingOverflow(
            elapsed / UInt64(era.slotLengthMilliseconds))
        return overflow ? nil : slot
    }

    /// A date as whole POSIX milliseconds.
    ///
    /// - Throws: ``CardanoCoreError/valueError(_:)`` when it does not fit an
    ///   `Int64`.
    fileprivate static func milliseconds(since1970 date: Date) throws -> Int64 {
        let milliseconds = (date.timeIntervalSince1970 * 1000).rounded()
        guard milliseconds.isFinite, milliseconds >= -0x1p63, milliseconds < 0x1p63 else {
            throw CardanoCoreError.valueError(
                "A system start of \(date.timeIntervalSince1970) seconds is out of range.")
        }
        return Int64(milliseconds)
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
    /// - Throws: When the bytes are not an era history, when an era's start
    ///   or slot length is out of range, or when the eras are not a valid
    ///   timeline (see ``init(eras:)``).
    public init(systemStart: Date, eraHistory: Data) throws {
        let startMilliseconds = try Self.milliseconds(since1970: systemStart)
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
                  let relativeMilliseconds = Int64(exactly: relativePicoseconds / 1_000_000_000),
                  case (let eraStart, false) = startMilliseconds.addingReportingOverflow(relativeMilliseconds)
            else {
                throw CardanoCoreError.deserializeError(
                    "An era summary's start and slot length have to be integers in range."
                )
            }
            eras.append(
                Era(
                    startSlot: startSlot,
                    startMilliseconds: eraStart,
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
        static let mainnet: UInt32 = 764_824_073
        static let preprod: UInt32 = 1
        static let preview: UInt32 = 2
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
    /// reason, which is worse than refusing to build the context at all. A
    /// slot length that is not positive returns `nil` too.
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
        // A slot length that is not a whole number of milliseconds, or does
        // not fit, has no timeline here.
        var exact = slotLength * 1000
        var whole = Decimal()
        NSDecimalRound(&whole, &exact, 0, .plain)
        guard whole == exact, let milliseconds = Int64(whole.description) else {
            return nil
        }
        // A chain with a Byron era whose slots were a different length needs its
        // fork slot, which is not in genesis.
        if let byron = genesis.byronGenesis,
           let byronMilliseconds = Int64(exactly: byron.blockVersionData.slotDuration),
           byronMilliseconds != milliseconds {
            return nil
        }
        return try? SlotTimeline(systemStart: systemStart, slotLengthMilliseconds: milliseconds)
    }
}
