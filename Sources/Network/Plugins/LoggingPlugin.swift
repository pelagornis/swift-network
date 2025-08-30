import Foundation

public class LoggingPlugin: NetworkPlugin {
    private let logger: NetworkLogger
    private let logLevel: LogLevel
    
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

public protocol NetworkLogger {
    func log(_ message: String, level: LogLevel)
}

public enum LogLevel: Int, CaseIterable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3
    
    func shouldLog(_ messageLevel: LogLevel) -> Bool {
        return messageLevel.rawValue >= self.rawValue
    }
}

public class ConsoleLogger: NetworkLogger {
    public init() {}
    
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
