# Entrega 22 — Catálogo único de seguradoras

**Base:** GitHub `b4909ae` (Etapa 21).

A lista de seguradoras passa a ser **uma só para todas as corretoras**, mantida por você no portal. Seguradora nova entra **pelo CNPJ**, com o nome oficial da Receita, e não dá mais para digitar errado.

## Como funciona

1. **Lista única** (`catalogo_seguradoras`): só a plataforma grava; as corretoras leem.
2. **Montagem:** no portal, **Seguradoras → Importar das corretoras** cria a lista a partir dos cadastros que já existem.
   - Nomes parecidos viram um só (CHUBB × Chubb, AXA × AXA Seguros). A grafia mais usada vira o nome e as outras ficam como **apelidos**.
   - Os registros que usavam as outras grafias passam a usar o nome.
   - Pode rodar de novo: só vincula o que faltar.
3. **O que é de cada corretora não muda:** telefone, e-mail, contato e "suspensa" continuam no cadastro dela, agora ligados à lista única.
4. **Seguradora nova** (Configurações → Seguradoras → **Nova**, ou **"Não achou? Cadastrar pelo CNPJ"** no fim da lista do campo):
   - a pessoa digita o CNPJ;
   - o **servidor** consulta a Receita e mostra o nome fantasia e a razão social; ela **escolhe** um dos dois, não digita;
   - se o CNPJ ou um nome parecido já está na lista, usa a existente;
   - se não, entra **"aguardando aprovação"**: a corretora já pode usar e você decide no portal.
5. **No portal, aba Seguradoras:**
   - pendentes: **Aprovar** (pode ajustar o nome), **Juntar com…** (quando é outra forma de uma que já existe) ou **Recusar** (só se ninguém usou);
   - lista única: clique para editar **nome, CNPJ, SUSEP, apelidos** ou desativar.
   - **Renomear ou juntar troca o nome nos sinistros, assistências e apólices de todas as corretoras.** O nome antigo vira apelido, então quem digitar o antigo cai no novo.
6. **Os registros continuam guardando o nome.** Escolhi assim para não mexer nos modelos de sinistro, assistência e apólice: o catálogo garante que o nome é único, e o servidor atualiza tudo quando ele muda.
7. **Segurança na ordem de publicação:**
   - enquanto a lista não for importada, o app continua usando o cadastro de cada corretora (como na Etapa 20);
   - o servidor recusa sugestões de seguradora nova enquanto a lista não estiver montada.

## Arquivos (20)

| Arquivo | O que mudou |
|---|---|
| `functions/catalogo.js` | **Novo.** Function `catalogoSeguradoras` (consultar CNPJ / sugerir) + regras de nome, CNPJ, Receita e a troca de nome em todas as corretoras. |
| `functions/testes/catalogo.teste.js` | **Novo.** 43 testes (importar, sugerir, aprovar, renomear, juntar, recusar, isolamento). |
| `functions/plataforma.js` | Ações do catálogo no portal (com auditoria). |
| `functions/index.js` | Exporta `catalogoSeguradoras`. |
| `firestore.rules` | `catalogo_seguradoras`: lê quem está ativo (aprovadas + pendentes da própria corretora); ninguém grava pelo app. |
| `lib/admin/aba_seguradoras_portal.dart` | **Novo.** Aba Seguradoras do portal. |
| `lib/admin/portal_app.dart` · `plataforma_api.dart` · `modelos_plataforma.dart` | Menu, chamadas e dados do catálogo. |
| `lib/services/catalogo_seguradoras_service.dart` | **Novo.** CNPJ/sugerir e a lista de Configurações (catálogo + dados da corretora). |
| `lib/widgets/nova_seguradora_dialog.dart` | **Novo.** Janela "Nova seguradora pelo CNPJ". |
| `lib/services/seguradoras_cadastradas.dart` | A lista vem do catálogo (com apelidos e pendentes); sem catálogo, segue o cadastro da corretora. |
| `lib/widgets/campo_seguradora.dart` | Apelidos valem; pendentes marcadas; "Não achou? Cadastrar pelo CNPJ". |
| `lib/screens/settings_screen.dart` | Aba Seguradoras: lista única + contatos da corretora; Nova = pelo CNPJ; nome só leitura. |
| `lib/models/seguradora_model.dart` · `lib/services/seguradora_service.dart` | Vínculo com o catálogo; gravar só os dados da corretora. |
| `lib/utils/seguradoras.dart` | Apelidos (`mapaDeApelidos`, `resolverComApelidos`). |
| `test/seguradoras_test.dart` · `test/modelos_plataforma_test.dart` | Testes novos de apelidos e do portal. |
| `README.md` | Seção do catálogo + histórico 22. |

## 1. Aplicar

```bash
cd ~/Projects/upgrade_seguros
unzip -o ~/Downloads/entrega-22.zip verificar-entrega.js
node verificar-entrega.js --antes        # 15 iguais ao GitHub b4909ae + 5 novos
unzip -o ~/Downloads/entrega-22.zip 'lib/*' 'test/*' 'functions/*' firestore.rules README.md
node verificar-entrega.js --analyze      # ✓ Todos
git diff --stat
git diff firestore.rules lib/screens/settings_screen.dart
```

## 2. Backup (recomendado — a importação troca nomes nos registros)

```bash
gcloud firestore export gs://upgrade-seguros.firebasestorage.app/backups/2026-11-24
```

## 3. Publicar (nesta ordem)

```bash
# 3a. regras + Functions
firebase deploy --only firestore:rules,functions:plataforma,functions:catalogoSeguradoras

# 3b. portal
flutter build web -t lib/main_admin.dart
rm -rf build/admin && cp -R build/web build/admin
flutter build web
firebase deploy --only hosting:admin

# 3c. app das corretoras (o build/web do passo anterior já é o app)
firebase deploy --only hosting:app
```

## 4. Montar a lista (portal)

1. Portal → **Seguradoras** → **Importar das corretoras** → confirme. Aparece algo como "46 criada(s) · 46 vinculada(s) · 0 grafia(s) trocada(s)". Menos criadas significa que havia nomes parecidos.
2. Passe o olho na **Lista única**. Se quiser, ajuste um nome (ex.: "PORTO SEGURO" → "Porto Seguro"): os registros acompanham.
   - CNPJ e SUSEP são opcionais por enquanto. Quando preenchidos, evitam duplicar se alguém cadastrar pelo CNPJ.

## 5. Testar

1. **App → Configurações → Seguradoras:** a mesma lista, com os contatos/telefones que já existiam. Abrir uma: o nome fica travado e o resto edita.
2. **Nova → CNPJ** de uma seguradora que **não** está na lista → Consultar → escolha o nome → **Adicionar**. Ela aparece com "Aguardando aprovação (já pode usar)".
3. **Abertura de sinistro:** no campo Seguradora, digite parte do nome da nova. Ela aparece com "(aguardando aprovação)". No fim da lista aparece **"Não achou? Cadastrar pelo CNPJ"**.
4. **Portal → Seguradoras:** a nova está em "Aguardando aprovação", com a corretora que sugeriu → **Aprovar**.
5. **CNPJ que já existe:** tente cadastrar de novo o mesmo CNPJ → "já está na lista como …".

| Sintoma | O que fazer |
|---|---|
| "Nova" pelo CNPJ dá erro 403 em HTML | Console → Cloud Run → `catalogoseguradoras` → Segurança → "Permitir acesso público" (o login é conferido no código). |
| "O catálogo ainda não foi montado…" | Falta o passo 4 (Importar). |
| Configurações mostra "Fora da lista única" | Cadastro da corretora sem entrada no catálogo. Rode **Importar** de novo no portal (só vincula o que falta). |

**Para voltar atrás:**
- regras: console → Firestore → Regras → Histórico;
- nomes: o backup do passo 2.

## Commit

```bash
git add -A lib test functions firestore.rules README.md
git commit -m "Entrega 22: catálogo único de seguradoras (CNPJ pela Receita, aprovação no portal)"
GIT_ASKPASS= git push
```
