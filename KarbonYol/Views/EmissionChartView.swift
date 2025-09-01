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

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {

                Picker("", selection: $scope) {
                    ForEach(ChartScope.allCases) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.segmented)

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
                        Chart(viewModel.last7Days) { p in
                            BarMark(
                                x: .value("Gün", p.date, unit: .day),
                                y: .value("kg", p.kg)
                            )
                        }
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .day)) { _ in
                                AxisGridLine()
                                AxisTick()
                                AxisValueLabel(format: .dateTime.day().weekday(.short))
                            }
                        }
                        .frame(height: 260)

                    case .monthly:
                        Chart(viewModel.last6Months) { p in
                            BarMark(
                                x: .value("Ay", p.monthStart, unit: .month),
                                y: .value("kg", p.kg)
                            )
                        }
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .month)) { _ in
                                AxisGridLine()
                                AxisTick()
                                AxisValueLabel(format: .dateTime.month(.abbreviated))
                            }
                        }
                        .frame(height: 260)

                    case .total:
                        Chart {
                            BarMark(x: .value("Toplam", "Karbon"),
                                    y: .value("kg", viewModel.totalEmissionKg))
                        }
                        .frame(height: 220)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Yapay Zeka İçgörüsü").font(.headline)
                    Text(viewModel.insightText).foregroundColor(.secondary)
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.secondary.opacity(0.15)))

                Spacer()
            }
            .padding()
            .navigationTitle("Emisyon Grafik")
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
