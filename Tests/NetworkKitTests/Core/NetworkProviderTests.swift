import Foundation
import XCTest
@testable import NetworkKit

// MARK: - Test Models
private struct User: Codable {
    let id: Int
    let name: String
    let email: String
}

// MARK: - NetworkProvider Tests
final class NetworkProviderTests: XCTestCase {
    fileprivate var mockSession: MockSession!
    fileprivate var networkProvider: NetworkProvider<MockEndpoint>!
    
    override func setUp() {
        super.setUp()
        mockSession = MockSession()
        networkProvider = NetworkProvider<MockEndpoint>(session: mockSession)
    }
    
    override func tearDown() {
        mockSession = nil
        networkProvider = nil
        super.tearDown()
    }
    
    func testSuccessfulRequest() async throws {
        // Given
        let expectedUser = User(id: 1, name: "John Doe", email: "john@example.com")
        let userData = try JSONEncoder().encode(expectedUser)
        let response = HTTPURLResponse(url: URL(string: "https://api.example.com")!, 
                                     statusCode: 200, 
                                     httpVersion: nil, 
                                     headerFields: nil)!
        
        mockSession.mockResult = .success((userData, response))
        
        let endpoint = MockEndpoint(baseURL: URL(string: "https://api.example.com")!, 
                                  path: "/users/1")
        
        // When
        let result: User = try await networkProvider.request(endpoint, as: User.self)
        
        // Then
        XCTAssertEqual(result.id, expectedUser.id)
        XCTAssertEqual(result.name, expectedUser.name)
        XCTAssertEqual(result.email, expectedUser.email)
        XCTAssertEqual(mockSession.performCallCount, 1)
    }
    
    func testRequestWithPlugins() async throws {
        // Given
        let mockPlugin = MockNetworkPlugin()
        let networkProviderWithPlugin = NetworkProvider<MockEndpoint>(
            session: mockSession,
            plugins: [mockPlugin]
        )
        
        let expectedUser = User(id: 1, name: "John Doe", email: "john@example.com")
        let userData = try JSONEncoder().encode(expectedUser)
        let response = HTTPURLResponse(url: URL(string: "https://api.example.com")!, 
                                     statusCode: 200, 
                                     httpVersion: nil, 
                                     headerFields: nil)!
        
        mockSession.mockResult = .success((userData, response))
        
        let endpoint = MockEndpoint(baseURL: URL(string: "https://api.example.com")!, 
                                  path: "/users/1")
        
        // When
        let _: User = try await networkProviderWithPlugin.request(endpoint, as: User.self)
        
        // Then
        XCTAssertEqual(mockPlugin.willSendCallCount, 1)
        XCTAssertEqual(mockPlugin.didReceiveCallCount, 1)
        XCTAssertNotNil(mockPlugin.lastDidReceiveResult)
    }
    
    func testRequestWithModifiers() async throws {
        // Given
        let expectedUser = User(id: 1, name: "John Doe", email: "john@example.com")
        let userData = try JSONEncoder().encode(expectedUser)
        let response = HTTPURLResponse(url: URL(string: "https://api.example.com")!, 
                                     statusCode: 200, 
                                     httpVersion: nil, 
                                     headerFields: nil)!
        
        mockSession.mockResult = .success((userData, response))
        
        let endpoint = MockEndpoint(baseURL: URL(string: "https://api.example.com")!, 
                                  path: "/users/1")
        
        let headerModifier = HeaderModifier(headers: ["Authorization": "Bearer token"])
        let timeoutModifier = TimeoutModifier(timeout: 30.0)
        
        // When
        let _: User = try await networkProvider.request(
            endpoint, 
            as: User.self, 
            modifiers: [headerModifier, timeoutModifier]
        )
        
        // Then
        XCTAssertEqual(mockSession.performCallCount, 1)
        let request = mockSession.lastRequest
        XCTAssertEqual(request?.value(forHTTPHeaderField: "Authorization"), "Bearer token")
        XCTAssertEqual(request?.timeoutInterval, 30.0)
    }
    
    func testServerError() async throws {
        // Given
        let errorData = "Server Error".data(using: .utf8)!
        let response = HTTPURLResponse(url: URL(string: "https://api.example.com")!, 
                                     statusCode: 500, 
                                     httpVersion: nil, 
                                     headerFields: nil)!
        
        mockSession.mockResult = .success((errorData, response))
        
        let endpoint = MockEndpoint(baseURL: URL(string: "https://api.example.com")!, 
                                  path: "/users/1")
        
        // When & Then
        do {
            let _: User = try await networkProvider.request(endpoint, as: User.self)
            XCTFail("Expected error to be thrown")
        } catch NetworkError.serverError(let statusCode, let data) {
            XCTAssertEqual(statusCode, 500)
            XCTAssertEqual(data, errorData)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testNetworkError() async throws {
        // Given
        let urlError = URLError(.networkConnectionLost)
        mockSession.mockResult = .failure(urlError)
        
        let endpoint = MockEndpoint(baseURL: URL(string: "https://api.example.com")!, 
                                  path: "/users/1")
        
        // When & Then
        do {
            let _: User = try await networkProvider.request(endpoint, as: User.self)
            XCTFail("Expected error to be thrown")
        } catch NetworkError.requestFailed(let error) {
            XCTAssertEqual(error as URLError, urlError)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

// MARK: - Mock Types
private struct MockEndpoint: Endpoint {
    let baseURL: URL
    let path: String
    let method: Http.Method = .get
    let task: Http.Task = .requestPlain
    let headers: [Http.Header] = []
    let sampleData: Data? = nil
    let timeout: TimeInterval? = nil
    
    var body: HTTPEndpoint {
        HTTPEndpoint(
            baseURL: baseURL,
            path: path,
            method: method,
            task: task,
            headers: headers,
            sampleData: sampleData,
            timeout: timeout
        )
    }
}

private class MockSession: Session {
    var mockResult: Result<(Data, URLResponse), Error>?
    var performCallCount = 0
    var lastRequest: URLRequest?
    
    func perform(_ request: URLRequest) async throws -> (Data, URLResponse) {
        performCallCount += 1
        lastRequest = request
        
        guard let mockResult = mockResult else {
            throw NetworkError.unknown
        }
        
        switch mockResult {
        case .success(let result):
            return result
        case .failure(let error):
            throw error
        }
    }
}

private class MockNetworkPlugin: NetworkPlugin {
    var willSendCallCount = 0
    var didReceiveCallCount = 0
    var lastDidReceiveResult: Result<(Data, URLResponse), Error>?
    
    func willSend(_ request: URLRequest, target: any Endpoint) {
        willSendCallCount += 1
    }
    
    func didReceive(_ result: Result<(Data, URLResponse), Error>, target: any Endpoint) {
        didReceiveCallCount += 1
        lastDidReceiveResult = result
    }
}
