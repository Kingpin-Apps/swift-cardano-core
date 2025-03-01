import Foundation

// MARK: - AlonzoGenesis
public struct AlonzoGenesis: JSONLoadable {
    let lovelacePerUTxOWord: Int
    let executionPrices: ExecutionPrices
    let maxTxExUnits: AlonzoGenesisExUnits
    let maxBlockExUnits: AlonzoGenesisExUnits
    let maxValueSize: Int
    let collateralPercentage: Int
    let maxCollateralInputs: Int
    let costModels: AlonzoCostModels
}

// MARK: - ExecutionPrices
public struct ExecutionPrices: Codable, Equatable, Hashable {
    let prSteps: PriceRatio
    let prMem: PriceRatio
}

// MARK: - PriceRatio
public struct PriceRatio: Codable, Equatable, Hashable {
    let numerator: Int
    let denominator: Int
}

// MARK: - ExUnits
public struct AlonzoGenesisExUnits: Codable, Equatable, Hashable {
    let exUnitsMem: Int
    let exUnitsSteps: Int
}


// MARK: - CostModels
public struct AlonzoCostModels: Codable, Equatable, Hashable {
    let plutusV1: [String: Int]
    
    enum CodingKeys: String, CodingKey {
        case plutusV1 = "PlutusV1"
    }
}
