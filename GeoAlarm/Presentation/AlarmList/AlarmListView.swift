import SwiftUI

struct AlarmListView: View {
    @Environment(\.palette) private var palette
    @State private var viewModel = AlarmListViewModel()
    @State private var editing: EditTarget?
    @State private var showSettings = false

    private enum EditTarget: Identifiable {
        case new
        case existing(GeoAlarm)
        var id: String {
            switch self {
            case .new: return "new"
            case .existing(let alarm): return alarm.id.uuidString
            }
        }
    }

    var body: some View {
        List {
            Section {
                PermissionBanner()
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())

            if viewModel.alarms.isEmpty {
                Section {
                    EmptyStateView()
                }
                .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(viewModel.alarms) { alarm in
                        AlarmRow(alarm: alarm,
                                 onToggle: { viewModel.setEnabled(alarm, enabled: $0) })
                            .contentShape(Rectangle())
                            .onTapGesture { editing = .existing(alarm) }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    viewModel.delete(alarm)
                                } label: {
                                    Label("Excluir", systemImage: "trash")
                                }
                            }
                    }
                    .listRowBackground(palette.surface)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(palette.background)
        .navigationTitle("GeoAlarm")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Ajustes")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { editing = .new } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Novo alarme")
            }
        }
        .sheet(item: $editing, onDismiss: { viewModel.load() }) { target in
            NavigationStack {
                switch target {
                case .new: AlarmEditView(alarm: nil)
                case .existing(let alarm): AlarmEditView(alarm: alarm)
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack { SettingsView() }
        }
        .alert("Erro", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .onAppear { viewModel.load() }
    }
}

private struct AlarmRow: View {
    @Environment(\.palette) private var palette
    let alarm: GeoAlarm
    let onToggle: (Bool) -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(alarm.isEnabled ? palette.accentSoft : Color.secondary.opacity(0.15))
                Image(systemName: alarm.transition == .enter ? "arrow.down.right.circle" : "arrow.up.right.circle")
                    .font(.title3)
                    .foregroundStyle(alarm.isEnabled ? palette.onAccentSoft : Color.secondary)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text(alarm.displayTitle)
                    .font(.headline)
                    .lineLimit(1)
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            Toggle("", isOn: Binding(get: { alarm.isEnabled }, set: onToggle))
                .labelsHidden()
        }
        .padding(.vertical, 4)
        .opacity(alarm.isEnabled ? 1 : 0.6)
    }

    private var summary: String {
        let action = alarm.transition == .enter ? "Ao entrar" : "Ao sair"
        return "\(action) · \(Geo.formatDistance(alarm.radiusMeters)) · \(DaysFormatter.summary(alarm.activeDays))"
    }
}

private struct EmptyStateView: View {
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 52))
                .foregroundStyle(palette.accent)
            Text("Nenhum alarme ainda")
                .font(.title3.weight(.semibold))
            Text("Toque em + para criar um alarme que toca quando você chegar (ou sair) de um lugar.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
