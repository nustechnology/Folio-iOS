import Foundation

enum Validator {
    private static let emailPattern = #"^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#

    static func isValidEmail(_ email: String) -> Bool {
        guard !email.isEmpty else { return false }
        return email.range(of: emailPattern, options: .regularExpression) != nil
    }

    static func isValidPassword(_ password: String) -> Bool {
        password.count >= 4
    }
}
