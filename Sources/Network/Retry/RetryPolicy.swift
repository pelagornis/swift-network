import Foundation

/**
 * A protocol for defining retry policies for network requests.
 * 
 * RetryPolicy allows you to configure automatic retry behavior when network
 * requests fail. It provides control over when to retry, how many times to retry,
 * and what delays to use between retries.
 * 
 * ## Usage
 * ```swift
 * let retryPolicy = ExponentialBackoffRetryPolicy(
 *     maxAttempts: 3,
 *     baseDelay: 1.0,
 *     multiplier: 2.0
 * )
 * 
 * let provider = NetworkProvider<UserEndpoint>(
 *     retryPolicy: retryPolicy
 * )
 * ```
 */
public protocol RetryPolicy {
    /**
     * Determines whether a request should be retried based on the error and attempt number.
     * 
     * - Parameters:
     *   - error: The error that occurred
     *   - attempt: The current attempt number (1-based)
     *   - request: The original request that failed
     * - Returns: `true` if the request should be retried, `false` otherwise
     */
    func shouldRetry(for error: Error, attempt: Int, request: URLRequest) -> Bool
    
    /**
     * Returns the delay to wait before the next retry attempt.
     * 
     * - Parameter attempt: The current attempt number (1-based)
     * - Returns: The delay in seconds
     */
    func delay(for attempt: Int) -> TimeInterval
    
    /**
     * Returns the maximum number of attempts allowed.
     * 
     * - Returns: The maximum number of attempts
     */
    func maxAttempts() -> Int
}

/**
 * A retry policy that uses exponential backoff for retry delays.
 * 
 * ExponentialBackoffRetryPolicy increases the delay between retries exponentially,
 * which helps prevent overwhelming the server while still providing retry capability.
 * 
 * ## Retry Behavior
 * - Delay increases exponentially: baseDelay * (multiplier ^ attempt)
 * - Maximum delay is capped to prevent excessive waits
 * - Only retries idempotent HTTP methods (GET, HEAD, PUT, DELETE, etc.)
 * - Retries on network errors and server errors (5xx)
 * 
 * ## Usage
 * ```swift
 * let retryPolicy = ExponentialBackoffRetryPolicy(
 *     maxAttempts: 3,
 *     baseDelay: 1.0,    // Start with 1 second
 *     maxDelay: 60.0,    // Cap at 60 seconds
 *     multiplier: 2.0    // Double the delay each time
 * )
 * // Delays: 1s, 2s, 4s
 * ```
 */
public struct ExponentialBackoffRetryPolicy: RetryPolicy {
    /// Maximum number of retry attempts
    private let maximumAttempts: Int
    
    /// Initial delay before first retry
    private let baseDelay: TimeInterval
    
    /// Maximum delay cap to prevent excessive waits
    private let maxDelay: TimeInterval
    
    /// Multiplier for exponential backoff calculation
    private let multiplier: Double
    
    /// Set of URLError codes that should trigger retries
    private let retryableErrors: Set<URLError.Code>
    
    /**
     * Creates a new ExponentialBackoffRetryPolicy.
     * 
     * - Parameters:
     *   - maxAttempts: Maximum number of retry attempts. Defaults to 3.
     *   - baseDelay: Initial delay in seconds. Defaults to 1.0.
     *   - maxDelay: Maximum delay cap in seconds. Defaults to 60.0.
     *   - multiplier: Exponential multiplier. Defaults to 2.0.
     *   - retryableErrors: Set of URLError codes to retry on. Defaults to common network errors.
     */
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
