import Foundation
import PotentCBOR


public struct ProposalProcedure: TextEnvelopable, CBORSerializable, Sendable {
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
            throw CardanoCoreError.deserializeError("Invalid ProposalProcedure deposit: \(primitiveArray[0])")
        }
        
        let govAction = try GovAction(from: primitiveArray[2])
        let anchor = try Anchor(from: primitiveArray[3])
        
        self.init(
            deposit: Coin(deposit),
            rewardAccount: rewardAccount,
            govAction: govAction,
            anchor: anchor
        )
    }
    
    public func toPrimitive() throws -> Primitive {
        return .list([
            .uint(UInt(deposit)),
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

public typealias ProposalProcedures = NonEmptyOrderedSet<ProposalProcedure>
