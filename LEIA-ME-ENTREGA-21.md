# Entrega 21 — Portal da plataforma (fundação)

**Base:** GitHub `e2be07f` (Etapa 20).

Primeira peça do SaaS: um **portal só seu**, separado do app das corretoras, para enxergar todas as corretoras. É a base para as próximas etapas: catálogo de seguradoras, módulos, planos, teste grátis e cobrança.

## O que entra

1. **Site separado**, no mesmo projeto Firebase: `https://upgrade-seguros-admin.web.app` (endereço provisório, até ter o nome/domínio).
   - O código fica em `lib/main_admin.dart` + `lib/admin/`.
   - O app das corretoras **não importa nada** disso.
2. **Admin da plataforma ≠ usuário de corretora** (lição do QuotaFlow):
   - **Conta própria**, com um e-mail que **não** seja de usuário de corretora.
   - **Criado só por script** no seu computador (`functions/scripts/admin-plataforma.js`), com a senha digitada escondida e no mínimo 10 caracteres. Não existe tela para criar admin.
   - **Dupla checagem no servidor:** a marca `plataforma` no login **+** o registro `plataforma_admins` ativo **+** não ser usuário de corretora.
   - **Tirar o acesso:** `remover` desliga na hora e encerra as sessões abertas.
3. **O portal não lê o banco direto.** Tudo passa pela Function `plataforma`, que confere o admin e grava a **auditoria** (entrada, ações).
4. **Telas do portal:**
   - **Visão geral:** corretoras, usuários, atendimentos e situação das contas.
   - **Corretoras:** CNPJ, contagens, situação e plano; clique para ver os detalhes.
   - **Auditoria:** últimas 100 ações.
5. **Conta da plataforma por corretora** (`plataforma_contas`): plano, situação, cortesia e histórico.
   - **Fica fora de `corretoras/{id}`**, onde o gestor da corretora pode gravar (e poderia ligar o próprio plano). O app só lê a própria conta; ninguém grava por ele.
   - Botão **"Criar contas que faltam"**: as corretoras atuais entram como *Ativa · Tudo ligado · cortesia*. Assim não ficam fora da receita, outra lição do QuotaFlow.

> **Mudança no jeito de publicar o app:** agora são dois sites. Use `firebase deploy --only hosting:app` para o app. Sem o `:app`, o Firebase tenta publicar os dois.

## Arquivos (13)

| Arquivo | O que mudou |
|---|---|
| `functions/plataforma.js` | **Novo.** Function do portal: confere o admin, lista as corretoras com contagens, auditoria, cria as contas que faltam. |
| `functions/scripts/admin-plataforma.js` | **Novo.** Script `adicionar` / `remover` / `listar` admin (roda no seu Mac). |
| `functions/testes/plataforma.teste.js` | **Novo.** 18 testes (quem entra, quem não entra, contagens, contas, auditoria). |
| `functions/testes/firebase-falso.js` | Firebase de teste: id automático, `orderBy`, marcas no login. |
| `functions/index.js` | Exporta `plataforma`. |
| `firestore.rules` | `plataforma_contas`: membro lê a própria (gestor lê o histórico); `plataforma_admins`: o admin lê o próprio; o resto, só o servidor. |
| `firebase.json` | Hospedagem em dois alvos: `app` (build/web) e `admin` (build/admin, sem indexação no Google). |
| `lib/main_admin.dart` | **Novo.** Ponto de entrada do portal. |
| `lib/admin/portal_app.dart` | **Novo.** Login e telas do portal. |
| `lib/admin/plataforma_api.dart` | **Novo.** Chamadas à Function. |
| `lib/admin/modelos_plataforma.dart` | **Novo.** Dados, rótulos e resumo (testados). |
| `test/modelos_plataforma_test.dart` | **Novo.** 5 testes. |
| `README.md` | Seção **🏢 Plataforma (SaaS)** + histórico 21. |

## 1. Aplicar

```bash
cd ~/Projects/upgrade_seguros
unzip -o ~/Downloads/entrega-21.zip verificar-entrega.js
node verificar-entrega.js --antes        # 5 iguais ao GitHub e2be07f + 8 novos
unzip -o ~/Downloads/entrega-21.zip 'lib/*' 'test/*' 'functions/*' firebase.json firestore.rules README.md
git diff firestore.rules firebase.json functions/index.js
```

## 2. Criar o site do portal e os alvos (uma vez)

```bash
firebase hosting:sites:create upgrade-seguros-admin
firebase target:apply hosting app upgrade-seguros
firebase target:apply hosting admin upgrade-seguros-admin
node verificar-entrega.js --analyze      # ✓ Todos (inclui "✓ .firebaserc (alvos…)")
```

> Se `upgrade-seguros-admin` já estiver em uso no Firebase, escolha outro (ex.: `upgrade-seguros-portal`) e use o mesmo nome no `target:apply`. O endereço muda junto.

## 3. Publicar (nesta ordem)

```bash
# 3a. regras + Function nova (o app das corretoras não muda nesta etapa)
firebase deploy --only firestore:rules,functions:plataforma

# 3b. portal: compila o portal, guarda em build/admin, recompila o app em build/web
flutter build web -t lib/main_admin.dart
rm -rf build/admin && cp -R build/web build/admin
flutter build web
firebase deploy --only hosting:admin
```

## 4. Criar o seu admin

Use um e-mail que **não** seja de usuário do app. No Gmail, dá para usar um apelido como `seunome+plataforma@gmail.com`, que chega na mesma caixa.

```bash
# uma vez: login do Google Cloud no seu Mac (abre o navegador)
gcloud auth application-default login
gcloud auth application-default set-quota-project upgrade-seguros

cd functions
node scripts/admin-plataforma.js adicionar seunome+plataforma@gmail.com
#   → pede a senha (escondida, 2×). Nunca mande a senha no chat.
node scripts/admin-plataforma.js listar
cd ..
```

> Sem `gcloud` no Mac: `brew install --cask google-cloud-sdk`.

## 5. Testar

1. Abra `https://upgrade-seguros-admin.web.app` e entre com o admin → **Visão geral**.
2. Deve aparecer o aviso laranja "1 corretora sem conta". Clique em **Criar contas que faltam** → a Upgrade fica **Ativa · Tudo ligado · cortesia**.
3. **Corretoras:** confira as contagens (≈116 sinistros, 705 assistências, 280 clientes, 8 usuários, mais o que entrou depois).
4. **Auditoria:** devem aparecer a sua entrada, "Admin adicionado" e "Criou contas que faltavam".
5. **Isolamento:**
   - entre no portal com **seu usuário da corretora** → "Acesso restrito ao administrador da plataforma";
   - entre no **app** com a conta de admin → não abre a corretora.

**Se der problema:**

| Sintoma | O que fazer |
|---|---|
| Portal diz "Não foi possível conferir o acesso" com erro 403 em HTML | A Function não ficou pública no Cloud Run. Console → Cloud Run → `plataforma` → Segurança → "Permitir acesso público". O login é conferido no código. |
| Login dá erro de chave de API / referer | Console do Google Cloud → APIs e serviços → Credenciais → a chave do navegador → inclua `upgrade-seguros-admin.web.app`. |
| Recomendado em qualquer caso | Firebase → Authentication → Configurações → Domínios autorizados → adicione `upgrade-seguros-admin.web.app`. |

**Para voltar atrás:**
- regras: console → Firestore → Regras → Histórico;
- portal: `firebase hosting:disable --site upgrade-seguros-admin`.

## Commit

```bash
git add -A lib test functions firebase.json firestore.rules .firebaserc README.md
git commit -m "Entrega 21: portal da plataforma (fundação) — admin por script, Function plataforma, contas das corretoras"
GIT_ASKPASS= git push
```
