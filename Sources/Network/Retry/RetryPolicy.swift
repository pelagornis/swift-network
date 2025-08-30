import Foundation

public protocol RetryPolicy {
    func shouldRetry(for error: Error, attempt: Int, request: URLRequest) -> Bool
    func delay(for attempt: Int) -> TimeInterval
    func maxAttempts() -> Int
}

public struct ExponentialBackoffRetryPolicy: RetryPolicy {
    private let maximumAttempts: Int
    private let baseDelay: TimeInterval
    private let maxDelay: TimeInterval
    private let multiplier: Double
    private let retryableErrors: Set<URLError.Code>
    
    public init(
        maxAttempts: Int = 3,
        baseDelay: TimeInterval = 1.0,
        maxDelay: TimeInterval = 60.0,
        multiplier: Double = 2.0,
        retryableErrors: Set<URLError.Code> = [
            .networkConnectionLost,
            .notConnectedToInternet,
            .timedOut,
            .cannotConnectToHost,
            .cannotFindHost,
            .dnsLookupFailed
        ]
    ) {
        self.maximumAttempts = maxAttempts
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
        self.multiplier = multiplier
        self.retryableErrors = retryableErrors
    }
    
    public func shouldRetry(for error: Error, attempt: Int, request: URLRequest) -> Bool {
        guard attempt < maximumAttempts else { return false }
        
        // Don't retry non-idempotent methods unless explicitly configured
        if !isIdempotent(request.httpMethod) {
            return false
        }
        
        if let urlError = error as? URLError {
            return retryableErrors.contains(urlError.code)
        }
        
        // Retry on server errors (5xx)
        if case NetworkError.serverError(let statusCode, _) = error {
            return statusCode >= 500 && statusCode < 600
        }
        
        return false
    }
    
    public func delay(for attempt: Int) -> TimeInterval {
        let delay = baseDelay * pow(multiplier, Double(attempt - 1))
        return min(delay, maxDelay)
    }
    
    public func maxAttempts() -> Int {
        return self.maximumAttempts
    }
    
    private func isIdempotent(_ method: String?) -> Bool {
        guard let method = method else { return false }
        return ["GET", "HEAD", "PUT", "DELETE", "OPTIONS", "TRACE"].contains(method.uppercased())
    }
}

public struct FixedDelayRetryPolicy: RetryPolicy {
    private let maximumAttempts: Int
    private let delay: TimeInterval
    private let retryableErrors: Set<URLError.Code>
    
    public init(
        maxAttempts: Int = 3,
        delay: TimeInterval = 2.0,
        retryableErrors: Set<URLError.Code> = [
            .networkConnectionLost,
            .notConnectedToInternet,
            .timedOut
        ]
    ) {
        self.maximumAttempts = maxAttempts
        self.delay = delay
        self.retryableErrors = retryableErrors
    }
    
    public func shouldRetry(for error: Error, attempt: Int, request: URLRequest) -> Bool {
        guard attempt < maximumAttempts else { return false }
        
        if let urlError = error as? URLError {
            return retryableErrors.contains(urlError.code)
        }
        
        return false
    }
    
    public func delay(for attempt: Int) -> TimeInterval {
        return self.delay
    }
    
    public func maxAttempts() -> Int {
        return self.maximumAttempts
    }
}

public struct CustomRetryPolicy: RetryPolicy {
    private let maximumAttempts: Int
    private let shouldRetryClosure: (Error, Int, URLRequest) -> Bool
    private let delayClosure: (Int) -> TimeInterval
    
    public init(
        maxAttempts: Int,
        shouldRetry: @escaping (Error, Int, URLRequest) -> Bool,
        delay: @escaping (Int) -> TimeInterval
    ) {
        self.maximumAttempts = maxAttempts
        self.shouldRetryClosure = shouldRetry
        self.delayClosure = delay
    }
    
    public func shouldRetry(for error: Error, attempt: Int, request: URLRequest) -> Bool {
        return shouldRetryClosure(error, attempt, request)
    }
    
    public func delay(for attempt: Int) -> TimeInterval {
        return delayClosure(attempt)
    }
    
    public func maxAttempts() -> Int {
        return self.maximumAttempts
    }
}
