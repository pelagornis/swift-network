import XCTest
@testable import Network

final class LoggingPluginTests: XCTestCase {
    fileprivate var mockLogger: MockNetworkLogger!
    fileprivate var loggingPlugin: LoggingPlugin!
    
    override func setUp() {
        super.setUp()
        mockLogger = MockNetworkLogger()
        loggingPlugin = LoggingPlugin(logger: mockLogger, logLevel: .info)
    }
    
    override func tearDown() {
        mockLogger = nil
        loggingPlugin = nil
        super.tearDown()
    }
    
    func testWillSendLogging() {
        // Given
        let url = URL(string: "https://api.example.com/users/1")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = "test data".data(using: .utf8)
        
        let endpoint = MockEndpoint(baseURL: URL(string: "https://api.example.com")!, path: "/users/1")
        
        // When
        loggingPlugin.willSend(request, target: endpoint)
        
        // Then
        XCTAssertEqual(mockLogger.logCallCount, 1)
        XCTAssertEqual(mockLogger.lastLogLevel, .info)
        XCTAssertNotNil(mockLogger.lastMessage)
        print("Actual log message: \(mockLogger.lastMessage ?? "nil")")
        XCTAssertTrue(mockLogger.lastMessage?.contains("🌐 Network Request:") == true)
        XCTAssertTrue(mockLogger.lastMessage?.contains("https://api.example.com/users/1") == true)
        XCTAssertTrue(mockLogger.lastMessage?.contains("GET") == true)
        XCTAssertTrue(mockLogger.lastMessage?.contains("application/json") == true)
        XCTAssertTrue(mockLogger.lastMessage?.contains("9 bytes") == true) // "test data" length
    }
    
    func testDidReceiveSuccessLogging() {
        // Given
        let responseData = "response data".data(using: .utf8)!
        let response = HTTPURLResponse(
            url: URL(string: "https://api.example.com/users/1")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        
        let result: Result<(Data, URLResponse), Error> = .success((responseData, response))
        let endpoint = MockEndpoint(baseURL: URL(string: "https://api.example.com")!, path: "/users/1")
        
        // When
        loggingPlugin.didReceive(result, target: endpoint)
        
        // Then
        XCTAssertEqual(mockLogger.logCallCount, 1)
        XCTAssertEqual(mockLogger.lastLogLevel, .info)
        XCTAssertTrue(mockLogger.lastMessage?.contains("✅ Network Response:") == true)
        XCTAssertTrue(mockLogger.lastMessage?.contains("https://api.example.com/users/1") == true)
        XCTAssertTrue(mockLogger.lastMessage?.contains("200") == true)
        XCTAssertTrue(mockLogger.lastMessage?.contains("13 bytes") == true) // "response data" length
    }
    
    func testDidReceiveErrorLogging() {
        // Given
        let error = URLError(.networkConnectionLost)
        let result: Result<(Data, URLResponse), Error> = .failure(error)
        let endpoint = MockEndpoint(baseURL: URL(string: "https://api.example.com")!, path: "/users/1")
        
        // When
        loggingPlugin.didReceive(result, target: endpoint)
        
        // Then
        XCTAssertEqual(mockLogger.logCallCount, 1)
        XCTAssertEqual(mockLogger.lastLogLevel, .error)
        XCTAssertNotNil(mockLogger.lastMessage)
        print("Actual error log message: \(mockLogger.lastMessage ?? "nil")")
        XCTAssertTrue(mockLogger.lastMessage?.contains("❌ Network Error:") == true)
        XCTAssertTrue(mockLogger.lastMessage?.contains("https://api.example.com/users/1") == true)
        XCTAssertTrue(mockLogger.lastMessage?.contains("NSURLErrorDomain") == true)
    }
    
    func testLogLevelFiltering() {
        // Given
        let debugPlugin = LoggingPlugin(logger: mockLogger, logLevel: .debug)
        let warningPlugin = LoggingPlugin(logger: mockLogger, logLevel: .warning)
        
        let request = URLRequest(url: URL(string: "https://api.example.com")!)
        let endpoint = MockEndpoint(baseURL: URL(string: "https://api.example.com")!, path: "/test")
        
        // When - Debug level should log info
        debugPlugin.willSend(request, target: endpoint)
        XCTAssertEqual(mockLogger.logCallCount, 1)
        
        // Reset
        mockLogger.reset()
        
        // When - Warning level should not log info
        warningPlugin.willSend(request, target: endpoint)
        XCTAssertEqual(mockLogger.logCallCount, 0)
        
        // Reset
        mockLogger.reset()
        
        // When - Warning level should log error
        let error = URLError(.networkConnectionLost)
        let result: Result<(Data, URLResponse), Error> = .failure(error)
        warningPlugin.didReceive(result, target: endpoint)
        XCTAssertEqual(mockLogger.logCallCount, 1)
    }
    
    func testConsoleLogger() {
        // Given
        let consoleLogger = ConsoleLogger()
        
        // When & Then - Should not crash
        consoleLogger.log("Test message", level: .info)
        consoleLogger.log("Test error", level: .error)
        consoleLogger.log("Test warning", level: .warning)
        consoleLogger.log("Test debug", level: .debug)
    }
    
    func testLogLevelComparison() {
        // Given
        let debugLevel = LogLevel.debug
        let infoLevel = LogLevel.info
        let warningLevel = LogLevel.warning
        let errorLevel = LogLevel.error
        
        // Then
        XCTAssertTrue(debugLevel.shouldLog(.debug))
        XCTAssertTrue(debugLevel.shouldLog(.info))
        XCTAssertTrue(debugLevel.shouldLog(.warning))
        XCTAssertTrue(debugLevel.shouldLog(.error))
        
        XCTAssertFalse(infoLevel.shouldLog(.debug))
        XCTAssertTrue(infoLevel.shouldLog(.info))
        XCTAssertTrue(infoLevel.shouldLog(.warning))
        XCTAssertTrue(infoLevel.shouldLog(.error))
        
        XCTAssertFalse(warningLevel.shouldLog(.debug))
        XCTAssertFalse(warningLevel.shouldLog(.info))
        XCTAssertTrue(warningLevel.shouldLog(.warning))
        XCTAssertTrue(warningLevel.shouldLog(.error))
        
        XCTAssertFalse(errorLevel.shouldLog(.debug))
        XCTAssertFalse(errorLevel.shouldLog(.info))
        XCTAssertFalse(errorLevel.shouldLog(.warning))
        XCTAssertTrue(errorLevel.shouldLog(.error))
    }
    
    func testLogLevelEmoji() {
        // Given
        let debugLevel = LogLevel.debug
        let infoLevel = LogLevel.info
        let warningLevel = LogLevel.warning
        let errorLevel = LogLevel.error
        
        // Then
        XCTAssertEqual(debugLevel.emoji, "🔍")
        XCTAssertEqual(infoLevel.emoji, "ℹ️")
        XCTAssertEqual(warningLevel.emoji, "⚠️")
        XCTAssertEqual(errorLevel.emoji, "❌")
    }
}

// MARK: - Mock Types
private class MockNetworkLogger: NetworkLogger {
    var logCallCount = 0
    var lastMessage: String?
    var lastLogLevel: LogLevel?
    
    func log(_ message: String, level: LogLevel) {
        logCallCount += 1
        lastMessage = message
        lastLogLevel = level
    }
    
    func reset() {
        logCallCount = 0
        lastMessage = nil
        lastLogLevel = nil
    }
}

private struct MockEndpoint: Endpoint {
    let baseURL: URL
    let path: String
    let method: Http.Method = .get
    let task: Http.Task = .requestPlain
    let headers: [Http.Header] = []
}
