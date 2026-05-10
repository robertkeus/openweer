import Foundation
import SwiftUI

enum BasemapStyle {
    case positron
    case darkMatter

    var url: URL {
        switch self {
        case .positron:
            return URL(string: "https://tiles.openfreemap.org/styles/positron")!
        case .darkMatter:
            return URL(string: "https://tiles.openfreemap.org/styles/dark")!
        }
    }

    static func resolve(for colorScheme: ColorScheme) -> BasemapStyle {
        colorScheme == .dark ? .darkMatter : .positron
    }
}
