import Foundation
import FirebaseFirestore

struct Journey: Identifiable, Codable {
    @DocumentID var id: String?
    var userId: String
    var date: Date
    var distanceKm: Double
    var emissionKg: Double
    var mode: String
    var durationMin: Double? // Süre (dakika)
    var aiApplied: Bool? // AI önerisi uygulandı mı?
}
