import Foundation
import XCTest
@testable import Network

// MARK: - Test Models
private struct User: Codable {
    let id: Int
    let name: String
    let email: String
}

// MARK: - ResponseHandler Tests
final class ResponseHandlerTests: XCTestCase {
    private var responseHandler: DefaultResponseHandler!
    private var cacheManager: MemoryCacheManager!
    
    override func setUp() {
        super.setUp()
        responseHandler = DefaultResponseHandler()
        cacheManager = MemoryCacheManager()
    }
    
    override func tearDown() {
        responseHandler = nil
        cacheManager = nil
        super.tearDown()
    }
    
    func testSuccessfulResponseHandling() throws {
        // Given
        let user = User(id: 1, name: "John Doe", email: "john@example.com")
        let userData = try JSONEncoder().encode(user)
        let response = HTTPURLResponse(
            url: URL(string: "https://api.example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        
        // When
        let result: User = try responseHandler.handle(userData, response: response, as: User.self)
        
        // Then
        XCTAssertEqual(result.id, user.id)
        XCTAssertEqual(result.name, user.name)
        XCTAssertEqual(result.email, user.email)
    }
    
    func testServerErrorResponse() throws {
        // Given
        let errorData = "Server Error".data(using: .utf8)!
        let response = HTTPURLResponse(
            url: URL(string: "https://api.example.com")!,
            statusCode: 500,
            httpVersion: nil,
            headerFields: nil
        )!
        
        // When & Then
        do {
            let _: User = try responseHandler.handle(errorData, response: response, as: User.self)
            XCTFail("Expected error to be thrown")
        } catch NetworkError.serverError(let statusCode, let data) {
            XCTAssertEqual(statusCode, 500)
            XCTAssertEqual(data, errorData)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testClientErrorResponse() throws {
        // Given
        let errorData = "Not Found".data(using: .utf8)!
        let response = HTTPURLResponse(
            url: URL(string: "https://api.example.com")!,
            statusCode: 404,
            httpVersion: nil,
            headerFields: nil
        )!
        
        // When & Then
        do {
            let _: User = try responseHandler.handle(errorData, response: response, as: User.self)
            XCTFail("Expected error to be thrown")
        } catch NetworkError.serverError(let statusCode, let data) {
            XCTAssertEqual(statusCode, 404)
            XCTAssertEqual(data, errorData)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testNonHTTPResponse() throws {
        // Given
        let userData = try JSONEncoder().encode(User(id: 1, name: "John", email: "john@example.com"))
        let response = URLResponse(
            url: URL(string: "https://api.example.com")!,
            mimeType: "application/json",
            expectedContentLength: userData.count,
            textEncodingName: nil
        )
        
        // When & Then
        do {
            let _: User = try responseHandler.handle(userData, response: response, as: User.self)
            XCTFail("Expected error to be thrown")
        } catch NetworkError.unknown {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testDecodingError() throws {
        // Given
        let invalidData = "Invalid JSON".data(using: .utf8)!
        let response = HTTPURLResponse(
            url: URL(string: "https://api.example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        
        // When & Then
        do {
            let _: User = try responseHandler.handle(invalidData, response: response, as: User.self)
            XCTFail("Expected error to be thrown")
        } catch {
            // Expected decoding error
            XCTAssertTrue(error is DecodingError)
        }
    }
    
    func testCustomDecoder() throws {
        // Given
        let customDecoder = JSONDecoder()
        customDecoder.keyDecodingStrategy = .convertFromSnakeCase
        
        let snakeCaseData = """
        {
            "user_id": 1,
            "user_name": "John Doe",
            "user_email": "john@example.com"
        }
        """.data(using: .utf8)!
        
        let response = HTTPURLResponse(
            url: URL(string: "https://api.example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        
        let customHandler = DefaultResponseHandler(decoder: customDecoder)
        
        // When
        let result: SnakeCaseUser = try customHandler.handle(snakeCaseData, response: response, as: SnakeCaseUser.self)
        
        // Then
        XCTAssertEqual(result.userId, 1)
        XCTAssertEqual(result.userName, "John Doe")
        XCTAssertEqual(result.userEmail, "john@example.com")
    }
}

// MARK: - CacheManager Tests
final class CacheManagerTests: XCTestCase {
    var cacheManager: MemoryCacheManager!
    
    override func setUp() {
        super.setUp()
        cacheManager = MemoryCacheManager()
    }
    
    override func tearDown() {
        cacheManager.clear()
        cacheManager = nil
        super.tearDown()
    }
    
    func testBasicCaching() throws {
        // Given
        let user = User(id: 1, name: "John Doe", email: "john@example.com")
        let key = "user_1"
        
        // When
        cacheManager.set(user, for: key, expiration: nil)
        let cachedUser: User? = cacheManager.get(for: key, as: User.self)
        
        // Then
        XCTAssertNotNil(cachedUser)
        XCTAssertEqual(cachedUser?.id, user.id)
        XCTAssertEqual(cachedUser?.name, user.name)
        XCTAssertEqual(cachedUser?.email, user.email)
    }
    
    func testCachingWithExpiration() async throws {
        // Given
        let user = User(id: 1, name: "John Doe", email: "john@example.com")
        let key = "user_1"
        let expiration: TimeInterval = 0.1 // 100ms
        
        // When
        cacheManager.set(user, for: key, expiration: expiration)
        
        // Then - Should be available immediately
        let immediateUser: User? = cacheManager.get(for: key, as: User.self)
        XCTAssertNotNil(immediateUser)
        
        // Wait for expiration
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        
        // Then - Should be expired
        let expiredUser: User? = cacheManager.get(for: key, as: User.self)
        XCTAssertNil(expiredUser)
    }
    
    func testCacheRemoval() throws {
        // Given
        let user = User(id: 1, name: "John Doe", email: "john@example.com")
        let key = "user_1"
        
        cacheManager.set(user, for: key, expiration: nil)
        
        // Verify it's cached
        let cachedUser: User? = cacheManager.get(for: key, as: User.self)
        XCTAssertNotNil(cachedUser)
        
        // When
        cacheManager.remove(for: key)
        
        // Then
        let removedUser: User? = cacheManager.get(for: key, as: User.self)
        XCTAssertNil(removedUser)
    }
    
    func testCacheClear() throws {
        // Given
        let user1 = User(id: 1, name: "John Doe", email: "john@example.com")
        let user2 = User(id: 2, name: "Jane Doe", email: "jane@example.com")
        
        cacheManager.set(user1, for: "user_1", expiration: nil)
        cacheManager.set(user2, for: "user_2", expiration: nil)
        
        // Verify both are cached
        XCTAssertNotNil(cacheManager.get(for: "user_1", as: User.self))
        XCTAssertNotNil(cacheManager.get(for: "user_2", as: User.self))
        
        // When
        cacheManager.clear()
        
        // Then
        XCTAssertNil(cacheManager.get(for: "user_1", as: User.self))
        XCTAssertNil(cacheManager.get(for: "user_2", as: User.self))
    }
    
    func testCacheWithDifferentTypes() throws {
        // Given
        let user = User(id: 1, name: "John Doe", email: "john@example.com")
        let string = "Hello World"
        let number = 42
        
        // When
        cacheManager.set(user, for: "user", expiration: nil)
        cacheManager.set(string, for: "string", expiration: nil)
        cacheManager.set(number, for: "number", expiration: nil)
        
        // Then
        let cachedUser: User? = cacheManager.get(for: "user", as: User.self)
        let cachedString: String? = cacheManager.get(for: "string", as: String.self)
        let cachedNumber: Int? = cacheManager.get(for: "number", as: Int.self)
        
        XCTAssertNotNil(cachedUser)
        XCTAssertNotNil(cachedString)
        XCTAssertNotNil(cachedNumber)
        
        XCTAssertEqual(cachedUser?.id, user.id)
        XCTAssertEqual(cachedString, string)
        XCTAssertEqual(cachedNumber, number)
    }
    
    func testCacheKeyCollision() throws {
        // Given
        let user1 = User(id: 1, name: "John Doe", email: "john@example.com")
        let user2 = User(id: 2, name: "Jane Smith", email: "jane@example.com")
        let key = "user_key"
        
        // When
        cacheManager.set(user1, for: key, expiration: nil)
        cacheManager.set(user2, for: key, expiration: nil)
        
        // Then - Should return the last set value
        let cachedUser: User? = cacheManager.get(for: key, as: User.self)
        
        // The last set value should be retrievable
        XCTAssertEqual(cachedUser?.id, user2.id)
        XCTAssertEqual(cachedUser?.name, user2.name)
    }
}

// MARK: - Helper Types
private struct SnakeCaseUser: Codable {
    let userId: Int
    let userName: String
    let userEmail: String
}

private struct DifferentUser: Codable {
    let title: String
    let firstName: String
    let lastName: String
}

private struct CompletelyDifferentStruct: Codable {
    let value: String
    let timestamp: Date
}
