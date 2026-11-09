# Entrega 13 — Vídeos no mesmo desenho dos anexos

**Base:** GitHub `4dbf6a6` (Etapa 12 + a sua troca do limite de vídeo de 20 para 100 MB).
**Data:** 08/11/2026.

## O que muda para quem usa

Na abertura do sinistro (planilha), o bloco de vídeos agora tem **o mesmo desenho das outras categorias de "Anexos e Documentos"**:

- rótulo cinza em maiúsculas **VÍDEOS DO SINISTRO**, com o contador ("0 de 5") ao lado;
- botão pequeno com contorno **"+ Adicionar vídeos"** à direita, igual ao "+ Adicionar arquivos";
- caixa cinza **"Arraste vídeos aqui ou clique para selecionar"**: dá para **arrastar e soltar** vídeos do computador (antes só pelo botão);
- os vídeos escolhidos aparecem dentro da caixa (miniatura com ▶, selo "a enviar", progresso ao salvar);
- embaixo da caixa, em letra pequena: formatos aceitos, limite de MB e máximo por sinistro.

Os vídeos arrastados passam pelas mesmas regras do botão (formato, tamanho, quantidade). Se algum for recusado, aparece o aviso com o motivo.

O detalhe do sinistro não mudou: lá os vídeos já seguem o desenho das "Fotos da Ocorrência" (título em negrito + botão "Adicionar Vídeo" no modo edição).

## Sobre a sua mudança para 100 MB (commit `4dbf6a6`)

Ela foi mantida. Encontrei dois efeitos dela e corrigi os dois:

1. **O teste `test/videos_test.dart` quebrava.** Ele conferia o padrão de 20 MB. Agora confere a regra (o padrão está dentro do teto de 100 MB) e testa a recusa "acima do limite" com um limite de 20 MB explícito. Assim você pode mudar o padrão de novo sem quebrar o teste.
2. **Um arquivo de exatamente 100 MB passava no app e era recusado no Storage.** O app aceita "até 100 MB" e a regra dizia "menor que 100 MB". A regra agora aceita até 100 MB, inclusive.

**Dica:** o caminho pensado para mudar o limite é **Configurações → "🎬 Vídeos do sinistro"**. O valor salvo ali vale mais que o padrão do código e muda sem novo deploy. Mudar no código também funciona, mas só vale para quem nunca salvou o cartão de Configurações.

**Vídeos de 60–70 MB na conversão:** a Function `converterVideo` tem 2 GiB de memória e até 9 minutos, o suficiente para isso. Um vídeo do celular nesse tamanho tem, em geral, 1 a 3 minutos e converte em bem menos tempo. Se uma conversão passar do tempo, o vídeo original fica intacto e continua tocando, só que sem a compactação.

## Arquivos (5)

| Arquivo | O que mudou | Por quê |
|---|---|---|
| `lib/widgets/videos_sinistro.dart` | `PainelVideosAbertura` redesenhado no padrão das categorias de anexos (rótulo, botão com contorno, caixa cinza, legenda). Agora tem estado próprio (destaque ao arrastar por cima). Novo `videosSoltos(...)`: aplica os limites aos arquivos arrastados. | Pedido do Marcony: mesma UX das outras categorias. |
| `lib/screens/spreadsheet_claim_screen.dart` | +4 linhas: `onSoltar` liga os vídeos arrastados à lista "a enviar" e agenda o salvamento automático. | Arrastar e soltar. |
| `storage.rules` | `size < 100 MB` → `size <= 100 MB`. | Arquivo de exatamente 100 MB. |
| `test/videos_test.dart` | Não depende mais do número padrão de MB. | O commit `4dbf6a6` quebrava o teste. |
| `README.md` | Linha da versão; seção "Vídeos do sinistro" (novo desenho, 100 MB, regra ≤); linha 13 no histórico; item no roadmap. | Documentação. |

E fora do git: **`verificar-entrega.js`** com os md5 da Etapa 13. A varredura de segredos agora também pega arquivos `.env.<qualquer coisa>`, como `functions/.env.upgrade-seguros` e `functions/.env. yaml` (com espaço). Por isso o verificador vai passar a avisar desses dois arquivos (⚠️). É um aviso antigo que antes passava despercebido, não um erro da etapa.

## Aplicar (na raiz do projeto, terminal do VS Code)

```bash
cd ~/Projects/upgrade_seguros
unzip -o ~/Downloads/entrega-13.zip verificar-entrega.js
node verificar-entrega.js --antes        # 5 arquivos iguais ao GitHub 4dbf6a6
unzip -o ~/Downloads/entrega-13.zip 'lib/*' 'test/*' README.md storage.rules
node verificar-entrega.js --analyze      # tem que terminar em ✓ Todos
```

Se o Safari já tiver descompactado o zip sozinho (pasta `~/Downloads/entrega-13`):

```bash
cp ~/Downloads/entrega-13/verificar-entrega.js .
node verificar-entrega.js --antes
cp -R ~/Downloads/entrega-13/lib ~/Downloads/entrega-13/test . && cp ~/Downloads/entrega-13/README.md ~/Downloads/entrega-13/storage.rules .
node verificar-entrega.js --analyze
```

Não há pacote novo: não precisa de `flutter pub get` nem de `npm install`.

## Ver as mudanças linha a linha (antes do commit)

```bash
git --no-pager diff --stat
git diff lib/widgets/videos_sinistro.dart
git diff lib/screens/spreadsheet_claim_screen.dart
git diff storage.rules
git diff test/videos_test.dart
git diff README.md
```

## Publicar no Firebase

Só as regras do Storage mudaram (a Function não mudou):

```bash
firebase deploy --only storage
```

## Testar

1. Nova abertura de sinistro → "Anexos e Documentos". O bloco **VÍDEOS DO SINISTRO** deve ter o mesmo jeito das categorias acima dele.
2. Clicar na caixa vazia → abre o seletor de vídeos.
3. No computador, **arrastar um .mp4** para a caixa: a borda fica verde, e ao soltar o vídeo aparece com o selo "a enviar".
4. Arrastar uma foto (.jpg) → aviso "formato não aceito".
5. Clicar na miniatura → o vídeo toca na janela.
6. "Salvar e Fechar" → progresso → abrir o sinistro no detalhe → o vídeo está lá e toca.
7. Com 5 vídeos, o botão "+ Adicionar vídeos" fica cinza e a caixa não aceita mais arquivos.

## Commit

```bash
git add -u
git commit -m "Entrega 13: 🎬 vídeos no desenho dos anexos (arrastar e soltar) · regra do Storage ≤ 100 MB · teste de vídeos independente do padrão"
GIT_ASKPASS= git push
```

## Lembrete de segurança (S1, continua pendente)

O token do bot do Telegram está no repositório público em `functions/.env.upgrade-seguros`, `functions/.env. yaml` e `functions/telegram-parameters.md`. Para resolver:

1. Revogue o token no @BotFather (/revoke) e gere um novo.
2. Tire os arquivos do git sem apagar do Mac:
   ```bash
   git rm --cached "functions/.env.upgrade-seguros" "functions/.env. yaml"
   printf '\nfunctions/.env*\n' >> .gitignore
   ```
3. Guardar o token novo como segredo do Firebase pede uma mudança no código das Functions. Faço isso numa etapa, quando você quiser. Até lá, deixe o token novo só no `.env` local (fora do git).

Atenção: o token antigo continua no histórico do git. Por isso revogar é o passo que realmente resolve.
