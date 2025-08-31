import Foundation

/**
 * A plugin that logs network requests and responses for debugging and monitoring.
 * 
 * The LoggingPlugin provides detailed logging of network activity including
 * request details, response information, and error conditions. It supports
 * configurable log levels and custom loggers.
 * 
 * ## Usage
 * ```swift
 * let loggingPlugin = LoggingPlugin(
 *     logger: ConsoleLogger(),
 *     logLevel: .info
 * )
 * 
 * let provider = NetworkProvider<UserEndpoint>(
 *     plugins: [loggingPlugin]
 * )
 * ```
 */
public class LoggingPlugin: NetworkPlugin {
    /// The logger instance used to output log messages
    private let logger: NetworkLogger
    
    /// The minimum log level for messages to be output
    private let logLevel: LogLevel
    
    /**
     * Creates a new LoggingPlugin.
     * 
     * - Parameters:
     *   - logger: The logger to use for output. Defaults to `ConsoleLogger()`.
     *   - logLevel: The minimum log level to output. Defaults to `.info`.
     */
    public init(logger: NetworkLogger = ConsoleLogger(), logLevel: LogLevel = .info) {
        self.logger = logger
        self.logLevel = logLevel
    }
    
    public func willSend(_ request: URLRequest, target: Endpoint) {
        guard logLevel.shouldLog(.info) else { return }
        
        let message = """
        🌐 Network Request:
        URL: \(request.url?.absoluteString ?? "Unknown")
        Method: \(request.httpMethod ?? "Unknown")
        Headers: \(request.allHTTPHeaderFields ?? [:])
        Body: \(request.httpBody?.count ?? 0) bytes
        """
        
        logger.log(message, level: .info)
    }
    
    public func didReceive(_ result: Result<(Data, URLResponse), Error>, target: Endpoint) {
        switch result {
        case .success((let data, let response)):
            guard logLevel.shouldLog(.info) else { return }
            
            let message = """
            ✅ Network Response:
            URL: \(response.url?.absoluteString ?? "Unknown")
            Status: \((response as? HTTPURLResponse)?.statusCode ?? 0)
            Data: \(data.count) bytes
            """
            
            logger.log(message, level: .info)
            
        case .failure(let error):
            guard logLevel.shouldLog(.error) else { return }
            
            let message = """
            ❌ Network Error:
            URL: \(target.baseURL.appendingPathComponent(target.path))
            Error: \(error.localizedDescription)
            """
            
            logger.log(message, level: .error)
        }
    }
}

/**
 * A protocol for custom loggers that can be used with LoggingPlugin.
 * 
 * Implement this protocol to create custom logging solutions that integrate
 * with the networking library's logging system.
 */
public protocol NetworkLogger {
    /**
     * Logs a message with the specified level.
     * 
     * - Parameters:
     *   - message: The message to log
     *   - level: The log level of the message
     */
    func log(_ message: String, level: LogLevel)
}

/**
 * Defines the available log levels for network logging.
 * 
 * Log levels are hierarchical - setting a level will include all higher levels.
 * For example, setting `.info` will include `.warning` and `.error` messages.
 */
public enum LogLevel: Int, CaseIterable {
    /// Debug level - detailed information for debugging
    case debug = 0
    
    /// Info level - general information about network activity
    case info = 1
    
    /// Warning level - potential issues that don't prevent operation
    case warning = 2
    
    /// Error level - errors that occurred during network operations
    case error = 3
    
    /**
     * Determines if a message at the given level should be logged.
     * 
     * - Parameter messageLevel: The level of the message to check
     * - Returns: `true` if the message should be logged, `false` otherwise
     */
    func shouldLog(_ messageLevel: LogLevel) -> Bool {
        return messageLevel.rawValue >= self.rawValue
    }
}

/**
 * A simple console-based logger that outputs messages to stdout.
 * 
 * This logger formats messages with timestamps and emoji indicators
 * for easy reading during development and debugging.
 */
public class ConsoleLogger: NetworkLogger {
    /**
     * Creates a new ConsoleLogger.
     */
    public init() {}
    
    /**
     * Logs a message to the console with timestamp and emoji.
     * 
     * - Parameters:
     *   - message: The message to log
     *   - level: The log level (determines the emoji used)
     */
    public func log(_ message: String, level: LogLevel) {
        let timestamp = DateFormatter.logFormatter.string(from: Date())
        let levelString = level.emoji
        print("[\(timestamp)] \(levelString) \(message)")
    }
}

private extension DateFormatter {
    static let logFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}

public extension LogLevel {
    var emoji: String {
        switch self {
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        }
    }
}
