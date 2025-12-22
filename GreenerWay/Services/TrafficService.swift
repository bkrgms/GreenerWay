import Foundation
import MapKit
import Combine

// MARK: - Traffic Models

enum TrafficSeverity: String, Codable, CaseIterable {
    case low = "Düşük"
    case moderate = "Orta"
    case heavy = "Yoğun"
    case severe = "Çok Yoğun"
    
    var color: String {
        switch self {
        case .low: return "green"
        case .moderate: return "yellow"
        case .heavy: return "orange"
        case .severe: return "red"
        }
    }
    
    var icon: String {
        switch self {
        case .low: return "car.fill"
        case .moderate: return "car.2.fill"
        case .heavy: return "exclamationmark.triangle.fill"
        case .severe: return "xmark.octagon.fill"
        }
    }
    
    var delayMultiplier: Double {
        switch self {
        case .low: return 1.0
        case .moderate: return 1.3
        case .heavy: return 1.6
        case .severe: return 2.0
        }
    }
}

struct TrafficInfo: Codable, Identifiable {
    let id: UUID
    let severity: TrafficSeverity
    let estimatedDelay: TimeInterval // saniye
    let averageSpeed: Double // km/h
    let description: String
    let timestamp: Date
    let routeSegment: String?
    
    init(severity: TrafficSeverity, estimatedDelay: TimeInterval, averageSpeed: Double, description: String, routeSegment: String? = nil) {
        self.id = UUID()
        self.severity = severity
        self.estimatedDelay = estimatedDelay
        self.averageSpeed = averageSpeed
        self.description = description
        self.timestamp = Date()
        self.routeSegment = routeSegment
    }
    
    var delayText: String {
        let minutes = Int(estimatedDelay / 60)
        if minutes < 1 {
            return "Gecikme yok"
        } else if minutes == 1 {
            return "~1 dk gecikme"
        } else {
            return "~\(minutes) dk gecikme"
        }
    }
    
    var speedText: String {
        return String(format: "%.0f km/h", averageSpeed)
    }
}

// MARK: - Traffic Service

@MainActor
class TrafficService: ObservableObject {
    static let shared = TrafficService()
    
    @Published var currentTraffic: TrafficInfo?
    @Published var isLoading = false
    @Published var lastUpdate: Date?
    
    private init() {}
    
    /// Apple Maps üzerinden rota bilgisi alarak trafik durumunu hesaplar
    func fetchTrafficInfo(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D, expectedTime: TimeInterval, distanceMeters: Double) async -> TrafficInfo? {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
            request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
            request.transportType = .automobile
            request.requestsAlternateRoutes = false
            
            let directions = MKDirections(request: request)
            let response = try await directions.calculateETA()
            
            let expectedTimeWithTraffic = response.expectedTravelTime
            let distanceKm = distanceMeters / 1000
            
            // Ortalama hız hesapla
            let averageSpeed = distanceKm / (expectedTimeWithTraffic / 3600)
            
            // Gecikme hesapla (trafik olmadan beklenen süre vs gerçek süre)
            let normalExpectedTime = distanceKm / 50 * 3600 // 50 km/h varsayılan
            let delay = max(0, expectedTimeWithTraffic - normalExpectedTime)
            
            // Trafik yoğunluğu belirle
            let severity = determineSeverity(averageSpeed: averageSpeed, delay: delay)
            
            let description = generateTrafficDescription(severity: severity, averageSpeed: averageSpeed)
            
            let trafficInfo = TrafficInfo(
                severity: severity,
                estimatedDelay: delay,
                averageSpeed: averageSpeed,
                description: description,
                routeSegment: nil
            )
            
            currentTraffic = trafficInfo
            lastUpdate = Date()
            
            return trafficInfo
            
        } catch {
            print("❌ Trafik bilgisi alınamadı: \(error.localizedDescription)")
            
            // Fallback: Basit hesaplama
            let distanceKm = distanceMeters / 1000
            let averageSpeed = distanceKm / (expectedTime / 3600)
            let severity = determineSeverity(averageSpeed: averageSpeed, delay: 0)
            
            let trafficInfo = TrafficInfo(
                severity: severity,
                estimatedDelay: 0,
                averageSpeed: averageSpeed,
                description: generateTrafficDescription(severity: severity, averageSpeed: averageSpeed),
                routeSegment: nil
            )
            
            currentTraffic = trafficInfo
            lastUpdate = Date()
            
            return trafficInfo
        }
    }
    
    /// Mevcut konum için basit trafik kontrolü
    func checkTrafficForCurrentLocation() async -> TrafficInfo? {
        guard let location = LocationDelegate.shared.lastLocation else {
            return nil
        }
        
        // Yakın çevrede trafik kontrolü için küçük bir rota hesapla
        let nearbyCoord = CLLocationCoordinate2D(
            latitude: location.coordinate.latitude + 0.01,
            longitude: location.coordinate.longitude + 0.01
        )
        
        return await fetchTrafficInfo(
            from: location.coordinate,
            to: nearbyCoord,
            expectedTime: 300, // 5 dakika
            distanceMeters: 1000 // 1 km
        )
    }
    
    private func determineSeverity(averageSpeed: Double, delay: TimeInterval) -> TrafficSeverity {
        // Hız ve gecikmeye göre trafik yoğunluğu
        if averageSpeed >= 45 && delay < 60 {
            return .low
        } else if averageSpeed >= 30 && delay < 300 {
            return .moderate
        } else if averageSpeed >= 15 && delay < 600 {
            return .heavy
        } else {
            return .severe
        }
    }
    
    private func generateTrafficDescription(severity: TrafficSeverity, averageSpeed: Double) -> String {
        switch severity {
        case .low:
            return "Trafik akıcı. Yolculuğunuz sorunsuz olacak."
        case .moderate:
            return "Trafik orta yoğunlukta. Küçük gecikmeler olabilir."
        case .heavy:
            return "Trafik yoğun. Alternatif rota düşünebilirsiniz."
        case .severe:
            return "Trafik çok yoğun! Mümkünse yolculuğu erteleyin veya toplu taşıma kullanın."
        }
    }
    
    /// Trafik durumuna göre ek süre hesapla
    func calculateAdjustedTime(originalTime: TimeInterval, traffic: TrafficInfo?) -> TimeInterval {
        guard let traffic = traffic else { return originalTime }
        return originalTime * traffic.severity.delayMultiplier
    }
}
