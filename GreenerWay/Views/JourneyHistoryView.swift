import SwiftUI

struct JourneyHistoryView: View {
    @StateObject private var viewModel = JourneyHistoryViewModel()
    @State private var selectedFilter: JourneyFilter = .all
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Üst Bar
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.medium))
                        .foregroundColor(.primary)
                        .frame(width: 40, height: 40)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }
                
                Spacer()
                
                Text("Yolculuk Geçmişi")
                    .font(.headline)
                
                Spacer()
                
                // Placeholder for balance
                Color.clear.frame(width: 40, height: 40)
            }
            .padding()
            
            // Filtre
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(JourneyFilter.allCases, id: \.self) { filter in
                        FilterChip(
                            title: filter.title,
                            icon: filter.icon,
                            isSelected: selectedFilter == filter
                        ) {
                            selectedFilter = filter
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 12)
            
            // İstatistik Özeti
            HStack(spacing: 12) {
                StatMiniCard(
                    title: "Toplam",
                    value: "\(viewModel.filteredJourneys(filter: selectedFilter).count)",
                    icon: "list.bullet"
                )
                StatMiniCard(
                    title: "Mesafe",
                    value: String(format: "%.1f km", viewModel.totalDistance(filter: selectedFilter)),
                    icon: "arrow.left.and.right"
                )
                StatMiniCard(
                    title: "CO₂",
                    value: String(format: "%.1f kg", viewModel.totalEmission(filter: selectedFilter)),
                    icon: "leaf"
                )
            }
            .padding(.horizontal)
            .padding(.bottom, 12)
            
            // Liste
            if viewModel.isLoading {
                Spacer()
                ProgressView()
                    .scaleEffect(1.2)
                Spacer()
            } else if viewModel.filteredJourneys(filter: selectedFilter).isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "car.side")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Henüz yolculuk yok")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Rota oluşturarak yolculuk ekleyebilirsin")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(viewModel.filteredJourneys(filter: selectedFilter)) { journey in
                            JourneyCard(journey: journey)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
        }
        .background(Color(.systemBackground))
        .navigationBarHidden(true)
        .task {
            await viewModel.loadJourneys()
        }
    }
}

// MARK: - Journey Filter
enum JourneyFilter: String, CaseIterable {
    case all, walking, car, transit
    
    var title: String {
        switch self {
        case .all: return "Tümü"
        case .walking: return "Yürüyüş"
        case .car: return "Araba"
        case .transit: return "Otobüs"
        }
    }
    
    var icon: String {
        switch self {
        case .all: return "list.bullet"
        case .walking: return "figure.walk"
        case .car: return "car.fill"
        case .transit: return "bus.fill"
        }
    }
}

// MARK: - Filter Chip
private struct FilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? Color.primary : Color(.systemGray6))
            .foregroundColor(isSelected ? Color(.systemBackground) : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Stat Mini Card
private struct StatMiniCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Journey Card
private struct JourneyCard: View {
    let journey: Journey
    
    private var modeIcon: String {
        switch journey.mode {
        case "walking": return "figure.walk"
        case "car": return "car.fill"
        case "transit": return "bus.fill"
        default: return "mappin"
        }
    }
    
    private var modeColor: Color {
        switch journey.mode {
        case "walking": return .green
        case "car": return .blue
        case "transit": return .orange
        default: return .gray
        }
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy, HH:mm"
        formatter.locale = Locale(identifier: "tr_TR")
        return formatter.string(from: journey.date)
    }
    
    var body: some View {
        HStack(spacing: 14) {
            // Mod İkonu
            ZStack {
                Circle()
                    .fill(modeColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: modeIcon)
                    .font(.body)
                    .foregroundColor(modeColor)
            }
            
            // Bilgiler
            VStack(alignment: .leading, spacing: 4) {
                Text(formattedDate)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack(spacing: 12) {
                    Label(String(format: "%.1f km", journey.distanceKm), systemImage: "arrow.left.and.right")
                    Label(String(format: "%.2f kg", journey.emissionKg), systemImage: "leaf")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // AI Badge
            if journey.aiApplied! {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(6)
                    .background(Color.orange.opacity(0.15))
                    .clipShape(Circle())
            }
        }
        .padding(14)
        .background(Color(.systemGray6))
        .cornerRadius(14)
    }
}

#Preview {
    NavigationView {
        JourneyHistoryView()
    }
}
