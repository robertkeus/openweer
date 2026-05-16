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
        case ..<thresholds[1]:  return Color(red: 155/255, green: 195/255, blue: 241/255)
        case ..<thresholds[2]:  return Color(red:  92/255, green: 142/255, blue: 232/255)
        case ..<thresholds[3]:  return Color(red:  31/255, green:  93/255, blue: 208/255)
        case ..<thresholds[4]:  return Color(red: 245/255, green: 213/255, blue:  45/255)
        case ..<thresholds[5]:  return Color(red: 245/255, green: 159/255, blue:  45/255)
        case ..<thresholds[6]:  return Color(red: 230/255, green:  53/255, blue:  61/255)
        case ..<thresholds[7]:  return Color(red: 163/255, green:  21/255, blue:  31/255)
        default:                return Color(red: 192/255, green:  38/255, blue: 211/255)
        }
    }
}
