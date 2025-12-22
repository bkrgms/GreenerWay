import SwiftUI
import MapKit

struct RouteSearchView: View {
    @StateObject private var viewModel = RouteViewModel()
    @StateObject private var emissionStatsVM = EmissionStatsViewModel()
    @State private var showDetail = false
    @State private var showFullscreenMap = false
    @State private var droppedPin: CLLocationCoordinate2D?
    @EnvironmentObject var authVM: AuthViewModel

    private var canCreateRouteFromInputs: Bool {
        let destIsEmpty = viewModel.destinationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasOrigin = viewModel.originCoordinate != nil || LocationDelegate.shared.lastLocation != nil || (!viewModel.originText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && viewModel.originText != "Mevcut Konum")
        return !destIsEmpty && hasOrigin
    }

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    headerSection
                    statsSection
                    mapSection
                    locationInputSection
                    modeSection
                    routeButton
                    menuGridSection
                    NavigationLink(destination: RouteDetailView(viewModel: viewModel), isActive: $showDetail) { EmptyView() }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationBarHidden(true)
            .fullScreenCover(isPresented: $showFullscreenMap) {
                FullscreenMapSheet(viewModel: viewModel, droppedPin: $droppedPin)
            }
            .task { await emissionStatsVM.load() }
            .onAppear { LocationDelegate.shared.requestWhenInUse() }
        }
    }
    
    // MARK: - Header
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("GreenerWay")
                    .font(.system(size: 28, weight: .bold))
                Text("Çevre dostu rotanı bul 🌱")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
            HStack(spacing: 12) {
                NavigationLink(destination: ProfileSettings()) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.primary)
                }
                Button { authVM.signOut() } label: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 20))
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.top, 10)
    }
    
    // MARK: - Stats
    private var statsSection: some View {
        HStack(spacing: 12) {
            StatCard(icon: "leaf.fill", value: String(format: "%.1f", emissionStatsVM.dayEmissionKg), label: "Bugün", unit: "kg", color: .green)
            StatCard(icon: "road.lanes", value: String(format: "%.1f", emissionStatsVM.dayDistanceKm), label: "Mesafe", unit: "km", color: .blue)
            StatCard(icon: "sum", value: String(format: "%.1f", emissionStatsVM.totalEmissionKg), label: "Toplam", unit: "kg", color: .orange)
        }
    }
    
    // MARK: - Map
    private var mapSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Hedef Seç").font(.headline).fontWeight(.semibold)
                Spacer()
                Button { showFullscreenMap = true } label: {
                    Label("Büyüt", systemImage: "arrow.up.left.and.arrow.down.right")
                        .font(.caption).foregroundColor(.blue)
                }
            }
            ZStack(alignment: .bottom) {
                InteractiveMapView(viewModel: viewModel, droppedPin: $droppedPin)
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                Text("📍 Haritaya uzun basarak hedef belirle")
                    .font(.caption).foregroundColor(.white)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color.black.opacity(0.7))
                    .clipShape(Capsule()).padding(.bottom, 10)
            }
            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        }
        .onChange(of: droppedPin?.latitude) { _, _ in
            if let pin = droppedPin { Task { await reverseGeocodePin(coordinate: pin) } }
        }
    }
    
    // MARK: - Location Input
    private var locationInputSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Circle().fill(Color.green).frame(width: 12, height: 12)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Nereden").font(.caption).foregroundColor(.secondary)
                    TextField("Mevcut konum", text: $viewModel.originText).font(.body)
                }
            }.padding()
            Divider().padding(.leading, 40)
            HStack(spacing: 14) {
                Circle().fill(Color.red).frame(width: 12, height: 12)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Nereye").font(.caption).foregroundColor(.secondary)
                    TextField("Hedef konum", text: $viewModel.destinationText).font(.body)
                }
            }.padding()
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
    
    // MARK: - Mode Selection
    private var modeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ulaşım Modu").font(.headline).fontWeight(.semibold)
            HStack(spacing: 10) {
                ModeCard(icon: "figure.walk", title: "Yürüyüş", emission: "0 kg", isSelected: viewModel.selectedMode == .walking, color: .green) { viewModel.selectedMode = .walking }
                ModeCard(icon: "car.fill", title: "Araba", emission: "~0.17/km", isSelected: viewModel.selectedMode == .car, color: .blue) { viewModel.selectedMode = .car }
                ModeCard(icon: "bus.fill", title: "Otobüs", emission: "~0.08/km", isSelected: viewModel.selectedMode == .transit, color: .orange) { viewModel.selectedMode = .transit }
            }
        }
    }
    
    // MARK: - Route Button
    private var routeButton: some View {
        Button {
            Task { await viewModel.buildRoute(); showDetail = true }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "arrow.triangle.turn.up.right.diamond.fill").font(.title3)
                Text("Rota Oluştur").font(.headline).fontWeight(.bold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(canCreateRouteFromInputs ? Color.black : Color(.systemGray4))
            .foregroundColor(canCreateRouteFromInputs ? .white : .gray)
            .cornerRadius(16)
        }
        .disabled(!canCreateRouteFromInputs)
        .shadow(color: canCreateRouteFromInputs ? .black.opacity(0.2) : .clear, radius: 8, y: 4)
    }
    
    // MARK: - Menu Grid
    private var menuGridSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                NavigationLink(destination: EmissionChartView(viewModel: emissionStatsVM)) { MenuButtonContent(icon: "chart.bar.fill", title: "Grafikler", color: .purple) }
                NavigationLink(destination: JourneyHistoryView()) { MenuButtonContent(icon: "clock.arrow.circlepath", title: "Geçmiş", color: .blue) }
                NavigationLink(destination: GoalsView()) { MenuButtonContent(icon: "target", title: "Hedefler", color: .green) }
            }
            HStack(spacing: 12) {
                NavigationLink(destination: BadgesView()) { MenuButtonContent(icon: "trophy.fill", title: "Rozetler", color: .orange) }
                NavigationLink(destination: NotificationSettingsView()) { MenuButtonContent(icon: "bell.fill", title: "Bildirimler", color: .red) }
                NavigationLink(destination: ProfileSettings()) { MenuButtonContent(icon: "gearshape.fill", title: "Ayarlar", color: .gray) }
            }
        }
    }
    
    // MARK: - Reverse Geocoding
    @MainActor
    private func reverseGeocodePin(coordinate: CLLocationCoordinate2D) async {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let p = placemarks.first {
                var parts: [String] = []
                if let s = p.thoroughfare { parts.append(s) }
                if let sub = p.subLocality { parts.append(sub) }
                if let c = p.locality { parts.append(c) }
                viewModel.destinationText = parts.isEmpty ? "Seçilen Konum" : parts.joined(separator: ", ")
                viewModel.destinationCoordinate = coordinate
            }
        } catch {
            viewModel.destinationText = "Seçilen Konum"
            viewModel.destinationCoordinate = coordinate
        }
    }
}

// MARK: - Stat Card
private struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            VStack(spacing: 2) {
                HStack(spacing: 2) {
                    Text(value)
                        .font(.system(size: 20, weight: .bold))
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(color.opacity(0.1))
        .cornerRadius(14)
    }
}

// MARK: - Mode Card
private struct ModeCard: View {
    let icon: String
    let title: String
    let emission: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isSelected ? color : Color(.systemGray5))
                        .frame(width: 48, height: 48)
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(isSelected ? .white : .primary)
                }
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(emission)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isSelected ? color.opacity(0.15) : Color(.systemBackground))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? color : Color(.systemGray4), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Menu Button
private struct MenuButtonContent: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
            }
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(.systemBackground))
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.03), radius: 3, y: 2)
    }
}

// MARK: - Eski Uyumluluk
struct TransportModeChip: View {
    let title: String
    let system: String
    let color: Color
    let mode: TransportMode
    @Binding var selected: TransportMode
    
    var body: some View {
        Button { selected = mode } label: {
            VStack(spacing: 6) {
                Image(systemName: system).font(.title2)
                Text(title).font(.caption)
            }
            .frame(width: 90, height: 64)
            .background(selected == mode ? Color.primary : Color(.systemGray6))
            .foregroundColor(selected == mode ? Color(.systemBackground) : .primary)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}
