import SwiftUI

extension View {
    func errorAlert(error: Binding<Error?>, onDismiss: (() -> Void)? = nil) -> some View {
        alert(
            "Error",
            isPresented: .constant(error.wrappedValue != nil),
            presenting: error.wrappedValue
        ) { _ in
            Button("OK") {
                error.wrappedValue = nil
                onDismiss?()
            }
        } message: { error in
            Text(error.localizedDescription)
        }
    }
}
