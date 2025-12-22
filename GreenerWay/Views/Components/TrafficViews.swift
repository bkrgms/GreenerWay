import SwiftUI

struct TrafficBadgeView: View {
    let traffic: TrafficInfo?
    let isLoading: Bool
    
    var body: some View {
        if isLoading {
            HStack(spacing: 6) {
                ProgressView()
                    .scaleEffect(0.7)
                Text("Trafik kontrol ediliyor...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        } else if let traffic = traffic {
            HStack(spacing: 8) {
                Image(systemName: traffic.severity.icon)
                    .foregroundColor(severityColor(traffic.severity))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(traffic.severity.rawValue)
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text(traffic.speedText)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                if traffic.estimatedDelay > 60 {
                    Divider()
                        .frame(height: 20)
                    
                    Text(traffic.delayText)
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(severityColor(traffic.severity).opacity(0.1))
            .cornerRadius(8)
        }
    }
    
    private func severityColor(_ severity: TrafficSeverity) -> Color {
        switch severity {
        case .low: return .green
        case .moderate: return .yellow
        case .heavy: return .orange
        case .severe: return .red
        }
    }
}

// MARK: - Traffic Card (Detailed)

struct TrafficCardView: View {
    let traffic: TrafficInfo?
    let isLoading: Bool
    let onRefresh: () async -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "car.fill")
                    .foregroundColor(.blue)
                Text("Trafik Durumu")
                    .font(.headline)
                
                Spacer()
                
                Button {
                    Task { await onRefresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if isLoading {
                HStack {
                    ProgressView()
                    Text("Trafik bilgisi alınıyor...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
            } else if let traffic = traffic {
                VStack(alignment: .leading, spacing: 10) {
                    // Severity indicator
                    HStack(spacing: 12) {
                        Circle()
                            .fill(severityColor(traffic.severity))
                            .frame(width: 12, height: 12)
                        
                        Text(traffic.severity.rawValue)
                            .font(.title3)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text(traffic.speedText)
                                .font(.headline)
                            Text("ortalama hız")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Description
                    Text(traffic.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // Delay info
                    if traffic.estimatedDelay > 60 {
                        HStack {
                            Image(systemName: "clock.badge.exclamationmark")
                                .foregroundColor(.orange)
                            Text(traffic.delayText)
                                .font(.subheadline)
                                .foregroundColor(.orange)
                        }
                        .padding(.top, 4)
                    }
                    
                    // Last update
                    if let lastUpdate = TrafficService.shared.lastUpdate {
                        Text("Son güncelleme: \(lastUpdate.formatted(date: .omitted, time: .shortened))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                }
            } else {
                Text("Trafik bilgisi mevcut değil")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func severityColor(_ severity: TrafficSeverity) -> Color {
        switch severity {
        case .low: return .green
        case .moderate: return .yellow
        case .heavy: return .orange
        case .severe: return .red
        }
    }
}

// MARK: - Inline Traffic Indicator

struct TrafficIndicator: View {
    let severity: TrafficSeverity
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(severity.rawValue)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    private var color: Color {
        switch severity {
        case .low: return .green
        case .moderate: return .yellow
        case .heavy: return .orange
        case .severe: return .red
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        TrafficBadgeView(
            traffic: TrafficInfo(severity: .moderate, estimatedDelay: 300, averageSpeed: 35, description: "Trafik orta yoğunlukta"),
            isLoading: false
        )
        
        TrafficCardView(
            traffic: TrafficInfo(severity: .heavy, estimatedDelay: 600, averageSpeed: 20, description: "Trafik yoğun. Alternatif rota düşünebilirsiniz."),
            isLoading: false,
            onRefresh: {}
        )
        
        TrafficIndicator(severity: .low)
    }
    .padding()
}
