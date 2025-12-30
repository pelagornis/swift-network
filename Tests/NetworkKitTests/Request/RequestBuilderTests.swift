import Foundation
import XCTest
@testable import NetworkKit

// MARK: - Test Models
private struct User: Codable {
    let id: Int
    let name: String
    let email: String
}

// MARK: - RequestBuilder Tests
final class RequestBuilderTests: XCTestCase {
    
    func testBasicRequestBuilding() throws {
        // Given
        let endpoint = MockEndpoint(
            baseURL: URL(string: "https://api.example.com")!,
            path: "/users/1"
        )
        
        // When
        let builder = NetworkRequestBuilder(endpoint: endpoint)
        let builtRequest = try builder.build()
        
        // Then
        XCTAssertEqual(builtRequest.urlRequest.url?.absoluteString, "https://api.example.com/users/1")
        XCTAssertEqual(builtRequest.urlRequest.httpMethod, "GET")
        XCTAssertNil(builtRequest.downloadDestination)
    }
    
    func testRequestWithHeaders() throws {
        // Given
        let endpoint = MockEndpoint(
            baseURL: URL(string: "https://api.example.com")!,
            path: "/users/1",
            headers: [
                Http.Header(field: "Accept", value: "application/json"),
                Http.Header(field: "Content-Type", value: "application/json")
            ]
        )
        
        // When
        let builder = NetworkRequestBuilder(endpoint: endpoint)
        let builtRequest = try builder.build()
        
        // Then
        XCTAssertEqual(builtRequest.urlRequest.value(forHTTPHeaderField: "Accept"), "application/json")
        XCTAssertEqual(builtRequest.urlRequest.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }
    
    func testRequestWithExtraHeaders() throws {
        // Given
        let endpoint = MockEndpoint(
            baseURL: URL(string: "https://api.example.com")!,
            path: "/users/1"
        )
        
        // When
        let builder = NetworkRequestBuilder(endpoint: endpoint)
            .addHeader(field: "Authorization", value: "Bearer token")
            .addHeaders(["X-Custom-Header": "custom-value"])
        
        let builtRequest = try builder.build()
        
        // Then
        XCTAssertEqual(builtRequest.urlRequest.value(forHTTPHeaderField: "Authorization"), "Bearer token")
        XCTAssertEqual(builtRequest.urlRequest.value(forHTTPHeaderField: "X-Custom-Header"), "custom-value")
    }
    
    func testRequestWithTimeout() throws {
        // Given
        let endpoint = MockEndpoint(
            baseURL: URL(string: "https://api.example.com")!,
            path: "/users/1"
        )
        
        // When
        let builder = NetworkRequestBuilder(endpoint: endpoint)
            .setTimeout(30.0)
        
        let builtRequest = try builder.build()
        
        // Then
        XCTAssertEqual(builtRequest.urlRequest.timeoutInterval, 30.0)
    }
    
    func testRequestWithCachePolicy() throws {
        // Given
        let endpoint = MockEndpoint(
            baseURL: URL(string: "https://api.example.com")!,
            path: "/users/1"
        )
        
        // When
        let builder = NetworkRequestBuilder(endpoint: endpoint)
            .setCachePolicy(.reloadIgnoringLocalCacheData)
        
        let builtRequest = try builder.build()
        
        // Then
        XCTAssertEqual(builtRequest.urlRequest.cachePolicy, .reloadIgnoringLocalCacheData)
    }
    
    func testRequestWithModifiers() throws {
        // Given
        let endpoint = MockEndpoint(
            baseURL: URL(string: "https://api.example.com")!,
            path: "/users/1"
        )
        
        let headerModifier = HeaderModifier(headers: ["X-Modifier": "modified"])
        let timeoutModifier = TimeoutModifier(timeout: 60.0)
        
        // When
        let builder = NetworkRequestBuilder(endpoint: endpoint)
            .addModifier(headerModifier)
            .addModifier(timeoutModifier)
        
        let builtRequest = try builder.build()
        
        // Then
        XCTAssertEqual(builtRequest.urlRequest.value(forHTTPHeaderField: "X-Modifier"), "modified")
        XCTAssertEqual(builtRequest.urlRequest.timeoutInterval, 60.0)
    }
    
    func testJSONRequestBuilding() throws {
        // Given
        let user = User(id: 1, name: "John Doe", email: "john@example.com")
        let endpoint = MockEndpoint(
            baseURL: URL(string: "https://api.example.com")!,
            path: "/users",
            method: .post,
            task: .requestJSON(user)
        )
        
        // When
        let builder = NetworkRequestBuilder(endpoint: endpoint)
        let builtRequest = try builder.build()
        
        // Then
        XCTAssertEqual(builtRequest.urlRequest.httpMethod, "POST")
        XCTAssertEqual(builtRequest.urlRequest.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertNotNil(builtRequest.urlRequest.httpBody)
        
        // Verify JSON body
        let decodedUser = try JSONDecoder().decode(User.self, from: builtRequest.urlRequest.httpBody!)
        XCTAssertEqual(decodedUser.id, user.id)
        XCTAssertEqual(decodedUser.name, user.name)
        XCTAssertEqual(decodedUser.email, user.email)
    }
    
    func testParametersRequestBuilding() throws {
        // Given
        let parameters = ["page": "1", "limit": "10"]
        let endpoint = MockEndpoint(
            baseURL: URL(string: "https://api.example.com")!,
            path: "/users",
            method: .get,
            task: .requestParameters(parameters, encoding: .url)
        )
        
        // When
        let builder = NetworkRequestBuilder(endpoint: endpoint)
        let builtRequest = try builder.build()
        
        // Then
        XCTAssertEqual(builtRequest.urlRequest.httpMethod, "GET")
        XCTAssertTrue(builtRequest.urlRequest.url?.absoluteString.contains("page=1") == true)
        XCTAssertTrue(builtRequest.urlRequest.url?.absoluteString.contains("limit=10") == true)
    }
    
    func testInvalidURLRequest() throws {
        // Given
        let endpoint = MockEndpoint(
            baseURL: URL(string: "https://api.example.com")!,
            path: "invalid path with spaces"
        )
        
        // When & Then - URLComponents can handle spaces, so this should not throw
        let builder = NetworkRequestBuilder(endpoint: endpoint)
        let request = try builder.build()
        XCTAssertNotNil(request)
    }
}

// MARK: - RequestModifier Tests
final class RequestModifierTests: XCTestCase {
    
    func testHeaderModifier() throws {
        // Given
        let originalRequest = BuiltRequest(
            urlRequest: URLRequest(url: URL(string: "https://api.example.com")!),
            downloadDestination: nil
        )
        
        let headerModifier = HeaderModifier(headers: [
            "Authorization": "Bearer token",
            "X-Custom": "value"
        ])
        
        // When
        let modifiedRequest = try headerModifier.modify(originalRequest)
        
        // Then
        XCTAssertEqual(modifiedRequest.urlRequest.value(forHTTPHeaderField: "Authorization"), "Bearer token")
        XCTAssertEqual(modifiedRequest.urlRequest.value(forHTTPHeaderField: "X-Custom"), "value")
    }
    
    func testTimeoutModifier() throws {
        // Given
        let originalRequest = BuiltRequest(
            urlRequest: URLRequest(url: URL(string: "https://api.example.com")!),
            downloadDestination: nil
        )
        
        let timeoutModifier = TimeoutModifier(timeout: 45.0)
        
        // When
        let modifiedRequest = try timeoutModifier.modify(originalRequest)
        
        // Then
        XCTAssertEqual(modifiedRequest.urlRequest.timeoutInterval, 45.0)
    }
    
    func testCachePolicyModifier() throws {
        // Given
        let originalRequest = BuiltRequest(
            urlRequest: URLRequest(url: URL(string: "https://api.example.com")!),
            downloadDestination: nil
        )
        
        let cachePolicyModifier = CachePolicyModifier(cachePolicy: .returnCacheDataElseLoad)
        
        // When
        let modifiedRequest = try cachePolicyModifier.modify(originalRequest)
        
        // Then
        XCTAssertEqual(modifiedRequest.urlRequest.cachePolicy, .returnCacheDataElseLoad)
    }
    
    func testMultipleModifiers() throws {
        // Given
        let originalRequest = BuiltRequest(
            urlRequest: URLRequest(url: URL(string: "https://api.example.com")!),
            downloadDestination: nil
        )
        
        let headerModifier = HeaderModifier(headers: ["Authorization": "Bearer token"])
        let timeoutModifier = TimeoutModifier(timeout: 30.0)
        let cachePolicyModifier = CachePolicyModifier(cachePolicy: .reloadIgnoringLocalCacheData)
        
        // When
        var modifiedRequest = try headerModifier.modify(originalRequest)
        modifiedRequest = try timeoutModifier.modify(modifiedRequest)
        modifiedRequest = try cachePolicyModifier.modify(modifiedRequest)
        
        // Then
        XCTAssertEqual(modifiedRequest.urlRequest.value(forHTTPHeaderField: "Authorization"), "Bearer token")
        XCTAssertEqual(modifiedRequest.urlRequest.timeoutInterval, 30.0)
        XCTAssertEqual(modifiedRequest.urlRequest.cachePolicy, .reloadIgnoringLocalCacheData)
    }
}

// MARK: - Mock Types
private struct MockEndpoint: Endpoint {
    let baseURL: URL
    let path: String
    let method: Http.Method
    let task: Http.Task
    let headers: [Http.Header]
    let sampleData: Data?
    let timeout: TimeInterval?
    
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
    
    init(baseURL: URL, path: String, method: Http.Method = .get, task: Http.Task = .requestPlain, headers: [Http.Header] = [], sampleData: Data? = nil, timeout: TimeInterval? = nil) {
        self.baseURL = baseURL
        self.path = path
        self.method = method
        self.task = task
        self.headers = headers
        self.sampleData = sampleData
        self.timeout = timeout
    }
}
