import Foundation

struct MultipartEncoder {
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
