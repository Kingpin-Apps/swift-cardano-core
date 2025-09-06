import Logging
import Foundation

public enum LogLevel {
    case debug
    case info
    case warning
    case error
}

// Setup Logging
private let loggingInitOnce: Void = {
    LoggingSystem.bootstrap { label in
        StreamLogHandler.standardOutput(label: label)
    }
}()

public protocol Loggable {
    var logger: Logger { get }
    func logState(logLevel: LogLevel)
}

public extension Loggable {
    
    func setupLogging() {
        _ = loggingInitOnce
    }
    
    func logState(logLevel: LogLevel = .debug) {
        let mirror = Mirror(reflecting: self)
        let properties = mirror.children.map { "\($0.label ?? "unknown"): \($0.value)" }.joined(separator: "\n")
        
        switch logLevel {
            case .debug:
                logger.debug("Class: \(type(of: self)), state:\n \(properties)")
            case .info:
                logger.info("Class: \(type(of: self)), state:\n \(properties)")
            case .warning:
                logger.warning("Class: \(type(of: self)), state:\n \(properties)")
            case .error:
                logger.error("Class: \(type(of: self)), state:\n \(properties)")
        }
    }
}
