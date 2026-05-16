import SwiftUI
import WidgetKit

@main
struct OpenWeerWidgetsBundle: WidgetBundle {
    var body: some Widget {
        CurrentConditionsWidget()
        RainNowcastWidget()
        ForecastWidget()
        RainLiveActivity()
    }
}
