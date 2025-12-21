import Foundation

/**
 * A protocol for performing network requests.
 * 
 * Session provides an abstraction layer for network request execution,
 * allowing for different implementations including URLSession, mock sessions
 * for testing, and custom network stacks.
 * 
 * ## Usage
 * ```swift
 * // Use default URLSession
 * let session: Session = URLSession.shared
 * 
 * // Use custom session
 * let customSession = CustomSession()
 * 
 * let (data, response) = try await session.perform(request)
 * ```
 */
public protocol Session {
    /**
     * Performs a network request and returns the response data and metadata.
     * 
     * - Parameter request: The URLRequest to perform
     * - Returns: A tuple containing the response data and URLResponse
     * - Throws: Any error that occurs during the request
     */
    func perform(_ request: URLRequest) async throws -> (Data, URLResponse)
}

/**
 * Extension that makes URLSession conform to the Session protocol.
 * 
 * This allows URLSession to be used seamlessly with the networking library
 * while maintaining all of its built-in functionality.
 */
extension URLSession: Session {
    /**
     * Performs a network request using URLSession's data method.
     * 
     * - Parameter request: The URLRequest to perform
     * - Returns: A tuple containing the response data and URLResponse
     * - Throws: Any error that occurs during the request
     */
    public func perform(_ request: URLRequest) async throws -> (Data, URLResponse) {
        try await self.data(for: request)
    }
}
