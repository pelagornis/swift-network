import Foundation

/**
 * A comprehensive network provider that orchestrates network requests with enterprise-grade features.
 * 
 * The NetworkProvider manages the entire request lifecycle including:
 * - Request building and execution
 * - Plugin processing (logging, authentication, etc.)
 * - Response handling and error management
 * - Enterprise features (retry policies, circuit breakers, caching, etc.)
 * 
 * ## Usage
 * ```swift
 * let provider = NetworkProvider<UserEndpoint>()
 * let users: [User] = try await provider.request(UserEndpoint(), as: [User].self)
 * ```
 * 
 * ## Enterprise Features
 * - **Retry Policies**: Automatic retry with configurable strategies
 * - **Circuit Breakers**: Fault tolerance with failure detection
 * - **Rate Limiting**: Request throttling and rate control
 * - **Caching**: Memory-based response caching
 * - **Security**: Certificate pinning and SSL validation
 * - **Metrics**: Comprehensive request/response monitoring
 */
public final class NetworkProvider<E: Endpoint> {
    /// The underlying session used for network requests
    private let session: Session
    
    /// Array of plugins that can intercept and modify requests/responses
    private let plugins: [NetworkPlugin]
    
    /// Handler responsible for processing response data
    private let responseHandler: ResponseHandler
    
    /// Whether stub mode is enabled for testing
    private let stubEnabled: Bool
    
    // MARK: - Enterprise Features (Optional)
    
    /// Retry policy for automatic request retries
    private let retryPolicy: RetryPolicy?
    
    /// Metrics collector for monitoring network performance
    private let metricsCollector: NetworkMetricsCollector?
    
    /// Security manager for certificate pinning and SSL validation
    private let securityManager: SecurityManager?
    
    /// Rate limiter for controlling request frequency
    private let rateLimiter: RateLimiter?
    
    /// Circuit breaker for fault tolerance
    private let circuitBreaker: CircuitBreaker?
    
    /// Cache manager for response caching
    private let cacheManager: CacheManager?
    
    /**
     * Initializes a new NetworkProvider with the specified configuration.
     * 
     * - Parameters:
     *   - session: The session to use for network requests. Defaults to `URLSession.shared`.
     *   - plugins: Array of plugins to apply to requests/responses. Defaults to empty array.
     *   - responseHandler: Handler for processing response data. Defaults to `DefaultResponseHandler`.
     *   - stubEnabled: Whether to enable stub mode for testing. Defaults to `false`.
     *   - retryPolicy: Policy for automatic request retries. Defaults to `nil`.
     *   - metricsCollector: Collector for network metrics. Defaults to `nil`.
     *   - securityManager: Manager for security features. Defaults to `nil`.
     *   - rateLimiter: Limiter for request rate control. Defaults to `nil`.
     *   - circuitBreaker: Circuit breaker for fault tolerance. Defaults to `nil`.
     *   - cacheManager: Manager for response caching. Defaults to `nil`.
     */
    public init(session: Session = URLSession.shared,
                plugins: [NetworkPlugin] = [],
                responseHandler: ResponseHandler = DefaultResponseHandler(),
                stubEnabled: Bool = false,
                // Enterprise features
                retryPolicy: RetryPolicy? = nil,
                metricsCollector: NetworkMetricsCollector? = nil,
                securityManager: SecurityManager? = nil,
                rateLimiter: RateLimiter? = nil,
                circuitBreaker: CircuitBreaker? = nil,
                cacheManager: CacheManager? = nil) {
        self.session = session
        self.plugins = plugins
        self.responseHandler = responseHandler
        self.stubEnabled = stubEnabled
        self.retryPolicy = retryPolicy
        self.metricsCollector = metricsCollector
        self.securityManager = securityManager
        self.rateLimiter = rateLimiter
        self.circuitBreaker = circuitBreaker
        self.cacheManager = cacheManager
    }
    
    /**
     * Performs a network request and decodes the response to the specified type.
     * 
     * This is the main method for making network requests. It handles the entire request lifecycle
     * including caching, retry logic, circuit breaker checks, and plugin processing.
     * 
     * - Parameters:
     *   - endpoint: The endpoint defining the request details
     *   - type: The type to decode the response into
     * - Returns: The decoded response data
     * - Throws: `NetworkError` if the request fails
     */
    public func request<T: Decodable>(_ endpoint: E, as type: T.Type) async throws -> T {
        return try await request(endpoint, as: type, modifiers: [])
    }
    
    /**
     * Performs a network request with additional request modifiers.
     * 
     * - Parameters:
     *   - endpoint: The endpoint defining the request details
     *   - type: The type to decode the response into
     *   - modifiers: Additional modifiers to apply to the request
     * - Returns: The decoded response data
     * - Throws: `NetworkError` if the request fails
     */
    public func request<T: Decodable>(_ endpoint: E, as type: T.Type, modifiers: [RequestModifier] = []) async throws -> T {
        // Check circuit breaker
        if let circuitBreaker = circuitBreaker, !circuitBreaker.shouldAllowRequest() {
            throw NetworkError.circuitBreakerOpen
        }
        
        // Check rate limiting
        if let rateLimiter = rateLimiter, !rateLimiter.shouldAllowRequest(for: endpoint) {
            throw NetworkError.rateLimitExceeded
        }
        
        // Check cache first
        if let cacheManager = cacheManager {
            let cacheKey = generateCacheKey(for: endpoint)
            if let cachedData: Data = cacheManager.get(for: cacheKey, as: Data.self) {
                do {
                    // Decode the cached JSON data
                    let decoder = JSONDecoder()
                    let cachedResult = try decoder.decode(T.self, from: cachedData)
                    
                    metricsCollector?.recordCacheHit(for: cacheKey)
                    return cachedResult
                } catch {
                    // If decoding fails, remove the invalid cache entry
                    cacheManager.remove(for: cacheKey)
                    // Notify plugins about cache decoding error
                    let cacheError = NetworkError.cachingError(error)
                    plugins.forEach { $0.didReceive(.failure(cacheError), target: endpoint) }
                }
            }
            metricsCollector?.recordCacheMiss(for: cacheKey)
        }
        
        var attempt = 0
        var lastError: Error?
        
        repeat {
            attempt += 1
            
            do {
                let result = try await performRequest(endpoint, as: type, modifiers: modifiers, attempt: attempt)
                
                // Record success
                circuitBreaker?.recordSuccess()
                rateLimiter?.recordRequest(for: endpoint)
                
                // Cache the result
                if let cacheManager = cacheManager {
                    let cacheKey = generateCacheKey(for: endpoint)
                    // Only cache if T conforms to Encodable
                    if let encodableResult = result as? any Encodable {
                        do {
                            // Encode the result to JSON data
                            let encoder = JSONEncoder()
                            let jsonData = try encoder.encode(encodableResult)
                            
                            // Store the JSON data in cache
                            cacheManager.set(jsonData, for: cacheKey, expiration: getCacheExpiration(for: endpoint))
                        } catch {
                            // Log encoding error but don't fail the request
                            // Notify plugins about caching error
                            let cacheError = NetworkError.cachingError(error)
                            plugins.forEach { $0.didReceive(.failure(cacheError), target: endpoint) }
                        }
                    }
                }
                
                return result
                
            } catch {
                lastError = error
                
                // Record failure
                circuitBreaker?.recordFailure(error)
                rateLimiter?.recordRequest(for: endpoint)
                
                // Check if we should retry
                guard let retryPolicy = retryPolicy,
                      retryPolicy.shouldRetry(for: error, attempt: attempt, request: buildRequest(from: endpoint)) else {
                    throw error
                }
                
                // Wait before retrying
                if attempt < retryPolicy.maxAttempts() {
                    try await Task.sleep(nanoseconds: UInt64(retryPolicy.delay(for: attempt) * 1_000_000_000))
                }
            }
        } while attempt < (retryPolicy?.maxAttempts() ?? 1)
        
        throw lastError ?? NetworkError.unknown
    }
    
    /**
     * Performs the actual network request with all enterprise features.
     * 
     * This method handles the complete request lifecycle including:
     * - Request building with modifiers
     * - Metrics collection
     * - Plugin notifications
     * - Response handling and error processing
     * 
     * - Parameters:
     *   - endpoint: The endpoint to request
     *   - type: The type to decode the response into
     *   - modifiers: Additional request modifiers
     *   - attempt: The current attempt number (for retry logic)
     * - Returns: The decoded response data
     * - Throws: NetworkError if the request fails
     */
    private func performRequest<T: Decodable>(_ endpoint: E, as type: T.Type, modifiers: [RequestModifier], attempt: Int) async throws -> T {
        let startTime = Date()
        
        // Build request
        let builder = NetworkRequestBuilder(endpoint: endpoint)
        modifiers.forEach { builder.addModifier($0) }
        let builtRequest = try builder.build()
        
        // Record metrics
        metricsCollector?.recordRequest(builtRequest.urlRequest, startTime: startTime)
        
        // Notify plugins
        plugins.forEach { $0.willSend(builtRequest.urlRequest, target: endpoint) }
        
        do {
            let (data, response) = try await session.perform(builtRequest.urlRequest)
            
            let endTime = Date()
            metricsCollector?.recordResponse(response, endTime: endTime, error: nil)
            
            plugins.forEach { $0.didReceive(.success((data, response)), target: endpoint) }
            
            return try responseHandler.handle(data, response: response, as: type)
            
        } catch let urlError as URLError {
            let endTime = Date()
            metricsCollector?.recordResponse(URLResponse(), endTime: endTime, error: urlError)
            
            plugins.forEach { $0.didReceive(.failure(urlError), target: endpoint) }
            throw NetworkError.requestFailed(urlError)
        } catch let networkError as NetworkError {
            let endTime = Date()
            metricsCollector?.recordResponse(URLResponse(), endTime: endTime, error: networkError)
            
            plugins.forEach { $0.didReceive(.failure(networkError), target: endpoint) }
            throw networkError
        } catch {
            let endTime = Date()
            metricsCollector?.recordResponse(URLResponse(), endTime: endTime, error: error)
            
            plugins.forEach { $0.didReceive(.failure(error), target: endpoint) }
            throw NetworkError.decodingError(error)
        }
    }
    
    /**
     * Builds a simplified URLRequest for retry policy evaluation.
     * 
     * This method creates a basic URLRequest from an endpoint for use
     * in retry policy decisions. It's a simplified version that doesn't
     * include all the full request building logic.
     * 
     * - Parameter endpoint: The endpoint to build a request from
     * - Returns: A basic URLRequest
     */
    private func buildRequest(from endpoint: E) -> URLRequest {
        // Simplified request building for retry policy
        let url = endpoint.baseURL.appendingPathComponent(endpoint.path)
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        return request
    }
    
    /**
     * Generates a cache key for an endpoint.
     * 
     * Creates a unique cache key based on the endpoint's host, path, and method.
     * This ensures that different endpoints have different cache entries.
     * 
     * - Parameter endpoint: The endpoint to generate a cache key for
     * - Returns: A unique cache key string
     */
    private func generateCacheKey(for endpoint: E) -> String {
        return "\(endpoint.baseURL.host ?? "")-\(endpoint.path)-\(endpoint.method.rawValue)"
    }
    
    /**
     * Gets the cache expiration time for an endpoint.
     * 
     * Returns the cache expiration time in seconds. Currently returns a fixed
     * 5-minute expiration, but could be enhanced to support endpoint-specific
     * cache policies or HTTP cache control directives.
     * 
     * - Parameter endpoint: The endpoint to get cache expiration for
     * - Returns: Cache expiration time in seconds, or nil for no expiration
     */
    private func getCacheExpiration(for endpoint: E) -> TimeInterval? {
        // Default cache expiration of 5 minutes
        // In a real implementation, you might want to:
        // 1. Check HTTP headers for cache control directives
        // 2. Use endpoint-specific cache policies
        // 3. Implement different expiration times for different HTTP methods
        return 300 // 5 minutes
    }
    
    // MARK: - Enterprise Features API
    
    /**
     * Retrieves current network metrics.
     * 
     * Returns comprehensive network performance metrics including request counts,
     * response times, error rates, and cache performance statistics.
     * 
     * - Returns: Current network metrics, or nil if metrics collection is not enabled
     */
    public func getMetrics() -> NetworkMetrics? {
        return (metricsCollector as? DefaultMetricsCollector)?.getMetrics()
    }
    
    /**
     * Resets all network metrics to zero.
     * 
     * Clears all collected metrics and starts fresh collection.
     * Useful for testing or when you want to reset performance tracking.
     */
    public func resetMetrics() {
        (metricsCollector as? DefaultMetricsCollector)?.reset()
    }
    
    /**
     * Gets the current state of the circuit breaker.
     * 
     * Returns the current state (closed, open, or half-open) of the circuit breaker
     * if one is configured for this provider.
     * 
     * - Returns: Current circuit breaker state, or nil if circuit breaker is not configured
     */
    public func getCircuitBreakerState() -> CircuitBreakerState? {
        return circuitBreaker?.getState()
    }
    
    /**
     * Manually resets the circuit breaker to closed state.
     * 
     * Forces the circuit breaker back to normal operation, clearing all
     * failure counts and timers. Useful for testing or manual recovery.
     */
    public func resetCircuitBreaker() {
        circuitBreaker?.reset()
    }
    
    /**
     * Clears all cached data.
     * 
     * Removes all cached responses from the cache manager.
     * Useful for freeing memory or ensuring fresh data on next requests.
     */
    public func clearCache() {
        cacheManager?.clear()
    }
    
    /**
     * Adds certificate pinning for a specific domain.
     * 
     * Pins a certificate to a domain for additional security validation.
     * The certificate will be validated against pinned certificates for future requests.
     * 
     * - Parameters:
     *   - certificate: The certificate to pin
     *   - domain: The domain to pin the certificate for
     */
    public func addCertificatePinning(_ certificate: SecCertificate, for domain: String) {
        securityManager?.addCertificatePinning(certificate, for: domain)
    }
}
