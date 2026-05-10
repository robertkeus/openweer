import SwiftUI

extension Color {
    static let owAccent      = Color("AccentColor")
    static let owSun         = Color("SunYellow")
    static let owSurface     = Color("SurfaceBackground")
    static let owSurfaceCard = Color("SurfaceCard")
    static let owInkPrimary  = Color("InkPrimary")
    static let owInkSecondary = Color("InkSecondary")
    static let owDanger      = Color("Danger")
    static let owNoRain      = Color("NoRain")
}

enum RainIntensity {
    static let thresholds: [Double] = [0.1, 0.5, 1, 2, 5, 10, 20, 50]

    static func color(forMmPerHour mm: Double) -> Color {
        switch mm {
        case ..<thresholds[0]:  return .owNoRain
        case ..<thresholds[1]:  return Color(red: 0.74, green: 0.86, blue: 1.00)
        case ..<thresholds[2]:  return Color(red: 0.45, green: 0.71, blue: 0.95)
        case ..<thresholds[3]:  return Color(red: 0.20, green: 0.55, blue: 0.85)
        case ..<thresholds[4]:  return Color(red: 0.12, green: 0.34, blue: 0.80)
        case ..<thresholds[5]:  return Color(red: 0.40, green: 0.20, blue: 0.65)
        case ..<thresholds[6]:  return Color(red: 0.65, green: 0.18, blue: 0.50)
        case ..<thresholds[7]:  return Color(red: 0.85, green: 0.20, blue: 0.30)
        default:                return Color(red: 0.95, green: 0.10, blue: 0.10)
        }
    }
}
