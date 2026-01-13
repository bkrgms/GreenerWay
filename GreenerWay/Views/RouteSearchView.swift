
import SwiftUI
import MapKit

struct RouteSearchView: View {
    @StateObject private var viewModel = RouteViewModel()
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
                Circle()
                    .fill(Color.green)
                    .frame(width: 12, height: 12)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Nereden")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Mevcut konum", text: $viewModel.originText)
                        .font(.body)
                }
            }
            .padding()
            
            Divider()
                .padding(.leading, 40)
            
            HStack(spacing: 14) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 12, height: 12)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Nereye")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Hedef konum", text: $viewModel.destinationText)
                        .font(.body)
                }
            }
            .padding()
        }
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
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
            HStack(spacing: 12) {
                Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                    .font(.title3)
                Text("Rota Oluştur")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(canCreateRouteFromInputs ? Color.primary : Color(.systemGray4))
            .foregroundColor(canCreateRouteFromInputs ? Color(.systemBackground) : .secondary)
            .cornerRadius(12)
        }
        .disabled(!canCreateRouteFromInputs)
    }
    
    // MARK: - Menu Grid
    private var menuGridSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                NavigationLink(destination: EmissionChartView(viewModel: EmissionStatsViewModel())) { MenuButtonContent(icon: "chart.bar.fill", title: "Grafikler", color: .purple) }
                NavigationLink(destination: JourneyHistoryView()) { MenuButtonContent(icon: "clock.arrow.circlepath", title: "Geçmiş", color: .blue) }
            }
            HStack(spacing: 12) {
                NavigationLink(destination: GoalsView()) { MenuButtonContent(icon: "target", title: "Hedefler", color: .green) }
                NavigationLink(destination: BadgesView()) { MenuButtonContent(icon: "trophy.fill", title: "Rozetler", color: .orange) }
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
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(isSelected ? color : Color(.systemGray5))
                        .frame(width: 52, height: 52)
                        .shadow(color: isSelected ? color.opacity(0.4) : .clear, radius: 8, y: 4)
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(isSelected ? .white : .secondary)
                }
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(isSelected ? .primary : .secondary)
                
                Text(emission)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? color.opacity(0.12) : Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? color : Color.primary.opacity(0.1), lineWidth: isSelected ? 2 : 1)
            )
            .shadow(color: isSelected ? color.opacity(0.2) : .clear, radius: 6, y: 3)
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
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(color)
            }
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
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

