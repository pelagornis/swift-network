import Foundation

/**
 * States that a circuit breaker can be in.
 * 
 * The circuit breaker pattern uses these states to control request flow
 * and provide fault tolerance for failing services.
 */
public enum CircuitBreakerState {
    /// Normal operation - requests are allowed to proceed
    case closed
    
    /// Failing state - requests are rejected immediately
    case open
    
    /// Testing state - limited requests are allowed to test recovery
    case halfOpen
}

/**
 * A protocol for implementing circuit breaker pattern.
 * 
 * Circuit breaker provides fault tolerance by temporarily stopping requests
 * when failures exceed a threshold. This prevents cascading failures and
 * allows the system to recover gracefully.
 * 
 * ## Circuit Breaker States
 * - **Closed**: Normal operation, requests are allowed
 * - **Open**: Failure threshold reached, requests are blocked
 * - **Half-Open**: Testing recovery, limited requests are allowed
 * 
 * ## Usage
 * ```swift
 * let circuitBreaker = DefaultCircuitBreaker(
 *     config: CircuitBreakerConfig(
 *         failureThreshold: 5,
 *         recoveryTimeout: 30
 *     )
 * )
 * 
 * if circuitBreaker.shouldAllowRequest() {
 *     // Make the request
 * } else {
 *     // Handle circuit breaker open
 * }
 * ```
 */
public protocol CircuitBreaker {
    /**
     * Determines if a request should be allowed to proceed.
     * 
     * - Returns: `true` if the request should be allowed, `false` if blocked
     */
    func shouldAllowRequest() -> Bool
    
    /**
     * Records a successful request.
     * 
     * This method updates the circuit breaker's internal state and may
     * cause state transitions (e.g., from half-open to closed).
     */
    func recordSuccess()
    
    /**
     * Records a failed request.
     * 
     * This method updates the circuit breaker's internal state and may
     * cause state transitions (e.g., from closed to open).
     * 
     * - Parameter error: The error that occurred
     */
    func recordFailure(_ error: Error)
    
    /**
     * Returns the current state of the circuit breaker.
     * 
     * - Returns: The current circuit breaker state
     */
    func getState() -> CircuitBreakerState
    
    /**
     * Manually resets the circuit breaker to closed state.
     * 
     * This method forces the circuit breaker back to normal operation,
     * clearing all failure counts and timers.
     */
    func reset()
}

/**
 * Configuration for circuit breaker behavior.
 * 
 * CircuitBreakerConfig defines the parameters that control how the circuit
 * breaker operates, including failure thresholds, recovery timeouts, and
 * state transition conditions.
 */
public struct CircuitBreakerConfig {
    /// Number of failures before opening the circuit
    public let failureThreshold: Int
    
    /// Time to wait before attempting recovery (half-open state)
    public let recoveryTimeout: TimeInterval
    
    /// Expected failure rate for adaptive thresholds
    public let expectedFailureRate: Double
    
    /// Minimum number of successful requests in half-open state before closing
    public let minimumRequestCount: Int
    
    /**
     * Creates a new CircuitBreakerConfig.
     * 
     * - Parameters:
     *   - failureThreshold: Number of failures before opening circuit. Defaults to 5.
     *   - recoveryTimeout: Time to wait before recovery attempt. Defaults to 60 seconds.
     *   - expectedFailureRate: Expected failure rate (0.0 to 1.0). Defaults to 0.5.
     *   - minimumRequestCount: Minimum successful requests for recovery. Defaults to 10.
     */
    public init(
        failureThreshold: Int = 5,
        recoveryTimeout: TimeInterval = 60.0,
        expectedFailureRate: Double = 0.5,
        minimumRequestCount: Int = 10
    ) {
        self.failureThreshold = failureThreshold
        self.recoveryTimeout = recoveryTimeout
        self.expectedFailureRate = expectedFailureRate
        self.minimumRequestCount = minimumRequestCount
    }
}

public final class DefaultCircuitBreaker: CircuitBreaker, @unchecked Sendable {
    private let config: CircuitBreakerConfig
    private let queue = DispatchQueue(label: "com.network.circuitbreaker", attributes: .concurrent)
    
    private var state: CircuitBreakerState = .closed
    private var failureCount = 0
    private var successCount = 0
    private var lastFailureTime: Date?
    private var lastStateChangeTime: Date = Date()
    
    public init(config: CircuitBreakerConfig = CircuitBreakerConfig()) {
        self.config = config
    }
    
    public func shouldAllowRequest() -> Bool {
        return queue.sync {
            switch state {
            case .closed:
                return true
            case .open:
                if shouldAttemptReset() {
                    transitionToHalfOpen()
                    return true
                }
                return false
            case .halfOpen:
                return true
            }
        }
    }
    
    public func recordSuccess() {
        queue.async(flags: .barrier) {
            self.successCount += 1
            
            switch self.state {
            case .closed:
                // Reset failure count on success
                self.failureCount = 0
            case .halfOpen:
                // If we get enough successes in half-open, close the circuit
                if self.successCount >= self.config.minimumRequestCount {
                    self.transitionToClosed()
                }
            case .open:
                break
            }
        }
    }
    
    public func recordFailure(_ error: Error) {
        queue.async(flags: .barrier) {
            self.failureCount += 1
            self.lastFailureTime = Date()
            
            switch self.state {
            case .closed:
                // Check if we should open the circuit
                if self.shouldOpenCircuit() {
                    self.transitionToOpen()
                }
            case .halfOpen:
                // Any failure in half-open state opens the circuit
                self.transitionToOpen()
            case .open:
                break
            }
        }
    }
    
    public func getState() -> CircuitBreakerState {
        return queue.sync { state }
    }
    
    public func reset() {
        queue.async(flags: .barrier) {
            self.state = .closed
            self.failureCount = 0
            self.successCount = 0
            self.lastFailureTime = nil
            self.lastStateChangeTime = Date()
        }
    }
    
    private func shouldOpenCircuit() -> Bool {
        let totalRequests = failureCount + successCount
        guard totalRequests >= config.minimumRequestCount else { return false }
        
        let failureRate = Double(failureCount) / Double(totalRequests)
        return failureRate >= config.expectedFailureRate || failureCount >= config.failureThreshold
    }
    
    private func shouldAttemptReset() -> Bool {
        guard let lastFailureTime = lastFailureTime else { return false }
        return Date().timeIntervalSince(lastFailureTime) >= config.recoveryTimeout
    }
    
    private func transitionToOpen() {
        state = .open
        lastStateChangeTime = Date()
        successCount = 0
    }
    
    private func transitionToHalfOpen() {
        state = .halfOpen
        lastStateChangeTime = Date()
        successCount = 0
        failureCount = 0
    }
    
    private func transitionToClosed() {
        state = .closed
        lastStateChangeTime = Date()
        successCount = 0
        failureCount = 0
    }
}

public class EndpointCircuitBreaker: CircuitBreaker {
    private let endpoint: Endpoint
    private let circuitBreaker: CircuitBreaker
    
    public init(endpoint: Endpoint, config: CircuitBreakerConfig = CircuitBreakerConfig()) {
        self.endpoint = endpoint
        self.circuitBreaker = DefaultCircuitBreaker(config: config)
    }
    
    public func shouldAllowRequest() -> Bool {
        return circuitBreaker.shouldAllowRequest()
    }
    
    public func recordSuccess() {
        circuitBreaker.recordSuccess()
    }
    
    public func recordFailure(_ error: Error) {
        circuitBreaker.recordFailure(error)
    }
    
    public func getState() -> CircuitBreakerState {
        return circuitBreaker.getState()
    }
    
    public func reset() {
        circuitBreaker.reset()
    }
}

public final class CircuitBreakerPlugin: NetworkPlugin, @unchecked Sendable {
    private let circuitBreakers: [String: CircuitBreaker]
    private let queue = DispatchQueue(label: "com.network.circuitbreaker", attributes: .concurrent)
    
    public init(circuitBreakers: [String: CircuitBreaker] = [:]) {
        self.circuitBreakers = circuitBreakers
    }
    
    public func willSend(_ request: URLRequest, target: Endpoint) {
        let key = generateKey(for: target)
        
        queue.sync {
            if let circuitBreaker = circuitBreakers[key] {
                if !circuitBreaker.shouldAllowRequest() {
                    // This would typically throw an error, but we'll let the request proceed
                    // and handle it in didReceive
                }
            }
        }
    }
    
    public func didReceive(_ result: Result<(Data, URLResponse), Error>, target: Endpoint) {
        let key = generateKey(for: target)
        
        queue.async {
            if let circuitBreaker = self.circuitBreakers[key] {
                switch result {
                case .success:
                    circuitBreaker.recordSuccess()
                case .failure(let error):
                    circuitBreaker.recordFailure(error)
                }
            }
        }
    }
    
    private func generateKey(for endpoint: Endpoint) -> String {
        return "\(endpoint.baseURL.host ?? "")-\(endpoint.path)"
    }
}
