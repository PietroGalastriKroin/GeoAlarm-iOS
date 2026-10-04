import SwiftUI

/// Raiz da interface: lista de alarmes e a tela de alarme em tela cheia por cima de tudo.
struct RootView: View {
    @Environment(AlarmCoordinator.self) private var coordinator
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.palette) private var palette

    var body: some View {
        NavigationStack {
            AlarmListView()
        }
        .fullScreenCover(item: Binding(
            get: { coordinator.activeAlarm },
            set: { newValue in if newValue == nil { coordinator.dismiss() } }
        )) { alarm in
            AlarmTriggerView(
                alarm: alarm,
                distanceMeters: coordinator.distanceMeters,
                isPreview: false,
                onDismiss: { coordinator.dismiss() },
                onSnooze: alarm.snoozeType == .none ? nil : { Task { await coordinator.snooze() } }
            )
            .task { await coordinator.refreshDistance() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                // Ao voltar para o app, reaplica as regiões (a posição pode ter mudado bastante).
                AppContainer.shared.resyncGeofences()
            }
        }
    }
}
