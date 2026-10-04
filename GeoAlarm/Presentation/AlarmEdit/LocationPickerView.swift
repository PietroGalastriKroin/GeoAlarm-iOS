import MapKit
import SwiftUI

/// Mapa com pino fixo no centro e um círculo do raio de ativação. O círculo é desenhado em
/// coordenadas geográficas reais (`MapCircle`, raio em metros), então acompanha tanto o
/// slider de raio quanto o zoom do mapa.
struct LocationPickerView: View {
    @Binding var coordinate: Coordinate
    @Binding var radiusMeters: Double
    var onConfirm: () -> Void

    @Environment(LocationEngine.self) private var location
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    @State private var position: MapCameraPosition
    @State private var center: CLLocationCoordinate2D
    @State private var query = ""
    @State private var results: [MKMapItem] = []
    @State private var searching = false
    @State private var searchMessage: String?

    init(coordinate: Binding<Coordinate>, radiusMeters: Binding<Double>, onConfirm: @escaping () -> Void) {
        _coordinate = coordinate
        _radiusMeters = radiusMeters
        self.onConfirm = onConfirm
        let start = CLLocationCoordinate2D(latitude: coordinate.wrappedValue.latitude,
                                           longitude: coordinate.wrappedValue.longitude)
        let span = max(radiusMeters.wrappedValue * 6, 1500)
        _center = State(initialValue: start)
        _position = State(initialValue: .region(MKCoordinateRegion(center: start,
                                                                    latitudinalMeters: span,
                                                                    longitudinalMeters: span)))
    }

    var body: some View {
        ZStack {
            Map(position: $position) {
                MapCircle(center: center, radius: radiusMeters)
                    .foregroundStyle(palette.accent.opacity(0.18))
                    .stroke(palette.accent, lineWidth: 2)
                UserAnnotation()
            }
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .onMapCameraChange(frequency: .continuous) { context in
                center = context.region.center
            }

            // Pino fixo no centro; a ponta do pino fica exatamente no centro do mapa.
            Image(systemName: "mappin")
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(palette.accent)
                .shadow(radius: 2)
                .offset(y: -19)
                .allowsHitTesting(false)
        }
        .safeAreaInset(edge: .top) { searchBar }
        .safeAreaInset(edge: .bottom) { controlPanel }
        .navigationTitle("Local do alarme")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Busca

    private var searchBar: some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Buscar endereço ou lugar", text: $query)
                    .submitLabel(.search)
                    .onSubmit { Task { await search() } }
                if searching { ProgressView() }
                if !query.isEmpty {
                    Button { query = ""; results = []; searchMessage = nil } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                }
            }
            .padding(10)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            if let searchMessage {
                Text(searchMessage)
                    .font(.footnote)
                    .padding(8)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            if !results.isEmpty {
                VStack(spacing: 0) {
                    ForEach(results.prefix(5), id: \.self) { item in
                        Button { select(item) } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name ?? "Local").font(.subheadline.weight(.medium))
                                if let subtitle = item.placemark.title {
                                    Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                }
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
    }

    private func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        searching = true
        searchMessage = nil
        defer { searching = false }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmed
        request.region = MKCoordinateRegion(center: center, latitudinalMeters: 50_000, longitudinalMeters: 50_000)
        do {
            let response = try await MKLocalSearch(request: request).start()
            results = response.mapItems
            if results.isEmpty { searchMessage = "Nada encontrado." }
        } catch {
            results = []
            searchMessage = "A busca precisa de internet. Você ainda pode mover o mapa ou digitar as coordenadas."
        }
    }

    private func select(_ item: MKMapItem) {
        let target = item.placemark.coordinate
        results = []
        query = item.name ?? query
        withAnimation {
            position = .region(MKCoordinateRegion(center: target,
                                                  latitudinalMeters: max(radiusMeters * 6, 1500),
                                                  longitudinalMeters: max(radiusMeters * 6, 1500)))
        }
    }

    // MARK: Painel inferior

    private var controlPanel: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Raio")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(Geo.formatDistance(radiusMeters))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: $radiusMeters,
                   in: GeoAlarm.minRadiusMeters...5000,
                   step: 50)
            RadiusChips(radiusMeters: $radiusMeters)

            HStack(spacing: 10) {
                Button {
                    Task {
                        if let here = await location.currentLocation() {
                            withAnimation {
                                position = .region(MKCoordinateRegion(
                                    center: CLLocationCoordinate2D(latitude: here.latitude, longitude: here.longitude),
                                    latitudinalMeters: max(radiusMeters * 6, 1500),
                                    longitudinalMeters: max(radiusMeters * 6, 1500)))
                            }
                        } else {
                            searchMessage = "Não consegui obter sua localização."
                        }
                    }
                } label: {
                    Label("Minha posição", systemImage: "location.fill")
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    coordinate = Coordinate(latitude: center.latitude, longitude: center.longitude)
                    onConfirm()
                    dismiss()
                } label: {
                    Label("Usar este local", systemImage: "checkmark")
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .background(.regularMaterial)
    }
}

/// Atalhos de raio sem quebra de linha.
struct RadiusChips: View {
    @Binding var radiusMeters: Double
    private let presets: [(String, Double)] = [("100 m", 100), ("500 m", 500), ("1 km", 1000), ("2 km", 2000)]
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 8) {
            ForEach(presets, id: \.1) { label, value in
                let selected = abs(radiusMeters - value) < 1
                Button { radiusMeters = value } label: {
                    Text(label)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selected ? palette.accent : palette.accentSoft,
                                    in: Capsule())
                        .foregroundStyle(selected ? palette.onAccent : palette.onAccentSoft)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
