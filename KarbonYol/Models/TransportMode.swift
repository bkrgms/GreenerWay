import Foundation

enum TransportMode: String, CaseIterable, Identifiable {
    case walking
    case car
    case transit
    var id: String { rawValue }
}
