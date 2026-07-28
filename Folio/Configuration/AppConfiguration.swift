import Foundation

enum AppConfiguration {
    enum Error: Swift.Error {
        case missingKey(String)
    }

    static var apiBaseURL: URL {
        guard let urlString = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
              let url = URL(string: urlString) else {
            fatalError("Missing or invalid API_BASE_URL in Info.plist")
        }
        return url
    }
}
