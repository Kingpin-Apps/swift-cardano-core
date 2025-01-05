//
//  Created by Hareem Adderley on 22/06/2024 AT 9:33 PM
//  Copyright © 2024 Kingpin Apps. All rights reserved.
//  

import Foundation
import SwiftMnemonic

enum CardanoException: Error, CustomStringConvertible, Equatable {
    case encodingException(String?)
    case decodingException(String?)
    case inputUTxODepletedException(String?)
    case insufficientUTxOBalanceException(String?)
    case invalidAddressInputException(String?)
    case invalidArgumentException(String?)
    case invalidDataException(String?)
    case invalidKeyTypeException(String?)
    case invalidLanguage(String?)
    case invalidOperationException(String?)
    case invalidTransactionException(String?)
    case serializeException(String?)
    case deserializeException(String?)
    case transactionBuilderException(String?)
    case transactionFailedException(String?)
    case uTxOSelectionException(String?)
    case maxInputCountExceededException(String?)
    case backendError(String?)
    case valueError(String?)
    case ioError(String?)
    
    var description: String {
        switch self {
        case .encodingException(let message):
            return message ?? "Encoding exception occurred."
        case .decodingException(let message):
            return message ?? "Decoding exception occurred."
        case .invalidKeyTypeException(let message):
            return message ?? "Invalid key type exception occurred."
        case .invalidAddressInputException(let message):
            return message ?? "Invalid address input exception occurred."
        case .invalidDataException(let message):
            return message ?? "Invalid data exception occurred."
        case .invalidArgumentException(let message):
            return message ?? "Invalid argument exception occurred."
        case .invalidOperationException(let message):
            return message ?? "Invalid operation exception occurred."
        case .serializeException(let message):
            return message ?? "Serialization exception occurred."
        case .deserializeException(let message):
            return message ?? "Deserialization exception occurred."
        case .invalidTransactionException(let message):
            return message ?? "Invalid transaction exception occurred."
        case .transactionBuilderException(let message):
            return message ?? "Transaction builder exception occurred."
        case .transactionFailedException(let message):
            return message ?? "Transaction failed exception occurred."
        case .uTxOSelectionException(let message):
            return message ?? "UTxO selection exception occurred."
        case .insufficientUTxOBalanceException(let message):
            return message ?? "Insufficient UTxO balance exception occurred."
        case .maxInputCountExceededException(let message):
            return message ?? "Max input count exceeded exception occurred."
        case .inputUTxODepletedException(let message):
            return message ?? "Input UTxO depleted exception occurred."
        case .backendError(let message):
            return message ?? "Backend error occurred."
        case .invalidLanguage(let message):
            return message ?? "Invalid language exception occurred."
        case .valueError(let message):
            return message ?? "Incorrect value exception occurred."
        case .ioError(let message):
            return message ?? "IO error occurred."
        }
    }
}

