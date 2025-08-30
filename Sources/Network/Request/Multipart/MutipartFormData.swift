import Foundation

public struct MultipartFormData: Sendable {
    public let name: String
    public let fileName: String?
    public let mimeType: String?
    public let data: Data
    
    public init(name: String,
                fileName: String? = nil,
                mimeType: String? = nil,
                data: Data) {
        self.name = name
        self.fileName = fileName
        self.mimeType = mimeType
        self.data = data
    }
}
