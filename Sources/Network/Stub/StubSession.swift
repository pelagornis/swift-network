import Foundation

/**
 * A stub implementation of Session for testing purposes.
 * 
 * StubSession allows you to create mock network responses for testing
 * without making actual network requests. It returns predefined data
 * and status codes to simulate various network scenarios.
 * 
 * ## Usage
 * ```swift
 * let stubData = """
 * {
 *   "id": 1,
 *   "name": "John Doe"
 * }
 * """.data(using: .utf8)!
 * 
 * let stubSession = StubSession(
 *     stubData,
 *     statusCode: 200,
 *     url: URL(string: "https://api.example.com/users")!
 * )
 * 
 * let provider = NetworkProvider<UserEndpoint>(session: stubSession)
 * ```
 */
public struct StubSession: Session {
    /// The data to return in the response
    let data: Data
    
    /// The HTTP status code to return
    let statusCode: Int
    
    /// The URL to associate with the response
    let url: URL

    /**
     * Creates a new StubSession.
     * 
     * - Parameters:
     *   - data: The data to return in the response
     *   - statusCode: The HTTP status code. Defaults to 200.
     *   - url: The URL to associate with the response
     */
    public init(_ data: Data, statusCode: Int = 200, url: URL) {
        self.data = data
        self.statusCode = statusCode
        self.url = url
    }

    public func perform(_ request: URLRequest) async throws -> (Data, URLResponse) {
        let res = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (data, res)
    }
}
