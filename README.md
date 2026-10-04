# GeoAlarm (iOS)

Despertador baseado em geofencing para iPhone, em Swift e SwiftUI, 100% offline na lógica de
alarme (nenhuma chamada de rede para disparar, só o mapa e a busca de endereços usam internet).
É o par do app Android [GeoAlarm](https://github.com/PietroGalastriKroin/GeoAlarm), usado como
especificação funcional.

Você escolhe um lugar e um raio, e o alarme toca quando você entra ou sai da área, mesmo com
o app fechado e o iPhone bloqueado.

## Como instalar no seu iPhone (sem Mac e sem conta paga)

O código é compilado automaticamente no GitHub (veja "Como o build funciona"). O resultado é um
arquivo `GeoAlarm.ipa` sem assinatura. Para instalá-lo no iPhone você assina o arquivo com o seu
Apple ID gratuito usando o **Sideloadly** no Windows.

1. **Baixe o app.** Abra a [página de Releases](https://github.com/PietroGalastriKroin/GeoAlarm-iOS/releases/tag/latest)
   e baixe o `GeoAlarm.ipa`.
2. **Prepare o Windows.** O Sideloadly exige o iTunes e o iCloud **das versões baixadas do site da
   Apple**, não as da Microsoft Store (se tiver as da loja, desinstale). Depois instale o
   [Sideloadly](https://sideloadly.io/).
3. **Ative o Modo de Desenvolvedor no iPhone.** Em Ajustes > Privacidade e Segurança > Modo de
   Desenvolvedor. A opção costuma só aparecer depois da primeira tentativa de instalar um app
   por esse método; ative, reinicie o iPhone e confirme.
4. **Conecte o iPhone ao PC** por cabo e toque em "Confiar".
5. **Instale.** No Sideloadly, arraste o `GeoAlarm.ipa`, informe seu Apple ID e clique em Start.
6. **Confie no app.** No iPhone, em Ajustes > Geral > VPN e Gerenciamento de Dispositivo, toque no
   seu Apple ID e em "Confiar".

> Limitações do Apple ID gratuito: o app expira em **7 dias** (o Sideloadly tem um serviço que
> renova automaticamente enquanto o PC estiver ligado e o iPhone na mesma rede) e você pode ter
> poucos apps instalados assim ao mesmo tempo. Os passos acima refletem a documentação do
> Sideloadly e da Apple na data de criação deste projeto e podem estar desatualizados, confira em
> sideloadly.io se algo não bater.

### Primeiro uso

1. Abra o app e conceda a localização em **duas etapas**: primeiro "Ao usar o app", depois
   "Sempre" (o banner no topo guia você). Sem "Sempre" o alarme não toca com o app fechado.
2. Em Ajustes (engrenagem), toque em **Testar alarme do sistema em 10 s**, aceite a permissão de
   alarmes, **bloqueie o iPhone** e coloque-o no **silencioso**. O alarme deve tocar mesmo assim.
3. Crie um alarme com o botão **+**.

## Roteiro de testes no aparelho

O simulador não cobre o que mais importa neste app. Confira no iPhone:

| O que testar | Como | Esperado |
|---|---|---|
| Alarme do sistema | Ajustes > Testar alarme do sistema, bloqueie e ponha no silencioso | Toca e mostra o alerta na tela de bloqueio |
| Geofence real | Alarme de 100 a 200 m perto de casa, saia e volte com o app fechado | Alarme toca ao cruzar a borda (com alguns segundos de atraso) |
| App aberto | Mesmo teste com o app em primeiro plano | Abre a tela de alarme do app, com som crescente e vibração |
| Soneca por tempo | Dispense com Soneca | Toca de novo no tempo escolhido |
| Soneca por distância | Soneca perto do ponto | Indicador azul de localização, toca de novo se ainda estiver perto |
| Mais de 20 alarmes | Crie 21 | O banner avisa que alguns ficam em espera |
| Som no AlarmKit | Ligue "Som escolhido no alerta do sistema" e use o teste | Se tocar mudo, desligue a opção |

O **registro de diagnóstico** (Ajustes) mostra o que aconteceu com o app fechado: eventos de região,
alarmes agendados e erros. Se algo falhar, ele é o primeiro lugar para olhar.

## Decisões de arquitetura

Documento completo em [`docs/superpowers/specs/2026-10-03-geoalarm-ios-design.md`](docs/superpowers/specs/2026-10-03-geoalarm-ios-design.md).

- **Clean Architecture + MVVM** em `Domain` (Swift puro, testado), `Data` e `Presentation`, mais `App`
  como raiz de composição (`AppContainer`, sem framework de DI).
- **Alarme com a tela bloqueada:** o iOS não permite tela cheia customizada sobre a tela de
  bloqueio. A solução é o **AlarmKit** (iOS 26+), que toca no silencioso e em Foco e mostra um alerta
  do sistema. Com o app aberto, aparece a tela customizada do app. Sem AlarmKit disponível ou
  autorizado, cai para uma cadeia de notificações locais. Critical Alerts e CallKit ficam fora (exigem
  entitlement aprovado pela Apple e conta paga, ou têm risco de rejeição na App Store), mas podem
  entrar depois atrás do protocolo `AlarmDelivering`.
- **Limite de 20 regiões:** `RegionSelector` monitora os 20 alarmes cujas bordas estão mais perto
  da posição atual e troca o conjunto ao se mover (mudança significativa de localização).
- **Soneca por distância:** o iOS não tem timer periódico confiável em segundo plano, então durante
  a soneca o app mantém localização contínua ligada (indicador azul).
- **Sons e vibração:** 6 sons embutidos gerados por `tools/generate_assets.py` e importação de áudio
  pelo seletor de arquivos. Vibração com CoreHaptics (Contínuo, Pulso curto, SOS, Batimento).
- **Tema:** claro, escuro ou automático e uma cor de destaque da qual toda a paleta é derivada
  (`Palette`).
- **Deployment target iOS 17.0** (SwiftData e MapKit para SwiftUI), com AlarmKit protegido por
  `#available(iOS 26, *)`.

## Limitações conhecidas

- A tela customizada só aparece com o app aberto. Com o iPhone bloqueado vale o alerta do sistema.
- O volume crescente e o som escolhido valem com o app aberto. O alerta do sistema usa o som
  padrão (a opção experimental tenta usar o som escolhido).
- Desligar "Tocar som" ou "Vibrar" só vale dentro do app. O alerta do AlarmKit sempre toca.
- Raios abaixo de 100 m não são confiáveis no iOS. Há atraso de alguns segundos entre cruzar a
  borda e o disparo (o sistema exige que você se afaste da borda por ~20 s).
- Se você forçar o encerramento do app (arrastar para cima no seletor de apps), o iOS **pode**
  deixar de relançá-lo por eventos de região até a próxima abertura manual.
- O mapa e a busca de endereço precisam de internet. Coordenadas digitadas funcionam offline.
- Riscos ainda **não verificados no aparelho** (a validação só é possível num iPhone real): se o
  AlarmKit exige algum entitlement com o Apple ID gratuito, se o agendamento dentro do callback de
  região em segundo plano funciona e se os botões do alerta do sistema executam sem a interface.
  Em todos os casos o app tem plano B, mas o comportamento deve ser conferido com o roteiro acima.

## Como o build funciona

Não há `.xcodeproj` no repositório. Ele é gerado por [XcodeGen](https://github.com/yonaskolb/XcodeGen)
a partir do `project.yml`. O workflow `.github/workflows/ios.yml` roda a cada push:

1. gera o projeto, compila e roda os **testes unitários** no simulador;
2. gera o archive para dispositivo, sem assinatura, e empacota o `GeoAlarm.ipa`;
3. no branch `main`, publica o `.ipa` na release `latest`;
4. publica os logs de build no branch `ci-logs` (útil para diagnosticar falhas sem abrir o Actions).

### Se você tiver um Mac

```bash
brew install xcodegen
xcodegen generate
open GeoAlarm.xcodeproj
```

No Xcode, escolha seu time em Signing & Capabilities e rode no iPhone. Se quiser editar o projeto,
altere o `project.yml` e gere de novo; o `.xcodeproj` não é versionado.

## Estrutura

```
GeoAlarm/
  App/            AppContainer, coordenador de alarme, intents do AlarmKit, delegate de notificações
  Domain/         modelos, protocolos, casos de uso, Haversine, seleção de regiões, regras de soneca
  Data/           SwiftData, CoreLocation, AlarmKit, notificações, áudio, háptica
  Presentation/   Lista, Edição (mapa, som), Alarme, Ajustes, tema
  Resources/      sons, ícone e assets
GeoAlarmTests/    testes unitários (Domain e Data)
tools/            gerador de sons e ícone
```
