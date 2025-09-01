import SwiftUI
import Charts

/// Emisyon panosu: Günlük / Aylık / Toplam
struct EmissionDashboardView: View {
    enum Scope: String, CaseIterable, Identifiable {
        case daily = "Günlük"
        case monthly = "Aylık"
        case total = "Toplam"
        var id: String { rawValue }
    }

    @EnvironmentObject var viewModel: RouteViewModel
    @State private var scope: Scope

    init(initialScope: Scope = .daily) {
        _scope = State(initialValue: initialScope)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Emisyon Özeti")
                .font(.title2.bold())

            Picker("Kapsam", selection: $scope) {
                ForEach(Scope.allCases) { s in
                    Text(s.rawValue).tag(s)
                }
            }
            .pickerStyle(.segmented)

            Group {
                switch scope {
                case .daily:
                    ChartView(points: dailyPoints(7), title: "Son 7 Gün")
                case .monthly:
                    ChartView(points: monthlyPoints(6), title: "Son 6 Ay")
                case .total:
                    TotalCard(totalKg: totalEmission())
                }
            }

            // AI özet kutusu
            VStack(alignment: .leading, spacing: 8) {
                Text("AI Yorumu").font(.headline)
                Text(aiInsightComparedToYesterday())
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Spacer()
        }
        .padding()
        .navigationTitle("Emisyonlar")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Grafik Bileşenleri
private struct ChartView: View {
    let points: [ChartPoint]
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            Chart(points) {
                BarMark(
                    x: .value("Zaman", $0.label),
                    y: .value("kg CO₂", $0.value)
                )
            }
            .frame(height: 260)
        }
    }
}

private struct TotalCard: View {
    let totalKg: Double
    var body: some View {
        VStack(spacing: 8) {
            Text("Toplam Emisyon").font(.headline)
            Text(String(format: "%.2f kg CO₂", totalKg))
                .font(.system(size: 28, weight: .bold))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Yerel tipler ve yardımcılar
private struct ChartPoint: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
    let date: Date
}

private extension EmissionDashboardView {

    // Eğer RouteViewModel içinde `trips` varsa ondan toplar; yoksa mevcut rotanın emisyonunu örnek veriyle gösterir.
    func dailyPoints(_ days: Int) -> [ChartPoint] {
        let cal = Calendar.current
        let now = Date()
        var result: [ChartPoint] = []

        let tripsMirror = Mirror(reflecting: viewModel)
        let trips = tripsMirror.children.first { $0.label == "trips" }?.value as? [Any]

        for i in (0..<days).reversed() {
            let d = cal.date(byAdding: .day, value: -i, to: now)!
            let label = DateFormatter.shortDay.string(from: d)

            var sum = 0.0
            if let trips = trips {
                for any in trips {
                    if let t = any as? TripLike, cal.isDate(t.date, inSameDayAs: d) {
                        sum += t.emissionKg
                    }
                }
            } else {
                // trips yoksa: mevcut rotanın emisyonunu örnek olarak kullan
                if cal.isDateInToday(d) {
                    sum = viewModel.emissionKg()
                }
            }
            result.append(.init(label: label, value: sum, date: d))
        }
        return result
    }

    func monthlyPoints(_ months: Int) -> [ChartPoint] {
        let cal = Calendar.current
        let now = Date()
        var result: [ChartPoint] = []

        let tripsMirror = Mirror(reflecting: viewModel)
        let trips = tripsMirror.children.first { $0.label == "trips" }?.value as? [Any]

        for i in (0..<months).reversed() {
            let mDate = cal.date(byAdding: .month, value: -i, to: now)!
            let comps = cal.dateComponents([.year, .month], from: mDate)
            let label = DateFormatter.shortMonth.string(from: mDate)

            var sum = 0.0
            if let trips = trips {
                for any in trips {
                    if let t = any as? TripLike {
                        let c = cal.dateComponents([.year, .month], from: t.date)
                        if c.year == comps.year && c.month == comps.month {
                            sum += t.emissionKg
                        }
                    }
                }
            } else {
                // trips yoksa: bu ay için mevcut rotanın emisyonu
                if comps.month == cal.component(.month, from: now) && comps.year == cal.component(.year, from: now) {
                    sum = viewModel.emissionKg()
                }
            }
            result.append(.init(label: label, value: sum, date: mDate))
        }
        return result
    }

    func totalEmission() -> Double {
        let tripsMirror = Mirror(reflecting: viewModel)
        if let trips = tripsMirror.children.first(where: { $0.label == "trips" })?.value as? [Any] {
            return trips.compactMap { ($0 as? TripLike)?.emissionKg }.reduce(0, +)
        }
        return viewModel.emissionKg()
    }

    func aiInsightComparedToYesterday() -> String {
        let cal = Calendar.current
        let today = Date()
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!

        let todayKg = sum(for: today, by: .day)
        let yesterdayKg = sum(for: yesterday, by: .day)

        guard yesterdayKg > 0 else {
            if todayKg > 0 { return "Harika! Düne göre emisyon kaydı başlattınız (\(String(format: "%.2f", todayKg)) kg CO₂)." }
            return "Bugün henüz emisyon kaydı yok."
        }
        let diff = todayKg - yesterdayKg
        let pct = (abs(diff) / max(yesterdayKg, 0.0001)) * 100.0
        if diff <= 0 {
            return "Tebrikler! Düne göre %\(Int(round(pct))) daha az emisyon saldınız."
        } else {
            return "Düne göre %\(Int(round(pct))) daha fazla emisyon salındı."
        }
    }

    private func sum(for date: Date, by component: Calendar.Component) -> Double {
        let cal = Calendar.current
        let tripsMirror = Mirror(reflecting: viewModel)
        if let trips = tripsMirror.children.first(where: { $0.label == "trips" })?.value as? [Any] {
            return trips.compactMap { $0 as? TripLike }.filter {
                switch component {
                case .day:      return cal.isDate($0.date, inSameDayAs: date)
                case .month:
                    let c1 = cal.dateComponents([.year, .month], from: $0.date)
                    let c2 = cal.dateComponents([.year, .month], from: date)
                    return c1.year == c2.year && c1.month == c2.month
                default: return false
                }
            }
            .map(\.emissionKg)
            .reduce(0, +)
        }
        // trips yoksa mevcut rotanın emisyonunu kullan
        return viewModel.emissionKg()
    }
}

// MARK: - TripLike protokolü (viewModel.trips varsa uyumlulaştırmak için)
private protocol TripLike {
    var date: Date { get }
    var emissionKg: Double { get }
}

// MARK: - Tarih formatlayıcılar
private extension DateFormatter {
    static let shortDay: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "dd.MM"
        return f
    }()
    static let shortMonth: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "MMM yy"
        return f
    }()
}
