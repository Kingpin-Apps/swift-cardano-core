import Foundation

class VerificationKeyWitness: ArrayCBORSerializable {
    var vkey: Any
    var signature: Data

    init(vkey: Any, signature: Data) {
        if let extendedVkey = vkey as? ExtendedVerificationKey {
            self.vkey = extendedVkey.toNonExtended()
        } else {
            self.vkey = vkey
        }
        self.signature = signature
    }

    enum CodingKeys: String, CodingKey {
        case vkey
        case signature
    }

    static func fromPrimitive(_ values: [Any]) -> VerificationKeyWitness {
        return VerificationKeyWitness(
            vkey: VerificationKey.fromPrimitive(values[0]),
            signature: values[1] as! Data
        )
    }
}

class TransactionWitnessSet: MapCBORSerializable {
    var vkeyWitnesses: [VerificationKeyWitness]?
    var nativeScripts: [NativeScript]?
    var bootstrapWitness: [Any]?
    var plutusV1Script: [PlutusV1Script]?
    var plutusV2Script: [PlutusV2Script]?
    var plutusData: [RawPlutusData]?
    var redeemer: [Redeemer]?

    init(
        vkeyWitnesses: [VerificationKeyWitness]? = nil,
        nativeScripts: [NativeScript]? = nil,
        bootstrapWitness: [Any]? = nil,
        plutusV1Script: [PlutusV1Script]? = nil,
        plutusV2Script: [PlutusV2Script]? = nil,
        plutusData: [RawPlutusData]? = nil,
        redeemer: [Redeemer]? = nil
    ) {
        self.vkeyWitnesses = vkeyWitnesses
        self.nativeScripts = nativeScripts
        self.bootstrapWitness = bootstrapWitness
        self.plutusV1Script = plutusV1Script
        self.plutusV2Script = plutusV2Script
        self.plutusData = plutusData
        self.redeemer = redeemer
    }

    enum CodingKeys: String, CodingKey {
        case vkeyWitnesses = "0"
        case nativeScripts = "1"
        case bootstrapWitness = "2"
        case plutusV1Script = "3"
        case plutusV2Script = "6"
        case plutusData = "4"
        case redeemer = "5"
    }

    static func fromPrimitive(_ values: Any) -> TransactionWitnessSet? {
        func getVkeyWitnesses(_ data: Any?) -> [VerificationKeyWitness]? {
            guard let data = data as? [Any] else { return nil }
            return data.map { VerificationKeyWitness.fromPrimitive($0 as! [Any]) }
        }

        func getNativeScripts(_ data: Any?) -> [NativeScript]? {
            guard let data = data as? [Any] else { return nil }
            return data.map { NativeScript.fromPrimitive($0 as! [Any]) }
        }

        func getPlutusV1Scripts(_ data: Any?) -> [PlutusV1Script]? {
            guard let data = data as? [Data] else { return nil }
            return data.map { PlutusV1Script($0) }
        }

        func getPlutusV2Scripts(_ data: Any?) -> [PlutusV2Script]? {
            guard let data = data as? [Data] else { return nil }
            return data.map { PlutusV2Script($0) }
        }

        func getRedeemers(_ data: Any?) -> [Redeemer]? {
            guard let data = data as? [Any] else { return nil }
            return data.map { Redeemer.fromPrimitive($0 as! [Any]) }
        }

        if let values = values as? [String: Any] {
            return TransactionWitnessSet(
                vkeyWitnesses: getVkeyWitnesses(values["0"]),
                nativeScripts: getNativeScripts(values["1"]),
                bootstrapWitness: values["2"] as? [Any],
                plutusV1Script: getPlutusV1Scripts(values["3"]),
                plutusV2Script: getPlutusV2Scripts(values["6"]),
                plutusData: values["4"] as? [RawPlutusData],
                redeemer: getRedeemers(values["5"])
            )
        } else if let values = values as? [Any] {
            let dict = Dictionary(uniqueKeysWithValues: values.enumerated().map { (String($0.offset), $0.element) })
            return TransactionWitnessSet(
                vkeyWitnesses: getVkeyWitnesses(dict["0"]),
                nativeScripts: getNativeScripts(dict["1"]),
                bootstrapWitness: dict["2"] as? [Any],
                plutusV1Script: getPlutusV1Scripts(dict["3"]),
                plutusV2Script: getPlutusV2Scripts(dict["6"]),
                plutusData: dict["4"] as? [RawPlutusData],
                redeemer: getRedeemers(dict["5"])
            )
        }
        return nil
    }
}
