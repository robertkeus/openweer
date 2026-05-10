import CoreLocation

struct KnownLocation: Identifiable, Hashable {
    let slug: String
    let name: String
    let lat: Double
    let lon: Double
    var id: String { slug }
    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: lat, longitude: lon) }
}

enum KnownLocations {
    static let all: [KnownLocation] = [
        .init(slug: "amsterdam",   name: "Amsterdam",   lat: 52.3676, lon: 4.9041),
        .init(slug: "rotterdam",   name: "Rotterdam",   lat: 51.9244, lon: 4.4777),
        .init(slug: "den-haag",    name: "Den Haag",    lat: 52.0705, lon: 4.3007),
        .init(slug: "utrecht",     name: "Utrecht",     lat: 52.0907, lon: 5.1214),
        .init(slug: "eindhoven",   name: "Eindhoven",   lat: 51.4416, lon: 5.4697),
        .init(slug: "groningen",   name: "Groningen",   lat: 53.2194, lon: 6.5665),
        .init(slug: "maastricht",  name: "Maastricht",  lat: 50.8514, lon: 5.6910),
        .init(slug: "arnhem",      name: "Arnhem",      lat: 51.9851, lon: 5.8987),
        .init(slug: "tilburg",     name: "Tilburg",     lat: 51.5719, lon: 5.0672),
        .init(slug: "leeuwarden",  name: "Leeuwarden",  lat: 53.2012, lon: 5.7999),
        .init(slug: "middelburg",  name: "Middelburg",  lat: 51.4988, lon: 3.6109),
        .init(slug: "enschede",    name: "Enschede",    lat: 52.2215, lon: 6.8937),
    ]
}

enum NLBoundingBox {
    static let minLat = 50.75
    static let maxLat = 53.48
    static let minLon = 3.36
    static let maxLon = 7.22

    static func contains(_ c: CLLocationCoordinate2D) -> Bool {
        c.latitude  >= minLat && c.latitude  <= maxLat &&
        c.longitude >= minLon && c.longitude <= maxLon
    }
}
