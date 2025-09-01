import Foundation
import FirebaseAuth

@MainActor
class JourneyViewModel: ObservableObject {
    @Published var journeys: [Journey] = []
    @Published var weeklyTotal: Double = 0
    @Published var monthlyTotal: Double = 0
    @Published var allTimeTotal: Double = 0
    
    func loadJourneys() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            let list = try await FirestoreManager.shared.fetchJourneys(for: uid)
            self.journeys = list.sorted { $0.date > $1.date }
            calculateTotals()
        } catch {
            print("❌ Journey fetch error: \(error)")
        }
    }
    
    private func calculateTotals() {
        let now = Date()
        let calendar = Calendar.current
        weeklyTotal = journeys
            .filter { calendar.isDate($0.date, equalTo: now, toGranularity: .weekOfYear) }
            .reduce(0) { $0 + $1.emissionKg }
        monthlyTotal = journeys
            .filter { calendar.isDate($0.date, equalTo: now, toGranularity: .month) }
            .reduce(0) { $0 + $1.emissionKg }
        allTimeTotal = journeys.reduce(0) { $0 + $1.emissionKg }
    }
}
