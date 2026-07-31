import Foundation

enum JWTDecoder {
    static func decodeExpiry(_ token: String) -> Date {
        let segments = token.components(separatedBy: ".")
        guard segments.count > 1 else {
            return .distantPast
        }
        let base64URL = segments[1]
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padded = base64URL + String(repeating: "=", count: (4 - base64URL.count % 4) % 4)
        guard let data = Data(base64Encoded: padded),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = json["exp"] as? TimeInterval else {
            return .distantPast
        }
        return Date(timeIntervalSince1970: exp)
    }
}
