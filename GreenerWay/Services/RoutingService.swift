import Foundation
import MapKit

struct RouteResult {
    let polyline: MKPolyline
    let distanceMeters: Double
    let expectedTravelTime: TimeInterval
}

final class RoutingService {
    func route(from: CLLocationCoordinate2D,
               to: CLLocationCoordinate2D,
               mode: TransportMode) async throws -> RouteResult {
        
        let src = MKMapItem(placemark: .init(coordinate: from))
        let dst = MKMapItem(placemark: .init(coordinate: to))
        
        let request = MKDirections.Request()
        request.source = src
        request.destination = dst
        request.requestsAlternateRoutes = false
        
        request.transportType = {
            switch mode {
            case .walking: return .walking
            case .car: return .automobile
            case .transit: return .transit
            }
        }()
        
        let directions = MKDirections(request: request)
        let response = try await directions.calculate()
        
        guard let route = response.routes.first else {
            throw URLError(.badServerResponse)
        }
        
        return .init(polyline: route.polyline,
                     distanceMeters: route.distance,
                     expectedTravelTime: route.expectedTravelTime)
    }
}
