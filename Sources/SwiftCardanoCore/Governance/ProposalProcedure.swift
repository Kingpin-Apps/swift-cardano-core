import Foundation
import PotentCBOR


public struct ProposalProcedure: PayloadJSONSerializable, CBORSerializable {
    public var _payload: Data
    public var _type: String
    public var _description: String
    
    public static var TYPE: String { "Governance proposal" }
    public static var DESCRIPTION: String { "New constitutional committee and/or threshold and/or terms proposal" }

    public let deposit: Coin
    public let rewardAccount: RewardAccount
    public let govAction: GovAction
    public let anchor: Anchor
    
    public init(
        deposit: Coin,
        rewardAccount: RewardAccount,
        govAction: GovAction,
        anchor: Anchor
    ) {
        self.deposit = deposit
        self.rewardAccount = rewardAccount
        self.govAction = govAction
        self.anchor = anchor
        
        self._payload =  try! CBORSerialization.data(from:
                .array(
                    [
                        try! CBOREncoder().encode(deposit).toCBOR,
                        try! CBOREncoder().encode(rewardAccount).toCBOR,
                        try! CBOREncoder().encode(govAction).toCBOR,
                        try! CBOREncoder().encode(anchor).toCBOR
                    ]
                )
        )
        self._type = Self.TYPE
        self._description = Self.DESCRIPTION
    }
    
    public init(payload: Data, type: String?, description: String?) {
        self._payload = payload
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
        
        let cbor = try! CBORDecoder().decode(ProposalProcedure.self, from: payload)
        
        self.deposit = cbor.deposit
        self.rewardAccount = cbor.rewardAccount
        self.govAction = cbor.govAction
        self.anchor = cbor.anchor
    }
    
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let deposit = try container.decode(Coin.self)
        let rewardAccount = try container.decode(RewardAccount.self)
        let govAction = try container.decode(GovAction.self)
        let anchor = try container.decode(Anchor.self)
        
        self.init(
            deposit: deposit,
            rewardAccount: rewardAccount,
            govAction: govAction,
            anchor: anchor
        )
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(deposit)
        try container.encode(rewardAccount)
        try container.encode(govAction)
        try container.encode(anchor)
    }
    
    public init(from primitive: Primitive) throws {
        // Note: GovAction doesn't currently have primitive methods implemented
        // This is a placeholder implementation that will need to be completed
        // when GovAction gets CBORSerializable conformance
        throw CardanoCoreError.deserializeError("ProposalProcedure primitive deserialization not yet implemented - GovAction needs CBORSerializable conformance")
    }
    
    public func toPrimitive() throws -> Primitive {
        // Note: GovAction doesn't currently have primitive methods implemented  
        // This is a placeholder implementation that will need to be completed
        // when GovAction gets CBORSerializable conformance
        throw CardanoCoreError.serializeError("ProposalProcedure primitive serialization not yet implemented - GovAction needs CBORSerializable conformance")
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

public typealias ProposalProcedures = NonEmptyOrderedSet<ProposalProcedure>
