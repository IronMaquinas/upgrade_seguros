# Entrega 16c — Multi-tenant, parte 3: arquivos por corretora e links protegidos

**Base:** GitHub `81e6d14` (Etapa 16b).
**Data:** 23/11/2026.

## O que muda

Até agora o banco já separava as corretoras (16 e 16b), mas os **arquivos** (fotos, laudos, documentos, vídeos) não:
- ficavam em pastas comuns a todas as corretoras (`sinistros/…`, `clientes/…`, `videos/…`);
- cada foto ou documento enviado ficava **público**: quem tivesse o link abria, sem login e para sempre (pendência S6).

Com esta entrega:

| O quê | Antes | Agora |
|---|---|---|
| Onde o arquivo novo fica | `sinistros/123/fotos/a.jpg` | `corretoras/{sua corretora}/sinistros/123/fotos/a.jpg` |
| Link gravado | público (`storage.googleapis.com/…`) | link do Firebase **com chave de acesso** (`firebasestorage.googleapis.com/…?token=…`), o mesmo tipo que os vídeos já usavam |
| Quem apaga arquivo | qualquer usuário ativo, qualquer arquivo | só da pasta da própria corretora |
| Regras do Storage | qualquer usuário ativo lê tudo | cada corretora só a própria pasta; pastas antigas só leitura/exclusão; o resto (ex.: `backups/`) fechado |

Para quem usa, nada muda: anexar, ver e excluir funcionam igual.

**Arquivos antigos.** Um cartão novo em Configurações, **📁 Arquivos da corretora** (só administrador), passa os arquivos antigos para a pasta da corretora:
- **Diagnóstico:** quantos arquivos ainda estão nas pastas antigas, por pasta e por coleção. Não muda nada.
- **Passar arquivos:** copia em lotes de 100 e troca os links gravados nos sinistros, assistências, clientes, tarefas etc. Repete sozinho até terminar. O original **não** é apagado. Se interromper, é só rodar de novo: continua de onde parou.
- **Apagar originais:** só **7 dias depois** de terminar a passagem. Apaga das pastas antigas só o que **já tem cópia**. A partir daí os links públicos antigos param de abrir (inclusive os que foram mandados por WhatsApp/e-mail ou estão em PDFs gerados antes). Precisa digitar APAGAR.

**Imagens no Chrome.** Os links novos são outros endereços, então o Chrome não reaproveita o cache antigo que estava atrapalhando. Deve resolver as fotos que às vezes não aparecem. Se continuar depois da passagem, me avise.

**Correção junto.** Vários lugares tiravam o nome do arquivo do link com `url.split('/').last`. No link novo isso mostraria `corretoras%2F…?alt=media&token=…` como nome, erraria o ícone de PDF e, no Detalhes do Cliente, podia até travar a tela (nome com menos de 10 letras). Agora tudo passa por um leitor único (`lib/utils/arquivos.dart`). A exclusão de arquivo de um sinistro também não reconhecia o formato novo (o dos vídeos): reconhece.

## Arquivos (23: 18 alterados, 5 novos)

| Arquivo | O que mudou |
|---|---|
| `functions/arquivos.js` **(novo)** | `uploadFile` e `deleteFiles` saíram do `index.js` para cá (mesmos nomes e endereços). Upload grava na pasta da corretora do usuário, sem `makePublic`, e devolve o link com chave. Exclusão só na pasta da corretora (pastas antigas: só a corretora que recebeu os dados antigos). Function nova `arquivosEmpresa` (diagnóstico, passar arquivos, apagar originais). |
| `functions/index.js` | Só exporta (o código de arquivo foi para `arquivos.js`); + `arquivosEmpresa`. |
| `functions/converter-video.js` | A conversão para 720p reconhece os vídeos na pasta da corretora (`corretoras/{id}/videos/…`) e os antigos (`videos/…`). |
| `functions/testes/arquivos.teste.js` **(novo)** | 51 testes: upload, exclusão, permissões, passagem (links, vídeos, datas intactas, lote de 100, arquivo sumido), apagar originais. |
| `functions/testes/firebase-falso.js` | O Firebase de mentira ganhou Storage e transação. |
| `storage.rules` | Por corretora (`membro(e)`), vídeo só em `corretoras/{id}/videos/` até 100 MB, pastas antigas só leitura/exclusão para a corretora migrada. |
| `storage-lifecycle.json` | + regra de Coldline (180 dias) para os vídeos dentro de `corretoras/`, pela extensão. |
| `lib/utils/arquivos.dart` **(novo)** | Lê caminho, nome e extensão dos dois formatos de link. |
| `test/arquivos_test.dart` **(novo)** | 8 testes. |
| `lib/widgets/arquivos_empresa_card.dart` **(novo)** | Cartão 📁 com Diagnóstico / Passar arquivos / Apagar originais, com progresso e botão Parar. |
| `lib/screens/settings_screen.dart` | Mostra o cartão 📁 logo abaixo do 🏢. |
| `lib/utils/videos.dart`, `lib/services/video_service.dart`, `test/videos_test.dart` | Vídeo novo vai para `corretoras/{id}/videos/sinistros/…`. |
| `lib/services/firestore_service.dart` | Leitura do caminho do arquivo pelo leitor único (antes, 2 funções diferentes, cada uma entendia um formato). |
| `lib/screens/claim_detail_screen.dart`, `assist_detail_screen.dart`, `spreadsheet_claim_screen.dart`, `lib/widgets/workshop_widget.dart`, `apolice_visualizacao_dialog.dart` | Nome do arquivo pelo leitor único. |
| `lib/screens/client_detail_screen.dart`, `client_form_screen.dart` | Nome e ícone (PDF/imagem) pelo leitor único. Foto de veículo pelo celular: bucket certo e pasta da corretora (antes ia para o bucket antigo `appspot.com`; no navegador esse envio não é usado). |
| `README.md` | Anexos, regras do Storage, Functions, S6, armadilhas, histórico e roadmap. |

Fora do git: `verificar-entrega.js`.

## Aplicar

```bash
cd ~/Projects/upgrade_seguros
unzip -o ~/Downloads/entrega-16c.zip verificar-entrega.js
node verificar-entrega.js --antes        # 18 arquivos iguais ao GitHub 81e6d14 e 5 novos ainda inexistentes
unzip -o ~/Downloads/entrega-16c.zip 'lib/*' 'functions/*' 'test/*' README.md storage.rules storage-lifecycle.json
node verificar-entrega.js --analyze      # tem que terminar em ✓ Todos
```

Se o Safari descompactou sozinho: `cp -R ~/Downloads/entrega-16c/lib ~/Downloads/entrega-16c/functions ~/Downloads/entrega-16c/test . && cp ~/Downloads/entrega-16c/README.md ~/Downloads/entrega-16c/storage.rules ~/Downloads/entrega-16c/storage-lifecycle.json .`

Para ver cada mudança:

```bash
git diff storage.rules storage-lifecycle.json
git diff functions/index.js functions/converter-video.js functions/testes/firebase-falso.js
git diff lib/services/firestore_service.dart lib/utils/videos.dart lib/services/video_service.dart
git diff lib/screens lib/widgets test/videos_test.dart
git status   # os 5 arquivos novos aparecem como "Untracked"
```

## Publicar (de preferência fora do expediente)

As regras novas do Storage não aceitam vídeo novo na pasta antiga. Então app, Functions e regras sobem **juntos**, e quem estiver com o app aberto precisa recarregar (Cmd+Shift+R).

### Passo 1: simular as regras do Storage no Playground (5 min)

Console → Storage → **Rules**. Cole o conteúdo do novo `storage.rules` no editor, **sem publicar**, e abra o **Playground de regras**. Tipo de simulação **get**. `<E>` = `WjuMRrs8wfSwomP3b4nEO8Zg2CW2`.

| # | Caminho | Autenticação | Esperado |
|---|---|---|---|
| 1 | `corretoras/<E>/sinistros/teste.jpg` | o seu UID | ✅ Permitido |
| 2 | `corretoras/<E>/sinistros/teste.jpg` | UID de um funcionário | ✅ Permitido |
| 3 | `corretoras/OUTRA/sinistros/teste.jpg` | o seu UID | ❌ Negado |
| 4 | `sinistros/teste.jpg` (pasta antiga) | o seu UID | ✅ Permitido |
| 5 | `backups/teste` | o seu UID | ❌ Negado |
| 6 | `corretoras/<E>/sinistros/teste.jpg` | não autenticado | ❌ Negado |

O arquivo não precisa existir. Se os 6 baterem, siga. Se algum der diferente, **não publique** e me mande o print.

### Passo 2: publicar tudo

```bash
flutter build web
firebase deploy --only functions,storage,hosting
```

Se o deploy perguntar sobre permissão do Storage para ler o Firestore, responda **Y** (já foi assim na 15).

### Passo 3: ciclo de vida dos vídeos

```bash
gcloud storage buckets update gs://upgrade-seguros.firebasestorage.app --lifecycle-file=storage-lifecycle.json
```

### Passo 4: testar (10 min)

Recarregue o app (Cmd+Shift+R).
- Abra um sinistro, **anexe uma foto** e um PDF. Os dois aparecem com o nome certo e abrem.
- No Console → Storage, a foto está em `corretoras/<E>/sinistros/<nº>/…`.
- **Exclua** a foto no app. Ela some também do Storage.
- **Anexe um vídeo** curto. Ele toca e, em alguns minutos, aparece convertido (`corretoras/<E>/videos/…`).
- Como funcionário: anexar e ver funcionam igual.

### Passo 5: passar os arquivos antigos (no mesmo dia, fora do expediente)

Peça para a equipe fechar o app durante a passagem. Uma tela antiga aberta pode gravar de volta o link antigo (sem perder nada; o passo 6 confere isso).

App → Configurações → **📁 Arquivos da corretora**:
1. **Diagnóstico:** anote o número de "Arquivos ainda nas pastas antigas".
2. **Passar arquivos:** deixe a tela aberta até o relatório final. Se aparecer "links para arquivos que já não existiam", são anexos que já estavam quebrados antes; ficam como estão. Me mande a lista se forem muitos.
3. **Diagnóstico** de novo: tem que dar **0**.
4. Abra alguns sinistros antigos com fotos e documentos: tudo abre (agora pelo link novo). Teste no **Chrome**.

### Passo 6: a partir de 30/11 (7 dias depois do passo 5)

No mesmo dia do passo 5 da 16b (backup + "Apagar dados antigos"):
1. 📁 **Diagnóstico** tem que continuar em 0. Se não estiver, rode **Passar arquivos** de novo.
2. 📁 **Apagar originais**, digite APAGAR. O relatório mostra quantos foram apagados e quantos arquivos antigos **ninguém usa** (ficam; a limpeza deles é a pendência de arquivos órfãos).

## Commit

```bash
git add -A lib functions test README.md storage.rules storage-lifecycle.json
git commit -m "Entrega 16c: 📁 arquivos por corretora e links com chave (fim dos públicos) · passagem dos arquivos antigos · leitor único de links"
GIT_ASKPASS= git push
```

## Depois desta

O multi-tenant fica completo no banco e nos arquivos. Pendências que voltam para a fila:
- alerta de valor na apólice (aguardando a sua cliente);
- gráfico de dezembro e o nome do "Top 10 por Receita";
- dica "isto parece uma anotação" nas tarefas;
- abertura rápida de guincho (aguardando o funcionário);
- limpeza dos arquivos órfãos (o "Apagar originais" vai mostrar quantos são).
