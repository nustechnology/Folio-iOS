import Foundation

protocol SortOptionProtocol: CaseIterable, Equatable, Hashable, Sendable {
  var rawValue: String { get }
  var displayTitle: String { get }
}
