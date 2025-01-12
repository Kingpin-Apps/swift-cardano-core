//
//  Created by Hareem Adderley on 22/06/2024 AT 9:33 PM
//  Copyright © 2024 Kingpin Apps. All rights reserved.
//  

import Foundation
import SwiftMnemonic

enum CardanoCoreError: Error, CustomStringConvertible, Equatable {
    case encodingError(String?)
    case decodingError(String?)
    case inputUTxODepletedError(String?)
    case insufficientUTxOBalanceError(String?)
    case invalidAddressInputError(String?)
    case invalidArgument(String?)
    case invalidDataError(String?)
    case invalidKeyTypeError(String?)
    case invalidLanguage(String?)
    case invalidOperation(String?)
    case invalidTransaction(String?)
    case serializeError(String?)
    case deserializeError(String?)
    case transactionFailederror(String?)
    case maxInputCountExceedederror(String?)
    case backendError(String?)
    case typeError(String?)
    case valueError(String?)
    case ioError(String?)
    case notImplementedError(String?)
    
    var description: String {
        switch self {
            case .encodingError(let message):
                return message ?? "Encoding error occurred."
            case .decodingError(let message):
                return message ?? "Decoding error occurred."
            case .invalidKeyTypeError(let message):
                return message ?? "Invalid key type error occurred."
            case .invalidAddressInputError(let message):
                return message ?? "Invalid address input error occurred."
            case .invalidDataError(let message):
                return message ?? "Invalid data error occurred."
            case .invalidArgument(let message):
                return message ?? "Invalid argument error occurred."
            case .invalidOperation(let message):
                return message ?? "Invalid operation error occurred."
            case .serializeError(let message):
                return message ?? "Serialization error occurred."
            case .deserializeError(let message):
                return message ?? "Deserialization error occurred."
            case .invalidTransaction(let message):
                return message ?? "Invalid transaction error occurred."
            case .transactionFailederror(let message):
                return message ?? "Transaction failed error occurred."
            case .insufficientUTxOBalanceError(let message):
                return message ?? "Insufficient UTxO balance error occurred."
            case .maxInputCountExceedederror(let message):
                return message ?? "Max input count exceeded error occurred."
            case .inputUTxODepletedError(let message):
                return message ?? "Input UTxO depleted error occurred."
            case .backendError(let message):
                return message ?? "Backend error occurred."
            case .invalidLanguage(let message):
                return message ?? "Invalid language error occurred."
            case .valueError(let message):
                return message ?? "Incorrect value error occurred."
            case .ioError(let message):
                return message ?? "IO error occurred."
            case .typeError(let message):
                return message ?? "Type error occurred."
            case .notImplementedError(let message):
                return message ?? "Not implemented error occurred."
        }
    }
}

