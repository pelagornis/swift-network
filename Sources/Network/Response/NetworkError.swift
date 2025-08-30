import Foundation

public enum NetworkError: LocalizedError, Equatable {
    case invalidRequest
    case encodingError(Error)
    case decodingError(Error)
    case requestFailed(URLError)
    case serverError(statusCode: Int, data: Data)
    case circuitBreakerOpen
    case rateLimitExceeded
    case cachingError(Error)
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
             (.unknown, .unknown):
            return true
        default:
            return false
        }
    }
}
