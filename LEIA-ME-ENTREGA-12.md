# Entrega 12: 🎬 vídeos do sinistro · 🗜️ conversão 720p · ❄️ arquivamento · 📸 fim das fotos duplicadas

**Base:** GitHub `c348350` (Etapas 01–11).

Esta etapa mexe no app **e no Firebase**:
- **Pacote novo no app:** `video_player`. Precisa de `flutter pub get`.
- **Cloud Function nova:** `converterVideo`, com o pacote `ffmpeg-static`. Precisa de `npm install` e de deploy.
- **Regras do Storage:** precisam de deploy.
- **Regra de arquivamento (Coldline):** um comando, uma vez só.

**Banco:** só acrescenta. Ganha o campo `videos` no sinistro e `videoMaxMb` / `videosPorSinistro` em `app_config/config`.

## O que muda para o usuário

**Abertura do sinistro → "Anexos e Documentos" → bloco "Vídeos do Sinistro"**
- **Adicionar:** botão **Adicionar vídeo**. Aceita MP4, MOV, M4V, 3GP e WEBM.
- **Limites:** até **20 MB** por vídeo e **5 vídeos** por sinistro. O vídeo do WhatsApp tem até 16 MB, então ele cabe direto.
- **Conferir antes de salvar:** clique na miniatura e o vídeo **toca numa janela sobre a própria tela**, com play/pausa, barra de tempo e som.
- **Envio:** os vídeos ficam marcados "a enviar" e sobem quando o sinistro é salvo, com a **porcentagem** na miniatura.
- **Vídeo recusado:** acima do limite ou em outro formato, o app avisa qual foi e por quê.

**Detalhe do sinistro → "Vídeos da Ocorrência"** (logo abaixo das fotos)
- **Assistir:** clique e o vídeo toca na janela, sem sair do detalhe.
- **Adicionar e excluir** (modo edição): o vídeo sobe na hora, com progresso. Excluir apaga também do armazenamento.
- **Gravação:** adicionar e excluir gravam direto no sinistro. Não depende do "Salvar" da edição, e não fica vídeo perdido no Storage.

**Configurações → "🎬 Vídeos do sinistro"**: os dois limites, MB por vídeo e vídeos por sinistro. É aqui que, no futuro, o plano contratado vai mandar.

## Como o espaço fica sob controle

1. **Limite na entrada:** 20 MB e 5 por sinistro, conferidos no app. As **regras do Storage** barram no servidor qualquer arquivo que não seja vídeo e qualquer vídeo acima de 100 MB (o teto de qualquer plano).
2. **Conversão no servidor:** logo depois do envio, a função `converterVideo` converte para **MP4 720p** (H.264, qualidade suficiente para acompanhar o evento). Ela grava **por cima, no mesmo endereço**, então o link salvo no sinistro continua valendo.
   - **No teste daqui:** um vídeo 1080p de 15 MB caiu para 1,7 MB. Em vídeo real (mais detalhe na imagem) a redução costuma ser menor, mas ainda grande.
   - **Bônus:** o vídeo do **iPhone (.mov / HEVC)**, que não toca no Chrome, passa a tocar depois da conversão. Antes de converter, o player avisa isso em vez de dar erro.
   - **Quando mantém o original:** se o original já era MP4 e a conversão não ficou menor.
3. **Arquivamento:** vídeos com mais de **180 dias** passam sozinhos para o armazenamento "frio" (**Coldline**), bem mais barato. Continuam abrindo normalmente.
4. **Medição para os planos:** cada vídeo guarda o tamanho e quem enviou. Quando entrar o multi-tenant, isso vira o "uso por corretora" para os planos bronze / prata / ouro ou por GB.

## Correções de fotos encontradas no caminho

- **Fotos duplicadas na abertura (afeta o seu custo hoje):** a cada salvamento, inclusive o **automático, que roda a cada edição**, a abertura comprimia e enviava **todas as fotos de novo, com nome novo**. Um sinistro editado várias vezes depois de anexar fotos deixou várias cópias de cada foto no Storage. Agora cada arquivo sobe uma vez só. As cópias antigas continuam lá; limpar dá para fazer depois, com cuidado.
- **Foto adicionada pelo detalhe do sinistro:** subia no **tamanho original**, sem compressão (e as maiores que ~7 MB falhavam no limite da função de upload). Agora usa a mesma compressão das outras telas (1024 px, JPG 50).
- **Sobre os "75%":** a compressão real das fotos é JPG qualidade 50 redimensionado para 1024 px de largura. Numa foto de celular comum, a redução fica bem acima de 75%.

## Uma descoberta de configuração

O `firebase_options.dart` aponta para o bucket `upgrade-seguros.appspot.com`, mas o bucket do projeto é `upgrade-seguros.firebasestorage.app` (você confirmou no console). As fotos não sentiam isso porque sobem pela Cloud Function. Os vídeos sobem direto do app, então fixei o bucket certo no serviço de vídeo (`Videos.bucket`). Deixei no roadmap regenerar o `firebase_options.dart` com `flutterfire configure`.

## Arquivos

| Arquivo | Novo? | O que mudou |
|---|---|---|
| `lib/utils/videos.dart` | **novo** | Regras: formatos, limites (20 MB / 5, teto 100 MB), caminho `videos/sinistros/…`, registro `VideoAnexo`, validação com motivo da recusa. |
| `test/videos_test.dart` | **novo** | 9 testes. |
| `lib/services/video_service.dart` | **novo** | Envio direto ao Storage com progresso, exclusão, gravação no sinistro. |
| `lib/widgets/videos_sinistro.dart` | **novo** | Seletor, player em janela, bloco da abertura e galeria do detalhe. |
| `lib/models/claim_model.dart` | alterado | Campo `videos`. |
| `lib/models/config_model.dart` / `lib/services/config_service.dart` | alterado | `videoMaxMb`, `videosPorSinistro`, `limitesVideo`, `getLimitesVideo` / `updateLimitesVideo`. |
| `lib/screens/settings_screen.dart` | alterado | Card "🎬 Vídeos do sinistro". |
| `lib/screens/spreadsheet_claim_screen.dart` | alterado | Bloco de vídeos em Anexos, envio ao salvar com progresso. **Anexos sobem uma vez só** (`_urlAnexoEnviado`). |
| `lib/screens/claim_detail_screen.dart` | alterado | "Vídeos da Ocorrência" e compressão da foto adicionada no detalhe. |
| `lib/services/firestore_service.dart` | alterado | Excluir o sinistro apaga também os vídeos. |
| `pubspec.yaml` | alterado | + `video_player: ^2.9.2`. |
| `functions/converter-video.js` | **novo** | Conversão para MP4 720p (testada aqui com vídeo em pé estilo iPhone .mov HEVC e vídeo deitado 1080p estilo WhatsApp). |
| `functions/index.js` | alterado | Exporta `converterVideo` (1 linha). |
| `functions/package.json` | alterado | + `ffmpeg-static`. |
| `storage.rules` | alterado | Vídeo só na pasta `videos/`, só logado, até 100 MB. O resto continua como antes. |
| `storage-lifecycle.json` | **novo** | Regra Coldline depois de 180 dias, só para `videos/`. |
| `README.md` | alterado | Seção "Vídeos do sinistro", Anexos, Cloud Functions, histórico, roadmap (planos, firebase_options). |

## Aplicar (Terminal, na raiz do projeto)

```bash
cd /Users/marcony/Projects/upgrade_seguros

unzip -o ~/Downloads/entrega-12.zip verificar-entrega.js -d .
node verificar-entrega.js --antes            # "✓ Os 18 arquivos são a base esperada"

unzip -o ~/Downloads/entrega-12.zip 'lib/*' 'test/*' 'functions/*' README.md pubspec.yaml storage.rules storage-lifecycle.json -d .

flutter pub get                              # baixa o video_player (atualiza o pubspec.lock)
(cd functions && npm install)                # baixa o ffmpeg-static (atualiza o package-lock.json)

node verificar-entrega.js --analyze          # tem que terminar em "✓ Todos"
```
> Se o Safari abriu o zip sozinho: copie as pastas `lib`, `test`, `functions` e os arquivos `README.md`, `pubspec.yaml`, `storage.rules`, `storage-lifecycle.json` e `verificar-entrega.js` da pasta `~/Downloads/entrega-12` para o projeto (`cp -R …`).

## Publicar no Firebase (depois de testar no app)

```bash
firebase deploy --only storage,functions:converterVideo
```
- **Primeira função de Storage do projeto:** o Firebase pode pedir para ativar APIs (Eventarc). Responda **Y**. Se der erro de permissão do "Eventarc Service Agent", espere 2–3 minutos e rode de novo. É normal na primeira vez.
- **Região:** a função fica em `us-central1`, a mesma do bucket (você confirmou: US).

**Arquivamento Coldline**, uma vez só, por um dos dois caminhos:
```bash
gcloud storage buckets update gs://upgrade-seguros.firebasestorage.app --lifecycle-file=storage-lifecycle.json
```
ou pelo console: console.cloud.google.com → Cloud Storage → Buckets → `upgrade-seguros.firebasestorage.app` → aba **Ciclo de vida** → Adicionar regra → "Definir classe de armazenamento: Coldline", idade **180 dias**, prefixo **`videos/`**.

## Revisar antes do commit

```bash
git --no-pager diff --stat HEAD
git --no-pager diff HEAD -- storage.rules functions/ pubspec.yaml lib/models lib/services/config_service.dart lib/services/firestore_service.dart
git diff HEAD -- lib/screens/spreadsheet_claim_screen.dart lib/screens/claim_detail_screen.dart
```
Vale ler inteiros o `functions/converter-video.js` (cerca de 120 linhas) e o `storage.rules`: é o que roda no servidor.

## Roteiro de teste

1. **Configurações:** o card "🎬 Vídeos do sinistro" mostra 20 MB e 5 vídeos.
2. **Nova abertura → Anexos → Adicionar vídeo:** escolha um vídeo do WhatsApp. Ele aparece "a enviar". Clique: toca na janela. Tente um arquivo de mais de 20 MB: aparece o aviso com o motivo.
3. **Salve o sinistro:** a porcentagem aparece na miniatura e depois some o "a enviar".
4. **Edite um campo** (dispara o salvamento automático): o vídeo **não** sobe de novo, e as fotos também não. No Storage, a pasta `sinistros/{nº}/fotos/` tem uma cópia de cada foto.
5. **Detalhe do sinistro → Vídeos da Ocorrência:** clique e o vídeo toca. Entre em **Editar** → Adicionar Vídeo (sobe na hora) → exclua um (pede confirmação).
6. **Depois do deploy:** envie um vídeo .mov do iPhone. Em alguns minutos ele toca no Chrome. No console do Storage, o arquivo fica menor e com a metadata `convertido = sim`.
7. Exclua um sinistro de teste com vídeo: a pasta `videos/sinistros/{nº}` some do Storage.

## Subir

```bash
git add lib/utils/videos.dart lib/services/video_service.dart lib/widgets/videos_sinistro.dart test/videos_test.dart functions/converter-video.js storage-lifecycle.json
git add -u
git commit -m "Etapa 12: vídeos do sinistro (limite, player, conversão 720p, Coldline); fotos não duplicam mais na abertura"
GIT_ASKPASS= git push
```

## Como foi testado aqui
- Análise antes × depois do **projeto inteiro** contra o GitHub `c348350`: nenhum erro ou aviso novo. O `video_player` 2.9.2 foi conferido tipo a tipo.
- 9 testes novos e todos os anteriores passando.
- **Conversão** rodada com o mesmo ffmpeg do `ffmpeg-static`:
  - vídeo em pé 1080×1920 HEVC (.mov, como o iPhone) → 720×1280 H.264;
  - vídeo deitado 1080p de 15 MB → 1280×720 H.264 com 1,7 MB.
- **O que não dá para testar aqui:** o deploy da função e das regras no seu projeto, e o envio real ao Storage. Para isso servem os passos 6 e 7 do roteiro.
- Simulação no clone do GitHub: `--antes`, cópia, verificador terminando em "✓ Todos".
