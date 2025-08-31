import Foundation

// Define a struct for BootstrapWitness
public struct BootstrapWitness: CBORSerializable, Equatable, Hashable {
    public let publicKey: Data // $vkey - bytes of size 32
    public let signature: Data // $signature - bytes of size 64
    public let chainCode: Data // bytes of size 32
    public let attributes: Data // bytes of variable size
    
    public init(publicKey: Data, signature: Data, chainCode: Data, attributes: Data) throws {
        // Validate data sizes according to comments
        guard publicKey.count == 32 else {
            throw CardanoCoreError.invalidArgument("PublicKey must be exactly 32 bytes, got \(publicKey.count)")
        }
        guard signature.count == 64 else {
            throw CardanoCoreError.invalidArgument("Signature must be exactly 64 bytes, got \(signature.count)")
        }
        guard chainCode.count == 32 else {
            throw CardanoCoreError.invalidArgument("ChainCode must be exactly 32 bytes, got \(chainCode.count)")
        }
        
        self.publicKey = publicKey
        self.signature = signature
        self.chainCode = chainCode
        self.attributes = attributes
    }
    
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        
        let publicKey = try container.decode(Data.self)
        let signature = try container.decode(Data.self)
        let chainCode = try container.decode(Data.self)
        let attributes = try container.decode(Data.self)
        
        try self.init(publicKey: publicKey, signature: signature, chainCode: chainCode, attributes: attributes)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(publicKey)
        try container.encode(signature)
        try container.encode(chainCode)
        try container.encode(attributes)
    }
    
    public init(from primitive: Primitive) throws {
        guard case let .list(elements) = primitive else {
            throw CardanoCoreError.deserializeError("Invalid BootstrapWitness primitive")
        }
        
        guard elements.count == 4 else {
            throw CardanoCoreError.deserializeError("BootstrapWitness requires exactly 4 elements")
        }
        
        // publicKey (32 bytes)
        guard case let .bytes(publicKeyData) = elements[0] else {
            throw CardanoCoreError.deserializeError("Invalid publicKey in BootstrapWitness")
        }
        
        // signature (64 bytes)
        guard case let .bytes(signatureData) = elements[1] else {
            throw CardanoCoreError.deserializeError("Invalid signature in BootstrapWitness")
        }
        
        // chainCode (32 bytes)
        guard case let .bytes(chainCodeData) = elements[2] else {
            throw CardanoCoreError.deserializeError("Invalid chainCode in BootstrapWitness")
        }
        
        // attributes (variable size)
        guard case let .bytes(attributesData) = elements[3] else {
            throw CardanoCoreError.deserializeError("Invalid attributes in BootstrapWitness")
        }
        
        try self.init(publicKey: publicKeyData, signature: signatureData, chainCode: chainCodeData, attributes: attributesData)
    }
    
    public func toPrimitive() throws -> Primitive {
        return .list([
            .bytes(publicKey),
            .bytes(signature),
            .bytes(chainCode),
            .bytes(attributes)
        ])
    }
}
