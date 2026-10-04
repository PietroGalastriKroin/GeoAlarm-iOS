import Foundation

/// Coordenada geográfica sem dependência de CoreLocation (mantém o Domain testável e puro).
struct Coordinate: Equatable, Hashable, Codable, Sendable {
    var latitude: Double
    var longitude: Double

    var isValid: Bool {
        (-90...90).contains(latitude) && (-180...180).contains(longitude)
    }
}

/// Um geo-alarme: um lugar, um raio, uma condição de disparo e tudo que é preciso para
/// montar a tela e o som do alerta.
struct GeoAlarm: Identifiable, Equatable, Hashable, Sendable {
    static let minRadiusMeters: Double = 100
    static let maxRadiusMeters: Double = 20_000

    var id: UUID = UUID()
    var title: String
    var message: String = ""
    var coordinate: Coordinate
    var radiusMeters: Double = 500
    var transition: GeofenceTransition = .enter
    var isEnabled: Bool = true
    var activeDays: Set<Weekday> = Weekday.everyDay

    var soundEnabled: Bool = true
    var vibrationEnabled: Bool = true
    /// Veja `SoundCatalog`: "default", "builtin:<nome>" ou "imported:<arquivo>".
    var soundID: String = SoundReference.defaultID
    var vibrationPattern: VibrationPattern = .continuous
    var volumeFadeInSeconds: Int = 15

    var snoozeType: SnoozeType = .time
    var snoozeMinutes: Int = 5
    var snoozeDistanceMeters: Double = 200

    var dismissStyle: DismissStyle = .swipe
    var showClock: Bool = true
    var showDistance: Bool = true
    /// Cor de fundo da tela do alarme no formato 0xRRGGBB. `nil` usa a cor de destaque do app.
    var backgroundColorRGB: Int? = nil
    /// Nome do arquivo (em Application Support/Backgrounds) da imagem de fundo.
    var backgroundImageFileName: String? = nil

    /// O raio efetivamente monitorado, respeitando o mínimo que o iOS consegue detectar bem.
    var effectiveRadiusMeters: Double {
        min(max(radiusMeters, Self.minRadiusMeters), Self.maxRadiusMeters)
    }

    /// Se o alarme pode disparar em `date`, respeitando a chave geral e os dias ativos.
    func isActive(on date: Date, calendar: Calendar = .current) -> Bool {
        isEnabled && activeDays.contains(Weekday(date: date, calendar: calendar))
    }

    /// Título mostrado na tela de alarme (usa um padrão quando o usuário deixou em branco).
    var displayTitle: String {
        title.trimmingCharacters(in: .whitespaces).isEmpty ? "Alarme" : title
    }
}

/// Referência a um som: padrão do sistema, embutido no app ou importado pelo usuário.
enum SoundReference: Equatable, Sendable {
    case systemDefault
    case builtIn(String)
    case imported(String)

    static let defaultID = "default"

    init(id: String) {
        if id.hasPrefix("builtin:") {
            self = .builtIn(String(id.dropFirst("builtin:".count)))
        } else if id.hasPrefix("imported:") {
            self = .imported(String(id.dropFirst("imported:".count)))
        } else {
            self = .systemDefault
        }
    }

    var id: String {
        switch self {
        case .systemDefault: return Self.defaultID
        case .builtIn(let name): return "builtin:\(name)"
        case .imported(let file): return "imported:\(file)"
        }
    }
}
