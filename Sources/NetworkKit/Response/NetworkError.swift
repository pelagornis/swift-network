import Foundation

/**
 * Errors that can occur during network operations.
 * 
 * NetworkError provides a comprehensive set of error types that cover
 * all possible failure scenarios in the networking library, from request
 * building to response processing.
 * 
 * ## Usage
 * ```swift
 * do {
 *     let users: [User] = try await provider.request(UserEndpoint(), as: [User].self)
 * } catch NetworkError.serverError(let statusCode, let data) {
 *     print("Server returned error: \(statusCode)")
 * } catch NetworkError.decodingError(let error) {
 *     print("Failed to decode response: \(error)")
 * } catch {
 *     print("Other error: \(error)")
 * }
 * ```
 */
public enum NetworkError: LocalizedError, Equatable {
    /// The request is invalid (missing required parameters, malformed URL, etc.)
    case invalidRequest
    
    /// Failed to encode request data (JSON encoding, form encoding, etc.)
    case encodingError(Error)
    
    /// Failed to decode response data to the expected type
    case decodingError(Error)
    
    /// The network request failed (timeout, connection error, etc.)
    case requestFailed(URLError)
    
    /// The server returned an error response
    case serverError(statusCode: Int, data: Data)
    
    /// The circuit breaker is open and blocking requests
    case circuitBreakerOpen
    
    /// The rate limit has been exceeded
    case rateLimitExceeded
    
    /// An error occurred during caching operations
    case cachingError(Error)
    
    /// Network connection is not available
    case noConnection
    
    /// An unknown error occurred
    case unknown
    
    public var errorDescription: String? {
        switch self {
        case .invalidRequest:
            return "Invalid request"
        case .encodingError(let error):
            return "Encoding error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        case .requestFailed(let urlError):
            return "Request failed: \(urlError.localizedDescription)"
        case .serverError(let statusCode, _):
            return "Server error with status code: \(statusCode)"
        case .circuitBreakerOpen:
            return "Circuit breaker is open"
        case .rateLimitExceeded:
            return "Rate limit exceeded"
        case .cachingError(let error):
            return "Caching error: \(error.localizedDescription)"
        case .noConnection:
            return "Network connection is not available"
        case .unknown:
            return "Unknown error occurred"
        }
    }
    
    public static func == (lhs: NetworkError, rhs: NetworkError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidRequest, .invalidRequest),
             (.decodingError, .decodingError),
             (.requestFailed, .requestFailed),
             (.serverError, .serverError),
             (.circuitBreakerOpen, .circuitBreakerOpen),
             (.rateLimitExceeded, .rateLimitExceeded),
             (.cachingError, .cachingError),
             (.noConnection, .noConnection),
             (.unknown, .unknown):
            return true
        default:
            return false
        }
    }
}
