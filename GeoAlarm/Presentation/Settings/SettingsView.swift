import SwiftUI
import UIKit
import UserNotifications

struct SettingsView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(LocationEngine.self) private var location
    @Environment(AlarmCoordinator.self) private var coordinator
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    @State private var notificationStatus = "Verificando…"
    @State private var alarmKitStatus = "Verificando…"
    @State private var testMessage: String?
    private let eventLog = EventLog.shared

    private static let swatches: [Int] = [0x3B6EF6, 0x7C4DFF, 0xE91E63, 0xF4511E, 0xFB8C00, 0x2E7D32, 0x00897B, 0x546E7A]

    var body: some View {
        Form {
            appearanceSection
            permissionsSection
            systemAlarmSection
            diagnosticsSection
            aboutSection
        }
        .scrollContentBackground(.hidden)
        .background(palette.background)
        .navigationTitle("Ajustes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("OK") { dismiss() }
            }
        }
        .task { await refreshStatuses() }
    }

    // MARK: Aparência

    private var appearanceSection: some View {
        Section("Aparência") {
            Picker("Tema", selection: Binding(
                get: { settings.settings.themeMode },
                set: { mode in settings.update { $0.themeMode = mode } }
            )) {
                Text("Claro").tag(ThemeMode.light)
                Text("Escuro").tag(ThemeMode.dark)
                Text("Automático").tag(ThemeMode.system)
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 10) {
                Text("Cor de destaque")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 8), spacing: 10) {
                    ForEach(Self.swatches, id: \.self) { rgb in
                        Button {
                            settings.update { $0.accentColorRGB = rgb }
                        } label: {
                            Circle()
                                .fill(Color(rgb: rgb))
                                .aspectRatio(1, contentMode: .fit)
                                .overlay {
                                    if settings.settings.accentColorRGB == rgb {
                                        Image(systemName: "checkmark")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Cor \(String(rgb, radix: 16))")
                    }
                }
            }
            .padding(.vertical, 4)

            ColorPicker("Outra cor", selection: Binding(
                get: { Color(rgb: settings.settings.accentColorRGB) },
                set: { color in settings.update { $0.accentColorRGB = color.rgbValue } }
            ), supportsOpacity: false)
        }
        .listRowBackground(palette.surface)
    }

    // MARK: Permissões

    private var permissionsSection: some View {
        Section {
            statusRow("Localização", value: locationText, ok: location.authorization == .always)
            statusRow("Notificações", value: notificationStatus, ok: notificationStatus == "Permitidas")
            if #available(iOS 26.0, *) {
                statusRow("Alarmes do sistema", value: alarmKitStatus, ok: alarmKitStatus == "Permitidos")
            } else {
                statusRow("Alarmes do sistema", value: "Requer iOS 26", ok: false)
            }
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Label("Abrir Ajustes do iOS", systemImage: "gearshape")
            }
        } header: {
            Text("Permissões")
        } footer: {
            Text("Para tocar com o app fechado, o GeoAlarm precisa de localização \"Sempre\" e de permissão para alarmes.")
        }
        .listRowBackground(palette.surface)
    }

    private var locationText: String {
        switch location.authorization {
        case .notDetermined: return "Não solicitada"
        case .denied: return "Negada"
        case .whenInUse: return "Só ao usar o app"
        case .always: return "Sempre"
        }
    }

    private func statusRow(_ title: String, value: String, ok: Bool) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundStyle(.secondary)
            Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.circle")
                .foregroundStyle(ok ? Color.green : Color.orange)
        }
    }

    private func refreshStatuses() async {
        let status = await AppContainer.shared.fallbackDelivery.authorizationStatus()
        switch status {
        case .authorized, .provisional, .ephemeral: notificationStatus = "Permitidas"
        case .denied: notificationStatus = "Negadas"
        case .notDetermined: notificationStatus = "Não solicitadas"
        @unknown default: notificationStatus = "Desconhecido"
        }
        if #available(iOS 26.0, *) {
            switch AppContainer.shared.delivery.alarmKit.authorizationState {
            case .authorized: alarmKitStatus = "Permitidos"
            case .denied: alarmKitStatus = "Negados"
            case .notDetermined: alarmKitStatus = "Não solicitados"
            @unknown default: alarmKitStatus = "Desconhecido"
            }
        }
    }

    // MARK: Alarme do sistema

    private var systemAlarmSection: some View {
        Section {
            Toggle("Som escolhido no alerta do sistema (experimental)", isOn: Binding(
                get: { settings.settings.customSoundInSystemAlert },
                set: { value in settings.update { $0.customSoundInSystemAlert = value } }
            ))
            Button {
                Task { await runSystemTest() }
            } label: {
                Label("Testar alarme do sistema em 10 s", systemImage: "bell.badge")
            }
            if let testMessage {
                Text(testMessage).font(.footnote).foregroundStyle(.secondary)
            }
        } header: {
            Text("Alarme do sistema")
        } footer: {
            Text("Se ligar a opção experimental e o alarme tocar mudo ou com o som errado no teste, desligue-a. Para o teste, bloqueie o iPhone e coloque-o no silencioso.")
        }
        .listRowBackground(palette.surface)
    }

    private func runSystemTest() async {
        var alarm = GeoAlarm(title: "Teste do GeoAlarm", coordinate: Coordinate(latitude: 0, longitude: 0))
        alarm.message = "Se você está vendo isto, o alarme do sistema funciona."
        alarm.snoozeType = .none
        await coordinator.testDelivery(alarm, after: 10)
        testMessage = "Teste agendado para daqui a 10 segundos. Bloqueie a tela agora."
        await refreshStatuses()
    }

    // MARK: Diagnóstico

    private var diagnosticsSection: some View {
        Section {
            HStack {
                Text("Áreas monitoradas")
                Spacer()
                Text("\(location.monitoredAlarmIDs.count) de 20").foregroundStyle(.secondary)
            }
            if eventLog.entries.isEmpty {
                Text("Nenhum evento registrado ainda.").foregroundStyle(.secondary)
            } else {
                ForEach(eventLog.entries.prefix(30)) { entry in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.text).font(.footnote)
                        Text(entry.date.formatted(date: .abbreviated, time: .standard))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Button(role: .destructive) {
                    eventLog.clear()
                } label: {
                    Label("Limpar registro", systemImage: "trash")
                }
            }
        } header: {
            Text("Diagnóstico")
        } footer: {
            Text("O registro mostra o que aconteceu com o app fechado (eventos de região, alarmes agendados, erros).")
        }
        .listRowBackground(palette.surface)
    }

    private var aboutSection: some View {
        Section("Sobre") {
            HStack {
                Text("Versão")
                Spacer()
                Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?")
                    .foregroundStyle(.secondary)
            }
        }
        .listRowBackground(palette.surface)
    }
}
