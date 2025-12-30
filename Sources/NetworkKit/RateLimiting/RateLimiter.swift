import Foundation


/**
 * A protocol for implementing rate limiting functionality.
 * 
 * RateLimiter controls the frequency of network requests to prevent
 * overwhelming servers and to comply with API rate limits. It provides
 * methods to check if requests should be allowed and to record request
 * activity.
 * 
 * ## Usage
 * ```swift
 * let rateLimiter = TokenBucketRateLimiter(
 *     config: RateLimitConfig(
 *         maxRequests: 100,
 *         timeWindow: 60
 *     )
 * )
 * 
 * if rateLimiter.shouldAllowRequest(for: endpoint) {
 *     // Make the request
 *     rateLimiter.recordRequest(for: endpoint)
 * } else {
 *     // Handle rate limit exceeded
 * }
 * ```
 */
public protocol RateLimiter {
    /**
     * Determines if a request should be allowed based on current rate limits.
     * 
     * - Parameter endpoint: The endpoint for which to check rate limits
     * - Returns: `true` if the request should be allowed, `false` if rate limited
     */
    func shouldAllowRequest(for endpoint: any Endpoint) -> Bool
    
    /**
     * Records that a request was made for rate limiting purposes.
     * 
     * This method updates the rate limiter's internal state to track
     * request frequency and maintain rate limits.
     * 
     * - Parameter endpoint: The endpoint for which the request was made
     */
    func recordRequest(for endpoint: any Endpoint)
    
    /**
     * Resets the rate limiter's internal state.
     * 
     * This method clears all request history and resets the rate limiter
     * to its initial state. Useful for testing or manual rate limit resets.
     */
    func reset()
}

/**
 * Configuration for rate limiting behavior.
 * 
 * RateLimitConfig defines the parameters that control how rate limiting
 * operates, including request limits, time windows, and burst allowances.
 */
public struct RateLimitConfig {
    /// Maximum number of requests allowed in the time window
    public let maxRequests: Int
    
    /// Time window in seconds for rate limiting
    public let timeWindow: TimeInterval
    
    /// Maximum burst size for token bucket algorithms
    public let burstSize: Int
    
    /**
     * Creates a new RateLimitConfig.
     * 
     * - Parameters:
     *   - maxRequests: Maximum requests allowed in the time window
     *   - timeWindow: Time window in seconds
     *   - burstSize: Maximum burst size. Defaults to maxRequests if not specified.
     */
    public init(maxRequests: Int, timeWindow: TimeInterval, burstSize: Int? = nil) {
        self.maxRequests = maxRequests
        self.timeWindow = timeWindow
        self.burstSize = burstSize ?? maxRequests
    }
}

public final class TokenBucketRateLimiter: RateLimiter, @unchecked Sendable {
    private let config: RateLimitConfig
    private let queue = DispatchQueue(label: "com.network.ratelimiter", attributes: .concurrent)
    private var tokens: Double
    private var lastRefillTime: Date
    
    public init(config: RateLimitConfig) {
        self.config = config
        self.tokens = Double(config.burstSize)
        self.lastRefillTime = Date()
    }
    
    public func shouldAllowRequest(for endpoint: any Endpoint) -> Bool {
        return queue.sync {
            refillTokens()
            return tokens >= 1.0
        }
    }
    
    public func recordRequest(for endpoint: any Endpoint) {
        queue.async(flags: .barrier) {
            self.refillTokens()
            self.tokens = max(0, self.tokens - 1.0)
        }
    }
    
    public func reset() {
        queue.async(flags: .barrier) {
            self.tokens = Double(self.config.burstSize)
            self.lastRefillTime = Date()
        }
    }
    
    private func refillTokens() {
        let now = Date()
        let timePassed = now.timeIntervalSince(lastRefillTime)
        let tokensToAdd = timePassed * Double(config.maxRequests) / config.timeWindow
        
        tokens = min(Double(config.burstSize), tokens + tokensToAdd)
        lastRefillTime = now
    }
}

public final class SlidingWindowRateLimiter: RateLimiter, @unchecked Sendable {
    private let config: RateLimitConfig
    private let queue = DispatchQueue(label: "com.network.ratelimiter", attributes: .concurrent)
    private var requestTimestamps: [Date] = []
    
    public init(config: RateLimitConfig) {
        self.config = config
    }
    
    public func shouldAllowRequest(for endpoint: any Endpoint) -> Bool {
        return queue.sync {
            cleanupOldRequests()
            return requestTimestamps.count < config.maxRequests
        }
    }
    
    public func recordRequest(for endpoint: any Endpoint) {
        queue.async(flags: .barrier) {
            self.cleanupOldRequests()
            self.requestTimestamps.append(Date())
        }
    }
    
    public func reset() {
        queue.async(flags: .barrier) {
            self.requestTimestamps.removeAll()
        }
    }
    
    private func cleanupOldRequests() {
        let cutoffTime = Date().addingTimeInterval(-config.timeWindow)
        requestTimestamps = requestTimestamps.filter { $0 > cutoffTime }
    }
}

public final class EndpointSpecificRateLimiter: RateLimiter, @unchecked Sendable {
    private let defaultConfig: RateLimitConfig
    private let endpointConfigs: [String: RateLimitConfig]
    private let limiters: [String: RateLimiter]
    private let queue = DispatchQueue(label: "com.network.ratelimiter", attributes: .concurrent)
    
    public init(defaultConfig: RateLimitConfig, endpointConfigs: [String: RateLimitConfig] = [:]) {
        self.defaultConfig = defaultConfig
        self.endpointConfigs = endpointConfigs
        
        var limiters: [String: RateLimiter] = [:]
        for (endpoint, config) in endpointConfigs {
            limiters[endpoint] = TokenBucketRateLimiter(config: config)
        }
        self.limiters = limiters
    }
    
    public func shouldAllowRequest(for endpoint: any Endpoint) -> Bool {
        let endpointKey = generateEndpointKey(endpoint)
        
        // Extract endpoint info before entering the sync closure
        let baseURL = endpoint.baseURL
        let path = endpoint.path
        let method = endpoint.method
        
        return queue.sync {
            if let limiter = limiters[endpointKey] {
                // Create HTTPEndpoint with extracted values for thread-safe access
                let httpEndpoint = HTTPEndpoint(
                    baseURL: baseURL,
                    path: path,
                    method: method
                )
                return limiter.shouldAllowRequest(for: httpEndpoint)
            } else {
                // Use default limiter
                return true // For now, allow by default
            }
        }
    }
    
    public func recordRequest(for endpoint: any Endpoint) {
        let endpointKey = generateEndpointKey(endpoint)
        
        // Extract endpoint info before entering the async closure
        let baseURL = endpoint.baseURL
        let path = endpoint.path
        let method = endpoint.method
        
        queue.async(flags: .barrier) {
            if let limiter = self.limiters[endpointKey] {
                // Create HTTPEndpoint with extracted values for thread-safe access
                let httpEndpoint = HTTPEndpoint(
                    baseURL: baseURL,
                    path: path,
                    method: method
                )
                limiter.recordRequest(for: httpEndpoint)
            }
        }
    }
    
    public func reset() {
        queue.async(flags: .barrier) {
            for limiter in self.limiters.values {
                limiter.reset()
            }
        }
    }
    
    private func generateEndpointKey(_ endpoint: any Endpoint) -> String {
        return "\(endpoint.baseURL.host ?? "")-\(endpoint.path)-\(endpoint.method.rawValue)"
    }
}

public class RateLimitingPlugin: NetworkPlugin {
    private let rateLimiter: RateLimiter
    
    public init(rateLimiter: RateLimiter) {
        self.rateLimiter = rateLimiter
    }
    
    public func willSend(_ request: URLRequest, target: any Endpoint) {
        // Rate limiting is handled before the request is sent
    }
    
    public func didReceive(_ result: Result<(Data, URLResponse), Error>, target: any Endpoint) {
        // Record the request for rate limiting purposes
        rateLimiter.recordRequest(for: target)
    }
}
