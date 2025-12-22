import SwiftUI
import Charts

enum ChartScope: String, CaseIterable, Identifiable {
    case daily = "Günlük"
    case monthly = "Aylık"
    case total = "Toplam"
    var id: String { rawValue }
}

struct EmissionChartView: View {
    @ObservedObject var viewModel: EmissionStatsViewModel
    @State private var scope: ChartScope = .daily
    @State private var isLoading = false
    @State private var hasLoaded = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
            
                // Mod seçici
                VStack(alignment: .leading, spacing: 8) {
                    Text("Ulaşım Modu")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Picker("Mod", selection: $viewModel.selectedMode) {
                        Text("Yürüyüş").tag(TransportMode.walking)
                        Text("Araba").tag(TransportMode.car)
                        Text("Otobüs").tag(TransportMode.transit)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: viewModel.selectedMode) { _, newValue in
                        viewModel.setMode(newValue)
                    }
                }
                Text("🚗 Araba").tag(TransportMode.car)
                Text("🚌 Toplu Taşıma").tag(TransportMode.transit)
            }
            .pickerStyle(.segmented)
            .onChange(of: viewModel.selectedMode) { oldValue, newValue in
                Task {
                    isLoading = true
                    await viewModel.load()
                    isLoading = false
                }
            }

            Picker("Zaman Aralığı", selection: $scope) {
                ForEach(ChartScope.allCases) { s in
                    Text(s.rawValue).tag(s)
                }
            }
            .pickerStyle(.segmented)

            if isLoading {
                HStack {
                    Spacer()
                    ProgressView("Veriler yükleniyor...")
                    Spacer()
                }
                .frame(height: 300)
            } else if viewModel.last7Days.isEmpty && viewModel.totalEmissionKg == 0 {
                VStack(spacing: 16) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("Henüz yolculuk verisi yok")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Rota oluştur, 'AI'yı tercih et' veya 'Benim tercihim' butonuna bas! 🌱")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button("Yenile") {
                        Task {
                            isLoading = true
                            await viewModel.load()
                            isLoading = false
                        }
                    }
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .frame(height: 300)
            } else {
                Group {
                    switch scope {
                    case .daily:
                        let todayKg = viewModel.last7Days.last?.kg ?? 0
                        SummaryRow(label: "Bugün (kg)", value: String(format: "%.2f", todayKg))
                    case .monthly:
                        let current = viewModel.last6Months.last?.kg ?? 0
                        SummaryRow(label: "Bu Ay (kg)", value: String(format: "%.2f", current))
                    case .total:
                        SummaryRow(label: "Toplam (kg)", value: String(format: "%.2f", viewModel.totalEmissionKg))
                    }
                }

                Group {
                    switch scope {
                    case .daily:
                        if viewModel.last7Days.isEmpty {
                            Text("Bu mod için günlük veri yok")
                                .foregroundColor(.secondary)
                                .frame(height: 260)
                        } else {
                            Chart(viewModel.last7Days) { p in
                                BarMark(
                                    x: .value("Gün", p.date, unit: .day),
                                    y: .value("kg", p.kg)
                                )
                                .foregroundStyle(.green)
                            }
                            .chartXAxis {
                                AxisMarks(values: .stride(by: .day)) { _ in
                                    AxisGridLine()
                                    AxisTick()
                                    AxisValueLabel(format: .dateTime.day().weekday(.short))
                                }
                            }
                            .frame(height: 260)
                        }

                    case .monthly:
                        if viewModel.last6Months.isEmpty {
                            Text("Bu mod için aylık veri yok")
                                .foregroundColor(.secondary)
                                .frame(height: 260)
                        } else {
                            Chart(viewModel.last6Months) { p in
                                BarMark(
                                    x: .value("Ay", p.monthStart, unit: .month),
                                    y: .value("kg", p.kg)
                                )
                                .foregroundStyle(.blue)
                            }
                            .chartXAxis {
                                AxisMarks(values: .stride(by: .month)) { _ in
                                    AxisGridLine()
                                    AxisTick()
                                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                                }
                            }
                            .frame(height: 260)
                        }

                    case .total:
                        Chart {
                            BarMark(x: .value("Toplam", "Karbon"),
                                    y: .value("kg", viewModel.totalEmissionKg))
                            .foregroundStyle(.orange)
                        }
                        .frame(height: 220)
                    }
                }
            }

            // Yapay Zeka İçgörüsü – zenginleştirilmiş
            VStack(alignment: .leading, spacing: 10) {
                Text("🧠 Yapay Zeka İçgörüsü").font(.headline)

                if let rec = viewModel.recommendation {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Önerilen Mod:")
                            .foregroundColor(.secondary)
                        Text(rec.suggestedMode.rawValue.capitalized)
                            .fontWeight(.semibold)
                    }
                    Text(rec.rationale)
                        .foregroundColor(.secondary)
                    Text("Tahmini Tasarruf: \(String(format: "%.2f", rec.potentialSavingsKg)) kg CO₂")
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                } else {
                    Text("Büyük bir dönüşüm fırsatı bulunamadı. Kısa mesafelerde yürüyüşü, orta mesafelerde toplu taşımayı değerlendirebilirsin.")
                        .foregroundColor(.secondary)
                }

                if !viewModel.insights.isEmpty {
                    Divider().opacity(0.2)
                    ForEach(viewModel.insights, id: \.self) { line in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                            Text(line)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.secondary.opacity(0.1)))

            Spacer()
        }
        .padding()
        .navigationTitle("Emisyon Grafiği")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .task {
            // Sayfa açıldığında verileri otomatik yükle
            if !hasLoaded {
                isLoading = true
                await viewModel.load()
                isLoading = false
                hasLoaded = true
            }
        }
    }
}

private struct SummaryRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label).font(.headline)
            Spacer()
            Text(value).font(.title3).fontWeight(.semibold)
        }
        .padding(.vertical, 4)
    }
}

