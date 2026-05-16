import SwiftUI
import WidgetKit
import ActivityKit

struct RainLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RainActivityAttributes.self) { context in
            RainActivityLockScreen(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(Color.owSurfaceCard)
                .activitySystemActionForegroundColor(Color.owInkPrimary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    RainExpandedLeading(state: context.state)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    RainExpandedTrailing(state: context.state)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    RainExpandedBottom(state: context.state)
                }
            } compactLeading: {
                Image(systemName: "umbrella.fill")
                    .foregroundStyle(Color.owAccent)
            } compactTrailing: {
                Text(RainActivityFormatting.compactTrailing(state: context.state))
                    .font(.caption2.monospacedDigit())
            } minimal: {
                Image(systemName: "umbrella.fill")
                    .foregroundStyle(Color.owAccent)
            }
            .widgetURL(URL(string: "openweer://rain"))
        }
    }
}
