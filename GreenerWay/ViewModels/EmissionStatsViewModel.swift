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

// Öneri modeli
struct EmissionRecommendation {
    let suggestedMode: TransportMode
    let rationale: String
    let potentialSavingsKg: Double
    let affectedTripsCount: Int
    let sampleRule: String
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

    // Gelişmiş içgörüler
    @Published var insights: [String] = []
    @Published var recommendation: EmissionRecommendation?

    // Data
    private var records: [JourneyRecord] = []
    private let db = Firestore.firestore()
    private var profile: UserProfile?

    // MARK: Public API
    func load() async {
        await fetchJourneys()
        await fetchProfile()
        computeAll()
    }

    func setDay(_ date: Date) {
        today = date
        computeDaily()
        computeInsightsAdvanced()
    }

    func setMode(_ mode: TransportMode) {
        selectedMode = mode
        computeDaily()
        computeLast7Days()
        computeLast6Months()
        computeTotal()
        computeInsightsAdvanced()
    }

    // MARK: Firestore fetch
    private func fetchJourneys() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("❌ EmissionStats: Kullanıcı oturum açmamış")
            records = []
            return
        }
        
        print("🔄 EmissionStats: Firebase'den yolculuklar çekiliyor... (uid: \(uid))")
        
        do {
            // Index hatası için geçici çözüm: order(by:) kullanmadan çekip uygulama tarafında sırala
            let snapshot = try await db.collection("journeys")
                .whereField("userId", isEqualTo: uid)
                .getDocuments()
            
            print("✅ EmissionStats: \(snapshot.documents.count) doküman bulundu")
            
            // Parse ve tarihe göre sırala
            var tempRecords: [JourneyRecord] = []
            for doc in snapshot.documents {
                let data = doc.data()
                let ts = (data["date"] as? Timestamp)?.dateValue() ?? (data["date"] as? Date) ?? Date()
                let mode = (data["mode"] as? String) ?? "car"
                let distanceKm = (data["distanceKm"] as? Double) ?? 0
                let emissionKg = (data["emissionKg"] as? Double) ?? 0
                let durationMin = data["durationMin"] as? Double
                
                let record = JourneyRecord(
                    date: ts,
                    mode: mode,
                    distanceKm: distanceKm,
                    emissionKg: emissionKg,
                    durationMin: durationMin
                )
                tempRecords.append(record)
            }
            
            // Tarihe göre sırala (eskiden yeniye)
            records = tempRecords.sorted { $0.date < $1.date }
            
            print("✅ EmissionStats: \(records.count) yolculuk işlendi")
            
            // Debug: İlk birkaç kaydı yazdır
            if !records.isEmpty {
                print("📊 İlk kayıt: Mod=\(records[0].mode), Emisyon=\(String(format: "%.2f", records[0].emissionKg))kg, Tarih=\(records[0].date)")
            } else {
                print("⚠️ EmissionStats: Kayıt bulunamadı")
            }
        } catch {
            print("❌ fetchJourneys error: \(error.localizedDescription)")
            records = []
        }
    }

    private func fetchProfile() async {
        do {
            self.profile = try await FirestoreManager.shared.fetchUserProfile()
        } catch {
            print("❌ fetchProfile error: \(error)")
            self.profile = nil
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

    private func emissionFactor(for mode: TransportMode) -> Double {
        switch mode {
        case .walking: return 0.0
        case .car:     return 0.192   // kg/km
        case .transit: return 0.105
        }
    }

    private func lastNDays(_ n: Int, from ref: Date = Date()) -> (start: Date, end: Date) {
        let cal = Calendar.current
        let end = cal.startOfDay(for: ref)
        let start = cal.date(byAdding: .day, value: -n + 1, to: end) ?? end
        return (start, end)
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

    // Yeni: Çok metrikli ve kişiselleştirilmiş içgörü
    private func computeInsightsAdvanced() {
        var newInsights: [String] = []

        // 1) Karbon yoğunluğu (kg/km)
        let factor = emissionFactor(for: selectedMode)
        newInsights.append("Seçili modun karbon yoğunluğu ≈ \(String(format: "%.3f", factor)) kg/km.")

        // 2) Haftanın günü paterni
        let weekdayFormatter = DateFormatter()
        weekdayFormatter.locale = Locale.current
        weekdayFormatter.dateFormat = "EEEE" // Pazartesi, Salı...

        let cal = Calendar.current
        var byWeekdayKg: [Int: Double] = [:] // 1...7
        for r in records where r.mode == selectedMode.rawValue {
            let wd = cal.component(.weekday, from: r.date)
            byWeekdayKg[wd, default: 0] += r.emissionKg
        }
        if let maxEntry = byWeekdayKg.max(by: { $0.value < $1.value }),
           let exampleDate = cal.date(from: DateComponents(weekday: maxEntry.key)) {
            newInsights.append("Bu modda en fazla emisyon genellikle \(weekdayFormatter.string(from: exampleDate)) günleri oluşuyor.")
        }

        // 3) Aylık trend (son ay vs bir önceki ay)
        if last6Months.count >= 2 {
            let last = last6Months.last!.kg
            let prev = last6Months[last6Months.count - 2].kg
            if prev > 0 {
                let change = (last - prev) / prev * 100
                if change < -5 {
                    newInsights.append("Son aya göre %\(Int(abs(change))) daha AZ emisyon.")
                } else if change > 5 {
                    newInsights.append("Son aya göre %\(Int(change)) daha FAZLA emisyon.")
                } else {
                    newInsights.append("Son ay ile bir önceki ay benzer seviyede.")
                }
            }
        }

        // 4) Kişiselleştirilmiş eşikler
        var walkMaxKm: Double = 1.8
        var transitMaxKm: Double = 12.0

        if let p = profile {
            if p.age >= 60 { walkMaxKm -= 0.5 }
            if p.healthStatus.lowercased().contains("kronik") { walkMaxKm -= 0.7 }
            if p.travellingWithChild { walkMaxKm -= 0.5 }

            // Karbon duyarlılığı yüksekse toplu taşımayı biraz daha fazla öner
            if p.carbonSensitivity >= 0.7 { transitMaxKm += 6 }
            if p.carbonSensitivity <= 0.3 { transitMaxKm -= 2 }
        }

        walkMaxKm = max(0.5, walkMaxKm)
        transitMaxKm = max(6.0, transitMaxKm)

        // 5) Son 30 gün: kısa/orta araba yolculuklarını dönüştürme simülasyonu
        let window = lastNDays(30)
        let last30 = records.filter { $0.date >= window.start && $0.date <= window.end }

        let carTrips = last30.filter { $0.mode == TransportMode.car.rawValue }
        let carFactor = emissionFactor(for: .car)
        let transitFactor = emissionFactor(for: .transit)

        var walkConvertibleCount = 0
        var walkConvertibleSavings = 0.0

        var transitConvertibleCount = 0
        var transitConvertibleSavings = 0.0

        for r in carTrips {
            if r.distanceKm <= walkMaxKm {
                // Araba -> Yürüyüş
                let saved = carFactor * r.distanceKm // yürüme 0
                walkConvertibleCount += 1
                walkConvertibleSavings += saved
            } else if r.distanceKm <= transitMaxKm {
                // Araba -> Toplu taşıma
                let saved = (carFactor - transitFactor) * r.distanceKm
                if saved > 0 {
                    transitConvertibleCount += 1
                    transitConvertibleSavings += saved
                }
            }
        }

        // 6) Öneri çıkarımı
        var best: EmissionRecommendation?
        if walkConvertibleSavings >= transitConvertibleSavings, walkConvertibleCount > 0 {
            best = EmissionRecommendation(
                suggestedMode: .walking,
                rationale: "Son 30 günde \(walkConvertibleCount) kısa araba yolculuğu (≤ \(String(format: "%.1f", walkMaxKm)) km) tespit edildi.",
                potentialSavingsKg: walkConvertibleSavings,
                affectedTripsCount: walkConvertibleCount,
                sampleRule: "≤ \(String(format: "%.1f", walkMaxKm)) km için yürüyüşü tercih et."
            )
        } else if transitConvertibleCount > 0 {
            best = EmissionRecommendation(
                suggestedMode: .transit,
                rationale: "Son 30 günde \(transitConvertibleCount) orta mesafe araba yolculuğu (≤ \(String(format: "%.1f", transitMaxKm)) km) tespit edildi.",
                potentialSavingsKg: transitConvertibleSavings,
                affectedTripsCount: transitConvertibleCount,
                sampleRule: "≤ \(String(format: "%.1f", transitMaxKm)) km için toplu taşımayı tercih et."
            )
        }

        // 7) İçgörüleri toparla
        if let best {
            let rounded = String(format: "%.2f", best.potentialSavingsKg)
            newInsights.insert("Öneri: \(best.sampleRule) Tahmini tasarruf: \(rounded) kg CO₂.", at: 0)
        } else {
            newInsights.insert("Mevcut yolculuklarında büyük bir dönüşüm fırsatı görünmüyor. Yine de kısa mesafelerde yürüyüş iyi bir seçenek 🌿", at: 0)
        }

        // 8) Sonuçları yayınla
        self.recommendation = best
        self.insights = newInsights
    }

    private func computeAll() {
        computeDaily()
        computeLast7Days()
        computeLast6Months()
        computeTotal()
        computeInsightsAdvanced()
    }
}

