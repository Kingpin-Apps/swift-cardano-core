import Foundation

extension Era {
    /// The era whose ledger rules address and value decoding follow.
    ///
    /// The ledger decodes the addresses and values in a transaction according
    /// to the protocol version it was submitted under
    /// (`ifDecoderVersionAtLeast` in `fromCborBothAddr`,
    /// `libs/cardano-ledger-core/src/Cardano/Ledger/Address.hs`, and in
    /// `decodeMultiAsset`, `eras/mary/impl/src/Cardano/Ledger/Mary/Value.hs`).
    /// ``Transaction/fromCBOR(data:era:)``, ``TransactionBody/fromCBOR(data:era:)``,
    /// ``Block/fromCBOR(data:era:)`` and ``TransactionOutput/fromCBOR(data:era:)``
    /// bind it while they decode.
    ///
    /// `nil` — decoding outside any of those — reads as the current era
    /// (Conway), whose rules are the strictest: what is placed on chain today.
    @TaskLocal public static var decoding: Era?

    /// The era decoding follows: ``decoding``, or Conway when it is not bound.
    static var decodingRules: Era { decoding ?? .conway }
}
