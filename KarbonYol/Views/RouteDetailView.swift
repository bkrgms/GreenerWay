import SwiftUI
import MapKit

struct RouteDetailView: View {
    @ObservedObject var viewModel: RouteViewModel
    @State private var pushChart = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // HARİTA
                MapView(viewModel: viewModel)
                    .frame(height: 250)
                    .cornerRadius(12)

                // BAŞLIK
                Text("🧭 Rota Özeti")
                    .font(.title3).bold()

                // ÖZET BİLGİLER (alt alta ve net)
                VStack(alignment: .leading, spacing: 8) {
                    SummaryRow(label: "Ulaşım", value: viewModel.selectedMode.rawValue.capitalized)
                    SummaryRow(label: "Mesafe", value: "\(String(format: "%.1f", viewModel.distanceMeters / 1000)) km")
                    SummaryRow(label: "Süre", value: "\(Int(viewModel.expectedTime / 60)) dk")
                    SummaryRow(label: "Varış", value: Date().addingTimeInterval(viewModel.expectedTime)
                        .formatted(date: .omitted, time: .shortened))
                    SummaryRow(label: "Karbon", value: "\(String(format: "%.2f", viewModel.emissionKg())) kg CO₂")

                    // İsteğe bağlı: Ortalama hız
                    if viewModel.expectedTime > 0 {
                        let km = viewModel.distanceMeters / 1000
                        let h = viewModel.expectedTime / 3600
                        SummaryRow(label: "Ort. Hız", value: "\(String(format: "%.1f", km / h)) km/s")
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.secondary.opacity(0.1)))

                // HAVA DURUMU (weatherInfo varsa)
                if let w = viewModel.weatherInfo {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("☁️ Hava Durumu").font(.headline)

                        SummaryRow(label: "Durum", value: w.condition.displayText)
                        SummaryRow(label: "Sıcaklık", value: "\(String(format: "%.1f", w.temperatureC))°C")

                        // Alanlar bazı projelerde opsiyonel, bazılarında zorunlu olabiliyor.
                        // Derleme hatası yaşamamak için Mirror ile güvenli okuyoruz.
                        let m = Mirror(reflecting: w)
                        if let feels = m.descendant("feelsLikeC") as? Double {
                            SummaryRow(label: "Hissedilen", value: "\(String(format: "%.1f", feels))°C")
                        }
                        if let hum = (m.descendant("humidity") as? Double).map({ Int($0) }) {
                            SummaryRow(label: "Nem", value: "\(hum)%")
                        } else if let humInt = m.descendant("humidity") as? Int {
                            SummaryRow(label: "Nem", value: "\(humInt)%")
                        }
                        if let wind = m.descendant("windSpeed") as? Double {
                            SummaryRow(label: "Rüzgar", value: "\(String(format: "%.1f", wind)) m/s")
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.06))
                    .cornerRadius(14)
                }

                // YAPAY ZEKA İÇGÖRÜSÜ (emisyon karşılaştırmalı öneri)
                AIInsightCard(distanceMeters: viewModel.distanceMeters,
                              selected: viewModel.selectedMode)

                // ---- İKİ BUTON ----
                VStack(spacing: 12) {

                    // 1) AI ile en düşük emisyonu uygula
                    Button {
                        let best = bestModeForCurrentDistance()
                        if best != viewModel.selectedMode {
                            viewModel.selectedMode = best
                        }
                        Task { await viewModel.buildRoute() }
                    } label: {
                        HStack {
                            Image(systemName: "wand.and.stars")
                            Text("AI ile en düşük emisyonu uygula")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }

                    // 2) Emisyon grafiği sayfasına git
                    NavigationLink(isActive: $pushChart) {
                        EmissionChartView(viewModel: EmissionStatsViewModel())
                    } label: {
                        EmptyView()
                    }   

                    Button {
                        pushChart = true
                    } label: {
                        HStack {
                            Image(systemName: "chart.bar.fill")
                            Text("Emisyon grafiği")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
                .padding(.top, 4)

                Spacer(minLength: 8)
            }
            .padding()
        }
        .navigationTitle("Rota Detayı")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - İç yardımcılar

    private func emissionKg(for mode: TransportMode) -> Double {
        let km = viewModel.distanceMeters / 1000
        let factor: Double
        switch mode {
        case .walking: factor = 0.0
        case .car:     factor = 0.192
        case .transit: factor = 0.105
        }
        return km * factor
    }

    private func bestModeForCurrentDistance() -> TransportMode {
        let modes: [TransportMode] = [.walking, .car, .transit]
        return modes.min { emissionKg(for: $0) < emissionKg(for: $1) } ?? viewModel.selectedMode
    }
}

// MARK: - Alt görünümler

private struct SummaryRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label).foregroundColor(.secondary)
            Spacer()
            Text(value).fontWeight(.semibold)
        }
    }
}

/// Seçili moda göre diğer modların emisyon farkını hesaplar ve kısa öneri üretir.
private struct AIInsightCard: View {
    let distanceMeters: Double
    let selected: TransportMode

    private func emissionKg(for mode: TransportMode) -> Double {
        let km = distanceMeters / 1000
        let factor: Double
        switch mode {
        case .walking: factor = 0.0
        case .car:     factor = 0.192
        case .transit: factor = 0.105
        }
        return km * factor
    }

    private var insightText: String {
        let current = emissionKg(for: selected)

        let otherModes: [TransportMode] = [.walking, .car, .transit].filter { $0 != selected }
        let comparisons = otherModes.map { ($0, emissionKg(for: $0)) }
                                    .sorted { $0.1 < $1.1 }

        guard let best = comparisons.first else { return "Veri bulunamadı." }

        if best.1 + 0.0001 < current {
            let diff = current - best.1
            let pct = current > 0 ? Int((diff / current) * 100) : 100
            return "\(selected.rawValue.capitalized) yerine \(best.0.rawValue.capitalized) seçersen tahmini \(String(format: "%.2f", diff)) kg CO₂ (≈%\(pct)) daha az salınım yaparsın."
        } else if abs(best.1 - current) <= 0.0001 {
            return "Seçtiğin mod emisyon açısından zaten en iyi seçenek 🌿"
        } else {
            return "Bu rota için emisyonlar benzer seviyede görünüyor."
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("🧠 Yapay Zeka İçgörüsü").font(.headline)

            // Seçili ve alternatif emisyonları tablo gibi göster
            VStack(spacing: 6) {
                EmissionLine(mode: selected, kg: emissionKg(for: selected), isSelected: true)
                ForEach([TransportMode.walking, .car, .transit].filter { $0 != selected }, id: \.rawValue) { m in
                    EmissionLine(mode: m, kg: emissionKg(for: m), isSelected: false)
                }
            }

            Text(insightText)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.secondary.opacity(0.1)))
    }

    private struct EmissionLine: View {
        let mode: TransportMode
        let kg: Double
        let isSelected: Bool
        var body: some View {
            HStack {
                Text(mode.rawValue.capitalized)
                Spacer()
                Text("\(String(format: "%.2f", kg)) kg CO₂")
                    .fontWeight(isSelected ? .bold : .regular)
                    .foregroundColor(isSelected ? .primary : .secondary)
            }
        }
    }
}
