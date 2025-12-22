import SwiftUI
import MapKit

// MARK: - Mini Harita Önizleme Bileşeni
struct MapPreviewView: View {
    @ObservedObject var viewModel: RouteViewModel
    let height: CGFloat
    let onTap: () -> Void
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Mini Harita
            MapView(viewModel: viewModel)
                .frame(height: height)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            
            // Genişlet butonu
            Button(action: onTap) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.caption)
                    Text("Genişlet")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
            }
            .padding(12)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

// MARK: - Tam Ekran Harita Sheet
struct FullscreenMapSheet: View {
    @ObservedObject var viewModel: RouteViewModel
    @Binding var droppedPin: CLLocationCoordinate2D?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Tam ekran harita (InteractiveMapView ile pin koyulabilir)
            InteractiveMapView(viewModel: viewModel, droppedPin: $droppedPin)
                .ignoresSafeArea()
            
            // Üst bar
            VStack(spacing: 0) {
                HStack {
                    // Kapat butonu
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title3.weight(.semibold))
                            .foregroundColor(.primary)
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    // Rota bilgisi
                    HStack(spacing: 12) {
                        Label(String(format: "%.1f km", viewModel.distanceMeters / 1000), systemImage: "arrow.left.and.right")
                        Label(formatDuration(viewModel.expectedTime), systemImage: "clock")
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                }
                .padding()
                
                Spacer()
            }
        }
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        if mins < 60 {
            return "\(mins) dk"
        } else {
            return "\(mins / 60) sa \(mins % 60) dk"
        }
    }
    
    @MainActor
    private func reverseGeocodePin(coordinate: CLLocationCoordinate2D) async {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let placemark = placemarks.first {
                var addressComponents: [String] = []
                
                if let street = placemark.thoroughfare {
                    addressComponents.append(street)
                }
                if let subLocality = placemark.subLocality {
                    addressComponents.append(subLocality)
                }
                if let locality = placemark.locality {
                    addressComponents.append(locality)
                }
                
                let address = addressComponents.isEmpty ? "Seçilen Konum" : addressComponents.joined(separator: ", ")
                viewModel.destinationText = address
                viewModel.destinationCoordinate = coordinate
                dismiss()
            }
        } catch {
            viewModel.destinationText = "Seçilen Konum"
            viewModel.destinationCoordinate = coordinate
            dismiss()
        }
    }
}

// MARK: - Rota Adımı Modeli
struct RouteStep: Identifiable {
    let id = UUID()
    let icon: String
    let instruction: String
    let distance: String
    let duration: String
}

// MARK: - Rota Adımları Listesi
struct RouteStepsView: View {
    let steps: [RouteStep]
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Başlık
            Button {
                withAnimation(.spring(response: 0.3)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                        .foregroundColor(.primary.opacity(0.7))
                    Text("Rota Adımları")
                        .font(.headline)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                // Adımlar listesi
                VStack(spacing: 0) {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                        HStack(spacing: 12) {
                            // Adım numarası ve ikon
                            ZStack {
                                Circle()
                                    .fill(Color(.systemGray5))
                                    .frame(width: 32, height: 32)
                                Image(systemName: step.icon)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                            }
                            
                            // Talimat
                            VStack(alignment: .leading, spacing: 2) {
                                Text(step.instruction)
                                    .font(.subheadline)
                                    .lineLimit(2)
                                HStack(spacing: 8) {
                                    Text(step.distance)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("•")
                                        .foregroundColor(.secondary)
                                    Text(step.duration)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 10)
                        
                        if index < steps.count - 1 {
                            // Bağlantı çizgisi
                            HStack {
                                Rectangle()
                                    .fill(Color(.systemGray4))
                                    .frame(width: 2, height: 16)
                                    .padding(.leading, 15)
                                Spacer()
                            }
                        }
                    }
                }
            } else {
                // Collapsed özet
                HStack(spacing: 8) {
                    Text("\(steps.count) adım")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("•")
                        .foregroundColor(.secondary)
                    Text("Detaylar için dokun")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(14)
    }
}

// MARK: - Rota Adımları Oluşturucu
@MainActor
func generateRouteSteps(from viewModel: RouteViewModel) -> [RouteStep] {
    let totalDistance = viewModel.distanceMeters
    let totalTime = viewModel.expectedTime
    let mode = viewModel.selectedMode
    
    // Basit adımlar oluştur (gerçek uygulamada MKRoute.steps kullanılır)
    var steps: [RouteStep] = []
    
    // Başlangıç
    steps.append(RouteStep(
        icon: "location.fill",
        instruction: "Başlangıç noktasından yola çık",
        distance: "-",
        duration: "-"
    ))
    
    // Mod bazlı ara adımlar
    let stepCount = min(4, max(2, Int(totalDistance / 1000)))
    let stepDistance = totalDistance / Double(stepCount)
    let stepTime = totalTime / Double(stepCount)
    
    for i in 1..<stepCount {
        let icon: String
        let instruction: String
        
        switch mode {
        case .walking:
            icon = i % 2 == 0 ? "arrow.turn.up.right" : "arrow.turn.up.left"
            instruction = i % 2 == 0 ? "Sağa dön ve yürümeye devam et" : "Sola dön ve yürümeye devam et"
        case .car:
            icon = i % 2 == 0 ? "arrow.turn.up.right" : "arrow.turn.up.left"
            instruction = i % 2 == 0 ? "Sağa dön" : "Sola dön, ana yola gir"
        case .transit:
            icon = i == 1 ? "bus.fill" : "figure.walk"
            instruction = i == 1 ? "Otobüse bin" : "Otobüsten in, yürüyerek devam et"
        }
        
        steps.append(RouteStep(
            icon: icon,
            instruction: instruction,
            distance: String(format: "%.0f m", stepDistance),
            duration: String(format: "%.0f dk", stepTime / 60)
        ))
    }
    
    // Varış
    steps.append(RouteStep(
        icon: "mappin.circle.fill",
        instruction: "Hedefe vardın",
        distance: String(format: "%.1f km", totalDistance / 1000),
        duration: String(format: "%.0f dk", totalTime / 60)
    ))
    
    return steps
}

#Preview {
    VStack {
        RouteStepsView(steps: [
            RouteStep(icon: "location.fill", instruction: "Başlangıç noktasından yola çık", distance: "-", duration: "-"),
            RouteStep(icon: "arrow.turn.up.right", instruction: "Sağa dön ve ana caddeye gir", distance: "200 m", duration: "2 dk"),
            RouteStep(icon: "arrow.turn.up.left", instruction: "Sola dön", distance: "500 m", duration: "5 dk"),
            RouteStep(icon: "mappin.circle.fill", instruction: "Hedefe vardın", distance: "1.2 km", duration: "12 dk")
        ])
    }
    .padding()
}
