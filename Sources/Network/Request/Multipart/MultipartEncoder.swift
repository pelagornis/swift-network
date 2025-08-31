import Foundation

/**
 * Encodes multipart form data for HTTP requests.
 * 
 * MultipartEncoder converts an array of MultipartFormData into the
 * proper multipart/form-data format required for file uploads and
 * complex form submissions.
 * 
 * ## Usage
 * ```swift
 * let parts = [
 *     MultipartFormData(name: "text", data: "Hello".data(using: .utf8)!),
 *     MultipartFormData(name: "file", fileName: "image.jpg", mimeType: "image/jpeg", data: imageData)
 * ]
 * 
 * let boundary = "Boundary-\(UUID().uuidString)"
 * let encodedData = MultipartEncoder.encode(parts: parts, boundary: boundary)
 * ```
 */
struct MultipartEncoder {
    /**
     * Encodes multipart form data parts into a single Data object.
     * 
     * - Parameters:
     *   - parts: Array of multipart form data parts
     *   - boundary: The boundary string to separate parts
     * - Returns: The encoded multipart form data
     */
    static func encode(parts: [MultipartFormData], boundary: String) -> Data {
        var data = Data()
        let lineBreak = "\r\n"
        for part in parts {
            data.append("--\(boundary)\(lineBreak)".data(using: .utf8)!)
            if let filename = part.fileName {
                data.append("Content-Disposition: form-data; name=\"\(part.name)\"; filename=\"\(filename)\"\(lineBreak)".data(using: .utf8)!)
            } else {
                data.append("Content-Disposition: form-data; name=\"\(part.name)\"\(lineBreak)".data(using: .utf8)!)
            }
            if let mime = part.mimeType {
                data.append("Content-Type: \(mime)\(lineBreak)".data(using: .utf8)!)
            }
            data.append(lineBreak.data(using: .utf8)!)
            data.append(part.data)
            data.append(lineBreak.data(using: .utf8)!)
        }
        data.append("--\(boundary)--\(lineBreak)".data(using: .utf8)!)
        return data
    }
}
