import PhotosUI
import SwiftUI

struct AlarmEditView: View {
    @State private var viewModel: AlarmEditViewModel
    @State private var showPicker = false
    @State private var previewing: GeoAlarm?
    @State private var photoItem: PhotosPickerItem?
    @State private var testMessage: String?
    @State private var haptics = HapticPlayer()

    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette
    @Environment(AlarmCoordinator.self) private var coordinator

    init(alarm: GeoAlarm?) {
        _viewModel = State(initialValue: AlarmEditViewModel(existing: alarm))
    }

    var body: some View {
        @Bindable var vm = viewModel
        Form {
            infoSection(vm: vm)
            locationSection(vm: vm)
            triggerSection(vm: vm)
            daysSection(vm: vm)
            soundSection(vm: vm)
            vibrationSection(vm: vm)
            snoozeSection(vm: vm)
            screenSection(vm: vm)
            testSection(vm: vm)
        }
        .scrollContentBackground(.hidden)
        .background(palette.background)
        .navigationTitle(viewModel.isNew ? "Novo alarme" : "Editar alarme")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") {
                    viewModel.clearBackgroundImageIfUnsaved()
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Salvar") {
                    if viewModel.save() { dismiss() }
                }
                .fontWeight(.semibold)
            }
        }
        .alert("Atenção", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .fullScreenCover(item: $previewing) { alarm in
            AlarmTriggerView(alarm: alarm,
                             distanceMeters: nil,
                             isPreview: true,
                             onDismiss: { previewing = nil },
                             onSnooze: alarm.snoozeType == .none ? nil : { previewing = nil })
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    viewModel.setBackgroundImage(data)
                }
                photoItem = nil
            }
        }
        .onDisappear { haptics.stop() }
    }

    // MARK: Seções

    @ViewBuilder
    private func infoSection(vm: AlarmEditViewModel) -> some View {
        @Bindable var vm = vm
        Section {
            TextField("Título (ex.: Chegando no trabalho)", text: $vm.alarm.title)
            TextField("Mensagem", text: $vm.alarm.message, axis: .vertical)
                .lineLimit(1...3)
        } header: {
            Text("Alarme")
        }
        .listRowBackground(palette.surface)
    }

    @ViewBuilder
    private func locationSection(vm: AlarmEditViewModel) -> some View {
        @Bindable var vm = vm
        Section {
            NavigationLink {
                LocationPickerView(coordinate: $vm.alarm.coordinate,
                                   radiusMeters: $vm.alarm.radiusMeters,
                                   onConfirm: { vm.hasLocation = true })
            } label: {
                HStack {
                    Label("Escolher no mapa", systemImage: "map")
                    Spacer()
                    if vm.hasLocation {
                        Text(String(format: "%.4f, %.4f", vm.alarm.coordinate.latitude, vm.alarm.coordinate.longitude))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Não definido").foregroundStyle(.secondary)
                    }
                }
            }
            CoordinateFields(coordinate: $vm.alarm.coordinate, onEdit: { vm.hasLocation = true })

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Raio")
                    Spacer()
                    Text(Geo.formatDistance(vm.alarm.radiusMeters))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(value: $vm.alarm.radiusMeters, in: GeoAlarm.minRadiusMeters...5000, step: 50)
                RadiusChips(radiusMeters: $vm.alarm.radiusMeters)
            }
            .padding(.vertical, 4)
        } header: {
            Text("Local")
        } footer: {
            Text("Raios abaixo de 100 m não são confiáveis no iOS. A precisão do GPS e a latência do sistema fazem o alarme disparar alguns segundos depois de cruzar a borda.")
        }
        .listRowBackground(palette.surface)
    }

    @ViewBuilder
    private func triggerSection(vm: AlarmEditViewModel) -> some View {
        @Bindable var vm = vm
        Section("Disparar") {
            Picker("Disparar", selection: $vm.alarm.transition) {
                Text("Ao entrar na área").tag(GeofenceTransition.enter)
                Text("Ao sair da área").tag(GeofenceTransition.exit)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
        .listRowBackground(palette.surface)
    }

    @ViewBuilder
    private func daysSection(vm: AlarmEditViewModel) -> some View {
        @Bindable var vm = vm
        Section("Dias da semana") {
            WeekdayChips(selection: $vm.alarm.activeDays)
        }
        .listRowBackground(palette.surface)
    }

    @ViewBuilder
    private func soundSection(vm: AlarmEditViewModel) -> some View {
        @Bindable var vm = vm
        Section {
            Toggle("Tocar som", isOn: $vm.alarm.soundEnabled)
            if vm.alarm.soundEnabled {
                NavigationLink {
                    SoundPickerView(soundID: $vm.alarm.soundID)
                } label: {
                    HStack {
                        Text("Som")
                        Spacer()
                        Text(SoundCatalog.shared.displayName(for: SoundReference(id: vm.alarm.soundID)))
                            .foregroundStyle(.secondary)
                    }
                }
                Stepper(value: $vm.alarm.volumeFadeInSeconds, in: 0...60, step: 5) {
                    HStack {
                        Text("Volume crescente")
                        Spacer()
                        Text(vm.alarm.volumeFadeInSeconds == 0 ? "Desligado" : "\(vm.alarm.volumeFadeInSeconds) s")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text("Som")
        } footer: {
            Text("O volume crescente e o som escolhido valem com o app aberto. Com o app em segundo plano, o alarme do sistema usa o som padrão do iOS e toca mesmo no silencioso.")
        }
        .listRowBackground(palette.surface)
    }

    @ViewBuilder
    private func vibrationSection(vm: AlarmEditViewModel) -> some View {
        @Bindable var vm = vm
        Section("Vibração") {
            Toggle("Vibrar", isOn: $vm.alarm.vibrationEnabled)
            if vm.alarm.vibrationEnabled {
                Picker("Padrão", selection: $vm.alarm.vibrationPattern) {
                    ForEach(VibrationPattern.allCases.filter { $0 != .none }, id: \.self) { pattern in
                        Text(Self.name(of: pattern)).tag(pattern)
                    }
                }
                Button {
                    haptics.start(vm.alarm.vibrationPattern)
                    Task {
                        try? await Task.sleep(nanoseconds: 4_000_000_000)
                        haptics.stop()
                    }
                } label: {
                    Label("Testar vibração", systemImage: "waveform")
                }
            }
        }
        .listRowBackground(palette.surface)
    }

    @ViewBuilder
    private func snoozeSection(vm: AlarmEditViewModel) -> some View {
        @Bindable var vm = vm
        Section {
            Picker("Soneca", selection: $vm.alarm.snoozeType) {
                Text("Nenhuma").tag(SnoozeType.none)
                Text("Por tempo").tag(SnoozeType.time)
                Text("Por distância").tag(SnoozeType.distance)
            }
            .pickerStyle(.segmented)

            switch vm.alarm.snoozeType {
            case .time:
                Stepper(value: $vm.alarm.snoozeMinutes, in: 1...60) {
                    HStack {
                        Text("Repetir em")
                        Spacer()
                        Text("\(vm.alarm.snoozeMinutes) min").foregroundStyle(.secondary)
                    }
                }
            case .distance:
                Stepper(value: $vm.alarm.snoozeDistanceMeters, in: 50...2000, step: 50) {
                    HStack {
                        Text("Tocar de novo a menos de")
                        Spacer()
                        Text(Geo.formatDistance(vm.alarm.snoozeDistanceMeters)).foregroundStyle(.secondary)
                    }
                }
            case .none:
                EmptyView()
            }
        } header: {
            Text("Soneca")
        } footer: {
            if vm.alarm.snoozeType == .distance {
                Text("Para reverificar a distância, o app mantém a localização ligada em segundo plano (indicador azul) enquanto a soneca durar. Isso gasta mais bateria.")
            }
        }
        .listRowBackground(palette.surface)
    }

    @ViewBuilder
    private func screenSection(vm: AlarmEditViewModel) -> some View {
        @Bindable var vm = vm
        Section {
            Picker("Descartar", selection: $vm.alarm.dismissStyle) {
                Text("Botão").tag(DismissStyle.button)
                Text("Arrastar").tag(DismissStyle.swipe)
                Text("Segurar 3 s").tag(DismissStyle.hold)
            }
            Toggle("Mostrar hora atual", isOn: $vm.alarm.showClock)
            Toggle("Mostrar distância restante", isOn: $vm.alarm.showDistance)

            Toggle("Cor de fundo personalizada", isOn: Binding(
                get: { vm.alarm.backgroundColorRGB != nil },
                set: { vm.alarm.backgroundColorRGB = $0 ? (vm.alarm.backgroundColorRGB ?? 0x1C3FA8) : nil }
            ))
            if let rgb = vm.alarm.backgroundColorRGB {
                ColorPicker("Cor", selection: Binding(
                    get: { Color(rgb: rgb) },
                    set: { vm.alarm.backgroundColorRGB = $0.rgbValue }
                ), supportsOpacity: false)
            }

            let hasImage = vm.alarm.backgroundImageFileName != nil
            PhotosPicker(selection: $photoItem, matching: .images) {
                Label(hasImage ? "Trocar imagem de fundo" : "Escolher imagem de fundo",
                      systemImage: "photo")
            }
            if hasImage {
                Button(role: .destructive) {
                    vm.clearBackgroundImage()
                } label: {
                    Label("Remover imagem de fundo", systemImage: "trash")
                }
            }

            Button {
                previewing = vm.alarm
            } label: {
                Label("Pré-visualizar tela do alarme", systemImage: "eye")
            }
        } header: {
            Text("Tela do alarme")
        } footer: {
            Text("No iOS, a tela personalizada aparece quando o app está aberto. Com o iPhone bloqueado, o sistema mostra o alerta dele.")
        }
        .listRowBackground(palette.surface)
    }

    @ViewBuilder
    private func testSection(vm: AlarmEditViewModel) -> some View {
        Section {
            Button {
                let alarm = vm.alarm
                Task {
                    await coordinator.testDelivery(alarm, after: 10)
                    testMessage = "Alarme de teste agendado para daqui a 10 segundos. Bloqueie o iPhone para ver o alerta do sistema."
                }
            } label: {
                Label("Testar alarme em 10 s", systemImage: "bell.badge")
            }
            .disabled(vm.isNew)
            if let testMessage {
                Text(testMessage).font(.footnote).foregroundStyle(.secondary)
            }
        } footer: {
            if vm.isNew {
                Text("Salve o alarme primeiro para poder testá-lo.")
            } else {
                Text("Usa a versão salva do alarme. Bloqueie a tela e coloque o iPhone no silencioso para conferir que ele toca mesmo assim.")
            }
        }
        .listRowBackground(palette.surface)
    }

    private static func name(of pattern: VibrationPattern) -> String {
        switch pattern {
        case .none: return "Nenhuma"
        case .continuous: return "Contínuo"
        case .shortPulse: return "Pulso curto"
        case .sos: return "SOS"
        case .heartbeat: return "Batimento cardíaco"
        }
    }
}

// MARK: Componentes

/// Campos de latitude e longitude, para quem prefere digitar (funciona 100% offline).
private struct CoordinateFields: View {
    @Binding var coordinate: Coordinate
    var onEdit: () -> Void

    @State private var latText = ""
    @State private var lonText = ""
    @FocusState private var focus: Field?
    private enum Field { case lat, lon }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Latitude").frame(width: 90, alignment: .leading)
                TextField("-25,4284", text: $latText)
                    .keyboardType(.numbersAndPunctuation)
                    .focused($focus, equals: .lat)
                    .multilineTextAlignment(.trailing)
            }
            HStack {
                Text("Longitude").frame(width: 90, alignment: .leading)
                TextField("-49,2733", text: $lonText)
                    .keyboardType(.numbersAndPunctuation)
                    .focused($focus, equals: .lon)
                    .multilineTextAlignment(.trailing)
            }
        }
        .onAppear(perform: syncFromBinding)
        .onChange(of: coordinate) { _, _ in
            if focus == nil { syncFromBinding() }
        }
        .onChange(of: latText) { _, _ in commit() }
        .onChange(of: lonText) { _, _ in commit() }
    }

    private func syncFromBinding() {
        latText = String(format: "%.6f", coordinate.latitude)
        lonText = String(format: "%.6f", coordinate.longitude)
    }

    private func commit() {
        guard focus != nil,
              let lat = Self.parse(latText), let lon = Self.parse(lonText) else { return }
        let candidate = Coordinate(latitude: lat, longitude: lon)
        if candidate.isValid, candidate != coordinate {
            coordinate = candidate
            onEdit()
        }
    }

    private static func parse(_ text: String) -> Double? {
        Double(text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."))
    }
}

/// Sete chips de igual largura, sem quebra de linha.
private struct WeekdayChips: View {
    @Binding var selection: Set<Weekday>
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                ForEach(DaysFormatter.displayOrder, id: \.self) { day in
                    let selected = selection.contains(day)
                    Button {
                        if selected { selection.remove(day) } else { selection.insert(day) }
                    } label: {
                        Text(DaysFormatter.shortNames[day] ?? "")
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(selected ? palette.accent : palette.accentSoft, in: Capsule())
                            .foregroundStyle(selected ? palette.onAccent : palette.onAccentSoft)
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack(spacing: 8) {
                quick("Todos", Weekday.everyDay)
                quick("Seg a Sex", Weekday.weekdays)
                quick("Fim de semana", Weekday.weekend)
            }
        }
        .padding(.vertical, 4)
    }

    private func quick(_ title: String, _ set: Set<Weekday>) -> some View {
        Button(title) { selection = set }
            .font(.footnote)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .buttonStyle(.bordered)
    }
}
