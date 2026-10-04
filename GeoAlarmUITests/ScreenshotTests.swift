import XCTest

/// Percorre as telas do app e salva capturas de tela em `$SIMULATOR_HOST_HOME/ui-shots`.
/// Serve para inspecionar o layout no CI, já que não há Xcode local. Não faz asserções
/// rígidas sobre o visual, só garante que a navegação principal funciona.
final class ScreenshotTests: XCTestCase {
    private var app: XCUIApplication!
    private var counter = 0

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        // Evita travar nos diálogos de permissão do sistema.
        addUIInterruptionMonitor(withDescription: "Permissões") { alert in
            for label in ["Allow While Using App", "Permitir ao Usar o App", "Allow", "Permitir", "OK"] {
                if alert.buttons[label].exists { alert.buttons[label].tap(); return true }
            }
            return false
        }
    }

    private func launch(_ extra: [String] = [], dark: Bool = false) {
        var args = ["-seedDemo", "-AppleLanguages", "(pt-BR)", "-AppleLocale", "pt_BR"]
        if dark { args += ["-settings.themeMode", "dark"] } else { args += ["-settings.themeMode", "light"] }
        app.launchArguments = args + extra
        app.launch()
    }

    private func shot(_ name: String) {
        counter += 1
        let data = XCUIScreen.main.screenshot().pngRepresentation
        let base = ProcessInfo.processInfo.environment["SIMULATOR_HOST_HOME"] ?? NSTemporaryDirectory()
        let dir = URL(fileURLWithPath: base).appendingPathComponent("ui-shots", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent(String(format: "%02d-%@.png", counter, name))
        try? data.write(to: file)
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func tapIfExists(_ element: XCUIElement, timeout: TimeInterval = 4) -> Bool {
        guard element.waitForExistence(timeout: timeout) else { return false }
        element.tap()
        return true
    }

    func testMainTourLight() {
        launch()
        sleep(2)
        app.tap()   // dispara o monitor de interrupção de permissões, se houver
        sleep(1)
        shot("lista-claro")

        // Editar um alarme existente
        if tapIfExists(app.staticTexts["Casa"]) {
            sleep(1)
            shot("editar-topo")
            for i in 1...5 {
                app.swipeUp()
                sleep(1)
                shot("editar-rolagem\(i)")
            }
            // Mapa
            for _ in 1...6 { app.swipeDown() }
            if tapIfExists(app.staticTexts["Escolher no mapa"]) {
                sleep(4)
                shot("mapa")
                app.navigationBars.buttons.firstMatch.tap()
            }
            _ = tapIfExists(app.buttons["Cancelar"])
        }

        // Novo alarme
        if tapIfExists(app.buttons["Novo alarme"]) {
            sleep(1)
            shot("novo-alarme")
            _ = tapIfExists(app.buttons["Cancelar"])
        }

        // Ajustes
        if tapIfExists(app.buttons["Ajustes"]) {
            sleep(1)
            shot("ajustes-topo")
            app.swipeUp()
            sleep(1)
            shot("ajustes-rolagem")
        }
    }

    func testMainTourDark() {
        launch(dark: true)
        sleep(2)
        app.tap()
        sleep(1)
        shot("lista-escuro")
        if tapIfExists(app.staticTexts["Casa"]) {
            sleep(1)
            shot("editar-escuro")
        }
    }

    func testTriggerSwipe() {
        launch(["-showTrigger", "swipe"])
        sleep(2)
        shot("alarme-arrastar")
    }

    func testTriggerHold() {
        launch(["-showTrigger", "hold"])
        sleep(2)
        shot("alarme-segurar")
    }

    func testTriggerButtonDark() {
        launch(["-showTrigger", "button"], dark: true)
        sleep(2)
        shot("alarme-botao")
    }
}
