import Foundation

public protocol NetworkMetricsCollector {
    func recordRequest(_ request: URLRequest, startTime: Date)
    func recordResponse(_ response: URLResponse, endTime: Date, error: Error?)
    func recordRetry(attempt: Int, error: Error)
    func recordCacheHit(for key: String)
    func recordCacheMiss(for key: String)
}

public struct NetworkMetrics {
    public let requestCount: Int
    public let successCount: Int
    public let failureCount: Int
    public let averageResponseTime: TimeInterval
    public let totalBytesTransferred: Int64
    public let cacheHitRate: Double
    public let retryCount: Int
    public let errorDistribution: [String: Int]
    
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
    
    public func getMetrics() -> NetworkMetrics {
        return queue.sync { metrics }
    }
    
    public func reset() {
        queue.async(flags: .barrier) {
            self.metrics = NetworkMetrics()
            self.requestStartTimes.removeAll()
            self.cacheHits = 0
            self.cacheMisses = 0
        }
    }
    
    private func generateRequestId(_ request: URLRequest) -> String {
        return "\(request.url?.absoluteString ?? "")-\(request.httpMethod ?? "")"
    }
    
    private func generateRequestId(_ urlString: String) -> String {
        return urlString
    }
    
    private func updateErrorDistribution(error: Error?) -> [String: Int] {
        var distribution = metrics.errorDistribution
        let errorKey = error?.localizedDescription ?? "Unknown"
        distribution[errorKey, default: 0] += 1
        return distribution
    }
}
