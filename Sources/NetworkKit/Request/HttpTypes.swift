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
}
