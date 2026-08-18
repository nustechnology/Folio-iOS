import Foundation

enum AppConfiguration {
    static var apiBaseURL: URL {
        let urlString = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String
        guard let url = validatedBaseURL(urlString) else {
            preconditionFailure("Missing or invalid HTTPS API_BASE_URL in Info.plist")
        }
        return url
    }

    static func validatedBaseURL(_ value: String?) -> URL? {
        guard let value,
              let url = URL(string: value),
              url.scheme == "https",
              url.host != nil else {
            return nil
        }
        return url
    }
}
