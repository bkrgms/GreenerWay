import Foundation
import MapKit
import CoreLocation
import FirebaseAuth
import FirebaseFirestore
import Contacts

// MARK: - Otobüs yakıt ve hat türleri
enum BusFuelType: String, CaseIterable, Identifiable {
    case diesel    = "Dizel"
    case cng       = "CNG"
    case electric  = "Elektrik"
    var id: String { rawValue }
}

enum BusRouteKind: String, CaseIterable, Identifiable {
    case city        = "Şehir içi"
    case intercity   = "Şehirlerarası"
    var id: String { rawValue }
}

// CLLocationManagerDelegate’yi Swift 6 için ayrı bir proxy’ye taşıyoruz.
final class RouteLocationProxy: NSObject, CLLocationManagerDelegate {
    weak var owner: RouteViewModel?

    init(owner: RouteViewModel) {
        self.owner = owner
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        guard let owner else { return }
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            if #available(iOS 14.0, *) {
                if manager.accuracyAuthorization == .reducedAccuracy {
                    manager.requestTemporaryFullAccuracyAuthorization(withPurposeKey: "LocationPreciseUsage", completion: { _ in })
                }
            }
            manager.startUpdatingLocation()
        }
        // UI güncellemeleri ana aktörde
        Task { @MainActor in
            // Gerekirse buraya UI-yanıtsal durum aktarımı eklenebilir
            _ = owner // no-op
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last, let owner = owner else { return }

        Task { @MainActor in
            // İlk girişte “Mevcut Konum” yazdır (UI boşsa)
            if owner.originText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                owner.originText = "Mevcut Konum"
            }

            owner.originCoordinate = loc.coordinate

            let acc = loc.horizontalAccuracy
            let isFresh = Date().timeIntervalSince(loc.timestamp) <= 10
            guard acc > 0, isFresh else { return }

            let shouldUpdateAddress: Bool = {
                guard acc < owner.bestOriginAccuracy else { return false }
                guard acc <= 35 else { return false }
                if let last = owner.lastReverseGeocodeAt, Date().timeIntervalSince(last) < 2 { return false }
                return true
            }()

            if shouldUpdateAddress {
                owner.bestOriginAccuracy = acc
                owner.lastReverseGeocodeAt = Date()
                await owner.prefillOriginAddress(from: loc)
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error:", error.localizedDescription)
    }
}

@MainActor
final class RouteViewModel: NSObject, ObservableObject {

    // MARK: Inputs
    @Published var originText: String = ""
    @Published var destinationText: String = "" {
        didSet {
            destinationCoordinate = nil
        }
    }
    @Published var selectedMode: TransportMode = .car

    // MARK: Map / Route state
    @Published var originCoordinate: CLLocationCoordinate2D?
    @Published var destinationCoordinate: CLLocationCoordinate2D?
    @Published var routePolyline: MKPolyline?
    @Published var distanceMeters: Double = 0
    @Published var expectedTime: TimeInterval = 0

    // MARK: Weather (opsiyonel)
    @Published var weatherInfo: WeatherInfo?

    // MARK: Transit (otobüs) kişi başı emisyon için girdiler
    @Published var busFuelType: BusFuelType?
    @Published var busConsumptionPer100: Double?   // Dizel: L/100km, CNG: kg/100km, Elektrik: kWh/100km
    @Published var busRouteKind: BusRouteKind?

    var shouldPersistJourneyForNextBuild: Bool = false

    // MARK: Private
    private let geocoder = CLGeocoder()
    private let locationManager = CLLocationManager()
    private let db = Firestore.firestore()
    private lazy var proxy = RouteLocationProxy(owner: self)

    // Adresin daha detaylı gelmesi için doğruluk takibi
    fileprivate var bestOriginAccuracy: CLLocationAccuracy = .greatestFiniteMagnitude
    fileprivate var lastReverseGeocodeAt: Date?

    override init() {
        super.init()
        locationManager.delegate = proxy
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.activityType = .otherNavigation

        locationManager.requestWhenInUseAuthorization()
        if #available(iOS 14.0, *) {
            if locationManager.accuracyAuthorization == .reducedAccuracy {
                locationManager.requestTemporaryFullAccuracyAuthorization(withPurposeKey: "LocationPreciseUsage") { error in
                    if let error = error {
                        print("⚠️ Full accuracy request failed: \(error.localizedDescription)")
                    }
                }
            }
        }
        locationManager.startUpdatingLocation()
    }

    var canCreateRoute: Bool {
        let hasDest = !(destinationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) || destinationCoordinate != nil
        let hasOrigin = originCoordinate != nil
            || !(originText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            || (locationManager.location != nil)
        return hasOrigin && hasDest
    }

    // TAM adres yazdırma – CNPostalAddress + CLPlacemark harman
    fileprivate func prefillOriginAddress(from location: CLLocation) async {
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location, preferredLocale: Locale.current)
            guard let p = placemarks.first else {
                originText = "Mevcut Konum"
                return
            }

            if let postal = p.postalAddress {
                // CNPostalAddress’ta thoroughfare/subThoroughfare yok; street içinde birlikte gelir.
                // Örn: "İnönü Cd. 45"
                var parts: [String] = []
                if !postal.street.isEmpty { parts.append(postal.street) }
                if let subLocality = p.subLocality, !subLocality.isEmpty { parts.append(subLocality) }
                if !postal.city.isEmpty { parts.append(postal.city) }
                if !postal.postalCode.isEmpty { parts.append(postal.postalCode) }
                if !postal.country.isEmpty { parts.append(postal.country) }

                originText = parts.isEmpty ? "Mevcut Konum" : parts.joined(separator: ", ")
            } else {
                // postalAddress yoksa CLPlacemark alanlarını kullan
                var parts: [String] = []
                if let street = p.thoroughfare, !street.isEmpty { parts.append(street) }
                if let number = p.subThoroughfare, !number.isEmpty { parts.append(number) }
                if let subLocality = p.subLocality, !subLocality.isEmpty { parts.append(subLocality) }
                if let locality = p.locality, !locality.isEmpty { parts.append(locality) }
                if let admin = p.administrativeArea, !admin.isEmpty { parts.append(admin) }
                if let postalCode = p.postalCode, !postalCode.isEmpty { parts.append(postalCode) }
                if let country = p.country, !country.isEmpty { parts.append(country) }
                originText = parts.isEmpty ? "Mevcut Konum" : parts.joined(separator: ", ")
            }
        } catch {
            originText = "Mevcut Konum"
        }
    }

    private func geocodeAddress(_ text: String) async throws -> CLLocationCoordinate2D {
        // Not: iOS 18 SDK’da CLGeocoder depreke uyarısı verir. İkinci aşamada MKGeocodingRequest’e geçebiliriz.
        let list = try await geocoder.geocodeAddressString(text)
        guard let c = list.first?.location?.coordinate else {
            throw NSError(domain: "Geocode", code: -1, userInfo: [NSLocalizedDescriptionKey: "Adres bulunamadı"])
        }
        return c
    }

    // MARK: Route (Apple Maps)
    func buildRoute() async {
        do {
            // Başlangıç
            let trimmedOrigin = originText.trimmingCharacters(in: .whitespacesAndNewlines)
            let from: CLLocationCoordinate2D
            if let live = originCoordinate {
                from = live
            } else if let last = locationManager.location?.coordinate {
                from = last
            } else if !trimmedOrigin.isEmpty && trimmedOrigin != "Mevcut Konum" {
                from = try await geocodeAddress(trimmedOrigin)
            } else {
                throw NSError(domain: "Route", code: -2, userInfo: [NSLocalizedDescriptionKey: "Başlangıç konumu bulunamadı"])
            }
            originCoordinate = from
            if originText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                originText = "Mevcut Konum"
            }

            // Varış
            let trimmedDest = destinationText.trimmingCharacters(in: .whitespacesAndNewlines)
            let to: CLLocationCoordinate2D
            if let picked = destinationCoordinate {
                to = picked
            } else if !trimmedDest.isEmpty {
                to = try await geocodeAddress(trimmedDest)
                destinationCoordinate = to
            } else {
                throw NSError(domain: "Route", code: -3, userInfo: [NSLocalizedDescriptionKey: "Varış adresi yok"])
            }

            let req = MKDirections.Request()
            // iOS 18 SDK’da MKPlacemark initializer’ı depreke; 2. aşamada MKMapItem(location:address:)’e geçeceğiz.
            req.source = MKMapItem(placemark: MKPlacemark(coordinate: from))
            req.destination = MKMapItem(placemark: MKPlacemark(coordinate: to))
            switch selectedMode {
            case .car:     req.transportType = .automobile
            case .walking: req.transportType = .walking
            case .transit: req.transportType = .transit
            }

            let res = try await MKDirections(request: req).calculate()
            guard let route = res.routes.first else { return }

            routePolyline = route.polyline
            distanceMeters = route.distance
            expectedTime  = route.expectedTravelTime

            await fetchWeatherIfAvailable(at: from)

            if shouldPersistJourneyForNextBuild {
                await saveJourney(aiApplied: true)
                shouldPersistJourneyForNextBuild = false
            }

        } catch {
            print("❌ Rota oluşturulamadı: \(error)")
        }
    }

    // MARK: Emission
    func emissionKg() -> Double {
        let km = distanceMeters / 1000
        let factor: Double
        switch selectedMode {
        case .walking: factor = 0.0
        case .car:     factor = 0.192
        case .transit: factor = 0.105
        }
        return km * factor
    }

    // MARK: Transit kişi başı emisyon hesabı
    struct TransitEmissionResult {
        let distanceKm: Double
        let fuelType: BusFuelType
        let consumptionPer100: Double
        let totalConsumption: Double
        let emissionFactor: Double
        let totalCO2Kg: Double
        let passengerCount: Int
        let perPassengerKg: Double
        let unitLabel: String
    }

    private func emissionFactor(for fuel: BusFuelType) -> (factor: Double, unit: String) {
        switch fuel {
        case .diesel:   return (2.68, "L")
        case .cng:      return (2.75, "kg")
        case .electric: return (0.00, "kWh")
        }
    }

    private func assumedPassengerCount(for kind: BusRouteKind) -> Int {
        switch kind {
        case .city: return 30
        case .intercity: return 40
        }
    }

    func computeTransitPerPassengerEmission() -> TransitEmissionResult? {
        guard selectedMode == .transit,
              distanceMeters > 0,
              let fuel = busFuelType,
              let cons = busConsumptionPer100,
              let kind = busRouteKind else { return nil }

        let km = distanceMeters / 1000.0
        let totalConsumption = (km / 100.0) * cons
        let ef = emissionFactor(for: fuel)
        let totalCO2 = totalConsumption * ef.factor
        let pax = assumedPassengerCount(for: kind)
        let perPax = pax > 0 ? totalCO2 / Double(pax) : totalCO2

        return TransitEmissionResult(distanceKm: km,
                                     fuelType: fuel,
                                     consumptionPer100: cons,
                                     totalConsumption: totalConsumption,
                                     emissionFactor: ef.factor,
                                     totalCO2Kg: totalCO2,
                                     passengerCount: pax,
                                     perPassengerKg: perPax,
                                     unitLabel: ef.unit)
    }

    // MARK: Firestore
    private func saveJourney(aiApplied: Bool = false) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let doc: [String: Any] = [
            "userId": uid,
            "date": Timestamp(date: Date()),
            "distanceKm": distanceMeters / 1000,
            "emissionKg": emissionKg(),
            "durationMin": expectedTime / 60,
            "mode": selectedMode.rawValue,
            "aiApplied": aiApplied
        ]
        do {
            try await db.collection("journeys").addDocument(data: doc)
        } catch {
            print("❌ saveJourney error: \(error)")
        }
    }

    func persistCurrentJourney() async {
        await saveJourney(aiApplied: false)
    }

    // Yeni: Seçilen yolculuğu (AI veya kullanıcı tercihi) açıkça kaydet
    func persistSelectedJourney(aiApplied: Bool) async {
        await saveJourney(aiApplied: aiApplied)
    }

    // MARK: Weather (opsiyonel)
    private func fetchWeatherIfAvailable(at coordinate: CLLocationCoordinate2D) async {
        if let svc = _OpenWeatherServiceSingleton.shared {
            do {
                let w = try await svc.current(at: coordinate)
                self.weatherInfo = w
            } catch {
                print("❌ Weather fetch error: \(error)")
            }
        }
    }
}

// Opsiyonel: uygulama başında set edebilirsin
final class _OpenWeatherServiceSingleton {
    static var shared: WeatherProviding?
}
