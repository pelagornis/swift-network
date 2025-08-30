import Foundation

public final class NetworkProvider<E: Endpoint> {
    private let session: Session
    private let plugins: [NetworkPlugin]
    private let responseHandler: ResponseHandler
    private let stubEnabled: Bool
    
    // MARK: - Enterprise Features (Optional)
    private let retryPolicy: RetryPolicy?
    private let metricsCollector: NetworkMetricsCollector?
    private let securityManager: SecurityManager?
    private let rateLimiter: RateLimiter?
    private let circuitBreaker: CircuitBreaker?
    private let cacheManager: CacheManager?
    
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
    
    public func request<T: Decodable>(_ endpoint: E, as type: T.Type) async throws -> T {
        return try await request(endpoint, as: type, modifiers: [])
    }
    
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
    
    private func buildRequest(from endpoint: E) -> URLRequest {
        // Simplified request building for retry policy
        let url = endpoint.baseURL.appendingPathComponent(endpoint.path)
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        return request
    }
    
    private func generateCacheKey(for endpoint: E) -> String {
        return "\(endpoint.baseURL.host ?? "")-\(endpoint.path)-\(endpoint.method.rawValue)"
    }
    
    private func getCacheExpiration(for endpoint: E) -> TimeInterval? {
        // Default cache expiration of 5 minutes
        // In a real implementation, you might want to:
        // 1. Check HTTP headers for cache control directives
        // 2. Use endpoint-specific cache policies
        // 3. Implement different expiration times for different HTTP methods
        return 300 // 5 minutes
    }
    
    // MARK: - Enterprise Features API
    
    public func getMetrics() -> NetworkMetrics? {
        return (metricsCollector as? DefaultMetricsCollector)?.getMetrics()
    }
    
    public func resetMetrics() {
        (metricsCollector as? DefaultMetricsCollector)?.reset()
    }
    
    public func getCircuitBreakerState() -> CircuitBreakerState? {
        return circuitBreaker?.getState()
    }
    
    public func resetCircuitBreaker() {
        circuitBreaker?.reset()
    }
    
    public func clearCache() {
        cacheManager?.clear()
    }
    
    public func addCertificatePinning(_ certificate: SecCertificate, for domain: String) {
        securityManager?.addCertificatePinning(certificate, for: domain)
    }
}
