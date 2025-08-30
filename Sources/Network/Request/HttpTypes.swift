import Foundation

public struct Http {
    public enum Method: String, Sendable {
        case get     = "GET"
        case post    = "POST"
        case put     = "PUT"
        case patch   = "PATCH"
        case delete  = "DELETE"
        case head    = "HEAD"
        case options = "OPTIONS"
    }

    public enum Task {
        case requestPlain
        case requestJSON(Encodable)
        case requestParameters([String: Any], encoding: ParameterEncoding)
        case uploadMultipart([MultipartFormData])
        case download(destination: DownloadDestination)
        case requestCustom(body: Data?, contentType: String?)
        case requestStream(InputStream, length: Int, contentType: String?)
    }
    
    public struct Header: Sendable {
        public let field: String
        public let value: String

        public init(field: String, value: String) {
            self.field = field
            self.value = value
        }
    }
}
