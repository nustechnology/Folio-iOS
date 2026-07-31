import Foundation

enum AppConfiguration {
    static var apiBaseURL: URL {
        guard let urlString = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
              let url = URL(string: urlString) else {
#if DEBUG
            Logger.error("Missing or invalid API_BASE_URL in Info.plist, falling back to default")
            return URL(string: "https://shale-crowd-satin.ngrok-free.dev")!
#else
            fatalError("Missing or invalid API_BASE_URL in Info.plist")
#endif
        }
        return url
    }
}
