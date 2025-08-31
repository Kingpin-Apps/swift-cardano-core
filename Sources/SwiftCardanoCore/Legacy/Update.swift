import Foundation

public struct Update: CBORSerializable, Equatable, Hashable {
    public let proposedprotocolParamUpdates: ProposedProtocolParamUpdates
    public let epoch: EpochNumber
    
    public init(
        proposedprotocolParamUpdates: ProposedProtocolParamUpdates,
        epoch: EpochNumber
    ) {
        self.proposedprotocolParamUpdates = proposedprotocolParamUpdates
        self.epoch = epoch
    }
    
    public init(from primitive: Primitive) throws {
        guard case let .list(components) = primitive, components.count == 2 else {
            throw CardanoCoreError.deserializeError("Invalid Update")
        }
        
        self.proposedprotocolParamUpdates = try ProposedProtocolParamUpdates(from: components[0])
        
        guard case let .int(epoch) = components[1] else {
            throw CardanoCoreError.deserializeError("Invalid EpochNumber")
        }
        self.epoch = EpochNumber(epoch)
    }

    public func toPrimitive() throws -> Primitive {
        return .list([
            try proposedprotocolParamUpdates.toPrimitive(),
            .int(Int(epoch))
        ])
    }
}

public struct ProposedProtocolParamUpdates: CBORSerializable, Equatable, Hashable {

    public let data: [GenesisHash: ProtocolParamUpdate]
    
    public init(_ data: [GenesisHash: ProtocolParamUpdate]) {
        self.data = data
    }
    
    public init(from primitive: Primitive) throws {
        guard case let .dict(primitive) = primitive else {
            throw CardanoCoreError.deserializeError("Invalid ProposedProtocolParamUpdates")
        }
        
        var data: [GenesisHash: ProtocolParamUpdate] = [:]
        for (key, value) in primitive {
            guard case .bytes(_) = key else {
                throw CardanoCoreError.deserializeError("Invalid GenesisHash")
            }
            let genesisHash = try GenesisHash(from: key)
            let protocolParamUpdate = try ProtocolParamUpdate(from: value)
            data[genesisHash] = protocolParamUpdate
        }
        self.data = data
    }
    
    public func toPrimitive() throws -> Primitive {
        var result: [Primitive: Primitive] = [:]
        for (key, value) in data {
            result[key.toPrimitive()] = try value.toPrimitive()
        }
        return .dict(result)
    }

}
