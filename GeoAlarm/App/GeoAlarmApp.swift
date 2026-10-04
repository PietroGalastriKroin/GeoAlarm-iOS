import SwiftUI

@main
struct GeoAlarmApp: App {
    private let container = AppContainer.shared

    init() {
        // Também roda quando o sistema relança o app em segundo plano por um evento de região.
        AppContainer.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            ThemedRoot {
                RootView()
            }
            .environment(container.settingsStore)
            .environment(container.coordinator)
            .environment(container.location)
        }
    }
}
