# GeoAlarm iOS: design e decisões

Par iOS do app Android [GeoAlarm](https://github.com/PietroGalastriKroin/GeoAlarm). Despertador por
geofencing, 100% offline na lógica de alarme. Este documento registra as decisões tomadas e os
riscos conhecidos. Aprovação: o autor delegou as escolhas ("do jeito que achar melhor"), então
estas decisões foram tomadas pelo implementador e podem ser revertidas.

## Contexto que moldou as decisões

- Dispositivo alvo do autor: iPhone 15, iOS 26.0.6.
- Desenvolvimento em Windows, sem Mac e sem conta paga do Apple Developer Program.
- Build e testes rodam em GitHub Actions (runner macOS 26, Xcode 26). O projeto Xcode é gerado
  por XcodeGen (`project.yml`), porque não há Xcode para criar um `.xcodeproj` à mão.
- Instalação no iPhone por sideload com Apple ID gratuito (ver README).

## Decisões

| Tema | Decisão | Motivo |
|---|---|---|
| Deployment target | iOS 17.0 (AlarmKit com `#available(iOS 26, *)`) | SwiftData e o MapKit para SwiftUI (`MapCircle`) exigem iOS 17. O pedido original era 16.1 por causa de Live Activities, mas AlarmKit torna isso irrelevante e o aparelho do autor é iOS 26. |
| Alarme com tela bloqueada | AlarmKit (principal), notificação local `timeSensitive` + som in-app (fallback) | Critical Alerts exigem entitlement aprovado e conta paga. CallKit fora de VoIP tem risco alto de rejeição. Um engenheiro da Apple indicou AlarmKit como o caminho para alarmes persistentes ([fórum](https://developer.apple.com/forums/thread/833511)). |
| Entrega do alarme | Protocolo `AlarmDelivering` no Domain, com `AlarmKitDelivery` e `NotificationFallbackDelivery` | Permite trocar ou acrescentar estratégias (Critical Alerts, CallKit) sem refatorar. |
| Persistência | SwiftData | Pedido original. Requer iOS 17. |
| Configurações | `UserDefaults` | Dois valores simples (tema e cor), SwiftData seria exagero. |
| Concorrência | Swift 5 language mode | O modo Swift 6 estrito gera erros de isolamento que só aparecem no CI e atrasam o ciclo. |
| Geofencing | `CLLocationManager` + `CLCircularRegion`, no máximo 20 regiões, escolhidas por proximidade | Limite do iOS. Reavaliado em mudança significativa de localização, abertura do app e CRUD. |
| Widget extension (Live Activity) | **Não incluída** | AlarmKit sem contagem regressiva não exige Live Activity (a documentação só associa a extension a countdown). Evita um segundo App ID no sideload gratuito. Soneca por tempo é reagendada pelo app. |

## Camadas

```
Domain/        Swift puro, sem frameworks de UI/dados. Modelos, protocolos, casos de uso,
               Haversine, seleção das 20 regiões, regra de soneca.
Data/          SwiftData, CoreLocation, AlarmKit, UserNotifications, AVFoundation, CoreHaptics.
Presentation/  SwiftUI + @Observable ViewModels. Uma pasta por tela.
App/           Composition root (AppContainer), @main, AppDelegate, roteamento do disparo.
```

## Fluxo de disparo

1. iOS reporta `didEnterRegion`/`didExitRegion` (relança o app em segundo plano, ~10 s).
2. `GeofenceEventHandler` carrega o alarme, valida `isEnabled` e dia da semana, e checa a
   transição configurada (entrar ou sair).
3. `AlarmTriggerCoordinator` chama `AlarmDelivering.deliver`. AlarmKit agenda um alarme
   `fixed(now + 2s)`; se falhar (sem autorização, erro), cai para notificação local.
4. App em primeiro plano: mostra direto a tela de alarme customizada, toca som com fade-in
   (`AVAudioPlayer`) e háptica (CoreHaptics).
5. Tela bloqueada: UI do sistema (AlarmKit). Botão secundário "Abrir" abre o app na tela
   customizada, onde valem o estilo de descarte, a hora e a distância.

## Limitações reais (documentadas, não escondidas)

- O iOS não permite tela cheia customizada sobre a tela de bloqueio. A UI customizada só
  aparece com o app aberto.
- Região monitorada: evento só é reportado após o aparelho se afastar da borda por uma
  distância mínima por ≥ 20 s. Precisão e latência variam (urbano, GPS fraco).
- Raio mínimo útil na prática: ~100 m. Valores menores disparam de forma errática.
- Soneca por distância: o iOS não permite timer periódico confiável em segundo plano, e
  "mudança significativa de localização" só dispara a cada ~500 m (inútil para quem está
  parado perto do ponto). A solução adotada é ligar localização contínua em segundo plano
  (`allowsBackgroundLocationUpdates`, indicador azul do sistema) enquanto a soneca durar, e
  reverificar a distância a cada 30 s (só vale a partir de 2 min, como no Android). Custa
  bateria e, se o iOS encerrar o app, a soneca se perde.
- Fade-in de volume e padrões de háptica só valem com o app em primeiro plano. O alerta do
  AlarmKit usa som e vibração do sistema.
- Sons customizados no AlarmKit: relatos de que podem falhar em dispositivo real (fonte
  secundária). Há fallback para o som padrão do sistema.
- Háptica: o iPhone não vibra continuamente por API pública. Os padrões repetem em loop com
  `CHHapticPatternPlayer`.
- Simulador não cobre háptica, AlarmKit na tela de bloqueio nem o som no silencioso. Isso só
  se valida no aparelho.

## Riscos abertos (a verificar no iPhone)

1. AlarmKit exige entitlement aprovado? A documentação da Apple não menciona; fontes
   secundárias divergem. Se exigir, o sideload gratuito não terá AlarmKit e o app usa o
   fallback.
2. Agendar AlarmKit de dentro do callback de região em segundo plano: não documentado.
3. `LiveActivityIntent` (botão secundário) executando sem widget extension.

## Testes

- Unitários (XCTest, rodam no CI, 29 testes): Haversine, seleção das 20 regiões, dias ativos,
  política de disparo e de soneca, linhas do tempo de vibração, repositório SwiftData (em
  memória) e persistência das configurações.
- Tour de interface (XCUITest, alvo `GeoAlarmUITests`, esquema `GeoAlarmUI`): percorre lista,
  edição, mapa, ajustes e as três telas de alarme em claro e escuro, e publica capturas de
  tela no branch `ci-shots` para inspeção visual (não há Xcode local). Usa dados de
  demonstração por argumentos de lançamento, compilados só em builds Debug.
- Build do app para o simulador em todo push.
- `.ipa` sem assinatura publicado como Release para o sideload.
- Lição registrada: `ModelContext` não mantém o `ModelContainer` vivo. O repositório guarda
  os dois, o que um teste (container liberado, trap no primeiro fetch) revelou.
