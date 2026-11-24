# Entrega 24 — Planos (aba Planos no portal + plano da corretora)

**Base:** GitHub `dd0f3f2` (Etapa 23).

## O que muda

1. **Portal → Planos** (item novo no menu lateral):
   - Cada plano-modelo tem nome, descrição, **preço mensal**, **franquias** e módulos.
   - Franquias: usuários, GB de arquivos e GB de vídeos. Para cada uma, a quantidade incluída e o preço de cada unidade a mais, ou "sem limite".
   - O cartão de cada plano mostra o preço, as franquias, os módulos e quantas corretoras estão nele.
   - **Desativado:** não pode ser escolhido para uma corretora nova; quem já está nele continua.
   - **Excluir** só aparece quando nenhuma corretora está no plano.
   - **Editar um plano em uso** pede confirmação e atualiza todas as corretoras dele: preço, franquias e módulos. Fica no histórico de cada uma.
2. **Portal → Corretoras → corretora → Plano da corretora** (no lugar de "Módulos do plano"):
   - **Tudo ligado** (como hoje), **Plano da lista** ou **Personalizado** (módulos, preço e franquias só dela);
   - **Cortesia** com data de fim (opcional) e **motivo** para o histórico.
   - O detalhe da corretora mostra o preço, a cortesia e **usuários × franquia**, com aviso quando passa do limite.
   - A lista de corretoras mostra o plano de cada uma.
3. **App:**
   - Na barra do topo, um botão **"Plano: Tudo ligado"** (ou o nome do plano) no lugar do ícone pequeno. No celular, um ícone maior.
   - **Meu plano** mostra a descrição, o preço (riscado quando é cortesia), "cortesia até dd/mm/aaaa" e o que o plano inclui.

**Fica como está:**
- As regras do Firestore/Storage não mudam: continuam olhando só a conta, que guarda uma cópia do plano. Por isso o deploy é só da Function.
- **A Upgrade continua em Tudo ligado.**
- Ainda não há medição de GB/vídeos nem cobrança (Etapas 25 a 28). As franquias, por enquanto, são o que o plano promete.
- O gatilho/recomendação continua sem trava (mexe em muitas telas; fica para depois).

## Arquivos (16)

| Arquivo | O que mudou |
|---|---|
| `functions/planos.js` (novo) | Planos-modelo: listar, salvar (e atualizar as corretoras do plano), excluir; plano da corretora. |
| `functions/plataforma.js` | Ações `planos`, `planoSalvar`, `planoExcluir`, `contaDefinirPlano`; a conta traz a data da cortesia. |
| `functions/testes/planos.teste.js` (novo) | 33 testes (permissão, validação, cópia na conta, edição em uso, desativado, personalizado, cortesia, auditoria). |
| `functions/testes/firebase-falso.js` | `Timestamp.fromDate`. |
| `lib/utils/planos.dart` (novo) | Franquias, R$ ↔ centavos, textos ("Até 5 usuários · R$ 49,00 por usuário a mais"). |
| `test/planos_test.dart` (novo) | 4 testes. |
| `lib/admin/aba_planos_portal.dart` (novo) | Aba Planos. |
| `lib/admin/editor_plano.dart` (novo) | Editor do plano, seletor de módulos, campos de preço e franquias. |
| `lib/admin/modulos_corretora_dialog.dart` | Virou "Plano da corretora" (mesmo arquivo). |
| `lib/admin/portal_app.dart` | Item Planos no menu; plano, preço, cortesia e usuários × franquia na corretora. |
| `lib/admin/modelos_plataforma.dart`, `plataforma_api.dart` | Plano-modelo e as chamadas novas. |
| `lib/services/plano_atual.dart` | Tipo, descrição, preço, franquias e validade da cortesia. |
| `lib/screens/meu_plano_screen.dart` | `BotaoMeuPlano`; preço, franquias e cortesia. |
| `lib/screens/dashboard_screen.dart` | Barra do topo usa o `BotaoMeuPlano`. |
| `README.md` | Seção "Planos (Etapa 24)" e histórico. |

Ver o que mudou: `git diff <arquivo>` (antes do commit). Os novos aparecem em `git status`.

## Aplicar e testar localmente

```bash
cd ~/Projects/upgrade_seguros
unzip -o ~/Downloads/entrega-24.zip verificar-entrega.js
node verificar-entrega.js --antes        # 10 iguais ao GitHub dd0f3f2, 6 novos ainda não existem
unzip -o ~/Downloads/entrega-24.zip 'lib/*' 'functions/*' 'test/*' README.md
node verificar-entrega.js --analyze      # ✓ Todos
git diff --stat
```

⚠️ O portal rodando localmente chama a Function **de produção**. Sem publicar a `plataforma`, a aba Planos mostra "Ação desconhecida". Publicar só ela é seguro, porque as ações antigas não mudam e nenhuma corretora troca de plano sozinha:

```bash
firebase deploy --only functions:plataforma
flutter run -d chrome -t lib/main_admin.dart   # portal
flutter run -d chrome                          # app (outra janela do terminal)
```

### Roteiro

1. **Portal → Planos → Novo plano:** "Essencial", R$ 199,00, usuários 5 com R$ 49,00 a mais, GB "sem limite", alguns módulos → Salvar. O cartão aparece com "0 corretora(s)".
2. **Portal → Corretoras:** a lista mostra "Tudo ligado (cortesia)". Abra a Upgrade: aparecem as linhas Plano e Cortesia e o botão **Plano da corretora**. Abra o botão e **só olhe**: "Plano da lista" mostra o Essencial no menu. **Cancele**. Não troque o plano da Upgrade: o app que a equipe usa lê a mesma conta.
3. **App:** o botão **"Plano: Tudo ligado"** aparece no topo → Meu plano.
4. Se quiser ver o app num plano com preço sem afetar a equipe, use uma corretora de teste, se tiver. Sem uma, dá para pôr a Upgrade no Essencial **por 1 minuto**, recarregar o app, ver o preço e os cadeados em Meu plano, e voltar em **Tudo ligado** com cortesia marcada.
5. **Excluir:** o Essencial sem corretoras mostra a lixeira.

## Publicar (depois de aprovar)

```bash
# a Function já foi no teste; se não:  firebase deploy --only functions:plataforma
flutter build web -t lib/main_admin.dart --no-tree-shake-icons
rm -rf build/admin && cp -R build/web build/admin
flutter build web
firebase deploy --only hosting:admin,hosting:app
```

## Commit

```bash
git add -A lib functions test README.md
git commit -m "Entrega 24: planos-modelo com preço e franquias, aba Planos no portal, plano da corretora e botão do plano no app"
GIT_ASKPASS= git push
```
