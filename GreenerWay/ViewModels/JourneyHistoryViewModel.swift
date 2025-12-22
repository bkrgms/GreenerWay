import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
class JourneyHistoryViewModel: ObservableObject {
    @Published var journeys: [Journey] = []
    @Published var isLoading = false
    
    private let db = Firestore.firestore()
    
    func loadJourneys() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ JourneyHistory: Kullanıcı oturum açmamış")
            return
        }
        
        isLoading = true
        
        do {
            let snapshot = try await db.collection("journeys")
                .whereField("userId", isEqualTo: userId)
                .getDocuments()
            
            var loadedJourneys: [Journey] = []
            
            for doc in snapshot.documents {
                let data = doc.data()
                
                let date: Date
                if let timestamp = data["date"] as? Timestamp {
                    date = timestamp.dateValue()
                } else {
                    date = Date()
                }
                
                let journey = Journey(
                    id: doc.documentID,
                    userId: userId,
                    date: date,
                    distanceKm: data["distanceKm"] as? Double ?? 0,
                    emissionKg: data["emissionKg"] as? Double ?? 0,
                    mode: data["mode"] as? String ?? "car",
                    durationMin: data["durationMin"] as? Double ?? 0,
                    aiApplied: data["aiApplied"] as? Bool ?? false
                )
                loadedJourneys.append(journey)
            }
            
            // Tarihe göre sırala (en yeni önce)
            journeys = loadedJourneys.sorted { $0.date > $1.date }
            
            print("✅ JourneyHistory: \(journeys.count) yolculuk yüklendi")
            
        } catch {
            print("❌ JourneyHistory hata: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    func filteredJourneys(filter: JourneyFilter) -> [Journey] {
        switch filter {
        case .all:
            return journeys
        case .walking:
            return journeys.filter { $0.mode == "walking" }
        case .car:
            return journeys.filter { $0.mode == "car" }
        case .transit:
            return journeys.filter { $0.mode == "transit" }
        }
    }
    
    func totalDistance(filter: JourneyFilter) -> Double {
        filteredJourneys(filter: filter).reduce(0) { $0 + $1.distanceKm }
    }
    
    func totalEmission(filter: JourneyFilter) -> Double {
        filteredJourneys(filter: filter).reduce(0) { $0 + $1.emissionKg }
    }
}
