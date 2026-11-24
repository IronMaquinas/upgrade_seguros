# Entrega 27 — Uso por corretora (GB de arquivos e de vídeos)

**Base:** GitHub `44edc28` (Etapa 26).

## O que muda

1. **Medição do uso** (`functions/uso.js`). Para cada corretora:
   - soma os **GB de arquivos** (tudo em `corretoras/{id}/`, menos os vídeos);
   - soma os **GB de vídeos** (`corretoras/{id}/videos/`);
   - conta os **usuários**;
   - grava o resultado na conta da corretora.

   A medição só lista nomes e tamanhos no Storage, sem baixar nada. As pastas antigas da raiz (até a 16b) não entram.
   - Roda **sozinha todo dia às 03:30** (Function agendada `medirUsoDiario`).
   - Ou na hora: **Portal → Financeiro → Medir uso agora**.
2. **Financeiro:**
   - A mensalidade passa a somar os **GB acima da franquia** × o preço por GB do plano. Arquivos e vídeos são contados separados, arredondados para cima: 10,2 GB com 10 incluídos = 1 GB a mais.
   - Novos cartões **GB extras** e **Armazenamento** (total de todas as corretoras).
   - Colunas **Arquivos** e **Vídeos**: "10,4 GB (+1)" quando passa da franquia; "–" quando ainda não foi medida.
   - O texto do topo diz quando foi a última medição.
   - **Copiar tabela** ganhou 4 colunas: GB arquivos, GB vídeos, GB acima e Valor GB.
3. **Portal → corretora:** arquivos, vídeos (tamanho e quantidade) e a data da medição.
4. **App → Meu plano:** em cada franquia com limite aparece **"Usado: 3,2 GB de 10 GB"** (ou "4 de 5" usuários), em laranja quando passa do limite, com a data da medição.

Nada muda nas regras.

## Arquivos (15)

| Arquivo | O que mudou |
|---|---|
| `functions/uso.js` (novo) | Medição por corretora, todas, e a rotina diária. |
| `functions/testes/uso.teste.js` (novo) | 12 testes (arquivos × vídeos, prefixo parecido, pasta antiga fora, várias páginas, portal, rotina). |
| `functions/plataforma.js` | Ação `medirUso`; a lista de corretoras traz o uso. |
| `functions/index.js` | Exporta `medirUsoDiario`. |
| `functions/testes/firebase-falso.js` | Agendador de mentira para os testes. |
| `lib/utils/planos.dart` | `UsoConta`: GB, texto ("1,5 GB"), GB acima da franquia. |
| `lib/admin/financeiro.dart` + `test/financeiro_test.dart` | GB na mensalidade e na tabela (7 testes). |
| `lib/admin/aba_financeiro_portal.dart` | Medir uso agora, cartões e colunas novos. |
| `lib/admin/portal_app.dart` | Uso no detalhe da corretora. |
| `lib/admin/modelos_plataforma.dart`, `plataforma_api.dart` | Uso da conta e a chamada `medirUso`. |
| `lib/services/plano_atual.dart`, `lib/screens/meu_plano_screen.dart` | "Usado: X de Y" no Meu plano. |
| `README.md` | Seção Etapa 27 e histórico. |

Ver o que mudou: `git diff <arquivo>`. Os novos aparecem em `git status`.

## Aplicar

```bash
cd ~/Projects/upgrade_seguros
unzip -o ~/Downloads/entrega-27.zip verificar-entrega.js
node verificar-entrega.js --antes        # 13 iguais ao GitHub 44edc28, 2 novos ainda não existem
unzip -o ~/Downloads/entrega-27.zip 'lib/*' 'functions/*' 'test/*' README.md
node verificar-entrega.js --analyze      # ✓ Todos
git diff --stat
```

## Publicar o servidor (para testar localmente)

É seguro: só **lê** o Storage e grava o campo `uso` na conta. A primeira publicação de uma Function agendada pode pedir para ativar o Cloud Scheduler; ele já está ativo por causa do Telegram.

```bash
firebase deploy --only functions:plataforma,functions:medirUsoDiario
```

## Testar (`flutter run -d chrome -t lib/main_admin.dart` e `flutter run -d chrome`)

1. **Portal → Financeiro → Medir uso agora.** Na Upgrade, pode levar alguns segundos, porque tem muitos arquivos. Depois aparecem "Uso de GB medido em …" e as colunas Arquivos e Vídeos.
2. **Corretoras → Upgrade:** as linhas Arquivos e Vídeos aparecem com o tamanho e a quantidade. Confira se batem com o que você vê no console do Firebase → Storage → `corretoras/<id>`.
3. Para ver o GB extra entrando na conta: no plano **Diamante**, ponha uma franquia de GB menor que o uso da Upgrade (ex.: 1 GB, R$ 5,00 por GB a mais). Volte ao Financeiro: aparecem "(+N)" e o valor somado (a Upgrade continua como cortesia, então o MRR não muda). **Depois volte a franquia como era.**
4. **App → Meu plano:** em cada franquia com limite aparece "Usado: …". Só aparece depois da primeira medição.
5. No dia seguinte, depois das 03:30, confira se a data da medição mudou sozinha.

Se o "Medir uso agora" der erro de tempo, me mande a mensagem. A rotina das 03:30 tem até 9 minutos; o botão, pouco mais de 1.

## Publicar o site (depois de aprovar)

```bash
flutter build web -t lib/main_admin.dart --no-tree-shake-icons
rm -rf build/admin && cp -R build/web build/admin
flutter build web
firebase deploy --only hosting:admin,hosting:app
```

## Commit

```bash
git add -A lib functions test README.md
git commit -m "Entrega 27: uso por corretora (GB de arquivos e vídeos), GB acima da franquia no financeiro e no Meu plano"
GIT_ASKPASS= git push
```
