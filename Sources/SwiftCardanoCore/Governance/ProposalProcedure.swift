import Foundation
import PotentCBOR


struct ProposalProcedure: PayloadJSONSerializable {
    var _payload: Data
    var _type: String
    var _description: String
    
    static var TYPE: String { "Governance proposal" }
    static var DESCRIPTION: String { "New constitutional committee and/or threshold and/or terms proposal" }

    let deposit: Coin
    let rewardAccount: RewardAccount
    let govAction: GovAction
    let anchor: Anchor
    
    init(
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
    
    init(payload: Data, type: String?, description: String?) {
        self._payload = payload
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
        
        let cbor = try! CBORDecoder().decode(ProposalProcedure.self, from: payload)
        
        self.deposit = cbor.deposit
        self.rewardAccount = cbor.rewardAccount
        self.govAction = cbor.govAction
        self.anchor = cbor.anchor
    }
    
    init(from decoder: Decoder) throws {
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
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(deposit)
        try container.encode(rewardAccount)
        try container.encode(govAction)
        try container.encode(anchor)
    }
    
    /// Serialize to JSON.
    ///
    /// The json output has three fields: "type", "description", and "cborHex".
    /// - Returns: JSON representation
    func toJSON() throws -> String? {
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


struct ProposalProcedures: Codable, Hashable, Equatable {
    var procedures: NonEmptyCBORSet<ProposalProcedure>
}
