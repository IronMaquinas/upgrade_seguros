# Entrega 25 — Autocadastro, teste de 14 dias e modo só leitura

**Base:** GitHub `f2e96c2` (Etapa 24).

## O que muda

1. **Tela de entrada do app:** novo link **"Sua corretora ainda não usa? Teste 14 dias grátis"**.
   - A corretora informa o CNPJ → **Consultar** (Receita, no navegador, como em Dados da corretora; só CNPJ ativo).
   - Depois: nome da corretora, SUSEP (opcional), nome do responsável, e-mail (vai ser o login), telefone e o aceite.
   - **Pedir cadastro** só grava um **pedido**. Nada é criado antes da sua aprovação.
   - Proteções: CNPJ válido, CNPJ que já usa o app é recusado, e-mail que já tem login é recusado, um pedido pendente por CNPJ/e-mail, teto de 100 pendentes e uma isca contra robôs.
2. **Portal → Pedidos** (novo item no menu, com contador; a Visão geral também avisa):
   - **Aprovar:** você escolhe o plano do teste (padrão **Tudo ligado**) e os dias (padrão **14**). O portal cria a corretora, o responsável como **gestor** e a conta em **teste**, e manda o e-mail do Firebase para ele criar a senha.
   - **Recusar:** com motivo.
   - **Pedidos de plano** (do app): **Marcar como atendido**, com anotação.
3. **Só leitura**, valendo no servidor e não só na tela:
   - Vale para teste vencido, "Teste terminou", suspensa e cancelada.
   - As regras do Firestore e do Storage barram criar, alterar e apagar. Ler continua liberado.
   - O teste vencido trava **pela data**, sem rotina agendada.
   - O gestor também não consegue criar usuário nesse estado.
   - "Inadimplente" ainda grava; o app só mostra o aviso.
4. **App:**
   - Faixa no topo: "Teste grátis: faltam N dias" (azul) ou "modo só leitura" (vermelho), com **Ver meu plano**. Sem teste nem bloqueio, nada aparece (é o caso da Upgrade).
   - **Meu plano** (só o gestor): **Planos disponíveis**, com os planos ativos da aba Planos, mais **Quero este plano** e **Falar sobre o meu plano**. Os dois viram pedido no portal.
5. **Portal → Corretoras → corretora → Situação:** teste (com data de fim), ativa, inadimplente, suspensa, cancelada ou teste terminou, com motivo no histórico.
   - A lista e a Visão geral usam a situação efetiva (teste vencido aparece como "Teste terminou").
   - A Visão geral lista os testes que terminam em até 3 dias.

**A Upgrade não muda nada:** está "Ativa" e com cortesia. A faixa não aparece e as regras novas deixam tudo como hoje.

## Arquivos (21)

| Arquivo | O que mudou |
|---|---|
| `functions/conta.js` (novo) | Functions `autocadastro` (pública) e `minhaConta` (logado); pedidos, aprovação, situação; `situacaoEfetiva`/`contaGrava`. |
| `functions/testes/conta.teste.js` (novo) | 39 testes. |
| `functions/index.js` | Exporta `autocadastro` e `minhaConta`. |
| `functions/plataforma.js` | Ações `pedidos`, `pedidoAprovar`, `pedidoRecusar`, `pedidoAtendido`, `contaDefinirSituacao`; a lista traz a situação efetiva. |
| `functions/planos.js` | Exporta o nome da coleção. |
| `functions/seguranca.js` | `criarUsuario` recusa conta em só leitura. |
| `functions/testes/firebase-falso.js` | `getUserByEmail`. |
| `firestore.rules` | `contaGrava(e)` nas gravações da corretora. |
| `storage.rules` | `contaGrava(e)` nos envios e exclusões da corretora (mesmo documento da conta; continua em 2 leituras). |
| `lib/screens/autocadastro_screen.dart` (novo) | Tela "Teste 14 dias grátis". |
| `lib/screens/auth_screen.dart` | Link para o autocadastro. |
| `lib/utils/situacao_conta.dart` (novo) + `test/situacao_conta_test.dart` (novo) | Situação efetiva, dias que faltam, avisos (3 testes). |
| `lib/services/plano_atual.dart` | Situação efetiva, só leitura, id do plano. |
| `lib/widgets/portao_empresa.dart` | Faixa do teste / só leitura no topo. |
| `lib/screens/meu_plano_screen.dart` | Situação efetiva; planos disponíveis e "Quero este plano". |
| `lib/admin/aba_pedidos_portal.dart` (novo) | Aba Pedidos (aprovar/recusar/atendido) e a janela Situação. |
| `lib/admin/portal_app.dart` | Pedidos no menu (contador), avisos na Visão geral, botão Situação. |
| `lib/admin/modelos_plataforma.dart`, `plataforma_api.dart` | Pedido, situação efetiva e as chamadas novas. |
| `README.md` | Seção Etapa 25, histórico e pendência S8 (App Check, se aparecer spam). |

Ver o que mudou: `git diff <arquivo>` (antes do commit). Os novos aparecem em `git status`.

## Aplicar

```bash
cd ~/Projects/upgrade_seguros
unzip -o ~/Downloads/entrega-25.zip verificar-entrega.js
node verificar-entrega.js --antes        # 15 iguais ao GitHub f2e96c2, 6 novos ainda não existem
unzip -o ~/Downloads/entrega-25.zip 'lib/*' 'functions/*' 'test/*' firestore.rules storage.rules README.md
node verificar-entrega.js --analyze      # ✓ Todos
git diff --stat
```

## Publicar o servidor (necessário para testar localmente)

O app e o portal rodando no seu Mac usam as regras e as Functions de produção. Publicar esta parte **é seguro para a Upgrade**: ela está "Ativa", e as regras novas só barram contas em teste vencido, suspensas ou canceladas. O deploy confere a sintaxe das regras antes de publicar; se houver erro, nada muda.

```bash
firebase deploy --only firestore:rules,storage,functions:plataforma,functions:autocadastro,functions:minhaConta,functions:criarUsuario
```

Se a tela de cadastro disser "Não foi possível enviar" e o endereço da `autocadastro` (ou da `minhaConta`) responder 403 em HTML, libere o acesso público no Cloud Run, como nas Functions anteriores (o login é conferido no código).

## Testar (local: `flutter run -d chrome` e `flutter run -d chrome -t lib/main_admin.dart`)

Use um **CNPJ ativo que não seja o da Upgrade** (ex.: o da BetaEyes) e um **e-mail que ainda não tem login** no app (ex.: um Gmail seu).

1. **App** → saia → **Teste 14 dias grátis** → CNPJ → Consultar → preencha → Pedir cadastro → "Pedido recebido!".
2. **Portal** → **Pedidos** (contador 1) → confira o CNPJ → **Aprovar** (Tudo ligado, 14) → "recebeu o e-mail para criar a senha".
3. Abra o e-mail → crie a senha → **App** → entre com esse e-mail. Aparecem a faixa azul "Teste grátis: faltam 14 dias" e a corretora vazia, sem o cartão de migração.
4. **Meu plano** → Planos disponíveis → **Quero este plano** → **Portal → Pedidos** → "Plano — …" → Marcar como atendido.
5. **Portal → Corretoras → (a nova) → Situação → Teste terminou → Salvar.** No app, recarregue: a faixa fica vermelha. Tente criar um cliente: é barrado. Volte para **Teste** (ou **Ativa**).
6. **Upgrade:** entre com o seu usuário normal. Sem faixa, tudo igual.

A corretora de teste fica no portal. Se não quiser mais, deixe em **Cancelada**: não há botão de apagar corretora, de propósito.

## Publicar o site (depois de aprovar)

```bash
flutter build web -t lib/main_admin.dart --no-tree-shake-icons
rm -rf build/admin && cp -R build/web build/admin
flutter build web
firebase deploy --only hosting:admin,hosting:app
```

## Commit

```bash
git add -A lib functions test firestore.rules storage.rules README.md
git commit -m "Entrega 25: autocadastro com CNPJ, pedidos no portal, teste de 14 dias e modo só leitura"
GIT_ASKPASS= git push
```
