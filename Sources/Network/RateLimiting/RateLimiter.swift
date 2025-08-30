import Foundation

// MARK: - Simple Endpoint for Sendable Closures
private struct SimpleEndpoint: Endpoint, @unchecked Sendable {
    let baseURL: URL
    let path: String
    let method: Http.Method
    let task: Http.Task = .requestPlain
    let headers: [Http.Header] = []
    let timeout: TimeInterval? = nil
}

public protocol RateLimiter {
    func shouldAllowRequest(for endpoint: Endpoint) -> Bool
    func recordRequest(for endpoint: Endpoint)
    func reset()
}

public struct RateLimitConfig {
    public let maxRequests: Int
    public let timeWindow: TimeInterval
    public let burstSize: Int
    
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
    
    public func shouldAllowRequest(for endpoint: Endpoint) -> Bool {
        return queue.sync {
            refillTokens()
            return tokens >= 1.0
        }
    }
    
    public func recordRequest(for endpoint: Endpoint) {
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
    
    public func shouldAllowRequest(for endpoint: Endpoint) -> Bool {
        return queue.sync {
            cleanupOldRequests()
            return requestTimestamps.count < config.maxRequests
        }
    }
    
    public func recordRequest(for endpoint: Endpoint) {
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
    
    public func shouldAllowRequest(for endpoint: Endpoint) -> Bool {
        let endpointKey = generateEndpointKey(endpoint)
        
        // Extract endpoint info before entering the sync closure
        let baseURL = endpoint.baseURL
        let path = endpoint.path
        let method = endpoint.method
        
        return queue.sync {
            if let limiter = limiters[endpointKey] {
                // Create a simple endpoint-like object with extracted values
                let simpleEndpoint = SimpleEndpoint(baseURL: baseURL, path: path, method: method)
                return limiter.shouldAllowRequest(for: simpleEndpoint)
            } else {
                // Use default limiter
                return true // For now, allow by default
            }
        }
    }
    
    public func recordRequest(for endpoint: Endpoint) {
        let endpointKey = generateEndpointKey(endpoint)
        
        // Extract endpoint info before entering the async closure
        let baseURL = endpoint.baseURL
        let path = endpoint.path
        let method = endpoint.method
        
        queue.async(flags: .barrier) {
            if let limiter = self.limiters[endpointKey] {
                // Create a simple endpoint-like object with extracted values
                let simpleEndpoint = SimpleEndpoint(baseURL: baseURL, path: path, method: method)
                limiter.recordRequest(for: simpleEndpoint)
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
    
    private func generateEndpointKey(_ endpoint: Endpoint) -> String {
        return "\(endpoint.baseURL.host ?? "")-\(endpoint.path)-\(endpoint.method.rawValue)"
    }
}

public class RateLimitingPlugin: NetworkPlugin {
    private let rateLimiter: RateLimiter
    
    public init(rateLimiter: RateLimiter) {
        self.rateLimiter = rateLimiter
    }
    
    public func willSend(_ request: URLRequest, target: Endpoint) {
        // Rate limiting is handled before the request is sent
    }
    
    public func didReceive(_ result: Result<(Data, URLResponse), Error>, target: Endpoint) {
        // Record the request for rate limiting purposes
        rateLimiter.recordRequest(for: target)
    }
}
