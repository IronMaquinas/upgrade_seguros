# Entrega 15.1 — Correção do endereço das Functions + deploy do Telegram

**Base:** a Etapa 15 aplicada no seu Mac (ainda não está no GitHub; tudo bem: aplique esta por cima e faça **um só commit** das duas).
**Data:** 09/11/2026.

## Problema 1: login por matrícula ("Failed to fetch")

O deploy mostrou que as Functions novas **estão publicadas** ("Skipped (No changes detected)" = já estavam no ar). Mesmo assim, o `curl` em `…cloudfunctions.net/apoioLogin` deu 404.

**Causa:** as Functions deste projeto são de 2ª geração e rodam no **Cloud Run**. Nesse caso o endereço `https://us-central1-upgrade-seguros.cloudfunctions.net/<nome>` não funciona; o que funciona é:

```
https://<nome em minúsculas>-hwtlk2s4qq-uc.a.run.app
```

É o mesmo formato que o `uploadFile` já usava, e por isso as fotos sempre funcionaram. Eu usei o formato errado nas Functions novas.

**Achado extra:** o `deleteFiles` também usava o endereço `cloudfunctions.net`, desde **antes** da Etapa 15. Muito provavelmente, excluir foto ou anexo **nunca apagava o arquivo** do armazenamento: o registro sumia do sinistro, mas o arquivo ficava lá. Esta correção conserta isso também. Os arquivos que ficaram para trás podem entrar numa limpeza futura do armazenamento.

### Confirme antes de aplicar (10 segundos)

```bash
curl -i -X POST https://apoiologin-hwtlk2s4qq-uc.a.run.app -H "Content-Type: application/json" -d '{"login":"2026"}'
```

O esperado é `HTTP/2 200` com `{"email":"…"}`. Se vier **403**, libere o acesso público no Cloud Run: Console do Google Cloud → Cloud Run → **apoiologin** → aba Segurança → **Permitir acesso público** → Salvar. Faça o mesmo para **npspublico**.

## Problema 2: Function do Telegram não atualizou

O erro diz: `Secret environment variable overlaps non secret environment variable: TELEGRAM_BOT_TOKEN`.

A Function do Telegram que está no ar ainda tem o token **antigo** guardado como variável comum, que veio do arquivo `.env` na publicação anterior. O Google não deixa ter os dois com o mesmo nome. Primeiro confira se os arquivos `.env` saíram mesmo do seu Mac:

```bash
ls -a functions | grep -i env
```

- **Se aparecer** `.env.upgrade-seguros` ou `.env. yaml`: você ainda não rodou o `git rm` do LEIA-ME 15. Rode-o (está abaixo, no "Aplicar").
- **Se não aparecer nada**, ou depois de remover: apague a Function antiga e publique de novo. É uma tarefa agendada (a cada 10 min); apagar e recriar não perde nada.

```bash
firebase functions:delete verificarAssistenciasAtradasTelegram --region us-central1 --force
firebase deploy --only functions:verificarAssistenciasAtradasTelegram
```

## Arquivos (2 + README)

| Arquivo | O que mudou |
|---|---|
| `lib/services/funcoes_nuvem.dart` | `url(nome)` monta o endereço do Cloud Run (`https://<nome>-hwtlk2s4qq-uc.a.run.app`). |
| `lib/services/firestore_service.dart` | `deleteFiles` passa a usar `FuncoesNuvem.url('deleteFiles')` (1 linha). |
| `README.md` | Linha 15.1 no histórico; nota no S3. |

Fora do git: `verificar-entrega.js` (md5 da 15.1).

## Aplicar

```bash
cd ~/Projects/upgrade_seguros
unzip -o ~/Downloads/entrega-15.1.zip verificar-entrega.js
node verificar-entrega.js --antes        # 3 arquivos iguais à Etapa 15
unzip -o ~/Downloads/entrega-15.1.zip 'lib/*' README.md

# só se ainda não fez na Etapa 15:
# git rm "functions/.env. yaml" functions/.env.upgrade-seguros functions/telegram-parameters.md
# printf '\nfunctions/.env*\n' >> .gitignore

node verificar-entrega.js --analyze      # tem que terminar em ✓ Todos
git diff lib/services/funcoes_nuvem.dart lib/services/firestore_service.dart
```

## Publicar

```bash
flutter build web
firebase deploy --only hosting
```

Depois recarregue o app com **Cmd+Shift+R** e teste:
1. Entrar com a **matrícula**.
2. Anexar e **excluir** uma foto num sinistro de teste. Para conferir que o arquivo sumiu do armazenamento: Console → Storage → pasta do sinistro.
3. Link do **NPS** numa janela anônima.
4. Usuários → **Novo usuário**.

Depois, siga do **passo 3** do LEIA-ME 15 em diante (testes, Playground e regras), caso ainda não tenha publicado as regras.

## Commit (Etapa 15 + 15.1 juntas)

```bash
git add firestore.rules functions/seguranca.js functions/testes/seguranca.teste.js lib/services/funcoes_nuvem.dart
git add -u
git commit -m "Entrega 15 + 15.1: 🔐 regras do Firestore/Storage · Functions com login · NPS/login/criar usuário pelo servidor · Telegram como segredo · endereço das Functions no Cloud Run"
GIT_ASKPASS= git push
```
