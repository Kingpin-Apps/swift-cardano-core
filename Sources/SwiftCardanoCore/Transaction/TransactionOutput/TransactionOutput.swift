import Foundation
@preconcurrency import BigInt
import CBORCodable
import OrderedCollections

public struct TransactionOutput: Serializable {
    public var address: Address { didSet { originalCBOR = nil } }
    public var amount: Value { didSet { originalCBOR = nil } }
    public var datumHash: DatumHash? { didSet { originalCBOR = nil } }
    public var datumOption: DatumOption? { didSet { originalCBOR = nil } }
    public var script: ScriptType? { didSet { originalCBOR = nil } }
    public var postAlonzo: Bool = false { didSet { originalCBOR = nil } }

    /// The exact bytes this output was decoded from, while it is unchanged.
    ///
    /// The minimum ADA an output must hold is worked out from its size as
    /// written, and its inline datum is hashed as written, so while this is
    /// set the output encodes to these bytes, on its own or inside a body.
    public internal(set) var originalCBOR: Data? = nil

    /// Decodes an output, keeping the bytes it was read from.
    public static func fromCBOR(data: Data) throws -> TransactionOutput {
        let scanner = CBORItemScanner(data)
        guard try scanner.end(ofItemAt: 0) == scanner.bytes.count else {
            throw CardanoCoreError.deserializeError("Trailing bytes after TransactionOutput")
        }
        var output = try Transaction.decoder().decode(TransactionOutput.self, from: data)
        try output.keepBytes(scanner.bytes)
        return output
    }

    /// Decodes an output as the ledger of `era` reads it, keeping the bytes
    /// it was read from.
    ///
    /// Which addresses and values the ledger accepts depends on the era —
    /// see ``Era/decoding`` — so an output from an earlier era should be read
    /// with that era.
    public static func fromCBOR(data: Data, era: Era) throws -> TransactionOutput {
        try Era.$decoding.withValue(era) { try fromCBOR(data: data) }
    }

    public init(from cbor: Data) throws {
        self = try Self.fromCBOR(data: cbor)
    }

    /// Reads the address of an output as the ledger does (`fromCborBothAddr`,
    /// `libs/cardano-ledger-core/src/Cardano/Ledger/Address.hs`): a byte
    /// string holding a Byron or Shelley payment address. An account (reward)
    /// address fails there: its header has the high bit set, which only the
    /// Byron header 0x82 may (`headerNonShelleyBits`).
    static func address(from primitive: Primitive) throws -> Address {
        guard case .bytes = primitive else {
            throw CardanoCoreError.deserializeError("TransactionOutput address: expected bytes, got \(primitive)")
        }
        let address = try Address(from: primitive)
        if address.addressType == .noneKey || address.addressType == .noneScript {
            throw CardanoCoreError.deserializeError(
                "TransactionOutput address: a reward address cannot receive an output")
        }
        return address
    }

    /// Records `bytes` as what this output was decoded from.
    mutating func keepBytes(_ bytes: Data) throws {
        let scanner = CBORItemScanner(bytes)
        if try scanner.header(at: 0).major == 5, datumOption != nil {
            for (key, value) in try scanner.entries(ofMapAt: 0)
            where try scanner.unsignedInteger(at: key.lowerBound) == 2 {
                try datumOption?.keepBytes(scanner.bytes.subdata(in: value))
            }
        }
        originalCBOR = scanner.bytes
    }

    public func toCBORData(deterministic: Bool = false) throws -> Data {
        _ = deterministic
        return try originalCBOR ?? CBOREncoder().encode(self)
    }

    /// Hashes what `==` compares, leaving out the bytes it was read from.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(address)
        hasher.combine(amount)
    }

    public var lovelace: BigInt {
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

    public init<Amount: BinaryInteger>(from
                address: String,
                amount: Amount,
                datumHash: String? = nil,
                datumOption: DatumOption? = nil,
                script: ScriptType? = nil,
                postAlonzo: Bool = false
    ) throws {
        self.address = try Address(from: .string(address))
        self.amount = Value(coin: BigInt(amount))
        
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
        if let originalCBOR {
            return .cborSimpleValue(.encoded(originalCBOR))
        }
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
            
    /// Checks that the amounts can be written in an output: the coin and
    /// each asset amount an unsigned 64-bit integer (`coin`, `positive_coin`
    /// in the CDDL; `decodeWord64` in `decodeMaryValue`,
    /// `eras/mary/impl/src/Cardano/Ledger/Mary/Value.hs`). A zero asset
    /// amount cannot occur: ``Asset`` drops it.
    public func validate() throws {
        if amount.coin < 0 {
            throw CardanoCoreError.invalidArgument("Transaction output cannot have negative amount of ADA: \(amount)")
        }
        if UInt64(exactly: amount.coin) == nil {
            throw CardanoCoreError.invalidArgument("Transaction output ADA amount does not fit an unsigned 64-bit integer: \(amount.coin)")
        }
        if try amount.multiAsset.count(criteria: { _, _, v in v < 0 }) > 0 {
            throw CardanoCoreError.invalidArgument("Transaction output cannot have negative amount of tokens or native assets: \(amount)")
        }
        if try amount.multiAsset.count(criteria: { _, _, v in UInt64(exactly: v) == nil }) > 0 {
            throw CardanoCoreError.invalidArgument("Transaction output token amount does not fit an unsigned 64-bit integer: \(amount)")
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

