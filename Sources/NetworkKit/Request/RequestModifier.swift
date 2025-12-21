import Foundation

/**
 * A protocol for modifying network requests during the building process.
 * 
 * RequestModifier allows you to apply custom modifications to requests
 * such as adding headers, setting timeouts, or changing cache policies.
 * Multiple modifiers can be applied to a single request.
 * 
 * ## Usage
 * ```swift
 * let modifier = HeaderModifier(headers: ["Authorization": "Bearer token"])
 * let request = try builder.addModifier(modifier).build()
 * ```
 */
public protocol RequestModifier {
    /**
     * Modifies a request and returns the modified version.
     * 
     * - Parameter request: The request to modify
     * - Returns: The modified request
     * - Throws: `NetworkError` if modification fails
     */
    func modify(_ request: BuiltRequest) throws -> BuiltRequest
}

/**
 * A modifier that adds or updates HTTP headers on a request.
 * 
 * HeaderModifier merges new headers with existing ones, with new headers
 * taking precedence over existing ones with the same name.
 * 
 * ## Usage
 * ```swift
 * let modifier = HeaderModifier(headers: [
 *     "Authorization": "Bearer token",
 *     "X-Custom-Header": "value"
 * ])
 * ```
 */
public class HeaderModifier: RequestModifier {
    /// The headers to add to the request
    private let headers: [String: String]
    
    /**
     * Creates a new HeaderModifier.
     * 
     * - Parameter headers: Dictionary of header field names to values
     */
    public init(headers: [String: String]) {
        self.headers = headers
    }
    
    public func modify(_ request: BuiltRequest) throws -> BuiltRequest {
        var urlRequest = request.urlRequest
        var currentHeaders = urlRequest.allHTTPHeaderFields ?? [:]
        currentHeaders.merge(headers) { _, new in new }
        urlRequest.allHTTPHeaderFields = currentHeaders
        return BuiltRequest(urlRequest: urlRequest, downloadDestination: request.downloadDestination)
    }
}

/**
 * A modifier that sets a custom timeout for a request.
 * 
 * TimeoutModifier overrides the default timeout for a specific request.
 * This is useful when you need different timeout values for different
 * types of requests.
 * 
 * ## Usage
 * ```swift
 * let modifier = TimeoutModifier(timeout: 60) // 60 seconds
 * ```
 */
public class TimeoutModifier: RequestModifier {
    /// The timeout value in seconds
    private let timeout: TimeInterval
    
    /**
     * Creates a new TimeoutModifier.
     * 
     * - Parameter timeout: The timeout value in seconds
     */
    public init(timeout: TimeInterval) {
        self.timeout = timeout
    }
    
    public func modify(_ request: BuiltRequest) throws -> BuiltRequest {
        var urlRequest = request.urlRequest
        urlRequest.timeoutInterval = timeout
        return BuiltRequest(urlRequest: urlRequest, downloadDestination: request.downloadDestination)
    }
}

/**
 * A modifier that sets a custom cache policy for a request.
 * 
 * CachePolicyModifier overrides the default cache policy for a specific request.
 * This allows fine-grained control over how requests are cached.
 * 
 * ## Usage
 * ```swift
 * let modifier = CachePolicyModifier(cachePolicy: .reloadIgnoringLocalCacheData)
 * ```
 */
public class CachePolicyModifier: RequestModifier {
    /// The cache policy to apply to the request
    private let cachePolicy: URLRequest.CachePolicy
    
    /**
     * Creates a new CachePolicyModifier.
     * 
     * - Parameter cachePolicy: The cache policy to apply
     */
    public init(cachePolicy: URLRequest.CachePolicy) {
        self.cachePolicy = cachePolicy
    }
    
    public func modify(_ request: BuiltRequest) throws -> BuiltRequest {
        var urlRequest = request.urlRequest
        urlRequest.cachePolicy = cachePolicy
        return BuiltRequest(urlRequest: urlRequest, downloadDestination: request.downloadDestination)
    }
}
