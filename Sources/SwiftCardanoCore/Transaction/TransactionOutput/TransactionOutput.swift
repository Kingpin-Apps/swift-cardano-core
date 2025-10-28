import Foundation
import OrderedCollections

public struct TransactionOutput: Serializable {
    public var address: Address
    public var amount: Value
    public var datumHash: DatumHash?
    public var datumOption: DatumOption?
    public var script: ScriptType?
    public var postAlonzo: Bool = false

    public var lovelace: Int {
        return amount.coin
    }
    
    public init(
        address: Address,
        amount: Value,
        datumHash: DatumHash? = nil,
        datumOption: DatumOption? = nil,
        script: ScriptType? = nil,
        postAlonzo: Bool = false
    ) {
        self.address = address
        self.amount = amount
        self.datumHash = datumHash
        self.datumOption = datumOption
        self.script = script
        self.postAlonzo = postAlonzo
    }
    
    public init(from
                address: String,
                amount: Int,
                datumHash: String? = nil,
                datumOption: DatumOption? = nil,
                script: ScriptType? = nil,
                postAlonzo: Bool = false
    ) throws {
        self.address = try Address(from: .string(address))
        self.amount = Value(coin: amount)
        
        if let datumHash = datumHash {
            self.datumHash = try DatumHash(from: .bytes(datumHash.hexStringToData))
        } else {
            self.datumHash = nil
        }
        
        self.datumOption = datumOption
        self.script = script
        self.postAlonzo = postAlonzo
    }
    
    // MARK: - CBORSerializable
    
    public init(from primitives: Primitive) throws {
        if case .list(_) = primitives {
            let output = try ShelleyTransactionOutput(from: primitives)
            self.address = output.address
            self.amount = output.amount
            self.datumHash = output.datumHash
            self.datumOption = nil
            self.script = nil
            self.postAlonzo = false  // Legacy format
        } else if case .orderedDict(_) = primitives {
            let output = try BabbageTransactionOutput(from: primitives)
            self.address = output.address
            self.amount = output.amount
            self.script = output.script
            let datum = output.datumOption?.datum ?? nil
            
            switch datum {
                case .datumHash(let hash):
                    self.datumHash = hash
                    self.datumOption = nil
                case .data(let data):
                    self.datumHash = nil
                    self.datumOption = DatumOption(datum: data)
                case .none:
                    self.datumHash = nil
                    self.datumOption = nil
            }
            
            self.postAlonzo = true  // Post-Alonzo format
        } else {
            throw CardanoCoreError.deserializeError("Invalid TransactionOutput type")
        }
    }
    
    public func toPrimitive() throws -> Primitive {
        if self.datumOption != nil || self.script != nil || self.postAlonzo {
            let datumOption: DatumOption?
            let scriptRef: ScriptRef?
            
            if let datumHash = self.datumHash {
                datumOption = DatumOption(datum: datumHash)
            } else if let datum = self.datumOption {
                datumOption = datum
            } else {
                datumOption = nil
            }
            
            if let script = script {
                scriptRef = try ScriptRef(script: Script(script: script))
            } else {
                scriptRef = nil
            }
            
            return try BabbageTransactionOutput(
                address: address,
                amount: amount,
                datumOption: datumOption,
                scriptRef: scriptRef
            ).toPrimitive()
        } else {
            return try ShelleyTransactionOutput(
                address: address,
                amount: amount,
                datumHash: datumHash
            ).toPrimitive()
        }
    }
    
    // MARK: - JSONSerializable
    
    public static func fromDict(_ dict: Primitive) throws -> TransactionOutput {
        guard case let .orderedDict(orderedDict) = dict else {
            throw CardanoCoreError.deserializeError("Invalid TransactionOutput dict format")
        }
        // Try to detect format based on presence of datum/scriptRef (post-Alonzo) vs datumHash (legacy)
        // Also check for postAlonzo flag if present
        let hasDatum = orderedDict[.string("datum")] != nil
        let hasScriptRef = orderedDict[.string("scriptRef")] != nil
        let hasPostAlonzoFlag = orderedDict[.string("postAlonzo")] != nil
        let hasDatumHash = orderedDict[.string("datumHash")] != nil
        
        // Check if it has numeric keys (CBOR format) - for PostAlonzo these are 0, 1, optionally 2, 3
        let hasNumericKeys = orderedDict.keys.contains(where: { key in
            if case .uint(let uint) = key, uint <= 3 {
                return true
            } else if case .int(let int) = key, int >= 0 && int <= 3 {
                return true
            }
            return false
        })
        
        // Determine format: if it has datum/scriptRef fields or postAlonzo flag, it's PostAlonzo
        // But respect explicit postAlonzo=false flag
        let explicitPostAlonzo: Bool?
        if hasPostAlonzoFlag {
            let flagValue = orderedDict[.string("postAlonzo")]
            if case let .bool(flag) = flagValue {
                explicitPostAlonzo = flag
            } else if case let .int(intFlag) = flagValue {
                // Handle int representation (0 = false, non-zero = true)
                explicitPostAlonzo = intFlag != 0
            } else if case let .uint(uintFlag) = flagValue {
                // Handle uint representation
                explicitPostAlonzo = uintFlag != 0
            } else {
                explicitPostAlonzo = nil
            }
        } else {
            explicitPostAlonzo = nil
        }
        
        let isPostAlonzo: Bool
        if let explicit = explicitPostAlonzo {
            // If explicitly set, use that value
            // However, if it's false but has datum/scriptRef, still parse as PostAlonzo format
            isPostAlonzo = explicit || hasDatum || hasScriptRef
        } else {
            // Auto-detect based on fields
            isPostAlonzo = hasDatum || hasScriptRef || (hasNumericKeys && !hasDatumHash)
        }
        
        if isPostAlonzo {
            let output = try BabbageTransactionOutput.fromDict(.orderedDict(orderedDict))
            let datum = output.datumOption?.datum ?? nil
            
            var datumHash: DatumHash?
            var datumOption: DatumOption?
            
            switch datum {
                case .datumHash(let hash):
                    datumHash = hash
                    datumOption = nil
                case .data(let data):
                    datumHash = nil
                    datumOption = DatumOption(datum: data)
                case .none:
                    datumHash = nil
                    datumOption = nil
            }
            
            // Restore the separate datumHash if it was stored (when both were set)
            if let extraDatumHashStr = orderedDict[.string("_datumHash")] {
                if case let .string(base64Str) = extraDatumHashStr {
                    if let data = Data(base64Encoded: base64Str) {
                        datumHash = DatumHash(payload: data)
                        // Keep datumOption as is since both were set
                        if output.datumOption != nil {
                            datumOption = output.datumOption
                        }
                    }
                }
            }
            
            // Use the explicit postAlonzo flag if it was set, otherwise default based on format
            let postAlonzoValue: Bool
            if let explicit = explicitPostAlonzo {
                postAlonzoValue = explicit
            } else {
                // No explicit flag, so default to true for PostAlonzo format
                postAlonzoValue = true
            }
            
            return TransactionOutput(
                address: output.address,
                amount: output.amount,
                datumHash: datumHash,
                datumOption: datumOption,
                script: output.script,
                postAlonzo: postAlonzoValue
            )
        } else {
            let output = try ShelleyTransactionOutput.fromDict(.orderedDict(orderedDict))
            return TransactionOutput(
                address: output.address,
                amount: output.amount,
                datumHash: output.datumHash,
                datumOption: nil,
                script: nil,
                postAlonzo: false
            )
        }
    }
    
    public func toDict() throws -> Primitive {
        if self.datumOption != nil || self.script != nil || self.postAlonzo {
            let datumOption: DatumOption?
            let scriptRef: ScriptRef?
            
            // Prefer the explicitly set datumOption over datumHash
            if let datum = self.datumOption {
                datumOption = datum
            } else if let datumHash = self.datumHash {
                datumOption = DatumOption(datum: datumHash)
            } else {
                datumOption = nil
            }
            
            if let script = script {
                scriptRef = try ScriptRef(script: Script(script: script))
            } else {
                scriptRef = nil
            }
            
            let babbageOutput = try BabbageTransactionOutput(
                address: address,
                amount: amount,
                datumOption: datumOption,
                scriptRef: scriptRef
            ).toDict()
            
            guard case let .orderedDict(orderedDict) = babbageOutput else {
                throw CardanoCoreError.serializeError("BabbageTransactionOutput toDict did not return orderedDict")
            }
            
            var dict = orderedDict
            
            // Add extra fields for proper round-tripping
            dict[.string("postAlonzo")] = .bool(postAlonzo)
            
            // If both datumHash and datumOption are set, preserve datumHash separately
            if self.datumHash != nil && self.datumOption != nil {
                dict[.string("_datumHash")] = .string(self.datumHash!.payload.base64EncodedString())
            }
            
            return .orderedDict(dict)
        } else {
            return try ShelleyTransactionOutput(
                address: address,
                amount: amount,
                datumHash: datumHash
            ).toDict()
        }
    }

    // MARK: - Validation
            
    public func validate() throws {
        if amount.coin < 0 {
            throw CardanoCoreError.invalidArgument("Transaction output cannot have negative amount of ADA: \(amount)")
        }
        if try amount.multiAsset.count(criteria: { _, _, v in v < 0 }) > 0 {
            throw CardanoCoreError.invalidArgument("Transaction output cannot have negative amount of tokens or native assets: \(amount)")
        }
    }
    
    // MARK: - Equatable
    
    public static func == (lhs: TransactionOutput, rhs: TransactionOutput) -> Bool {
        return lhs.address == rhs.address &&
        lhs.amount == rhs.amount &&
        lhs.datumHash == rhs.datumHash &&
        lhs.datumOption == rhs.datumOption &&
        lhs.script == rhs.script &&
        lhs.postAlonzo == rhs.postAlonzo
    }
}

