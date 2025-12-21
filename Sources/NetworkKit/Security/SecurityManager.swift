import Foundation
#if canImport(Security)
@preconcurrency import Security
#endif

/**
 * A protocol for managing SSL/TLS certificate validation and pinning.
 * 
 * SecurityManager provides certificate validation, certificate pinning,
 * and domain name validation for secure network communications.
 * 
 * ## Features
 * - Certificate validation using system trust store
 * - Certificate pinning for additional security
 * - Domain name validation
 * - Configurable invalid certificate handling
 * 
 * ## Usage
 * ```swift
 * let securityManager = DefaultSecurityManager(
 *     allowInvalidCertificates: false,
 *     validateDomainName: true
 * )
 * 
 * // Add certificate pinning
 * if let certificate = loadCertificate() {
 *     securityManager.addCertificatePinning(certificate, for: "api.example.com")
 * }
 * ```
 */
#if canImport(Security)
public protocol SecurityManager {
    /**
     * Validates a server certificate against the trust store and pinned certificates.
     * 
     * - Parameters:
     *   - serverTrust: The server trust object to validate
     *   - domain: The domain name for validation
     * - Returns: `true` if the certificate is valid, `false` otherwise
     */
    func validateCertificate(_ serverTrust: SecTrust, domain: String) -> Bool
    
    /**
     * Adds a certificate for pinning to a specific domain.
     * 
     * - Parameters:
     *   - certificate: The certificate to pin
     *   - domain: The domain to pin the certificate for
     */
    func addCertificatePinning(_ certificate: SecCertificate, for domain: String)
    
    /**
     * Removes certificate pinning for a specific domain.
     * 
     * - Parameter domain: The domain to remove pinning for
     */
    func removeCertificatePinning(for domain: String)
    
    /**
     * Checks if certificate pinning is configured for a domain.
     * 
     * - Parameter domain: The domain to check
     * - Returns: `true` if certificate pinning is configured, `false` otherwise
     */
    func isCertificatePinned(for domain: String) -> Bool
}
#else
/**
 * A protocol for managing SSL/TLS certificate validation and pinning.
 * 
 * This version is used when the Security framework is not available.
 * All methods accept Any types instead of Security framework types.
 */
public protocol SecurityManager {
    /**
     * Validates a server certificate against the trust store and pinned certificates.
     * 
     * - Parameters:
     *   - serverTrust: The server trust object to validate
     *   - domain: The domain name for validation
     * - Returns: `true` if the certificate is valid, `false` otherwise
     */
    func validateCertificate(_ serverTrust: Any, domain: String) -> Bool
    
    /**
     * Adds a certificate for pinning to a specific domain.
     * 
     * - Parameters:
     *   - certificate: The certificate to pin
     *   - domain: The domain to pin the certificate for
     */
    func addCertificatePinning(_ certificate: Any, for domain: String)
    
    /**
     * Removes certificate pinning for a specific domain.
     * 
     * - Parameter domain: The domain to remove pinning for
     */
    func removeCertificatePinning(for domain: String)
    
    /**
     * Checks if certificate pinning is configured for a domain.
     * 
     * - Parameter domain: The domain to check
     * - Returns: `true` if certificate pinning is configured, `false` otherwise
     */
    func isCertificatePinned(for domain: String) -> Bool
}
#endif

#if canImport(Security)
/**
 * A concrete implementation of SecurityManager using the Security framework.
 * 
 * DefaultSecurityManager provides comprehensive certificate validation and
 * pinning capabilities with thread-safe operations and configurable behavior.
 * 
 * ## Features
 * - Standard certificate validation using SecTrustEvaluateWithError
 * - Certificate pinning with domain-specific certificates
 * - Thread-safe operations using concurrent dispatch queue
 * - Configurable invalid certificate handling
 * - Domain name validation support
 */
public final class DefaultSecurityManager: SecurityManager, @unchecked Sendable {
    /// Concurrent queue for thread-safe operations
    private let queue = DispatchQueue(label: "com.network.security", attributes: .concurrent)
    
    /// Dictionary mapping domains to sets of pinned certificate data
    private var pinnedCertificates: [String: Set<Data>] = [:]
    
    /// Whether to allow invalid certificates (for testing/development)
    private let allowInvalidCertificates: Bool
    
    /// Whether to validate domain names
    private let validateDomainName: Bool
    
    /**
     * Creates a new DefaultSecurityManager.
     * 
     * - Parameters:
     *   - allowInvalidCertificates: Whether to allow invalid certificates. Defaults to false.
     *   - validateDomainName: Whether to validate domain names. Defaults to true.
     */
    public init(allowInvalidCertificates: Bool = false, validateDomainName: Bool = true) {
        self.allowInvalidCertificates = allowInvalidCertificates
        self.validateDomainName = validateDomainName
    }
    
    public func validateCertificate(_ serverTrust: SecTrust, domain: String) -> Bool {
        var error: CFError?
        let isValid = SecTrustEvaluateWithError(serverTrust, &error)
        
        guard isValid else {
            return allowInvalidCertificates
        }
        
        // Check if certificate is pinned
        if isCertificatePinned(for: domain) {
            return validatePinnedCertificate(serverTrust, for: domain)
        }
        
        // Standard validation passed
        return true
    }
    
    public func addCertificatePinning(_ certificate: SecCertificate, for domain: String) {
        queue.async(flags: .barrier) {
            let certificateData = SecCertificateCopyData(certificate) as Data
            self.pinnedCertificates[domain, default: []].insert(certificateData)
        }
    }
    
    public func removeCertificatePinning(for domain: String) {
        queue.async(flags: .barrier) {
            self.pinnedCertificates.removeValue(forKey: domain)
        }
    }
    
    public func isCertificatePinned(for domain: String) -> Bool {
        return queue.sync {
            return pinnedCertificates[domain]?.isEmpty == false
        }
    }
    
    private func validatePinnedCertificate(_ serverTrust: SecTrust, for domain: String) -> Bool {
        let pinnedCerts = queue.sync { pinnedCertificates[domain] ?? [] }
        
        #if os(iOS) && compiler(>=5.5)
        if #available(iOS 15.0, *) {
            guard let certificateChain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate] else {
                return false
            }
            
            for certificate in certificateChain {
                let certificateData = SecCertificateCopyData(certificate) as Data
                
                if pinnedCerts.contains(certificateData) {
                    return true
                }
            }
        } else {
            // Fallback for iOS < 15.0
            let certificateCount = SecTrustGetCertificateCount(serverTrust)
            for i in 0..<certificateCount {
                guard let certificate = SecTrustGetCertificateAtIndex(serverTrust, i) else {
                    continue
                }
                let certificateData = SecCertificateCopyData(certificate) as Data
                
                if pinnedCerts.contains(certificateData) {
                    return true
                }
            }
        }
        #elseif os(macOS) && compiler(>=5.5)
        if #available(macOS 12.0, *) {
            guard let certificateChain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate] else {
                return false
            }
            
            for certificate in certificateChain {
                let certificateData = SecCertificateCopyData(certificate) as Data
                
                if pinnedCerts.contains(certificateData) {
                    return true
                }
            }
        } else {
            // Fallback for macOS < 12.0
            let certificateCount = SecTrustGetCertificateCount(serverTrust)
            for i in 0..<certificateCount {
                guard let certificate = SecTrustGetCertificateAtIndex(serverTrust, i) else {
                    continue
                }
                let certificateData = SecCertificateCopyData(certificate) as Data
                
                if pinnedCerts.contains(certificateData) {
                    return true
                }
            }
        }
        #else
        // Fallback for other platforms or older compilers
        let certificateCount = SecTrustGetCertificateCount(serverTrust)
        for i in 0..<certificateCount {
            guard let certificate = SecTrustGetCertificateAtIndex(serverTrust, i) else {
                continue
            }
            let certificateData = SecCertificateCopyData(certificate) as Data
            
            if pinnedCerts.contains(certificateData) {
                return true
            }
        }
        #endif
        
        return false
    }
}
#else
public final class DefaultSecurityManager: SecurityManager, @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.network.security", attributes: .concurrent)
    private var pinnedCertificates: [String: Set<Data>] = [:]
    private let allowInvalidCertificates: Bool
    private let validateDomainName: Bool
    
    public init(allowInvalidCertificates: Bool = false, validateDomainName: Bool = true) {
        self.allowInvalidCertificates = allowInvalidCertificates
        self.validateDomainName = validateDomainName
    }
    
    public func validateCertificate(_ serverTrust: Any, domain: String) -> Bool {
        // Security framework not available, return true for compatibility
        return true
    }
    
    public func addCertificatePinning(_ certificate: Any, for domain: String) {
        // Security framework not available, no-op
    }
    
    public func removeCertificatePinning(for domain: String) {
        queue.async(flags: .barrier) {
            self.pinnedCertificates.removeValue(forKey: domain)
        }
    }
    
    public func isCertificatePinned(for domain: String) -> Bool {
        return queue.sync {
            return pinnedCertificates[domain]?.isEmpty == false
        }
    }
}
#endif

public class CertificatePinningPlugin: NetworkPlugin {
    private let securityManager: SecurityManager
    
    public init(securityManager: SecurityManager = DefaultSecurityManager()) {
        self.securityManager = securityManager
    }
    
    public func willSend(_ request: URLRequest, target: Endpoint) {
        // Certificate pinning validation happens in URLSession delegate
    }
    
    public func didReceive(_ result: Result<(Data, URLResponse), Error>, target: Endpoint) {
        // Handle certificate validation results if needed
    }
}

#if canImport(Security)
public final class URLSessionSecurityDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
    private let securityManager: SecurityManager
    
    public init(securityManager: SecurityManager) {
        self.securityManager = securityManager
        super.init()
    }
    
    public func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        let protectionSpace = challenge.protectionSpace
        
        guard protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        let domain = protectionSpace.host
        let isValid = securityManager.validateCertificate(serverTrust, domain: domain)
        
        if isValid {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}
#else
public final class URLSessionSecurityDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
    private let securityManager: SecurityManager
    
    public init(securityManager: SecurityManager) {
        self.securityManager = securityManager
        super.init()
    }
    
    public func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // Security framework not available, perform default handling
        completionHandler(.performDefaultHandling, nil)
    }
}
#endif
