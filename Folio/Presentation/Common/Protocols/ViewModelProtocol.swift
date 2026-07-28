import SwiftUI
import Combine

protocol ViewModelProtocol: ObservableObject {
    associatedtype State
    associatedtype Action

    var state: State { get }

    func handle(_ action: Action)
}
