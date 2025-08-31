import Foundation

/**
 * Convenience extensions for creating common HTTP headers.
 * 
 * These factory methods provide a clean, readable way to create
 * frequently used HTTP headers without manually specifying field names.
 */
public extension Http.Header {
    /**
     * Creates a Content-Type header.
     * 
     * - Parameter type: The MIME type (e.g., "application/json")
     * - Returns: A Content-Type header
     */
    static func contentType(_ type: String) -> Self {
        .init(field: "Content-Type", value: type)
    }
    
    /**
     * Creates an Accept header.
     * 
     * - Parameter type: The accepted MIME type (e.g., "application/json")
     * - Returns: An Accept header
     */
    static func accept(_ type: String) -> Self {
        .init(field: "Accept", value: type)
    }
    
    /**
     * Creates an Authorization header with Bearer token.
     * 
     * - Parameter token: The authentication token
     * - Returns: An Authorization header with "Bearer" prefix
     */
    static func authorization(_ token: String) -> Self {
        .init(field: "Authorization", value: "Bearer \(token)")
    }
    
    /**
     * Creates a User-Agent header.
     * 
     * - Parameter agent: The user agent string
     * - Returns: A User-Agent header
     */
    static func userAgent(_ agent: String) -> Self {
        .init(field: "User-Agent", value: agent)
    }
    
    /**
     * Predefined Content-Type header for JSON.
     * 
     * Equivalent to `contentType("application/json")`
     */
    static var json: Self {
        .contentType("application/json")
    }
    
    /**
     * Predefined Content-Type header for form URL encoding.
     * 
     * Equivalent to `contentType("application/x-www-form-urlencoded")`
     */
    static var formURLEncoded: Self {
        .contentType("application/x-www-form-urlencoded")
    }
}
