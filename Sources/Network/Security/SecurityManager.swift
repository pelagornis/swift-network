import Foundation
#if canImport(Security)
@preconcurrency import Security
#endif

#if canImport(Security)
public protocol SecurityManager {
    func validateCertificate(_ serverTrust: SecTrust, domain: String) -> Bool
    func addCertificatePinning(_ certificate: SecCertificate, for domain: String)
    func removeCertificatePinning(for domain: String)
    func isCertificatePinned(for domain: String) -> Bool
}
#else
public protocol SecurityManager {
    func validateCertificate(_ serverTrust: Any, domain: String) -> Bool
    func addCertificatePinning(_ certificate: Any, for domain: String)
    func removeCertificatePinning(for domain: String)
    func isCertificatePinned(for domain: String) -> Bool
}
#endif

#if canImport(Security)
public final class DefaultSecurityManager: SecurityManager, @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.network.security", attributes: .concurrent)
    private var pinnedCertificates: [String: Set<Data>] = [:]
    private let allowInvalidCertificates: Bool
    private let validateDomainName: Bool
    
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
        
        guard let certificateChain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate] else {
            return false
        }
        
        for certificate in certificateChain {
            let certificateData = SecCertificateCopyData(certificate) as Data
            
            if pinnedCerts.contains(certificateData) {
                return true
            }
        }
        
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
