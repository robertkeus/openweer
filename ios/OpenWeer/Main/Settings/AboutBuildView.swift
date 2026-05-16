import SwiftUI

/// "Hoe is dit gebouwd" — credits the data source, the stack, and the
/// open-source nature of the project. Pushed onto the settings nav stack.
struct AboutBuildView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("about_build.intro", bundle: .main)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.owInkSecondary)

                section(
                    title: "about_build.data_heading",
                    body: "about_build.data_body"
                )
                section(
                    title: "about_build.stack_heading",
                    body: "about_build.stack_body"
                )
                section(
                    title: "about_build.opensource_heading",
                    body: "about_build.opensource_body"
                )
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.owSurface.ignoresSafeArea())
        .navigationTitle(Text("about_build.title", bundle: .main))
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func section(title: String.LocalizationValue, body: String.LocalizationValue) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: title, bundle: .main))
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.owInkPrimary)
            Text(String(localized: body, bundle: .main))
                .font(.system(size: 15))
                .foregroundStyle(Color.owInkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
