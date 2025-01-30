import Foundation
import PotentCBOR

enum MoveInstantaneousRewardSource: Int, Codable {
    case reserves = 0
    case treasury = 1
}

struct DeltaCoin: Codable {
    let deltaCoin: Int
}

struct MoveInstantaneousReward: Codable {
    let source: MoveInstantaneousRewardSource
    let rewards: [String: DeltaCoin]?
    let coin: UInt64?
}

struct MoveInstantaneousRewards: CertificateSerializable {
    var _payload: Data
    var _type: String
    var _description: String
    
    var type: String { get { return MoveInstantaneousRewards.TYPE } }
    var description: String { get { return MoveInstantaneousRewards.DESCRIPTION } }

    static var TYPE: String { CertificateType.shelley.rawValue }
    static var DESCRIPTION: String { CertificateDescription.moveInstantaneousRewards.rawValue }
    static var CODE: CertificateCode { get { return .moveInstantaneousRewards } }
    
    let moveInstantaneousRewards: MoveInstantaneousReward
    
    /// Initialize a new `MoveInstantaneousRewards` certificate
    /// - Parameter moveInstantaneousRewards: The move instantaneous rewards
    init(moveInstantaneousRewards: MoveInstantaneousReward) {
        self.moveInstantaneousRewards = moveInstantaneousRewards
        
        self._payload =  try! CBORSerialization.data(from:
                .array(
                    [
                        CBOR(integerLiteral: Self.CODE.rawValue),
                        try! CBOREncoder().encode(moveInstantaneousRewards).toCBOR
                    ]
                )
        )
        self._type = Self.TYPE
        self._description = Self.DESCRIPTION
    }
    
    /// Initialize a new `MoveInstantaneousRewards` certificate from its Text Envelope representation
    /// - Parameters:
    ///  - payload: The CBOR representation of the certificate
    ///  - type: The type of the certificate
    ///  - description: The description of the certificate
    init(payload: Data, type: String?, description: String?) {
        self._payload = payload
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
        
        let cbor = try! CBORDecoder().decode(MoveInstantaneousRewards.self, from: payload)
        
        self.moveInstantaneousRewards = cbor.moveInstantaneousRewards
    }

    
    /// Initialize a new `MoveInstantaneousRewards` certificate from its CBOR representation
    /// - Parameter decoder: The decoder
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)
        
        guard case Self.CODE.rawValue = code else {
            throw CardanoCoreError.deserializeError("Invalid MoveInstantaneousRewards type: \(code)")
        }
        
        let moveInstantaneousRewards = try container.decode(MoveInstantaneousReward.self)
        
        self.init(moveInstantaneousRewards: moveInstantaneousRewards)
    }
    
    /// Encode the `MoveInstantaneousRewards` certificate to the given encoder
    /// - Parameter encoder: The encoder
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(Self.CODE.rawValue)
        try container.encode(moveInstantaneousRewards)
    }
}
