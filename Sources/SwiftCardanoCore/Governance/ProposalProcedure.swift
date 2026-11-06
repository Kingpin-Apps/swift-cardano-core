import Foundation
import CBORCodable


/// A governance proposal: `proposal_procedure = [deposit, reward_account, gov_action, anchor]`.
public struct ProposalProcedure: TextEnvelopable, CBORSerializable, Sendable {
    public var _payload: Data
    public var _type: String
    public var _description: String
    
    public static var TYPE: String { "Governance proposal" }
    public static var DESCRIPTION: String { "New constitutional committee and/or threshold and/or terms proposal" }
    
    /// The deposit paid for the proposal, in lovelace.
    public let deposit: Coin
    /// The reward account the deposit is returned to.
    public let rewardAccount: RewardAccount
    /// The governance action being proposed.
    public let govAction: GovAction
    /// The anchor to the proposal's off-chain rationale.
    public let anchor: Anchor
    
    /// Creates a proposal procedure.
    ///
    /// - Parameters:
    ///   - deposit: The deposit paid for the proposal, in lovelace.
    ///   - rewardAccount: The reward account the deposit is returned to.
    ///   - govAction: The governance action being proposed.
    ///   - anchor: The anchor to the proposal's off-chain rationale.
    /// - Throws: When the proposal cannot be encoded for its payload.
    public init(
        deposit: Coin,
        rewardAccount: RewardAccount,
        govAction: GovAction,
        anchor: Anchor
    ) throws {
        self.deposit = deposit
        self.rewardAccount = rewardAccount
        self.govAction = govAction
        self.anchor = anchor
        self._payload = Data()
        self._type = Self.TYPE
        self._description = Self.DESCRIPTION
        self._payload = try toCBORData()
    }
    
    /// Initialize the proposal from its text-envelope payload.
    /// - Parameters:
    ///   - payload: The CBOR of the proposal
    ///   - type: The text-envelope type
    ///   - description: The text-envelope description
    public init(payload: Data, type: String?, description: String?) throws {
        self._payload = payload
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
        
        let cbor = try CBORDecoder.ledger().decode(ProposalProcedure.self, from: payload)
        
        self.deposit = cbor.deposit
        self.rewardAccount = cbor.rewardAccount
        self.govAction = cbor.govAction
        self.anchor = cbor.anchor
    }
    
    public init(from primitive: Primitive) throws {
        guard case let .list(primitiveArray) = primitive else {
            throw CardanoCoreError.deserializeError("Invalid ProposalProcedure type: \(primitive)")
        }
        
        guard primitiveArray.count == 4 else {
            throw CardanoCoreError.deserializeError("Invalid ProposalProcedure array size: \(primitiveArray.count)")
        }
        
        guard case let .uint(deposit) = primitiveArray[0] else {
            throw CardanoCoreError.deserializeError("Invalid ProposalProcedure deposit: \(primitiveArray[0])")
        }
        
        guard case let .bytes(rewardAccount) = primitiveArray[1] else {
            throw CardanoCoreError.deserializeError("Invalid ProposalProcedure reward account: \(primitiveArray[1])")
        }
        
        let govAction = try GovAction(from: primitiveArray[2])
        let anchor = try checkedAnchor(primitiveArray[3])
        
        try self.init(
            deposit: deposit,
            rewardAccount: rewardAccount,
            govAction: govAction,
            anchor: anchor
        )
    }
    
    public func toPrimitive() throws -> Primitive {
        return .list([
            .uint(deposit),
            .bytes(rewardAccount),
            try govAction.toPrimitive(),
            try anchor.toPrimitive()
        ])
    }
    
    /// Serialize to JSON.
    ///
    /// The json output has three fields: "type", "description", and "cborHex".
    /// - Returns: JSON representation
    public func toJSON() throws -> String? {
        let jsonString = """
        {
            "type": "\(type)",
            "description": "\(description)",
            "cborHex": "\(payload.toHex)"
        }
        """
        return jsonString
    }
}

/// The proposals in a transaction body: a non-empty ordered set.
public typealias ProposalProcedures = NonEmptyOrderedSet<ProposalProcedure>
