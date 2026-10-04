import Foundation

/// Distância entre dois pontos pela fórmula de Haversine. Matemática pura, sem GPS nem rede.
enum Geo {
    static let earthRadiusMeters = 6_371_000.0

    static func distanceMeters(from a: Coordinate, to b: Coordinate) -> Double {
        let lat1 = a.latitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let dLat = (b.latitude - a.latitude) * .pi / 180
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let h = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return earthRadiusMeters * 2 * atan2(sqrt(h), sqrt(1 - h))
    }

    static func isWithin(_ radiusMeters: Double, of center: Coordinate, point: Coordinate) -> Bool {
        distanceMeters(from: center, to: point) <= radiusMeters
    }

    /// "850 m" abaixo de 1 km, "1,2 km" acima.
    static func formatDistance(_ meters: Double) -> String {
        if meters < 1000 {
            return "\(Int(meters.rounded())) m"
        }
        let km = meters / 1000
        let text = km < 10 ? String(format: "%.1f", km) : String(Int(km.rounded()))
        return text.replacingOccurrences(of: ".", with: ",") + " km"
    }
}
