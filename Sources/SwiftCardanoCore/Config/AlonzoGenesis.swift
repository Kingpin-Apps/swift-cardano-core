import Foundation

// MARK: - AlonzoGenesis
public struct AlonzoGenesis: JSONLoadable {
    public let lovelacePerUTxOWord: Int
    public let executionPrices: ExecutionPrices
    public let maxTxExUnits: AlonzoGenesisExUnits
    public let maxBlockExUnits: AlonzoGenesisExUnits
    public let maxValueSize: Int
    public let collateralPercentage: Int
    public let maxCollateralInputs: Int
    public let costModels: AlonzoCostModels
}

// MARK: - ExecutionPrices
public struct ExecutionPrices: Codable, Equatable, Hashable {
    public let prSteps: PriceRatio
    public let prMem: PriceRatio
}

// MARK: - PriceRatio
public struct PriceRatio: Codable, Equatable, Hashable {
    public let numerator: Int
    public let denominator: Int
}

// MARK: - ExUnits
public struct AlonzoGenesisExUnits: Codable, Equatable, Hashable {
    public let exUnitsMem: Int
    public let exUnitsSteps: Int
}


// MARK: - CostModels
public struct AlonzoCostModels: Codable, Equatable, Hashable {
    public let plutusV1: [String: Int]
    
    enum CodingKeys: String, CodingKey {
        case plutusV1 = "PlutusV1"
    }
}
