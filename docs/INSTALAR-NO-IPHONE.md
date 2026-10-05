# Instalar o GeoAlarm no iPhone

Guia para quem vai instalar e testar o app. Não precisa saber programar nem ter conta paga da Apple.

## O que você precisa

- Um iPhone com **iOS 17 ou mais novo** (o app foi pensado para iOS 26) e um cabo USB.
- Um **computador com Windows** (caminho A) ou **Mac** (caminho B).
- Um **Apple ID** (o mesmo do iCloud). Gratuito serve.
- O arquivo do app: **GeoAlarm.ipa**, em
  https://github.com/PietroGalastriKroin/GeoAlarm-iOS/releases/tag/latest
  (clique em `GeoAlarm.ipa` para baixar, são 3 MB).

> Privacidade: o Sideloadly pede o seu Apple ID para assinar o app. Se preferir, crie um Apple ID
> só para isso. Se o Apple ID tiver verificação em duas etapas e o login falhar, gere uma "senha
> específica de app" em appleid.apple.com e use no lugar da senha (isso depende da versão do
> Sideloadly, confira no site dele).

## Caminho A: Windows (Sideloadly)

1. **Instale o iTunes e o iCloud pelo site da Apple**, não pela Microsoft Store. Se já tiver as
   versões da loja, desinstale antes. O Sideloadly só funciona com as versões do site.
2. **Instale o Sideloadly** em https://sideloadly.io
3. **No iPhone, ative o Modo de Desenvolvedor:** Ajustes > Privacidade e Segurança > Modo de
   Desenvolvedor. A opção costuma só aparecer depois da primeira tentativa de instalação (passo 6).
   Ative, reinicie o iPhone e confirme.
4. **Conecte o iPhone ao PC** com o cabo e toque em **Confiar** no aparelho.
5. **Abra o Sideloadly**, arraste o `GeoAlarm.ipa` para a janela e escolha o seu iPhone.
6. Digite o **Apple ID** e clique em **Start**. Aguarde terminar.
   Se o Modo de Desenvolvedor ainda não estiver ativo, ele aparece agora em Ajustes: ative (passo 3).
7. **Confie no app:** Ajustes > Geral > VPN e Gerenciamento de Dispositivo > toque no Apple ID >
   **Confiar**.
8. Abra o **GeoAlarm** na tela inicial.

## Caminho B: Mac (Xcode)

1. Instale o **Xcode** (App Store) e o XcodeGen: `brew install xcodegen`.
2. Baixe o código: https://github.com/PietroGalastriKroin/GeoAlarm-iOS (botão Code > Download ZIP).
3. No Terminal, dentro da pasta: `xcodegen generate` e depois `open GeoAlarm.xcodeproj`.
4. No Xcode: selecione o projeto **GeoAlarm** > Signing & Capabilities > escolha o seu **Team** (Apple ID).
   Se der erro de identificador, troque o Bundle Identifier por um nome seu.
5. Conecte o iPhone, ative o **Modo de Desenvolvedor** (como no passo 3 acima), escolha o iPhone
   no topo do Xcode e clique em **Run** (▶).

## Primeiro uso e testes

1. **Localização em duas etapas.** No banner do topo, toque em "Permitir ao usar o app" e depois
   em "Permitir Sempre". Sem "Sempre" o alarme não toca com o app fechado.
2. **Teste do alarme do sistema (o mais importante).** Engrenagem > "Testar alarme do sistema em
   10 s". Aceite a permissão de alarmes, **bloqueie o iPhone** e ponha no **silencioso**.
   Deve tocar e mostrar o alerta na tela de bloqueio.
3. **Teste real.** Crie um alarme (botão +) num lugar perto, com raio de 100 a 200 m. Saia da
   área e volte com o app fechado. O alarme toca alguns segundos depois de cruzar a borda.
4. **Soneca:** teste por tempo e por distância (esta liga o indicador azul de localização).

## Se algo der errado

- O app mostra um **registro de diagnóstico** em Engrenagem > Diagnóstico. Tire um print dele e
  envie junto com a descrição do problema.
- **O app fechou sozinho depois de uns dias:** com Apple ID gratuito o app expira em 7 dias.
  Reinstale pelo mesmo caminho (o Sideloadly também pode renovar automaticamente).
- **"Não foi possível verificar o app":** repita o passo 7 do caminho A.
- **Alarme tocou mudo ou com som errado no teste do sistema:** em Ajustes, desligue "Som
  escolhido no alerta do sistema (experimental)".
- Alarme não toca com o app fechado: confira se a localização está em **Sempre** e não force o
  encerramento do app (arrastar para cima no seletor de apps).

## O que o autor quer saber depois dos testes

1. O teste do alarme do sistema (passo 2) tocou com o iPhone bloqueado e no silencioso?
2. O alarme disparou sozinho ao cruzar a área, com o app fechado?
3. Os botões **Soneca** e **Dispensar** do alerta da tela de bloqueio funcionaram?
4. Alguma tela ficou cortada, estranha ou confusa?
