import Foundation
import FirebaseFirestore

struct Journey: Identifiable, Codable {
    @DocumentID var id: String?
    var userId: String
    var date: Date
    var distanceKm: Double
    var emissionKg: Double
    var mode: String
}
