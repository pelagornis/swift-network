import Foundation

/**
 * A protocol that defines the structure of a network endpoint.
 * 
 * The `Endpoint` protocol provides a type-safe, declarative way to specify all aspects
 * of a network request including the URL, method, headers, and request body.
 * 
 * ## Usage
 * ```swift
 * struct UserEndpoint: Endpoint {
 *     let baseURL = URL(string: "https://api.example.com")!
 *     let path = "/users"
 *     let method = Http.Method.get
 *     let task = Http.Task.requestPlain
 *     let headers = [Http.Header.accept("application/json")]
 *     let timeout: TimeInterval? = 30
 * }
 * ```
 * 
 * ## Required Properties
 * - `baseURL`: The base URL of the API
 * - `path`: The specific endpoint path
 * - `method`: The HTTP method to use
 * - `task`: The request task (body, parameters, etc.)
 * 
 * ## Optional Properties
 * - `headers`: Additional HTTP headers
 * - `sampleData`: Sample data for testing/stubbing
 * - `timeout`: Custom timeout for this endpoint
 */
public protocol Endpoint {
    /// The base URL of the API (e.g., "https://api.example.com")
    var baseURL: URL { get }
    
    /// The specific endpoint path (e.g., "/users" or "/users/{id}")
    var path: String { get }
    
    /// The HTTP method to use for this request
    var method: Http.Method { get }
    
    /// The request task defining the body, parameters, or other request data
    var task: Http.Task { get }
    
    /// Additional HTTP headers to include with the request
    var headers: [Http.Header] { get }
    
    /// Sample data for testing or stubbing purposes
    var sampleData: Data? { get }
    
    /// Custom timeout for this specific endpoint
    var timeout: TimeInterval? { get }
}

/**
 * Default implementations for optional Endpoint properties.
 * 
 * These defaults allow you to create endpoints with minimal configuration
 * while still having access to all optional features when needed.
 */
public extension Endpoint {
    /// Default empty headers array
    var headers: [Http.Header] {
        []
    }
    
    /// Default nil sample data
    var sampleData: Data? {
        nil
    }
    
    /// Default nil timeout (uses session default)
    var timeout: TimeInterval? {
        nil
    }
}
