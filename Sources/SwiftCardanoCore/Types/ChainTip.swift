import Foundation

/// Represents the current view of the blockchain head ("chain tip").
///
/// A chain tip is the most recent block known to the node. This model captures
/// commonly returned fields from Cardano-like APIs, including the block number,
/// epoch and slot information, and synchronization progress.
public struct ChainTip: Codable, Equatable, Sendable {
    /// Absolute block height of the tip. `nil` if unknown or not applicable.
    public let block: Int?

    /// Current epoch number at the tip. `nil` if unknown.
    public let epoch: Int?

    /// Current era name at the tip (for example: "Byron", "Shelley", "Alonzo").
    /// `nil` if not provided by the backend.
    public let era: String?

    /// Hash of the tip block in hex (or backend-specific representation).
    /// `nil` if not available.
    public let hash: String?

    /// Absolute slot number at the tip. `nil` if unknown.
    public let slot: Int?

    /// Slot index within the current epoch. `nil` if unknown.
    public let slotInEpoch: Int?

    /// Number of remaining slots until the end of the current epoch.
    /// `nil` if unknown or not provided.
    public let slotsToEpochEnd: Int?

    /// Node synchronization progress expressed as a string (for example: "100.00")
    /// or a human-readable phrase depending on backend. `nil` if unknown.
    public let syncProgress: String?

    // MARK: - Init

    /// Creates a new `ChainTip`.
    /// - Parameters:
    ///   - block: Absolute block height of the tip.
    ///   - epoch: Current epoch number at the tip.
    ///   - era: Current era name at the tip.
    ///   - hash: Hash of the tip block.
    ///   - slot: Absolute slot number at the tip.
    ///   - slotInEpoch: Slot index within the current epoch.
    ///   - slotsToEpochEnd: Remaining slots until the end of the current epoch.
    ///   - syncProgress: Node synchronization progress as a string.
    public init(
        block: Int?,
        epoch: Int?,
        era: String?,
        hash: String?,
        slot: Int?,
        slotInEpoch: Int?,
        slotsToEpochEnd: Int?,
        syncProgress: String?
    ) {
        self.block = block
        self.epoch = epoch
        self.era = era
        self.hash = hash
        self.slot = slot
        self.slotInEpoch = slotInEpoch
        self.slotsToEpochEnd = slotsToEpochEnd
        self.syncProgress = syncProgress
    }

    // MARK: - Codable

    /// Coding keys map to common snake_case keys used by many APIs.
    /// Adjust as needed if your backend uses different names.
    private enum CodingKeys: String, CodingKey {
        case block
        case epoch
        case era
        case hash
        case slot
        case slotInEpoch = "slot_in_epoch"
        case slotsToEpochEnd = "slots_to_epoch_end"
        case syncProgress = "sync_progress"
    }
}
