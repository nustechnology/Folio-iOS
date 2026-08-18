import SwiftUI

struct ErrorView: View {
    let message: String
    let retryAction: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(Color.folioGold)

            Text(String(localized: "Something went wrong"))
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundColor(Color.folioInkSoft)
                .multilineTextAlignment(.center)

            if let retryAction {
                Button(action: retryAction) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text(String(localized: "Retry"))
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
    }
}

#Preview {
    ErrorView(message: "Network connection lost") {
        print("Retry tapped")
    }
}
