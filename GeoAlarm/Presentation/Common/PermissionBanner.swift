import SwiftUI
import UIKit

/// Fluxo de permissão de localização em duas etapas, como no Android: primeiro "ao usar o
/// app", depois "sempre". Nunca pede os dois juntos.
struct PermissionBanner: View {
    @Environment(LocationEngine.self) private var location
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 10) {
            switch location.authorization {
            case .notDetermined:
                banner(icon: "location",
                       title: "Permitir localização",
                       message: "O GeoAlarm precisa saber onde você está para disparar os alarmes. Passo 1 de 2.",
                       primary: ("Permitir ao usar o app", { location.requestWhenInUse() }),
                       showSettings: false)
            case .whenInUse:
                banner(icon: "location.fill",
                       title: "Falta um passo: localização \"Sempre\"",
                       message: "Para o alarme tocar com o app fechado, escolha \"Sempre\" na próxima tela. Se ela não aparecer, abra os Ajustes. Passo 2 de 2.",
                       primary: ("Permitir \"Sempre\"", { location.requestAlways() }),
                       showSettings: true)
            case .denied:
                banner(icon: "location.slash",
                       title: "Localização negada",
                       message: "Sem a localização o app não consegue disparar alarmes. Ative em Ajustes > GeoAlarm > Localização.",
                       primary: nil,
                       showSettings: true)
            case .always:
                if location.overflowCount > 0 {
                    note("O iOS limita o monitoramento a 20 áreas. \(location.overflowCount) alarme(s) ligado(s) ficam em espera e entram em vigor quando você chega perto deles.")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, location.authorization == .always && location.overflowCount == 0 ? 0 : 8)
    }

    private func banner(icon: String, title: String, message: String,
                        primary: (String, () -> Void)?, showSettings: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(palette.accent)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline)
                    Text(message).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            HStack {
                if let primary {
                    Button(primary.0, action: primary.1)
                        .buttonStyle(.borderedProminent)
                }
                if showSettings {
                    Button("Abrir Ajustes") { openSettings() }
                        .buttonStyle(.bordered)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.accentSoft.opacity(0.6), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func note(_ text: String) -> some View {
        Label(text, systemImage: "info.circle")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
