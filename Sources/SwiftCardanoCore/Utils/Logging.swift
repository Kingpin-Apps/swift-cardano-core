import Logging
import Foundation

/// The level at which ``Loggable/logState(logLevel:)`` writes a value's state.
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

/// A type that can write its stored properties to a `Logger`.
public protocol Loggable {
    /// The logger the value writes to.
    var logger: Logger { get }
    /// Writes the type name and every stored property to ``logger``.
    /// - Parameter logLevel: The level to log at.
    func logState(logLevel: LogLevel)
}

public extension Loggable {
    
    /// Bootstraps the logging system to write to standard output. Only the
    /// first call has any effect.
    func setupLogging() {
        _ = loggingInitOnce
    }
    
    /// Writes the type name and every stored property, found by reflection,
    /// to ``logger``.
    /// - Parameter logLevel: The level to log at. Defaults to ``LogLevel/debug``.
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
