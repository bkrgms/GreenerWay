import WidgetKit
import SwiftUI

// MARK: - Widget Entry

struct EmissionEntry: TimelineEntry {
    let date: Date
    let totalEmission: Double
    let savedEmission: Double
    let journeyCount: Int
    let lastMode: String
}

// MARK: - Widget Provider

struct EmissionWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> EmissionEntry {
        EmissionEntry(
            date: Date(),
            totalEmission: 2.5,
            savedEmission: 1.2,
            journeyCount: 3,
            lastMode: "walking"
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (EmissionEntry) -> Void) {
        let entry = EmissionEntry(
            date: Date(),
            totalEmission: 2.5,
            savedEmission: 1.2,
            journeyCount: 3,
            lastMode: "walking"
        )
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<EmissionEntry>) -> Void) {
        // UserDefaults'tan verileri çek (App Group kullanılmalı)
        let defaults = UserDefaults(suiteName: "group.com.greenerway.app") ?? UserDefaults.standard
        
        let totalEmission = defaults.double(forKey: "todayEmission")
        let savedEmission = defaults.double(forKey: "todaySaved")
        let journeyCount = defaults.integer(forKey: "todayJourneyCount")
        let lastMode = defaults.string(forKey: "lastMode") ?? "walking"
        
        let entry = EmissionEntry(
            date: Date(),
            totalEmission: totalEmission,
            savedEmission: savedEmission,
            journeyCount: journeyCount,
            lastMode: lastMode
        )
        
        // Her 30 dakikada bir güncelle
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        
        completion(timeline)
    }
}

// MARK: - Widget Views

struct EmissionWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: EmissionEntry
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Small Widget

struct SmallWidgetView: View {
    var entry: EmissionEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "leaf.fill")
                    .foregroundColor(.green)
                Text("GreenerWay")
                    .font(.caption)
                    .fontWeight(.bold)
            }
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Bugün")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(String(format: "%.1f", entry.savedEmission))
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    Text("kg")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text("CO₂ tasarruf")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack {
                Image(systemName: modeIcon(entry.lastMode))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(entry.journeyCount) yolculuk")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .containerBackground(.background, for: .widget)
    }
    
    private func modeIcon(_ mode: String) -> String {
        switch mode {
        case "walking": return "figure.walk"
        case "car": return "car.fill"
        case "transit": return "bus.fill"
        default: return "figure.walk"
        }
    }
}

// MARK: - Medium Widget

struct MediumWidgetView: View {
    var entry: EmissionEntry
    
    var body: some View {
        HStack(spacing: 16) {
            // Sol taraf - Tasarruf
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "leaf.fill")
                        .foregroundColor(.green)
                    Text("GreenerWay")
                        .font(.caption)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bugünkü Tasarruf")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(String(format: "%.1f", entry.savedEmission))
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                        Text("kg CO₂")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            
            Divider()
            
            // Sağ taraf - İstatistikler
            VStack(alignment: .leading, spacing: 12) {
                StatRow(icon: "car.fill", title: "Emisyon", value: String(format: "%.1f kg", entry.totalEmission), color: .orange)
                StatRow(icon: "figure.walk", title: "Yolculuk", value: "\(entry.journeyCount)", color: .blue)
                StatRow(icon: modeIcon(entry.lastMode), title: "Son Mod", value: modeName(entry.lastMode), color: .purple)
            }
        }
        .padding()
        .containerBackground(.background, for: .widget)
    }
    
    private func modeIcon(_ mode: String) -> String {
        switch mode {
        case "walking": return "figure.walk"
        case "car": return "car.fill"
        case "transit": return "bus.fill"
        default: return "figure.walk"
        }
    }
    
    private func modeName(_ mode: String) -> String {
        switch mode {
        case "walking": return "Yürüyüş"
        case "car": return "Araba"
        case "transit": return "Otobüs"
        default: return "Yürüyüş"
        }
    }
}

struct StatRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
                .frame(width: 16)
            
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.caption)
                    .fontWeight(.semibold)
            }
        }
    }
}

// MARK: - Widget Configuration
// NOT: Bu widget'ı kullanmak için Xcode'da ayrı bir Widget Extension target oluşturmanız gerekir:
// File > New > Target > Widget Extension
// Sonra bu kodları oraya taşıyın ve @main attribute'unu ekleyin.

// @main // Widget Extension target'ında bu satırı aktif edin
struct GreenerWayWidget: Widget {
    let kind: String = "GreenerWayWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: EmissionWidgetProvider()) { entry in
            EmissionWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Karbon Tasarrufu")
        .description("Günlük karbon ayak izini takip et")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    GreenerWayWidget()
} timeline: {
    EmissionEntry(date: Date(), totalEmission: 2.5, savedEmission: 1.2, journeyCount: 3, lastMode: "walking")
}

#Preview(as: .systemMedium) {
    GreenerWayWidget()
} timeline: {
    EmissionEntry(date: Date(), totalEmission: 2.5, savedEmission: 1.2, journeyCount: 3, lastMode: "walking")
}
