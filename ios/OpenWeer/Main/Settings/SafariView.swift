import SwiftUI
import SafariServices

/// Thin SwiftUI wrapper around `SFSafariViewController` so we can present
/// web pages (privacy, terms, LinkedIn) in-app without leaving OpenWeer.
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        let controller = SFSafariViewController(url: url, configuration: config)
        controller.preferredControlTintColor = UIColor(Color.owAccent)
        controller.dismissButtonStyle = .done
        return controller
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
