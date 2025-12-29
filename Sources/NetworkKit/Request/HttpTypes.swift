import Foundation

/**
 * Core HTTP types used throughout the networking library.
 * 
 * This namespace contains the fundamental types for defining HTTP methods,
 * request tasks, and headers in a type-safe manner.
 */
public struct Http {
    /**
     * HTTP methods supported by the networking library.
     * 
     * Each case corresponds to a standard HTTP method with its string representation.
     */
    public enum Method: String, Sendable {
        /// HTTP GET method - retrieve data
        case get     = "GET"
        
        /// HTTP POST method - create new resource
        case post    = "POST"
        
        /// HTTP PUT method - update existing resource
        case put     = "PUT"
        
        /// HTTP PATCH method - partial update
        case patch   = "PATCH"
        
        /// HTTP DELETE method - remove resource
        case delete  = "DELETE"
        
        /// HTTP HEAD method - get headers only
        case head    = "HEAD"
        
        /// HTTP OPTIONS method - get allowed methods
        case options = "OPTIONS"
    }

    /**
     * Defines the type of request task to perform.
     * 
     * Each case represents a different way to send data or handle the request.
     */
    public enum Task {
        /// Simple request with no body
        case requestPlain
        
        /// Request with JSON-encoded body
        case requestJSON(Encodable)
        
        /// Request with URL-encoded or form-encoded parameters
        case requestParameters([String: Any], encoding: ParameterEncoding)
        
        /// Request with multipart form data (file uploads)
        case uploadMultipart([MultipartFormData])
        
        /// Request that downloads data to a specific destination
        case download(destination: DownloadDestination)
        
        /// Custom request with raw data and content type
        case requestCustom(body: Data?, contentType: String?)
        
        /// Request with streaming data
        case requestStream(InputStream, length: Int, contentType: String?)
    }
    
    /**
     * Represents an HTTP header with field name and value.
     * 
     * This struct provides a type-safe way to define HTTP headers
     * and ensures proper formatting.
     */
    public struct Header: Sendable {
        /// The header field name (e.g., "Content-Type")
        public let field: String
        
        /// The header value (e.g., "application/json")
        public let value: String

        /**
         * Creates a new HTTP header.
         * 
         * - Parameters:
         *   - field: The header field name
         *   - value: The header value
         */
        public init(field: String, value: String) {
            self.field = field
            self.value = value
        }
    }
    
    /**
     * HTTP status codes as defined by RFC 7231 and other standards.
     * 
     * This enum provides a type-safe representation of all standard HTTP status codes,
     * organized by their response class (1xx Informational, 2xx Success, 3xx Redirection,
     * 4xx Client Error, 5xx Server Error).
     * 
     * ## Usage
     * ```swift
     * let statusCode = Http.StatusCode.ok
     * print(statusCode.rawValue) // 200
     * print(statusCode.isSuccess) // true
     * 
     * // Convert from integer
     * if let code = Http.StatusCode(rawValue: 404) {
     *     print(code) // .notFound
     * }
     * ```
     */
    public enum StatusCode: Int, Sendable, CaseIterable {
        // MARK: - 1xx Informational
        
        /// 100 Continue - The server has received the request headers
        case `continue` = 100
        
        /// 101 Switching Protocols - The requester has asked the server to switch protocols
        case switchingProtocols = 101
        
        /// 102 Processing - The server has received and is processing the request
        case processing = 102
        
        /// 103 Early Hints - Used to return some response headers before final HTTP message
        case earlyHints = 103
        
        // MARK: - 2xx Success
        
        /// 200 OK - The request has succeeded
        case ok = 200
        
        /// 201 Created - The request has been fulfilled and a new resource has been created
        case created = 201
        
        /// 202 Accepted - The request has been accepted for processing
        case accepted = 202
        
        /// 203 Non-Authoritative Information - The request was successful but the information may be from another source
        case nonAuthoritativeInformation = 203
        
        /// 204 No Content - The request was successful but there is no content to return
        case noContent = 204
        
        /// 205 Reset Content - The request was successful and the user agent should reset the document view
        case resetContent = 205
        
        /// 206 Partial Content - The server is delivering only part of the resource
        case partialContent = 206
        
        /// 207 Multi-Status - Provides status for multiple independent operations
        case multiStatus = 207
        
        /// 208 Already Reported - The members of a DAV binding have already been enumerated
        case alreadyReported = 208
        
        /// 226 IM Used - The server has fulfilled a GET request for the resource
        case imUsed = 226
        
        // MARK: - 3xx Redirection
        
        /// 300 Multiple Choices - The request has multiple possible responses
        case multipleChoices = 300
        
        /// 301 Moved Permanently - The resource has been permanently moved
        case movedPermanently = 301
        
        /// 302 Found - The resource has been temporarily moved
        case found = 302
        
        /// 303 See Other - The response can be found at another URI
        case seeOther = 303
        
        /// 304 Not Modified - The resource has not been modified since the last request
        case notModified = 304
        
        /// 305 Use Proxy - The requested resource must be accessed through a proxy
        case useProxy = 305
        
        /// 307 Temporary Redirect - The resource is temporarily located at another URI
        case temporaryRedirect = 307
        
        /// 308 Permanent Redirect - The resource is permanently located at another URI
        case permanentRedirect = 308
        
        // MARK: - 4xx Client Error
        
        /// 400 Bad Request - The request could not be understood by the server
        case badRequest = 400
        
        /// 401 Unauthorized - The request requires user authentication
        case unauthorized = 401
        
        /// 402 Payment Required - Reserved for future use
        case paymentRequired = 402
        
        /// 403 Forbidden - The server understood the request but refuses to authorize it
        case forbidden = 403
        
        /// 404 Not Found - The requested resource could not be found
        case notFound = 404
        
        /// 405 Method Not Allowed - The method specified in the request is not allowed
        case methodNotAllowed = 405
        
        /// 406 Not Acceptable - The server cannot produce a response matching the list of acceptable values
        case notAcceptable = 406
        
        /// 407 Proxy Authentication Required - The client must first authenticate itself with the proxy
        case proxyAuthenticationRequired = 407
        
        /// 408 Request Timeout - The server timed out waiting for the request
        case requestTimeout = 408
        
        /// 409 Conflict - The request could not be completed due to a conflict
        case conflict = 409
        
        /// 410 Gone - The resource is no longer available
        case gone = 410
        
        /// 411 Length Required - The request did not specify the length of its content
        case lengthRequired = 411
        
        /// 412 Precondition Failed - The server does not meet one of the preconditions
        case preconditionFailed = 412
        
        /// 413 Payload Too Large - The request entity is larger than limits defined by the server
        case payloadTooLarge = 413
        
        /// 414 URI Too Long - The URI provided was too long for the server to process
        case uriTooLong = 414
        
        /// 415 Unsupported Media Type - The request entity has a media type which the server does not support
        case unsupportedMediaType = 415
        
        /// 416 Range Not Satisfiable - The client has asked for a portion of the file that the server cannot supply
        case rangeNotSatisfiable = 416
        
        /// 417 Expectation Failed - The server cannot meet the requirements of the Expect request-header field
        case expectationFailed = 417
        
        /// 418 I'm a teapot - The server refuses to brew coffee because it is a teapot (RFC 2324)
        case imATeapot = 418
        
        /// 421 Misdirected Request - The request was directed at a server that is not able to produce a response
        case misdirectedRequest = 421
        
        /// 422 Unprocessable Entity - The request was well-formed but contains semantic errors
        case unprocessableEntity = 422
        
        /// 423 Locked - The resource that is being accessed is locked
        case locked = 423
        
        /// 424 Failed Dependency - The request failed because it depended on another request that failed
        case failedDependency = 424
        
        /// 425 Too Early - The server is unwilling to risk processing a request that might be replayed
        case tooEarly = 425
        
        /// 426 Upgrade Required - The client should switch to a different protocol
        case upgradeRequired = 426
        
        /// 428 Precondition Required - The origin server requires the request to be conditional
        case preconditionRequired = 428
        
        /// 429 Too Many Requests - The user has sent too many requests in a given amount of time
        case tooManyRequests = 429
        
        /// 431 Request Header Fields Too Large - The server is unwilling to process the request
        case requestHeaderFieldsTooLarge = 431
        
        /// 451 Unavailable For Legal Reasons - The server is denying access to the resource as a consequence of a legal demand
        case unavailableForLegalReasons = 451
        
        // MARK: - 5xx Server Error
        
        /// 500 Internal Server Error - The server encountered an unexpected condition
        case internalServerError = 500
        
        /// 501 Not Implemented - The server does not support the functionality required to fulfill the request
        case notImplemented = 501
        
        /// 502 Bad Gateway - The server received an invalid response from an upstream server
        case badGateway = 502
        
        /// 503 Service Unavailable - The server is currently unable to handle the request
        case serviceUnavailable = 503
        
        /// 504 Gateway Timeout - The server did not receive a timely response from an upstream server
        case gatewayTimeout = 504
        
        /// 505 HTTP Version Not Supported - The server does not support the HTTP protocol version
        case httpVersionNotSupported = 505
        
        /// 506 Variant Also Negotiates - Transparent content negotiation for the request results in a circular reference
        case variantAlsoNegotiates = 506
        
        /// 507 Insufficient Storage - The method could not be performed on the resource because the server is unable to store the representation
        case insufficientStorage = 507
        
        /// 508 Loop Detected - The server detected an infinite loop while processing the request
        case loopDetected = 508
        
        /// 510 Not Extended - Further extensions to the request are required for the server to fulfill it
        case notExtended = 510
        
        /// 511 Network Authentication Required - The client needs to authenticate to gain network access
        case networkAuthenticationRequired = 511
        
        // MARK: - Unknown Status Code
        
        /// Unknown status code - used for non-standard status codes
        case unknown = -1
        
        // MARK: - Computed Properties
        
        /// Returns true if the status code is in the 1xx range (Informational)
        public var isInformational: Bool {
            return (100..<200).contains(rawValue)
        }
        
        /// Returns true if the status code is in the 2xx range (Success)
        public var isSuccess: Bool {
            return (200..<300).contains(rawValue)
        }
        
        /// Returns true if the status code is in the 3xx range (Redirection)
        public var isRedirection: Bool {
            return (300..<400).contains(rawValue)
        }
        
        /// Returns true if the status code is in the 4xx range (Client Error)
        public var isClientError: Bool {
            return (400..<500).contains(rawValue)
        }
        
        /// Returns true if the status code is in the 5xx range (Server Error)
        public var isServerError: Bool {
            return (500..<600).contains(rawValue)
        }
        
        /// Returns a human-readable description of the status code
        public var description: String {
            switch self {
            case .continue: return "Continue"
            case .switchingProtocols: return "Switching Protocols"
            case .processing: return "Processing"
            case .earlyHints: return "Early Hints"
            case .ok: return "OK"
            case .created: return "Created"
            case .accepted: return "Accepted"
            case .nonAuthoritativeInformation: return "Non-Authoritative Information"
            case .noContent: return "No Content"
            case .resetContent: return "Reset Content"
            case .partialContent: return "Partial Content"
            case .multiStatus: return "Multi-Status"
            case .alreadyReported: return "Already Reported"
            case .imUsed: return "IM Used"
            case .multipleChoices: return "Multiple Choices"
            case .movedPermanently: return "Moved Permanently"
            case .found: return "Found"
            case .seeOther: return "See Other"
            case .notModified: return "Not Modified"
            case .useProxy: return "Use Proxy"
            case .temporaryRedirect: return "Temporary Redirect"
            case .permanentRedirect: return "Permanent Redirect"
            case .badRequest: return "Bad Request"
            case .unauthorized: return "Unauthorized"
            case .paymentRequired: return "Payment Required"
            case .forbidden: return "Forbidden"
            case .notFound: return "Not Found"
            case .methodNotAllowed: return "Method Not Allowed"
            case .notAcceptable: return "Not Acceptable"
            case .proxyAuthenticationRequired: return "Proxy Authentication Required"
            case .requestTimeout: return "Request Timeout"
            case .conflict: return "Conflict"
            case .gone: return "Gone"
            case .lengthRequired: return "Length Required"
            case .preconditionFailed: return "Precondition Failed"
            case .payloadTooLarge: return "Payload Too Large"
            case .uriTooLong: return "URI Too Long"
            case .unsupportedMediaType: return "Unsupported Media Type"
            case .rangeNotSatisfiable: return "Range Not Satisfiable"
            case .expectationFailed: return "Expectation Failed"
            case .imATeapot: return "I'm a teapot"
            case .misdirectedRequest: return "Misdirected Request"
            case .unprocessableEntity: return "Unprocessable Entity"
            case .locked: return "Locked"
            case .failedDependency: return "Failed Dependency"
            case .tooEarly: return "Too Early"
            case .upgradeRequired: return "Upgrade Required"
            case .preconditionRequired: return "Precondition Required"
            case .tooManyRequests: return "Too Many Requests"
            case .requestHeaderFieldsTooLarge: return "Request Header Fields Too Large"
            case .unavailableForLegalReasons: return "Unavailable For Legal Reasons"
            case .internalServerError: return "Internal Server Error"
            case .notImplemented: return "Not Implemented"
            case .badGateway: return "Bad Gateway"
            case .serviceUnavailable: return "Service Unavailable"
            case .gatewayTimeout: return "Gateway Timeout"
            case .httpVersionNotSupported: return "HTTP Version Not Supported"
            case .variantAlsoNegotiates: return "Variant Also Negotiates"
            case .insufficientStorage: return "Insufficient Storage"
            case .loopDetected: return "Loop Detected"
            case .notExtended: return "Not Extended"
            case .networkAuthenticationRequired: return "Network Authentication Required"
            case .unknown: return "Unknown Status Code"
            }
        }
        
        // MARK: - Initializers
        
        /**
         * Creates a StatusCode from an integer value.
         * 
         * - Parameter rawValue: The integer status code value
         * - Returns: A StatusCode enum case if the value is recognized, otherwise `.unknown`
         */
        public init(rawValue: Int) {
            // Check all known status codes (excluding unknown)
            let knownStatusCodes: [StatusCode] = [
                .continue, .switchingProtocols, .processing, .earlyHints,
                .ok, .created, .accepted, .nonAuthoritativeInformation, .noContent,
                .resetContent, .partialContent, .multiStatus, .alreadyReported, .imUsed,
                .multipleChoices, .movedPermanently, .found, .seeOther, .notModified,
                .useProxy, .temporaryRedirect, .permanentRedirect,
                .badRequest, .unauthorized, .paymentRequired, .forbidden, .notFound,
                .methodNotAllowed, .notAcceptable, .proxyAuthenticationRequired, .requestTimeout,
                .conflict, .gone, .lengthRequired, .preconditionFailed, .payloadTooLarge,
                .uriTooLong, .unsupportedMediaType, .rangeNotSatisfiable, .expectationFailed,
                .imATeapot, .misdirectedRequest, .unprocessableEntity, .locked, .failedDependency,
                .tooEarly, .upgradeRequired, .preconditionRequired, .tooManyRequests,
                .requestHeaderFieldsTooLarge, .unavailableForLegalReasons,
                .internalServerError, .notImplemented, .badGateway, .serviceUnavailable,
                .gatewayTimeout, .httpVersionNotSupported, .variantAlsoNegotiates,
                .insufficientStorage, .loopDetected, .notExtended, .networkAuthenticationRequired
            ]
            
            if let statusCode = knownStatusCodes.first(where: { $0.rawValue == rawValue }) {
                self = statusCode
            } else {
                self = .unknown
            }
        }
        
        /**
         * Creates a StatusCode from an HTTPURLResponse.
         * 
         * - Parameter response: The HTTPURLResponse to extract the status code from
         * - Returns: A StatusCode enum case
         */
        public init(from response: HTTPURLResponse) {
            self.init(rawValue: response.statusCode)
        }
    }
}
