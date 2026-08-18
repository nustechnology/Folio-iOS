import Foundation

enum AuthError: LocalizedError, Equatable {
    case invalidEmail
    case emailAlreadyExists
    case passwordTooShort
    case passwordsDoNotMatch
    case invalidCredentials
    case sessionExpired
    case sessionPersistenceFailed
    case sessionRemovalFailed
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            return String(localized: "Please enter a valid email address.")
        case .emailAlreadyExists:
            return String(localized: "An account with this email already exists")
        case .passwordTooShort:
            return String(localized: "Password must be at least 4 characters long.")
        case .passwordsDoNotMatch:
            return String(localized: "Passwords do not match.")
        case .invalidCredentials:
            return String(localized: "Invalid email or password. Please try again.")
        case .sessionExpired:
            return String(localized: "Session expired. Please sign in again.")
        case .sessionPersistenceFailed:
            return String(localized: "Unable to save your session. Please try again.")
        case .sessionRemovalFailed:
            return String(localized: "Unable to sign out securely. Please try again.")
        case .networkError(let message):
            return message
        }
    }
}
