import Foundation

public extension Http.Header {
    static func contentType(_ type: String) -> Self {
        .init(field: "Content-Type", value: type)
    }
    
    static func accept(_ type: String) -> Self {
        .init(field: "Accept", value: type)
    }
    
    static func authorization(_ token: String) -> Self {
        .init(field: "Authorization", value: "Bearer \(token)")
    }
    
    static var json: Self {
        .contentType("application/json")
    }
    
    static var formURLEncoded: Self {
        .contentType("application/x-www-form-urlencoded")
    }
}
