import Foundation

// MARK: - HTTP Endpoint

/**
 * HTTP endpoint implementation that stores actual request information.
 * 
 * This struct stores all the necessary information for making HTTP requests
 * and implements the Endpoint protocol. It serves as the terminal node in the
 * endpoint chain, providing direct access to stored properties.
 */
public struct HTTPEndpoint: Endpoint {
    /// The base URL of the API
    public var baseURL: URL
    
    /// The specific endpoint path
    public var path: String
    
    /// The HTTP method to use
    public var method: Http.Method
    
    /// The request task defining the body, parameters, or other request data
    public var task: Http.Task
    
    /// Additional HTTP headers
    public var headers: [Http.Header]
    
    /// Sample data for testing or stubbing purposes
    public var sampleData: Data?
    
    /// Custom timeout for this specific endpoint
    public var timeout: TimeInterval?
    
    public typealias Body = HTTPEndpoint
    
    public var body: HTTPEndpoint {
        self
    }
    
    public init(
        baseURL: URL = URL(string: "https://api.example.com")!,
        path: String = "/",
        method: Http.Method = .get,
        task: Http.Task = .requestPlain,
        headers: [Http.Header] = [],
        sampleData: Data? = nil,
        timeout: TimeInterval? = nil
    ) {
        self.baseURL = baseURL
        self.path = path
        self.method = method
        self.task = task
        self.headers = headers
        self.sampleData = sampleData
        self.timeout = timeout
    }
}

// MARK: - Environment

/**
 * Environment values that can be shared across endpoints.
 * Similar to SwiftUI's Environment, this allows common configuration
 * to be shared without repetition.
 */
public struct Environment {
    /// Base URL for the API
    public var baseURL: URL?
    
    /// Common headers to include in all requests
    public var headers: [Http.Header]
    
    /// Default timeout for requests
    public var timeout: TimeInterval?
    
    public init(
        baseURL: URL? = nil,
        headers: [Http.Header] = [],
        timeout: TimeInterval? = nil
    ) {
        self.baseURL = baseURL
        self.headers = headers
        self.timeout = timeout
    }
    
    /// Merges another environment into this one
    public func merging(_ other: Environment) -> Environment {
        Environment(
            baseURL: other.baseURL ?? self.baseURL,
            headers: self.headers + other.headers,
            timeout: other.timeout ?? self.timeout
        )
    }
}

// MARK: - HTTP DSL Components

/**
 * Protocol for HTTP DSL components used in the builder pattern.
 */
public protocol HTTPComponent {
    func apply(to endpoint: inout HTTPEndpoint, environment: inout Environment)
}

/**
 * Base URL component for HTTP DSL.
 */
public struct BaseURL: HTTPComponent {
    let url: URL
    
    public init(_ url: URL) {
        self.url = url
    }
    
    public init(_ string: String) {
        self.url = URL(string: string)!
    }
    
    public func apply(to endpoint: inout HTTPEndpoint, environment: inout Environment) {
        endpoint.baseURL = url
        environment.baseURL = url
    }
}

/**
 * Path component for HTTP DSL.
 */
public struct Path: HTTPComponent {
    let value: String
    
    public init(_ path: String) {
        self.value = path
    }
    
    public func apply(to endpoint: inout HTTPEndpoint, environment: inout Environment) {
        endpoint.path = value
    }
}

/**
 * Method component for HTTP DSL.
 */
public struct Method: HTTPComponent {
    let value: Http.Method
    
    public init(_ method: Http.Method) {
        self.value = method
    }
    
    public func apply(to endpoint: inout HTTPEndpoint, environment: inout Environment) {
        endpoint.method = value
    }
}

/**
 * Task component for HTTP DSL.
 */
public struct HTTPTask: HTTPComponent {
    let value: Http.Task
    
    public init(_ task: Http.Task) {
        self.value = task
    }
    
    public func apply(to endpoint: inout HTTPEndpoint, environment: inout Environment) {
        endpoint.task = value
    }
}

/**
 * Headers component for HTTP DSL.
 */
public struct Headers: HTTPComponent {
    let value: [Http.Header]
    
    public init(_ headers: [Http.Header]) {
        self.value = headers
    }
    
    public func apply(to endpoint: inout HTTPEndpoint, environment: inout Environment) {
        endpoint.headers = value
        environment.headers.append(contentsOf: value)
    }
}

/**
 * Timeout component for HTTP DSL.
 */
public struct Timeout: HTTPComponent {
    let value: TimeInterval
    
    public init(_ timeout: TimeInterval) {
        self.value = timeout
    }
    
    public func apply(to endpoint: inout HTTPEndpoint, environment: inout Environment) {
        endpoint.timeout = value
        environment.timeout = value
    }
}

// MARK: - HTTP Builder

/**
 * Result builder for creating HTTP endpoints using a declarative DSL.
 * 
 * This builder allows you to create endpoints in a SwiftUI-like style:
 * ```swift
 * HTTP {
 *     BaseURL("https://api.example.com")
 *     Path("/users")
 *     Method(.get)
 * }
 * ```
 */
@resultBuilder
public enum HTTPBuilder {
    // Thread-local storage for base endpoint
    private static let baseEndpointKey = "com.networkkit.httpbuilder.base"
    
    private static var baseEndpoint: HTTPEndpoint? {
        get {
            Thread.current.threadDictionary[baseEndpointKey] as? HTTPEndpoint
        }
        set {
            if let value = newValue {
                Thread.current.threadDictionary[baseEndpointKey] = value
            } else {
                Thread.current.threadDictionary.removeObject(forKey: baseEndpointKey)
            }
        }
    }
    
    static func setBase(_ base: HTTPEndpoint) {
        baseEndpoint = base
    }
    
    static func clearBase() {
        baseEndpoint = nil
    }
    
    public static func buildBlock(_ components: HTTPComponent...) -> HTTPEndpoint {
        // Start with base endpoint if available, otherwise use default
        var endpoint = baseEndpoint ?? HTTPEndpoint()
        var environment = Environment()
        
        // Clear base after use
        baseEndpoint = nil
        
        // Apply all components
        for component in components {
            component.apply(to: &endpoint, environment: &environment)
        }
        
        // Apply environment defaults if not set
        if let baseURL = environment.baseURL, endpoint.baseURL == URL(string: "https://api.example.com")! {
            endpoint.baseURL = baseURL
        }
        if !environment.headers.isEmpty && endpoint.headers.isEmpty {
            endpoint.headers = environment.headers
        }
        if let timeout = environment.timeout, endpoint.timeout == nil {
            endpoint.timeout = timeout
        }
        
        return endpoint
    }
    
    public static func buildBlock(_ component: HTTPComponent) -> HTTPEndpoint {
        var endpoint = baseEndpoint ?? HTTPEndpoint()
        var environment = Environment()
        baseEndpoint = nil
        component.apply(to: &endpoint, environment: &environment)
        
        // Apply environment defaults if not set
        if let baseURL = environment.baseURL, endpoint.baseURL == URL(string: "https://api.example.com")! {
            endpoint.baseURL = baseURL
        }
        if !environment.headers.isEmpty && endpoint.headers.isEmpty {
            endpoint.headers = environment.headers
        }
        if let timeout = environment.timeout, endpoint.timeout == nil {
            endpoint.timeout = timeout
        }
        
        return endpoint
    }
    
    public static func buildOptional(_ component: HTTPComponent?) -> HTTPEndpoint {
        var endpoint = baseEndpoint ?? HTTPEndpoint()
        var environment = Environment()
        baseEndpoint = nil
        component?.apply(to: &endpoint, environment: &environment)
        return endpoint
    }
    
    public static func buildEither(first component: HTTPComponent) -> HTTPEndpoint {
        var endpoint = baseEndpoint ?? HTTPEndpoint()
        var environment = Environment()
        baseEndpoint = nil
        component.apply(to: &endpoint, environment: &environment)
        return endpoint
    }
    
    public static func buildEither(second component: HTTPComponent) -> HTTPEndpoint {
        var endpoint = baseEndpoint ?? HTTPEndpoint()
        var environment = Environment()
        baseEndpoint = nil
        component.apply(to: &endpoint, environment: &environment)
        return endpoint
    }
}

/**
 * Creates an HTTP endpoint using the DSL builder.
 * 
 * ## Usage
 * ```swift
 * var body: some Endpoint {
 *     HTTP {
 *         BaseURL("https://api.example.com")
 *         Path("/users")
 *         Method(.get)
 *         HTTPTask(.requestPlain)
 *         Headers([.accept("application/json")])
 *     }
 * }
 * ```
 * 
 * ## With Base Endpoint (inherits common settings)
 * ```swift
 * let baseEndpoint = HTTP {
 *     BaseURL("https://api.example.com")
 *     Headers([.accept("application/json")])
 *     Timeout(30.0)
 * }
 * 
 * var body: some Endpoint {
 *     HTTP(base: baseEndpoint) {
 *         Path("/users")
 *         Method(.get)
 *     }
 * }
 * ```
 */
public func HTTP(@HTTPBuilder _ content: () -> HTTPEndpoint) -> HTTPEndpoint {
    return content()
}

/**
 * Creates an HTTP endpoint with a base endpoint that provides default values.
 * 
 * The base endpoint's values are used as defaults, and can be overridden by
 * components in the builder.
 */
public func HTTP(base: HTTPEndpoint, @HTTPBuilder _ content: () -> HTTPEndpoint) -> HTTPEndpoint {
    // Set base in thread-local storage for HTTPBuilder to use
    HTTPBuilder.setBase(base)
    defer { HTTPBuilder.clearBase() }
    
    // Build endpoint starting from base, applying only the components
    return content()
}

// MARK: - Endpoint Protocol

/**
 * A protocol that defines the structure of a network endpoint.
 * 
 * The `Endpoint` protocol provides a type-safe, declarative way to specify all aspects
 * of a network request including the URL, method, headers, and request body.
 * 
 * ## Usage
 * 
 * ### SwiftUI-Style DSL with body property
 * ```swift
 * enum UserEndpoint: Endpoint {
 *     case getUsers
 *     case getUser(id: Int)
 *     
 *     var body: HTTPEndpoint? {
 *         switch self {
 *         case .getUsers:
 *             return HTTP {
 *                 BaseURL("https://api.example.com")
 *                 Path("/users")
 *                 Method(.get)
 *             }
 *         case .getUser(let id):
 *             return HTTP {
 *                 BaseURL("https://api.example.com")
 *                 Path("/users/\(id)")
 *                 Method(.get)
 *             }
 *         }
 *     }
 * }
 * ```
 * 
 * All endpoint properties (`baseURL`, `path`, `method`, `task`, `headers`, `sampleData`, `timeout`)
 * are accessed through the `body` property, which should resolve to an `HTTPEndpoint`.
 */
public protocol Endpoint {
    associatedtype Body: Endpoint
    
    /// SwiftUI-style endpoint definition using DSL
    /// All endpoint information is accessed through this property
    /// The body should eventually resolve to an HTTPEndpoint
    var body: Self.Body { get }
}

/**
 * Extension providing access to endpoint properties through the body.
 * 
 * Properties are accessed recursively through the body property chain.
 * HTTPEndpoint serves as the terminal node - when body.baseURL is called on HTTPEndpoint,
 * it accesses the stored property directly, terminating the recursion.
 */
public extension Endpoint {
    /// The base URL of the API (accessed through body)
    var baseURL: URL {
        // For HTTPEndpoint, access stored property directly to avoid recursion
        if let httpEndpoint = self as? HTTPEndpoint {
            return httpEndpoint.baseURL
        }
        return body.baseURL
    }
    
    /// The specific endpoint path (accessed through body)
    var path: String {
        if let httpEndpoint = self as? HTTPEndpoint {
            return httpEndpoint.path
        }
        return body.path
    }
    
    /// The HTTP method to use for this request (accessed through body)
    var method: Http.Method {
        if let httpEndpoint = self as? HTTPEndpoint {
            return httpEndpoint.method
        }
        return body.method
    }
    
    /// The request task defining the body, parameters, or other request data (accessed through body)
    var task: Http.Task {
        if let httpEndpoint = self as? HTTPEndpoint {
            return httpEndpoint.task
        }
        return body.task
    }
    
    /// Additional HTTP headers to include with the request (accessed through body)
    var headers: [Http.Header] {
        if let httpEndpoint = self as? HTTPEndpoint {
            return httpEndpoint.headers
        }
        return body.headers
    }
    
    /// Sample data for testing or stubbing purposes (accessed through body)
    var sampleData: Data? {
        if let httpEndpoint = self as? HTTPEndpoint {
            return httpEndpoint.sampleData
        }
        return body.sampleData
    }
    
    /// Custom timeout for this specific endpoint (accessed through body)
    var timeout: TimeInterval? {
        if let httpEndpoint = self as? HTTPEndpoint {
            return httpEndpoint.timeout
        }
        return body.timeout
    }
}
