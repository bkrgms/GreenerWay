import SwiftUI
import MapKit

struct RouteDetailView: View {
    @ObservedObject var viewModel: RouteViewModel
    @State private var pushChart = false

    // User profile and AI recommendation
    @State private var userProfile: UserProfile?
    @State private var recommendation: AIRecommendation?

    // Transit input field (visual only)
    @State private var busConsumptionField: String = ""
    // Snapshot of user preferred mode coming from search view
    @State private var userPreferredMode: TransportMode?

    var body: some View {
        ZStack {
            // Gizli NavigationLink: NavigationView ile uyumlu
            NavigationLink(
                destination: EmissionChartView(viewModel: makeStatsVM()),
                isActive: $pushChart
            ) {
                EmptyView()
            }
            .hidden()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    mapSection()
                    routeHeaderSection()
                    titleSection()
                    summaryCardSection()
                    weatherDetailSection()
                    transitSection()
                    aiInsightSection()
                    actionButtonsSection()
                    Spacer(minLength: 8)
                }
                .padding()
            }
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
        // NavigationDestination kaldırıldı; NavigationLink kullanıyoruz.
    }

    // EmissionChartView için VM üretici
    private func makeStatsVM() -> EmissionStatsViewModel {
        let vm = EmissionStatsViewModel()
        vm.selectedMode = viewModel.selectedMode
        return vm
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
        Button {
            let modeToApply = recommendation?.mode ?? bestModeForCurrentDistance()
            if modeToApply != viewModel.selectedMode {
                viewModel.selectedMode = modeToApply
            }
            Task {
                // 1) Rota hazır değilse oluştur
                if viewModel.routePolyline == nil || viewModel.distanceMeters <= 0 {
                    if viewModel.canCreateRoute { await viewModel.buildRoute() }
                } else {
                    // zaten seçim değiştiyse tekrar hesapla
                    await viewModel.buildRoute()
                }
                // 2) Seçimi AI olarak KAYDET
                await viewModel.persistSelectedJourney(aiApplied: true)
                // 3) İçgörüyü yenile
                await refreshAIRecommendation()
            }
        } label: {
            FilledActionButton(
                title: "AI'yı tercih et",
                systemName: "wand.and.stars",
                background: .green
            )
        }
        .contentShape(Rectangle())
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func applyUserChoiceButton() -> some View {
        Button {
            if let preferred = userPreferredMode {
                viewModel.selectedMode = preferred
            }
            Task {
                // 1) Rota hazır değilse oluştur
                if viewModel.routePolyline == nil || viewModel.distanceMeters <= 0 {
                    if viewModel.canCreateRoute { await viewModel.buildRoute() }
                } else {
                    await viewModel.buildRoute()
                }
                // 2) Seçimi KULLANICI tercihi olarak KAYDET
                await viewModel.persistSelectedJourney(aiApplied: false)
                // 3) İçgörüyü yenile
                await refreshAIRecommendation()
            }
        } label: {
            FilledActionButton(
                title: "Benim tercihim",
                systemName: "hand.tap",
                background: .gray.opacity(0.8)
            )
        }
        .contentShape(Rectangle())
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func chartButtonsSection() -> some View {
        if #available(iOS 16.0, *) {
            Button {
                Task {
                    // Eğer mesafe henüz 0 ise ya da rota yoksa önce rotayı oluştur.
                    if viewModel.distanceMeters <= 0 || viewModel.routePolyline == nil {
                        if viewModel.canCreateRoute {
                            await viewModel.buildRoute()
                        }
                    }
                    // Ardından güncel seçili moda göre yolculuğu kaydet.
                    await viewModel.persistCurrentJourney()
                    // Ve grafiğe geç.
                    await MainActor.run { pushChart = true }
                }
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

// Rich AI insight card
private struct AIInsightCard: View {
    let recommendation: AIRecommendation?
    let distanceMeters: Double
    let selected: TransportMode
    let weather: WeatherInfo?
    let profile: UserProfile?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Yapay Zeka İçgörüsü").font(.headline)

            if let rec = recommendation {
                Text(rec.summary)
                    .fontWeight(.semibold)

                if !rec.reasons.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(rec.reasons, id: \.self) { line in
                            HStack(alignment: .top, spacing: 8) {
                                Text("•")
                                Text(line).foregroundColor(.secondary)
                            }
                        }
                    }
                }
            } else {
                Text("Veriler yükleniyor. Mesafe, hava durumu ve profil bilgilerine göre en uygun ulaşım modu önerilecek.")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.secondary.opacity(0.1)))
    }
}

// Route header card
private struct RouteHeaderCard: View {
    let originText: String
    let destinationText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "location.fill").foregroundColor(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Nereden").font(.caption).foregroundColor(.secondary)
                    Text(originText).fontWeight(.semibold).lineLimit(2)
                }
            }
            HStack(spacing: 12) {
                Rectangle().fill(Color.secondary.opacity(0.3)).frame(width: 2, height: 12).padding(.leading, 4)
                Rectangle().fill(Color.clear).frame(height: 0)
            }
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "mappin.and.ellipse").foregroundColor(.red)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Nereye").font(.caption).foregroundColor(.secondary)
                    Text(destinationText).fontWeight(.semibold).lineLimit(2)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
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

// Summary card with weather
private struct SummaryCard: View {
    let selectedMode: TransportMode
    let distanceMeters: Double
    let expectedTime: TimeInterval
    let emissionKg: Double
    let weather: WeatherInfo?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SummaryRow(label: "Ulaşım", value: selectedMode.rawValue.capitalized)
            SummaryRow(label: "Mesafe", value: "\(String(format: "%.1f", distanceMeters / 1000)) km")
            SummaryRow(label: "Süre", value: "\(Int(expectedTime / 60)) dk")
            SummaryRow(label: "Varış", value: Date().addingTimeInterval(expectedTime)
                .formatted(date: .omitted, time: .shortened))
            SummaryRow(label: "Karbon", value: "\(String(format: "%.2f", emissionKg)) kg CO₂")

            if let speedText = averageSpeedText(distanceMeters: distanceMeters, expectedTime: expectedTime) {
                SummaryRow(label: "Ort. Hız", value: speedText)
            }

            if let w = weather {
                WeatherInlineBadge(weather: w)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.secondary.opacity(0.1)))
    }

    private func averageSpeedText(distanceMeters: Double, expectedTime: TimeInterval) -> String? {
        guard expectedTime > 0, distanceMeters > 0 else { return nil }
        let km = distanceMeters / 1000
        let hours = expectedTime / 3600
        guard hours > 0 else { return nil }
        let speed = km / hours
        return "\(String(format: "%.1f", speed)) km/sa"
    }
}

// Transit per passenger emission card
private struct TransitEmissionCard: View {
    @ObservedObject var viewModel: RouteViewModel
    @Binding var busConsumptionField: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Otobüs Kişi Başı Emisyonu")
                .font(.headline)

            let distanceText = String(format: "%.1f", viewModel.distanceMeters/1000)
            Text("Yakıt türü ve tüketimi girin; hat türünü seçin. Mesafe \(distanceText) km üzerinden kişi başı CO₂ hesaplanır.")
                .foregroundColor(.secondary)

            // Inputs
            HStack {
                Text("Yakıt Türü")
                    .foregroundColor(.secondary)
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
            }

            HStack {
                Text("100 km Tüketim")
                    .foregroundColor(.secondary)
                Spacer()
                TextField("örn. 35", text: $busConsumptionField)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
                    .frame(width: 120)
                    .onChange(of: busConsumptionField) { newValue in
                        let normalized = newValue.replacingOccurrences(of: ",", with: ".")
                        viewModel.busConsumptionPer100 = Double(normalized)
                    }
            }

            HStack {
                Text("Hat Türü")
                    .foregroundColor(.secondary)
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
            }

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
        .background(Color(.secondarySystemBackground))
        .cornerRadius(14)
    }
}

// Detailed weather card
private struct WeatherDetailCard: View {
    let weather: WeatherInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: icon(for: weather.condition))
                    .foregroundColor(color(for: weather.condition))
                Text("Hava Durumu")
                    .font(.headline)
                Spacer()
                Text("\(String(format: "%.1f", weather.temperatureC))°C")
                    .fontWeight(.semibold)
            }
            HStack {
                Label("Hissedilen: \(String(format: "%.1f", weather.feelsLikeC))°C", systemImage: "thermometer")
                Spacer()
                Label("Nem: \(weather.humidity)%", systemImage: "drop.fill")
            }
            .foregroundColor(.secondary)
            HStack {
                Label("Rüzgar: \(String(format: "%.1f", weather.windSpeed)) m/s", systemImage: "wind")
                Spacer()
                let normalized = normalizedPrecipitationChance(for: weather)
                Label("Yağış olasılığı: \(Int(normalized * 100))%", systemImage: "cloud.rain")
            }
            .foregroundColor(.secondary)
            Text(conditionDisplayText(weather.condition))
                .foregroundColor(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.secondary.opacity(0.1)))
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
