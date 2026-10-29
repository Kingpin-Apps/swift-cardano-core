import Foundation
import OrderedCollections

public struct Update: Serializable {
    public let proposedprotocolParamUpdates: ProposedProtocolParamUpdates
    public let epoch: EpochNumber

    public enum CodingKeys: String, CodingKey {
        case proposedprotocolParamUpdates
        case epoch
    }

    public init(
        proposedprotocolParamUpdates: ProposedProtocolParamUpdates,
        epoch: EpochNumber
    ) {
        self.proposedprotocolParamUpdates = proposedprotocolParamUpdates
        self.epoch = epoch
    }

    // MARK: - CBORSerializable

    public init(from primitive: Primitive) throws {
        guard case .list(let components) = primitive, components.count == 2 else {
            throw CardanoCoreError.deserializeError("Invalid Update")
        }

        self.proposedprotocolParamUpdates = try ProposedProtocolParamUpdates(from: components[0])

        self.epoch = try components[1].integer("Update epoch", as: EpochNumber.self)
    }

    public func toPrimitive() throws -> Primitive {
        return .list([
            try proposedprotocolParamUpdates.toPrimitive(),
            .integer(epoch),
        ])
    }

    // MARK: - JSONSerializable

    public static func fromDict(_ dict: Primitive) throws -> Update {
        guard case .orderedDict(let orderedDict) = dict else {
            throw CardanoCoreError.deserializeError("Invalid Update dict format")
        }
        guard
            let proposedprotocolParamUpdatesPrimitive = orderedDict[
                .string(CodingKeys.proposedprotocolParamUpdates.rawValue)]
        else {
            throw CardanoCoreError.deserializeError(
                "Missing proposedprotocolParamUpdates in Update dict")
        }
        let proposedprotocolParamUpdates = try ProposedProtocolParamUpdates(
            from: proposedprotocolParamUpdatesPrimitive)

        guard let epochPrimitive = orderedDict[.string(CodingKeys.epoch.rawValue)] else {
            throw CardanoCoreError.deserializeError("Missing or invalid epoch in Update dict")
        }
        let epoch = try epochPrimitive.integer("Update epoch", as: EpochNumber.self)

        return Update(
            proposedprotocolParamUpdates: proposedprotocolParamUpdates,
            epoch: epoch
        )
    }

    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        dict[.string(CodingKeys.proposedprotocolParamUpdates.rawValue)] =
            try proposedprotocolParamUpdates
            .toPrimitive()
        dict[.string(CodingKeys.epoch.rawValue)] = .integer(epoch)
        return .orderedDict(dict)
    }

}

public struct ProposedProtocolParamUpdates: Serializable {
    public let data: [GenesisHash: ProtocolParamUpdate]

    public init(_ data: [GenesisHash: ProtocolParamUpdate]) {
        self.data = data
    }

    // MARK: - CBORSerializable

    public init(from primitive: Primitive) throws {
        var pairs: [(Primitive, Primitive)]
        switch primitive {
        case .dict(let d):
            pairs = Array(d)
        case .orderedDict(let od):
            pairs = od.map { ($0.key, $0.value) }
        default:
            throw CardanoCoreError.deserializeError("Invalid ProposedProtocolParamUpdates")
        }

        var data: [GenesisHash: ProtocolParamUpdate] = [:]
        for (key, value) in pairs {
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

    // MARK: - JSONSerializable

    public static func fromDict(_ dict: Primitive) throws -> ProposedProtocolParamUpdates {
        guard case .orderedDict(let orderedDict) = dict else {
            throw CardanoCoreError.deserializeError(
                "Invalid ProposedProtocolParamUpdates dict format")
        }
        var data: [GenesisHash: ProtocolParamUpdate] = [:]
        for (key, value) in orderedDict {
            guard case .bytes(_) = key else {
                throw CardanoCoreError.deserializeError("Invalid GenesisHash")
            }
            let genesisHash = try GenesisHash(from: key)
            let protocolParamUpdate = try ProtocolParamUpdate(from: value)
            data[genesisHash] = protocolParamUpdate
        }
        return ProposedProtocolParamUpdates(data)
    }

    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        for (key, value) in data {
            dict[key.toPrimitive()] = try value.toPrimitive()
        }
        return .orderedDict(dict)
    }
}
