import Foundation

/**
 * A protocol for collecting network performance metrics.
 * 
 * NetworkMetricsCollector allows you to track various network performance
 * indicators including request counts, response times, error rates, cache
 * performance, and retry statistics.
 * 
 * ## Usage
 * ```swift
 * let metricsCollector = DefaultMetricsCollector()
 * 
 * let provider = NetworkProvider<UserEndpoint>(
 *     metricsCollector: metricsCollector
 * )
 * 
 * // Later, get metrics
 * let metrics = metricsCollector.getMetrics()
 * print("Average response time: \(metrics.averageResponseTime)s")
 * ```
 */
public protocol NetworkMetricsCollector {
    /**
     * Records the start of a network request.
     * 
     * - Parameters:
     *   - request: The request being made
     *   - startTime: The time when the request started
     */
    func recordRequest(_ request: URLRequest, startTime: Date)
    
    /**
     * Records the completion of a network response.
     * 
     * - Parameters:
     *   - response: The response received
     *   - endTime: The time when the response completed
     *   - error: Any error that occurred, or nil if successful
     */
    func recordResponse(_ response: URLResponse, endTime: Date, error: Error?)
    
    /**
     * Records a retry attempt.
     * 
     * - Parameters:
     *   - attempt: The retry attempt number
     *   - error: The error that caused the retry
     */
    func recordRetry(attempt: Int, error: Error)
    
    /**
     * Records a cache hit.
     * 
     * - Parameter key: The cache key that was hit
     */
    func recordCacheHit(for key: String)
    
    /**
     * Records a cache miss.
     * 
     * - Parameter key: The cache key that was missed
     */
    func recordCacheMiss(for key: String)
}

/**
 * A collection of network performance metrics.
 * 
 * NetworkMetrics provides a comprehensive view of network performance
 * including request statistics, timing information, cache performance,
 * and error analysis.
 */
public struct NetworkMetrics {
    /// Total number of requests made
    public let requestCount: Int
    
    /// Number of successful requests
    public let successCount: Int
    
    /// Number of failed requests
    public let failureCount: Int
    
    /// Average response time in seconds
    public let averageResponseTime: TimeInterval
    
    /// Total bytes transferred
    public let totalBytesTransferred: Int64
    
    /// Cache hit rate as a percentage (0.0 to 1.0)
    public let cacheHitRate: Double
    
    /// Total number of retry attempts
    public let retryCount: Int
    
    /// Distribution of errors by error type
    public let errorDistribution: [String: Int]
    
    /**
     * Creates a new NetworkMetrics instance.
     * 
     * - Parameters:
     *   - requestCount: Total number of requests. Defaults to 0.
     *   - successCount: Number of successful requests. Defaults to 0.
     *   - failureCount: Number of failed requests. Defaults to 0.
     *   - averageResponseTime: Average response time in seconds. Defaults to 0.
     *   - totalBytesTransferred: Total bytes transferred. Defaults to 0.
     *   - cacheHitRate: Cache hit rate (0.0 to 1.0). Defaults to 0.
     *   - retryCount: Total retry attempts. Defaults to 0.
     *   - errorDistribution: Error distribution by type. Defaults to empty dictionary.
     */
    public init(
        requestCount: Int = 0,
        successCount: Int = 0,
        failureCount: Int = 0,
        averageResponseTime: TimeInterval = 0,
        totalBytesTransferred: Int64 = 0,
        cacheHitRate: Double = 0,
        retryCount: Int = 0,
        errorDistribution: [String: Int] = [:]
    ) {
        self.requestCount = requestCount
        self.successCount = successCount
        self.failureCount = failureCount
        self.averageResponseTime = averageResponseTime
        self.totalBytesTransferred = totalBytesTransferred
        self.cacheHitRate = cacheHitRate
        self.retryCount = retryCount
        self.errorDistribution = errorDistribution
    }
}

public final class DefaultMetricsCollector: NetworkMetricsCollector, @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.network.metrics", attributes: .concurrent)
    private var metrics = NetworkMetrics()
    private var requestStartTimes: [String: Date] = [:]
    private var cacheHits = 0
    private var cacheMisses = 0
    
    public init() {}
    
    public func recordRequest(_ request: URLRequest, startTime: Date) {
        queue.async(flags: .barrier) {
            self.metrics = NetworkMetrics(
                requestCount: self.metrics.requestCount + 1,
                successCount: self.metrics.successCount,
                failureCount: self.metrics.failureCount,
                averageResponseTime: self.metrics.averageResponseTime,
                totalBytesTransferred: self.metrics.totalBytesTransferred,
                cacheHitRate: self.metrics.cacheHitRate,
                retryCount: self.metrics.retryCount,
                errorDistribution: self.metrics.errorDistribution
            )
            
            let requestId = self.generateRequestId(request)
            self.requestStartTimes[requestId] = startTime
        }
    }
    
    public func recordResponse(_ response: URLResponse, endTime: Date, error: Error?) {
        queue.async(flags: .barrier) {
            let requestId = self.generateRequestId(response.url?.absoluteString ?? "")
            guard let startTime = self.requestStartTimes.removeValue(forKey: requestId) else { return }
            
            let responseTime = endTime.timeIntervalSince(startTime)
            let totalRequests = self.metrics.successCount + self.metrics.failureCount
            let newAverageResponseTime = (self.metrics.averageResponseTime * Double(totalRequests) + responseTime) / Double(totalRequests + 1)
            
            let bytesTransferred = Int64(response.expectedContentLength)
            let newTotalBytes = self.metrics.totalBytesTransferred + bytesTransferred
            
            if error != nil {
                self.metrics = NetworkMetrics(
                    requestCount: self.metrics.requestCount,
                    successCount: self.metrics.successCount,
                    failureCount: self.metrics.failureCount + 1,
                    averageResponseTime: newAverageResponseTime,
                    totalBytesTransferred: newTotalBytes,
                    cacheHitRate: self.metrics.cacheHitRate,
                    retryCount: self.metrics.retryCount,
                    errorDistribution: self.updateErrorDistribution(error: error)
                )
            } else {
                self.metrics = NetworkMetrics(
                    requestCount: self.metrics.requestCount,
                    successCount: self.metrics.successCount + 1,
                    failureCount: self.metrics.failureCount,
                    averageResponseTime: newAverageResponseTime,
                    totalBytesTransferred: newTotalBytes,
                    cacheHitRate: self.metrics.cacheHitRate,
                    retryCount: self.metrics.retryCount,
                    errorDistribution: self.metrics.errorDistribution
                )
            }
        }
    }
    
    public func recordRetry(attempt: Int, error: Error) {
        queue.async(flags: .barrier) {
            self.metrics = NetworkMetrics(
                requestCount: self.metrics.requestCount,
                successCount: self.metrics.successCount,
                failureCount: self.metrics.failureCount,
                averageResponseTime: self.metrics.averageResponseTime,
                totalBytesTransferred: self.metrics.totalBytesTransferred,
                cacheHitRate: self.metrics.cacheHitRate,
                retryCount: self.metrics.retryCount + 1,
                errorDistribution: self.metrics.errorDistribution
            )
        }
    }
    
    public func recordCacheHit(for key: String) {
        queue.async(flags: .barrier) {
            self.cacheHits += 1
            let totalCacheAccess = self.cacheHits + self.cacheMisses
            let newCacheHitRate = totalCacheAccess > 0 ? Double(self.cacheHits) / Double(totalCacheAccess) : 0
            
            self.metrics = NetworkMetrics(
                requestCount: self.metrics.requestCount,
                successCount: self.metrics.successCount,
                failureCount: self.metrics.failureCount,
                averageResponseTime: self.metrics.averageResponseTime,
                totalBytesTransferred: self.metrics.totalBytesTransferred,
                cacheHitRate: newCacheHitRate,
                retryCount: self.metrics.retryCount,
                errorDistribution: self.metrics.errorDistribution
            )
        }
    }
    
    public func recordCacheMiss(for key: String) {
        queue.async(flags: .barrier) {
            self.cacheMisses += 1
            let totalCacheAccess = self.cacheHits + self.cacheMisses
            let newCacheHitRate = totalCacheAccess > 0 ? Double(self.cacheHits) / Double(totalCacheAccess) : 0
            
            self.metrics = NetworkMetrics(
                requestCount: self.metrics.requestCount,
                successCount: self.metrics.successCount,
                failureCount: self.metrics.failureCount,
                averageResponseTime: self.metrics.averageResponseTime,
                totalBytesTransferred: self.metrics.totalBytesTransferred,
                cacheHitRate: newCacheHitRate,
                retryCount: self.metrics.retryCount,
                errorDistribution: self.metrics.errorDistribution
            )
        }
    }
    
    /**
     * Retrieves the current network metrics.
     * 
     * Returns a snapshot of all collected metrics including request counts,
     * response times, error rates, and cache performance.
     * 
     * - Returns: Current network metrics
     */
    public func getMetrics() -> NetworkMetrics {
        return queue.sync { metrics }
    }
    
    /**
     * Resets all metrics to their initial state.
     * 
     * Clears all collected metrics, request start times, and cache statistics.
     * Useful for testing or when you want to start fresh metrics collection.
     */
    public func reset() {
        queue.async(flags: .barrier) {
            self.metrics = NetworkMetrics()
            self.requestStartTimes.removeAll()
            self.cacheHits = 0
            self.cacheMisses = 0
        }
    }
    
    /**
     * Generates a unique request identifier from a URLRequest.
     * 
     * Creates a unique identifier based on the request URL and HTTP method.
     * This is used to track request timing and correlate requests with responses.
     * 
     * - Parameter request: The URLRequest to generate an ID for
     * - Returns: A unique request identifier string
     */
    private func generateRequestId(_ request: URLRequest) -> String {
        return "\(request.url?.absoluteString ?? "")-\(request.httpMethod ?? "")"
    }
    
    /**
     * Generates a request identifier from a URL string.
     * 
     * Creates a request identifier from a URL string for response tracking.
     * 
     * - Parameter urlString: The URL string to generate an ID for
     * - Returns: A request identifier string
     */
    private func generateRequestId(_ urlString: String) -> String {
        return urlString
    }
    
    /**
     * Updates the error distribution with a new error.
     * 
     * Increments the count for the given error type in the error distribution.
     * This helps track which types of errors occur most frequently.
     * 
     * - Parameter error: The error to record, or nil for unknown errors
     * - Returns: Updated error distribution dictionary
     */
    private func updateErrorDistribution(error: Error?) -> [String: Int] {
        var distribution = metrics.errorDistribution
        let errorKey = error?.localizedDescription ?? "Unknown"
        distribution[errorKey, default: 0] += 1
        return distribution
    }
}
