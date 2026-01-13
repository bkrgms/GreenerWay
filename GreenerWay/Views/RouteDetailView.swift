import SwiftUI
import MapKit
import CoreLocation

struct RouteDetailView: View {
    @ObservedObject var viewModel: RouteViewModel
    @State private var showEmissionChart = false
    @StateObject private var emissionStatsVM = EmissionStatsViewModel()
    @StateObject private var badgeVM = BadgeViewModel()
    @StateObject private var trafficService = TrafficService.shared

    // User profile and AI recommendation
    @State private var userProfile: UserProfile?
    @State private var recommendation: AIRecommendation?
    @State private var trafficInfo: TrafficInfo?

    // Transit input field (visual only)
    @State private var busConsumptionField: String = ""
    // Snapshot of user preferred mode coming from search view
    @State private var userPreferredMode: TransportMode?
    
    // Validation
    @State private var showTransitWarning = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                mapSection()
                routeHeaderSection()
                titleSection()
                summaryCardSection()
                trafficSection()
                weatherDetailSection()
                transitSection()
                aiInsightSection()
                actionButtonsSection()
                Spacer(minLength: 8)
            }
            .padding()
        }
        .navigationTitle("Rota Detayı")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if viewModel.routePolyline == nil, viewModel.canCreateRoute {
                await viewModel.buildRoute()
            }
            if busConsumptionField.isEmpty, let v = viewModel.busConsumptionPer100 {
                busConsumptionField = String(format: "%.1f", v)
            }
            await loadUserProfileIfNeeded()
            await refreshAIRecommendation()
            await badgeVM.loadUserStats()
            await fetchTrafficInfo()
        }
        .alert("🎉 Yeni Rozet!", isPresented: $badgeVM.showBadgeUnlockedAlert) {
            Button("Harika!", role: .cancel) {}
        } message: {
            if let badge = badgeVM.recentlyUnlocked {
                Text("\(badge.title) rozetini kazandın!\n+\(badge.points) puan")
            }
        }
        .onAppear {
            // Ensure location permission and start
            LocationDelegate.shared.requestWhenInUse()
            LocationDelegate.shared.start()

            if viewModel.originText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                viewModel.originText = "Mevcut Konum"
            }

            if userPreferredMode == nil {
                userPreferredMode = viewModel.selectedMode
            }
            Task {
                if viewModel.routePolyline == nil, viewModel.canCreateRoute {
                    await viewModel.buildRoute()
                    await refreshAIRecommendation()
                }
            }
        }
        .onDisappear {
            viewModel.routePolyline = nil
        }
        // iOS 17+ onChange
        .onChange(of: viewModel.canCreateRoute, initial: false) { _, canCreate in
            guard canCreate else { return }
            Task {
                if viewModel.routePolyline == nil {
                    await viewModel.buildRoute()
                    await refreshAIRecommendation()
                }
            }
        }
        .onChange(of: viewModel.selectedMode, initial: false) { _, _ in
            Task { await refreshAIRecommendation() }
        }
        .onChange(of: viewModel.distanceMeters, initial: false) { _, _ in
            Task { await refreshAIRecommendation() }
        }
        .onChange(of: viewModel.expectedTime, initial: false) { _, _ in
            Task { await refreshAIRecommendation() }
        }
        .onChange(of: viewModel.weatherInfo?.condition, initial: false) { _, _ in
            Task { await refreshAIRecommendation() }
        }
        .onChange(of: viewModel.busFuelType, initial: false) { _, _ in
            Task { await refreshAIRecommendation() }
        }
        .onChange(of: viewModel.busRouteKind, initial: false) { _, _ in
            Task { await refreshAIRecommendation() }
        }
        .onChange(of: viewModel.busConsumptionPer100, initial: false) { _, _ in
            Task { await refreshAIRecommendation() }
        }
        .alert("Eksik Bilgi", isPresented: $showTransitWarning) {
            Button("Tamam", role: .cancel) { }
        } message: {
            Text("Otobüs seçildiğinde yakıt türü, 100 km tüketim ve hat türü bilgileri zorunludur.")
        }
        .sheet(isPresented: $showEmissionChart) {
            NavigationView {
                EmissionChartView(viewModel: emissionStatsVM)
                    .navigationBarItems(leading: Button("Kapat") {
                        showEmissionChart = false
                    })
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private func mapSection() -> some View {
        MapView(viewModel: viewModel)
            .frame(height: 250)
            .cornerRadius(12)
    }

    @ViewBuilder
    private func routeHeaderSection() -> some View {
        RouteHeaderCard(
            originText: viewModel.originText.isEmpty ? "Mevcut Konum" : viewModel.originText,
            destinationText: viewModel.destinationText.isEmpty ? "Varış" : viewModel.destinationText
        )
    }

    @ViewBuilder
    private func titleSection() -> some View {
        Text("Rota Özeti")
            .font(.title3)
            .bold()
    }

    @ViewBuilder
    private func summaryCardSection() -> some View {
        SummaryCard(
            selectedMode: viewModel.selectedMode,
            distanceMeters: viewModel.distanceMeters,
            expectedTime: viewModel.expectedTime,
            emissionKg: viewModel.emissionKg(),
            weather: viewModel.weatherInfo
        )
    }
    
    @ViewBuilder
    private func trafficSection() -> some View {
        if viewModel.selectedMode == .car {
            TrafficCardView(
                traffic: trafficInfo,
                isLoading: trafficService.isLoading,
                onRefresh: {
                    await fetchTrafficInfo()
                }
            )
        }
    }
    
    @ViewBuilder
    private func weatherDetailSection() -> some View {
        if let w = viewModel.weatherInfo {
            WeatherDetailCard(weather: w)
        }
    }

    @ViewBuilder
    private func transitSection() -> some View {
        if viewModel.selectedMode == .transit {
            TransitEmissionCard(
                viewModel: viewModel,
                busConsumptionField: $busConsumptionField
            )
        }
    }

    @ViewBuilder
    private func aiInsightSection() -> some View {
        AIInsightCard(
            recommendation: recommendation,
            distanceMeters: viewModel.distanceMeters,
            selected: viewModel.selectedMode,
            weather: viewModel.weatherInfo,
            profile: userProfile
        )
    }

    @ViewBuilder
    private func actionButtonsSection() -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                applyAIButton()
                applyUserChoiceButton()
            }
            chartButtonsSection()
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private func applyAIButton() -> some View {
        let isValid = isTransitValid()
        Button {
            guard isValid else {
                showTransitWarning = true
                return
            }
            let modeToApply = recommendation?.mode ?? bestModeForCurrentDistance()
            if modeToApply != viewModel.selectedMode {
                viewModel.selectedMode = modeToApply
            }
            Task {
                if viewModel.routePolyline == nil || viewModel.distanceMeters <= 0 {
                    if viewModel.canCreateRoute { await viewModel.buildRoute() }
                } else {
                    await viewModel.buildRoute()
                }
                await viewModel.persistSelectedJourney(aiApplied: true)
                
                // Rozet sistemine kaydet
                let distanceKm = viewModel.distanceMeters / 1000
                let emissionKg = emissionKg(for: modeToApply)
                await badgeVM.recordJourney(
                    mode: modeToApply,
                    distanceKm: distanceKm,
                    emissionKg: emissionKg,
                    aiUsed: true
                )
                
                await refreshAIRecommendation()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                Text("Akıllı Öneri")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isValid ? Color.primary : Color(.systemGray4))
            .foregroundColor(isValid ? Color(.systemBackground) : Color(.systemGray2))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .disabled(!isValid)
    }

    @ViewBuilder
    private func applyUserChoiceButton() -> some View {
        let isValid = isTransitValid()
        Button {
            guard isValid else {
                showTransitWarning = true
                return
            }
            if let preferred = userPreferredMode {
                viewModel.selectedMode = preferred
            }
            Task {
                if viewModel.routePolyline == nil || viewModel.distanceMeters <= 0 {
                    if viewModel.canCreateRoute { await viewModel.buildRoute() }
                } else {
                    await viewModel.buildRoute()
                }
                await viewModel.persistSelectedJourney(aiApplied: false)
                
                // Rozet sistemine kaydet
                let distanceKm = viewModel.distanceMeters / 1000
                let mode = userPreferredMode ?? viewModel.selectedMode
                let emissionKg = emissionKg(for: mode)
                await badgeVM.recordJourney(
                    mode: mode,
                    distanceKm: distanceKm,
                    emissionKg: emissionKg,
                    aiUsed: false
                )
                
                await refreshAIRecommendation()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "hand.tap")
                Text("Tercihim")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isValid ? Color(.secondarySystemGroupedBackground) : Color(.systemGray4))
            .foregroundColor(isValid ? .primary : Color(.systemGray2))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.primary.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isValid)
    }

    @ViewBuilder
    private func chartButtonsSection() -> some View {
        if #available(iOS 16.0, *) {
            Button {
                Task {
                    emissionStatsVM.selectedMode = viewModel.selectedMode
                    await emissionStatsVM.load()
                    await MainActor.run { showEmissionChart = true }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chart.bar.fill")
                    Text("Emisyon Grafiğini Gör")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color(.secondarySystemGroupedBackground))
                .foregroundColor(.primary)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Helpers

    private func emissionKg(for mode: TransportMode) -> Double {
        let km = max(0, viewModel.distanceMeters / 1000)
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
        let km = max(0, viewModel.distanceMeters / 1000)

        var best = viewModel.selectedMode
        var bestEmission = Double.greatestFiniteMagnitude
        var bestTimePenalty = Double.greatestFiniteMagnitude

        for m in modes {
            let e = emissionKg(for: m)
            let t = timePenalty(for: m, distanceKm: km)
            if e < bestEmission || (abs(e - bestEmission) < 1e-9 && t < bestTimePenalty) {
                bestEmission = e
                bestTimePenalty = t
                best = m
            }
        }
        return best
    }

    private func timePenalty(for mode: TransportMode, distanceKm: Double) -> Double {
        switch mode {
        case .walking: return distanceKm / 5.0
        case .transit: return distanceKm / 25.0
        case .car:
            let h = max(0.0001, viewModel.expectedTime / 3600)
            let currentSpeed = distanceKm / h
            let speed = viewModel.selectedMode == .car && currentSpeed > 0 ? currentSpeed : 30.0
            return distanceKm / speed
        }
    }

    private func loadUserProfileIfNeeded() async {
        if userProfile == nil {
            do {
                userProfile = try await FirestoreManager.shared.fetchUserProfile()
            } catch {
                print("Profile fetch error: \(error)")
            }
        }
    }
    
    private func fetchTrafficInfo() async {
        guard viewModel.selectedMode == .car else { return }
        guard let origin = LocationDelegate.shared.lastLocation?.coordinate else { return }
        
        // Hedef koordinatını al (basit geocoding)
        let geocoder = CLGeocoder()
        do {
            let placemarks = try await geocoder.geocodeAddressString(viewModel.destinationText)
            if let destination = placemarks.first?.location?.coordinate {
                trafficInfo = await trafficService.fetchTrafficInfo(
                    from: origin,
                    to: destination,
                    expectedTime: viewModel.expectedTime,
                    distanceMeters: viewModel.distanceMeters
                )
                
                // Trafik yoğunsa bildirim gönder
                if let traffic = trafficInfo, traffic.severity == .heavy || traffic.severity == .severe {
                    await NotificationManager.shared.sendTrafficAlertNotification(
                        severity: traffic.severity,
                        routeDescription: viewModel.destinationText
                    )
                }
            }
        } catch {
            print("❌ Geocoding hatası: \(error)")
        }
    }

    private func refreshAIRecommendation() async {
        let perPassengerTransit = viewModel.computeTransitPerPassengerEmission()?.perPassengerKg
        let rec = computeAIRecommendation(
            distanceMeters: viewModel.distanceMeters,
            expectedTime: viewModel.expectedTime,
            weather: viewModel.weatherInfo,
            profile: userProfile,
            current: viewModel.selectedMode,
            transitPerPassengerKg: perPassengerTransit
        )
        await MainActor.run { self.recommendation = rec }
    }

    private func computeAIRecommendation(distanceMeters: Double,
                                         expectedTime: TimeInterval,
                                         weather: WeatherInfo?,
                                         profile: UserProfile?,
                                         current: TransportMode,
                                         transitPerPassengerKg: Double?) -> AIRecommendation {

        let km = max(0, distanceMeters / 1000)
        var reasons: [String] = []
        var walkMax: Double = 1.8
        var transitMax: Double = 15.0

        if let p = profile {
            if p.age >= 60 {
                walkMax -= 0.6
                reasons.append("Yaş \(p.age) olduğu için uzun yürüyüşler daha az önerilir.")
            }
            if p.healthStatus.lowercased().contains("kronik") {
                walkMax -= 0.7
                reasons.append("Sağlık durumun (\(p.healthStatus)) dikkate alınarak yürüyüş eşiği düşürüldü.")
            }
            if p.travellingWithChild {
                walkMax -= 0.5
                reasons.append("Çocukla seyahat edildiği için yürüyüş mesafesi kısaltıldı.")
            }
            if p.carbonSensitivity >= 0.7 {
                transitMax += 5
                walkMax += 0.2
                reasons.append("Karbon duyarlılığı yüksek, düşük emisyonlu modlar önceliklendirildi.")
            } else if p.carbonSensitivity <= 0.3 {
                transitMax -= 2
                walkMax -= 0.2
                reasons.append("Karbon duyarlılığı düşük, pratiklik biraz daha öne alındı.")
            }
        }

        var weatherPenalty = false
        var weatherFavor = false
        if let w = weather {
            switch w.condition {
            case .rain, .snow:
                weatherPenalty = true
                reasons.append("Yağış var (\(conditionDisplayText(w.condition))); uzun yürüyüş önerilmez.")
            case .clear, .clouds, .unknown:
                break
            }
            if w.windSpeed >= 10 {
                weatherPenalty = true
                reasons.append("Rüzgar kuvvetli (\(String(format: "%.1f", w.windSpeed)) m/s); yürüyüş konforu düşer.")
            }
            if w.feelsLikeC < 5 {
                weatherPenalty = true
                reasons.append("Hissedilen sıcaklık düşük (\(String(format: "%.1f", w.feelsLikeC))°C); yürüyüş sınırlı önerilir.")
            } else if w.feelsLikeC > 32 {
                weatherPenalty = true
                reasons.append("Aşırı sıcak (\(String(format: "%.1f", w.feelsLikeC))°C); yürüyüş önerilmez.")
            } else if (10...28).contains(w.feelsLikeC), w.windSpeed < 8, w.condition != .rain, w.condition != .snow {
                weatherFavor = true
                reasons.append("Hava yürüyüş için elverişli.")
            }
        }
        if weatherPenalty { walkMax = min(walkMax, 0.8) }
        if weatherFavor { walkMax += 0.5 }
        walkMax = max(0.5, walkMax)

        var heavyTraffic = false
        var moderateTraffic = false
        if expectedTime > 0, km > 0, current == .car {
            let avgSpeed = km / (expectedTime / 3600)
            if avgSpeed < 15 {
                heavyTraffic = true
                reasons.append("Trafik yoğun: ortalama hız \(String(format: "%.1f", avgSpeed)) km/sa.")
            } else if avgSpeed < 25 {
                moderateTraffic = true
                reasons.append("Trafik orta yoğun: ortalama hız \(String(format: "%.1f", avgSpeed)) km/sa.")
            } else {
                reasons.append("Trafik akıcı görünüyor: ortalama hız \(String(format: "%.1f", avgSpeed)) km/sa.")
            }
        }

        reasons.append("Mesafe \(String(format: "%.1f", km)) km.")

        let carKg = km * 0.192
        let transitAvgKg = km * 0.105
        let walkKg = 0.0

        let walkText = String(format: "%.2f", walkKg)
        let carText = String(format: "%.2f", carKg)
        let transitAvgText = String(format: "%.2f", transitAvgKg)
        if let perPax = transitPerPassengerKg {
            let perPaxText = String(format: "%.3f", perPax)
            reasons.append("Tahmini emisyonlar — Yürüyüş: \(walkText) kg, Otobüs (kişi başı): \(perPaxText) kg, Araba (toplam): \(carText) kg. (Karşılaştırma için toplu taşıma ortalaması: \(transitAvgText) kg)")
        } else {
            reasons.append("Tahmini emisyonlar — Yürüyüş: \(walkText) kg, Toplu Taşıma: \(transitAvgText) kg, Araba: \(carText) kg.")
        }

        let recommendWalking = km <= walkMax && !weatherPenalty
        let recommendTransit = km > walkMax && km <= transitMax
        let preferTransitDueToTraffic = (heavyTraffic || moderateTraffic) && km <= (transitMax + 5)

        var selected: TransportMode
        if recommendWalking {
            selected = .walking
            reasons.append("Mesafe ve hava koşulları yürüyüş için uygun.")
        } else {
            var transitPreferred = recommendTransit || preferTransitDueToTraffic
            if let perPax = transitPerPassengerKg, perPax < carKg {
                let perPaxText = String(format: "%.3f", perPax)
                transitPreferred = true
                reasons.append("Kişi başı otobüs emisyonu (\(perPaxText) kg) araba toplam emisyonundan daha düşük.")
            }
            if transitPreferred {
                selected = .transit
                if heavyTraffic {
                    reasons.append("Yoğun trafik nedeniyle toplu taşıma daha öngörülebilir ve düşük emisyonlu.")
                } else if moderateTraffic {
                    reasons.append("Trafik orta; toplu taşıma emisyon açısından avantajlı.")
                } else {
                    reasons.append("Orta/uzun mesafede toplu taşıma dengeli bir tercih.")
                }
            } else {
                selected = .car
                reasons.append("Mesafe uzun veya koşullar gereği araba daha pratik görünüyor.")
            }
        }

        let selectedKg = {
            switch selected {
            case .walking: return 0.0
            case .car:     return carKg
            case .transit: return transitAvgKg
            }
        }()
        let currentKg = {
            switch current {
            case .walking: return 0.0
            case .car:     return carKg
            case .transit: return transitAvgKg
            }
        }()
        let savings = max(0, currentKg - selectedKg)

        var summaryParts: [String] = []
        switch selected {
        case .walking:
            summaryParts.append("Öneri: Yürüyüş.")
            if weatherFavor { summaryParts.append("Hava koşulları destekliyor.") }
            summaryParts.append("Kısa mesafede sıfır emisyonla en çevreci seçenek.")
        case .transit:
            summaryParts.append("Öneri: Toplu taşıma.")
            if let perPax = transitPerPassengerKg {
                summaryParts.append("Girilen değerlere göre kişi başı emisyon avantajı var (\(String(format: "%.3f", perPax)) kg).")
            } else if heavyTraffic {
                summaryParts.append("Trafik yoğun, toplu taşıma daha öngörülebilir ve daha düşük emisyonlu olabilir.")
            } else {
                summaryParts.append("Orta mesafede emisyon/konfor dengesi iyi.")
            }
        case .car:
            summaryParts.append("Öneri: Araba.")
            summaryParts.append("Mesafe uzun ve süre açısından avantaj sağlayabilir.")
        }

        if savings > 0.0001 {
            summaryParts.append("Seçiminle yaklaşık \(String(format: "%.2f", savings)) kg CO₂ tasarruf edebilirsin.")
        }

        let summary = summaryParts.joined(separator: " ")

        return AIRecommendation(mode: selected,
                                summary: summary,
                                reasons: reasons,
                                potentialSavingsKg: savings)
    }
    
    // Validation helper
    private func isTransitValid() -> Bool {
        // Yürüyüş veya araba modunda validasyon gerekmiyor
        if viewModel.selectedMode == .walking || viewModel.selectedMode == .car {
            return true
        }
        
        // Transit modunda validasyon gerekli
        if viewModel.selectedMode == .transit {
            return viewModel.busFuelType != nil &&
                   viewModel.busConsumptionPer100 != nil &&
                   viewModel.busRouteKind != nil
        }
        
        return true
    }
}

// MARK: - Models used only by this file

struct AIRecommendation {
    let mode: TransportMode
    let summary: String
    let reasons: [String]
    let potentialSavingsKg: Double
}

// MARK: - Shared button

private struct FilledActionButton: View {
    let title: String
    let systemName: String
    let background: Color
    var foreground: Color = .white

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemName)
                .imageScale(.medium)
            Text(title)
                .fontWeight(.semibold)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .font(.system(size: 16, weight: .semibold))
        .frame(maxWidth: .infinity, minHeight: 48)
        .padding(.horizontal, 12)
        .background(background)
        .foregroundColor(foreground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Subviews

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

// Rich AI insight card - SADE VE OKUNABİLİR
private struct AIInsightCard: View {
    let recommendation: AIRecommendation?
    let distanceMeters: Double
    let selected: TransportMode
    let weather: WeatherInfo?
    let profile: UserProfile?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("Akıllı Öneri")
                    .font(.headline)
            }

            if let rec = recommendation {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: modeIcon(rec.mode))
                            .foregroundColor(.green)
                        Text(modeText(rec.mode))
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                    
                    Text(rec.summary)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if rec.potentialSavingsKg > 0 {
                        HStack {
                            Image(systemName: "leaf.fill")
                                .foregroundColor(.green)
                            Text("Tasarruf: \(String(format: "%.2f", rec.potentialSavingsKg)) kg CO₂")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .padding(.top, 4)
                    }
                }
            } else {
                Text("Veriler hazırlanıyor...")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    private func modeIcon(_ mode: TransportMode) -> String {
        switch mode {
        case .walking: return "figure.walk"
        case .car: return "car.fill"
        case .transit: return "bus.fill"
        }
    }
    
    private func modeText(_ mode: TransportMode) -> String {
        switch mode {
        case .walking: return "Yürüyüş"
        case .car: return "Araba"
        case .transit: return "Toplu Taşıma"
        }
    }
}

// Route header card - SADE TASARIM
private struct RouteHeaderCard: View {
    let originText: String
    let destinationText: String

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)
                Text(originText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
            
            HStack(spacing: 10) {
                Image(systemName: "location.fill")
                    .font(.caption)
                    .foregroundColor(.red)
                Text(destinationText)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// Weather inline badge used inside summary
private struct WeatherInlineBadge: View {
    let weather: WeatherInfo
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon(for: weather.condition))
                .foregroundColor(color(for: weather.condition))
            Text("\(String(format: "%.1f", weather.temperatureC))°C")
                .fontWeight(.semibold)
            Text(conditionDisplayText(weather.condition))
                .foregroundColor(.secondary)
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "wind")
                Text("\(String(format: "%.1f", weather.windSpeed)) m/s")
            }
            .foregroundColor(.secondary)
        }
        .padding(10)
        .background(Color.blue.opacity(0.06))
        .cornerRadius(10)
    }

    private func icon(for c: WeatherInfo.Condition) -> String {
        switch c {
        case .clear: return "sun.max.fill"
        case .clouds: return "cloud.fill"
        case .rain: return "cloud.rain.fill"
        case .snow: return "snow"
        case .unknown: return "questionmark.circle"
        }
    }

    private func color(for c: WeatherInfo.Condition) -> Color {
        switch c {
        case .clear: return .yellow
        case .clouds: return .gray
        case .rain: return .blue
        case .snow: return .cyan
        case .unknown: return .gray
        }
    }
}

// Summary card with weather - MODERN 6 KARTLI TASARIM
private struct SummaryCard: View {
    let selectedMode: TransportMode
    let distanceMeters: Double
    let expectedTime: TimeInterval
    let emissionKg: Double
    let weather: WeatherInfo?

    var body: some View {
        VStack(spacing: 12) {
            // İlk satır: Ulaşım, Mesafe, Süre
            HStack(spacing: 10) {
                StatCardView(
                    icon: modeIcon(),
                    title: modeTitle(),
                    value: "ULAŞIM",
                    color: .primary
                )
                StatCardView(
                    icon: "arrow.left.and.right",
                    title: String(format: "%.1f", distanceMeters / 1000),
                    value: "km",
                    subtitle: "MESAFE",
                    color: .blue
                )
                StatCardView(
                    icon: "clock",
                    title: formatDuration(expectedTime),
                    value: "",
                    subtitle: "SÜRE",
                    color: .orange
                )
            }
            
            // İkinci satır: Varış, Karbon, Hava
            HStack(spacing: 10) {
                StatCardView(
                    icon: "flag.checkered",
                    title: Date().addingTimeInterval(expectedTime).formatted(date: .omitted, time: .shortened),
                    value: "",
                    subtitle: "VARIŞ SAATİ",
                    color: .green
                )
                StatCardView(
                    icon: "leaf",
                    title: String(format: "%.2f", emissionKg),
                    value: "kg CO₂",
                    subtitle: "KARBON",
                    color: emissionKg == 0 ? .green : .orange
                )
                if let w = weather {
                    StatCardView(
                        icon: weatherIcon(w.condition),
                        title: String(format: "%.0f°C", w.temperatureC),
                        value: "",
                        subtitle: "HAVA",
                        color: .cyan
                    )
                } else {
                    StatCardView(
                        icon: "cloud",
                        title: "--",
                        value: "",
                        subtitle: "HAVA",
                        color: .gray
                    )
                }
            }
        }
    }
    
    private func modeIcon() -> String {
        switch selectedMode {
        case .walking: return "figure.walk"
        case .car: return "car.fill"
        case .transit: return "bus.fill"
        }
    }
    
    private func modeTitle() -> String {
        switch selectedMode {
        case .walking: return "Yürü"
        case .car: return "Araba"
        case .transit: return "Otobüs"
        }
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let totalMinutes = Int(seconds / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        
        if hours > 0 {
            return "\(hours):\(String(format: "%02d", minutes))"
        } else {
            return "\(minutes) dk"
        }
    }
    
    private func weatherIcon(_ condition: WeatherInfo.Condition) -> String {
        switch condition {
        case .clear: return "sun.max.fill"
        case .clouds: return "cloud.fill"
        case .rain: return "cloud.rain.fill"
        case .snow: return "snow"
        case .unknown: return "cloud"
        }
    }
}

// MARK: - İstatistik Kartı Bileşeni
private struct StatCardView: View {
    let icon: String
    let title: String
    let value: String
    var subtitle: String = ""
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            if !value.isEmpty {
                Text(value)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 110)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// Transit per passenger emission card
private struct TransitEmissionCard: View {
    @ObservedObject var viewModel: RouteViewModel
    @Binding var busConsumptionField: String
    
    private var isComplete: Bool {
        viewModel.busFuelType != nil &&
        viewModel.busConsumptionPer100 != nil &&
        viewModel.busRouteKind != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Otobüs Kişi Başı Emisyonu")
                    .font(.headline)
                if !isComplete {
                    Spacer()
                    Text("Zorunlu")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(6)
                }
            }

            let distanceText = String(format: "%.1f", viewModel.distanceMeters/1000)
            Text("Yakıt türü ve tüketimi girin; hat türünü seçin. Mesafe \(distanceText) km üzerinden kişi başı CO₂ hesaplanır.")
                .foregroundColor(.secondary)

            // Inputs
            HStack {
                Text("Yakıt Türü")
                    .foregroundColor(viewModel.busFuelType == nil ? .red : .secondary)
                Spacer()
                Picker("Yakıt Türü", selection: Binding<BusFuelType?>(
                    get: { viewModel.busFuelType },
                    set: { viewModel.busFuelType = $0 }
                )) {
                    Text("Seçiniz").tag(nil as BusFuelType?)
                    ForEach(BusFuelType.allCases, id: \.self) { t in
                        Text(t.rawValue).tag(BusFuelType?.some(t))
                    }
                }
                .pickerStyle(.menu)
                .foregroundColor(viewModel.busFuelType == nil ? .red : .primary)
            }
            .padding(10)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(viewModel.busFuelType == nil ? Color.red : Color.clear, lineWidth: 1)
            )

            HStack {
                Text("100 km Tüketim")
                    .foregroundColor(viewModel.busConsumptionPer100 == nil ? .red : .secondary)
                Spacer()
                TextField("örn. 35", text: $busConsumptionField)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
                    .frame(width: 120)
                    .onChange(of: busConsumptionField) { _, newValue in
                        let normalized = newValue.replacingOccurrences(of: ",", with: ".")
                        viewModel.busConsumptionPer100 = Double(normalized)
                    }
            }
            .padding(10)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(viewModel.busConsumptionPer100 == nil ? Color.red : Color.clear, lineWidth: 1)
            )

            HStack {
                Text("Hat Türü")
                    .foregroundColor(viewModel.busRouteKind == nil ? .red : .secondary)
                Spacer()
                Picker("Hat Türü", selection: Binding<BusRouteKind?>(
                    get: { viewModel.busRouteKind },
                    set: { viewModel.busRouteKind = $0 }
                )) {
                    Text("Seçiniz").tag(nil as BusRouteKind?)
                    ForEach(BusRouteKind.allCases, id: \.self) { k in
                        Text(k.rawValue).tag(BusRouteKind?.some(k))
                    }
                }
                .pickerStyle(.menu)
                .foregroundColor(viewModel.busRouteKind == nil ? .red : .primary)
            }
            .padding(10)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(viewModel.busRouteKind == nil ? Color.red : Color.clear, lineWidth: 1)
            )

            // Result and formulas
            if let r = viewModel.computeTransitPerPassengerEmission() {
                Divider().opacity(0.2)

                let dText = String(format: "%.2f", r.distanceKm)
                let consText = String(format: "%.2f", r.consumptionPer100)
                let totalConsText = String(format: "%.2f", r.totalConsumption)
                let efText = String(format: "%.2f", r.emissionFactor)
                let totalCO2Text = String(format: "%.2f", r.totalCO2Kg)
                let perPaxText = String(format: "%.3f", r.perPassengerKg)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Hesap Adımları").font(.subheadline).fontWeight(.semibold)

                    Text("• Mesafe = \(dText) km")
                    Text("• Toplam tüketim = (\(dText) / 100) × \(consText) = \(totalConsText) \(r.unitLabel)")
                    Text("• Emisyon faktörü = \(efText) kg CO₂/\(r.unitLabel)")
                    Text("• Toplam CO₂ = \(totalConsText) × \(efText) = \(totalCO2Text) kg")
                    Text("• Yolcu sayısı = \(r.passengerCount)")
                    Text("• Kişi başı CO₂ = \(totalCO2Text) / \(r.passengerCount) = \(perPaxText) kg")
                        .fontWeight(.semibold)
                        .foregroundColor(.green)

                    Divider().opacity(0.2)
                    Text("Bu rota için kişi başı yaklaşık \(perPaxText) kg CO₂.")
                        .fontWeight(.semibold)
                }
            } else {
                Text("Kişi başı emisyonu görmek için yakıt türü, tüketim ve hat türünü giriniz.")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// Detailed weather card - SADE
private struct WeatherDetailCard: View {
    let weather: WeatherInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon(for: weather.condition))
                    .foregroundColor(color(for: weather.condition))
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(conditionDisplayText(weather.condition))
                        .font(.headline)
                    Text("\(String(format: "%.0f", weather.temperatureC))°C")
                        .font(.title3)
                        .fontWeight(.bold)
                }
                
                Spacer()
            }
            
            HStack(spacing: 16) {
                Label("\(String(format: "%.0f", weather.windSpeed)) m/s", systemImage: "wind")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Label("\(weather.humidity)%", systemImage: "drop.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private func icon(for c: WeatherInfo.Condition) -> String {
        switch c {
        case .clear: return "sun.max.fill"
        case .clouds: return "cloud.fill"
        case .rain: return "cloud.rain.fill"
        case .snow: return "snow"
        case .unknown: return "questionmark.circle"
        }
    }

    private func color(for c: WeatherInfo.Condition) -> Color {
        switch c {
        case .clear: return .yellow
        case .clouds: return .gray
        case .rain: return .blue
        case .snow: return .cyan
        case .unknown: return .gray
        }
    }
}

// Helper: normalize precipitation chance for UI
fileprivate func normalizedPrecipitationChance(for weather: WeatherInfo) -> Double {
    var chance = weather.precipitationChance
    switch weather.condition {
    case .rain, .snow:
        chance = max(chance, 0.7)
    case .clear, .clouds, .unknown:
        break
    }
    return min(max(chance, 0.0), 1.0)
}

// Helper: condition display text (avoid duplicate extensions)
fileprivate func conditionDisplayText(_ condition: WeatherInfo.Condition) -> String {
    switch condition {
    case .clear: return "Açık"
    case .clouds: return "Bulutlu"
    case .rain: return "Yağmurlu"
    case .snow: return "Karlı"
    case .unknown: return "Bilinmiyor"
    }
}
