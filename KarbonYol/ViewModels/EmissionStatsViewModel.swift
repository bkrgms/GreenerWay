import Foundation
import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - Grafik noktaları
struct EmissionDayPoint: Identifiable {
    let id = UUID()
    let date: Date
    let kg: Double
}

struct EmissionMonthPoint: Identifiable {
    let id = UUID()
    let monthStart: Date
    let kg: Double
}

// MARK: - ViewModel
@MainActor
final class EmissionStatsViewModel: ObservableObject {

    struct JourneyRecord {
        let date: Date
        let mode: String
        let distanceKm: Double
        let emissionKg: Double
        let durationMin: Double?
    }

    // Seçimler
    @Published var today: Date = Date()
    @Published var selectedMode: TransportMode = .car

    // Günlük özet
    @Published var dayDistanceKm: Double = 0
    @Published var dayEmissionKg: Double = 0
    @Published var dayDurationMin: Double = 0

    // Grafik verileri
    @Published var last7Days: [EmissionDayPoint] = []
    @Published var last6Months: [EmissionMonthPoint] = []
    @Published var totalEmissionKg: Double = 0

    // İçgörü
    @Published var insightText: String = "Yükleniyor…"

    // Data
    private var records: [JourneyRecord] = []
    private let db = Firestore.firestore()

    // MARK: Public API
    func load() async {
        await fetchJourneys()
        computeAll()
    }

    func setDay(_ date: Date) {
        today = date
        computeDaily()
        computeInsights()
    }

    func setMode(_ mode: TransportMode) {
        selectedMode = mode
        computeDaily()
        computeLast7Days()
        computeLast6Months()
        computeTotal()
        computeInsights()
    }

    // MARK: Firestore fetch
    private func fetchJourneysQuery() -> Query? {
        guard let uid = Auth.auth().currentUser?.uid else { return nil }
        return db.collection("journeys")
            .whereField("userId", isEqualTo: uid)
            .order(by: "date", descending: false)
    }

    private func parseDoc(_ data: [String: Any]) -> JourneyRecord? {
        let ts = (data["date"] as? Timestamp)?.dateValue() ?? (data["date"] as? Date) ?? Date()
        let mode = (data["mode"] as? String) ?? "car"
        let distanceKm = (data["distanceKm"] as? Double) ?? 0
        let emissionKg = (data["emissionKg"] as? Double) ?? 0
        let durationMin = data["durationMin"] as? Double
        return JourneyRecord(date: ts, mode: mode, distanceKm: distanceKm, emissionKg: emissionKg, durationMin: durationMin)
    }

    private func fetchJourneys() async {
        guard let q = fetchJourneysQuery() else { return }
        do {
            let snap = try await q.getDocuments()
            records = snap.documents.compactMap { parseDoc($0.data()) }
        } catch {
            print("❌ fetchJourneys error: \(error)")
            records = []
        }
    }

    // MARK: Helpers
    private func isSameDay(_ a: Date, _ b: Date) -> Bool {
        Calendar.current.isDate(a, inSameDayAs: b)
    }

    private func monthStart(_ date: Date) -> Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: date)
        return cal.date(from: comps) ?? date
    }

    // MARK: Compute
    private func computeDaily() {
        let modeRaw = selectedMode.rawValue
        let dayRecs = records.filter { isSameDay($0.date, today) && $0.mode == modeRaw }
        dayDistanceKm = dayRecs.reduce(0) { $0 + $1.distanceKm }
        dayEmissionKg = dayRecs.reduce(0) { $0 + $1.emissionKg }
        dayDurationMin = dayRecs.reduce(0) { $0 + ($1.durationMin ?? 0) }
    }

    private func computeLast7Days() {
        let cal = Calendar.current
        let end = cal.startOfDay(for: Date())
        guard let start = cal.date(byAdding: .day, value: -6, to: end) else { return }
        var pts: [EmissionDayPoint] = []
        for i in 0..<7 {
            guard let d = cal.date(byAdding: .day, value: i, to: start) else { continue }
            let kg = records
                .filter { isSameDay($0.date, d) && $0.mode == selectedMode.rawValue }
                .reduce(0) { $0 + $1.emissionKg }
            pts.append(EmissionDayPoint(date: d, kg: kg))
        }
        last7Days = pts
    }

    private func computeLast6Months() {
        let cal = Calendar.current
        let base = monthStart(Date())
        var pts: [EmissionMonthPoint] = []
        for i in stride(from: 5, through: 0, by: -1) {
            guard let m = cal.date(byAdding: .month, value: -i, to: base) else { continue }
            let next = cal.date(byAdding: .month, value: 1, to: m) ?? m
            let kg = records
                .filter { $0.mode == selectedMode.rawValue && $0.date >= m && $0.date < next }
                .reduce(0) { $0 + $1.emissionKg }
            pts.append(EmissionMonthPoint(monthStart: m, kg: kg))
        }
        last6Months = pts
    }

    private func computeTotal() {
        totalEmissionKg = records
            .filter { $0.mode == selectedMode.rawValue }
            .reduce(0) { $0 + $1.emissionKg }
    }

    private func computeInsights() {
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: today)
        let yesterday = cal.date(byAdding: .day, value: -1, to: todayStart) ?? todayStart

        let todayKg = records
            .filter { isSameDay($0.date, todayStart) && $0.mode == selectedMode.rawValue }
            .reduce(0) { $0 + $1.emissionKg }

        let yestKg = records
            .filter { isSameDay($0.date, yesterday) && $0.mode == selectedMode.rawValue }
            .reduce(0) { $0 + $1.emissionKg }

        if yestKg == 0 {
            if todayKg == 0 {
                insightText = "Bugün henüz emisyon yok. Harika, sıfır salınım! 🌿"
            } else {
                // 🔧 Burada kaçan tırnak sorunu düzeltilmiştir
                insightText = "Düne göre daha fazla aktivite var: bugün \(String(format: "%.2f", todayKg)) kg CO₂."
            }
        } else {
            let change = (todayKg - yestKg) / yestKg * 100
            if change < 0 {
                insightText = "Düne göre %\(abs(Int(change))) daha AZ emisyon 👏"
            } else if change > 0 {
                insightText = "Düne göre %\(Int(change)) daha FAZLA emisyon."
            } else {
                insightText = "Dün ile aynı seviyede emisyon."
            }
        }
    }

    private func computeAll() {
        computeDaily()
        computeLast7Days()
        computeLast6Months()
        computeTotal()
        computeInsights()
    }
}
