import Foundation

/**
 * Represents a part of multipart form data.
 * 
 * MultipartFormData is used for file uploads and complex form submissions
 * that require multiple data types (text, files, etc.) to be sent in a
 * single request.
 * 
 * ## Usage
 * ```swift
 * let imageData = UIImage(named: "photo")?.jpegData(compressionQuality: 0.8)
 * let multipartData = MultipartFormData(
 *     name: "image",
 *     fileName: "photo.jpg",
 *     mimeType: "image/jpeg",
 *     data: imageData ?? Data()
 * )
 * ```
 */
public struct MultipartFormData: Sendable {
    /// The form field name for this part
    public let name: String
    
    /// Optional filename for file uploads
    public let fileName: String?
    
    /// Optional MIME type for the data
    public let mimeType: String?
    
    /// The actual data content
    public let data: Data
    
    /**
     * Creates a new MultipartFormData.
     * 
     * - Parameters:
     *   - name: The form field name
     *   - fileName: Optional filename for file uploads
     *   - mimeType: Optional MIME type for the data
     *   - data: The data content
     */
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
