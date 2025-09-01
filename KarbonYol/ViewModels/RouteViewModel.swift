import Foundation
import MapKit
import CoreLocation
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class RouteViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {

    // MARK: Inputs
    @Published var originText: String = ""
    @Published var destinationText: String = ""
    @Published var selectedMode: TransportMode = .car

    // MARK: Map / Route state
    @Published var originCoordinate: CLLocationCoordinate2D?
    @Published var destinationCoordinate: CLLocationCoordinate2D?
    @Published var routePolyline: MKPolyline?
    @Published var distanceMeters: Double = 0
    @Published var expectedTime: TimeInterval = 0

    // MARK: Weather (opsiyonel)
    @Published var weatherInfo: WeatherInfo?

    // MARK: Private
    private let geocoder = CLGeocoder()
    private let locationManager = CLLocationManager()
    private var didPrefillOrigin = false
    private let db = Firestore.firestore()

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    var canCreateRoute: Bool {
        let hasDest = !(destinationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) || destinationCoordinate != nil
        let hasOrigin = originCoordinate != nil || !(originText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        return hasOrigin && hasDest
    }

    // MARK: CLLocation
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        originCoordinate = loc.coordinate

        if !didPrefillOrigin && originText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            didPrefillOrigin = true
            Task { await prefillOriginAddress(from: loc) }
        }
    }

    private func prefillOriginAddress(from location: CLLocation) async {
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let p = placemarks.first {
                var parts: [String] = []
                if let sub = p.subLocality { parts.append(sub) }
                if let thr = p.thoroughfare { parts.append(thr) }
                if let city = p.locality { parts.append(city) }
                originText = parts.isEmpty ? "Mevcut Konum" : parts.joined(separator: " ")
            } else {
                originText = "Mevcut Konum"
            }
        } catch {
            originText = "Mevcut Konum"
        }
    }

    private func geocodeAddress(_ text: String) async throws -> CLLocationCoordinate2D {
        let list = try await geocoder.geocodeAddressString(text)
        guard let c = list.first?.location?.coordinate else {
            throw NSError(domain: "Geocode", code: -1, userInfo: [NSLocalizedDescriptionKey: "Adres bulunamadı"])
        }
        return c
    }

    // MARK: Route (Apple Maps)
    func buildRoute() async {
        do {
            // From
            let from: CLLocationCoordinate2D
            if !originText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && originText != "Mevcut Konum" {
                from = try await geocodeAddress(originText)
            } else if let live = originCoordinate {
                from = live
            } else {
                from = try await geocodeAddress(originText)
            }
            originCoordinate = from

            // To
            let to: CLLocationCoordinate2D
            if let picked = destinationCoordinate {
                to = picked
            } else {
                to = try await geocodeAddress(destinationText)
                destinationCoordinate = to
            }

            let req = MKDirections.Request()
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

            await fetchWeatherIfAvailable(at: from)   // opsiyonel
            await saveJourney()                        // Firestore

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

    // MARK: Firestore
    private func saveJourney() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let doc: [String: Any] = [
            "userId": uid,
            "date": Timestamp(date: Date()),
            "distanceKm": distanceMeters / 1000,
            "emissionKg": emissionKg(),
            "durationMin": expectedTime / 60,
            "mode": selectedMode.rawValue
        ]
        do {
            try await db.collection("journeys").addDocument(data: doc)
        } catch {
            print("❌ saveJourney error: \(error)")
        }
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
