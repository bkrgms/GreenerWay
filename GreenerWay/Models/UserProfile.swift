import Foundation
import FirebaseFirestore


struct UserProfile: Codable, Identifiable {
    @DocumentID var id: String?   // Firestore doküman ID (uid ile aynı olabilir)
    
    var age: Int
    var carbonSensitivity: Double
    var healthStatus: String
    var travellingWithChild: Bool
    
    // Opsiyonel ek ayarlar
    var notifications: Bool? = true
    var carbonUnit: String? = "kg"
    
    // Yeni: Kullanıcının kazandığı rozet kimlikleri
    var earnedBadgeIDs: [String]?
    
    // Firestore için default initializer
    init(age: Int,
         carbonSensitivity: Double,
         healthStatus: String,
         travellingWithChild: Bool,
         notifications: Bool? = true,
         carbonUnit: String? = "kg",
         earnedBadgeIDs: [String]? = nil) {
        
        self.age = age
        self.carbonSensitivity = carbonSensitivity
        self.healthStatus = healthStatus
        self.travellingWithChild = travellingWithChild
        self.notifications = notifications
        self.carbonUnit = carbonUnit
        self.earnedBadgeIDs = earnedBadgeIDs
    }
}
