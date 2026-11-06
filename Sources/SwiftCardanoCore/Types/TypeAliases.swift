import Foundation

// MARK: - Types Aliases
/// An amount of ada, in lovelace.
public typealias Coin = UInt64
/// The bytes of a reward (stake) account address.
public typealias RewardAccount = Data
/// A slot number.
public typealias SlotNumber = UInt64

// Represents a 4-byte unsigned integer
/// A number of epochs, as a 4-byte unsigned integer.
public typealias EpochInterval = UInt32

// Represents an 8-byte unsigned integer
/// An epoch number, as an 8-byte unsigned integer.
public typealias EpochNumber = UInt64

// Represents a block number (uint .size 8)
/// A block number (`uint .size 8`).
public typealias BlockNumber = UInt64

// Represents a transaction index within a block (uint .size 2)
/// The index of a transaction within a block (`uint .size 2`).
public typealias TransactionIndex = UInt16
