# Entrega 16 — Multi-tenant, parte 1 (preparação): cada corretora com a própria pasta

**Base:** GitHub `0d24d50` (Etapas 01–15.1).
**Data:** 10/11/2026.

> ⚠️ **Leia tudo antes.** Esta etapa muda **onde** os dados ficam no banco, e é a maior até agora (34 arquivos). A publicação tem **ordem certa** e uma janela de uns 15 minutos em que só o administrador consegue usar o app. Faça num horário tranquilo (à noite ou no fim de semana).

## O que é multi-tenant e o que muda nesta etapa

Até agora, os dados de todas as corretoras iam para as mesmas listas do banco (`sinistros`, `clientes` etc.). Com uma corretora só, tudo bem. Com a segunda, uma veria os dados da outra.

A partir desta etapa, **cada corretora tem a própria pasta** no banco:

```
corretoras/{id da corretora}                 ← cadastro (nome, logo, CNPJ) — já existia
corretoras/{id da corretora}/sinistros/…     ← antes: sinistros/…
corretoras/{id da corretora}/assistencias/…  ← antes: assistencias/…
corretoras/{id da corretora}/clientes/…      ← e assim por diante (13 coleções)
```

O app descobre a corretora do usuário pelo campo `empresaId` do cadastro dele (`users/{uid}`). Esse campo já existia e era usado para a logo e a assinatura dos PDFs. Depois disso, o app só lê e grava dentro da pasta dessa corretora.

**Parte 1 (esta):** os dados passam para as pastas, o app usa as pastas, e Configurações fica somente leitura para o funcionário.
**Parte 2 (16b):** as **regras do banco** passam a impedir que um usuário acesse a pasta de outra corretora. As coleções antigas da raiz são apagadas, e o Storage e os links de arquivos também passam a ser separados por corretora.

### Por que pastas e não um campo em cada documento (mudança em relação ao que eu tinha proposto)

Na proposta da Etapa 15 eu falei em "um campo `corretoraId` em cada documento". Ao fazer o levantamento, mudei para pastas:
- **Com campo:** cerca de 70 consultas do app ganhariam um filtro novo, e o Firestore exige um **índice composto** para cada consulta que filtra ou ordena por mais de um campo. Cada índice esquecido seria uma tela quebrada em produção.
- **Com pastas:** as consultas continuam exatamente iguais. Os índices que você já tem continuam valendo, porque o Firestore indexa pelo **nome** da coleção, não pelo caminho. A mudança no código ficou quase mecânica: trocar *de onde* cada lista é lida.
- **Para a Europa e o comparativo entre corretoras (ponto 4):** os dois desenhos servem igualmente.

## O que muda para quem usa

- **Nada visível** depois da migração. Os mesmos dados, as mesmas telas.
- **Configurações:** o funcionário vê tudo, mas não altera. Aparece uma faixa amarela "Somente leitura", e os campos não respondem. Em Seguradoras e Oficinas, os botões mostram o aviso "Somente o gestor pode alterar".
- **Usuários:** as listas de funcionários (Usuários, Relatórios, responsável de tarefa) mostram **só a equipe da corretora**.
- **Usuário sem corretora no cadastro** vê um aviso para procurar o administrador, em vez de telas vazias.
- **Pesquisa NPS:** os links já enviados continuam funcionando.
- **Telegram:** cada corretora usa as próprias configurações.

## Arquivos (34)

**Novos (6):**
| Arquivo | O quê |
|---|---|
| `lib/services/empresa_atual.dart` | A corretora do usuário logado: `EmpresaAtual.carregar()`, `EmpresaAtual.col('sinistros')` → `corretoras/{id}/sinistros`. Lista das 13 coleções da corretora. |
| `lib/widgets/portao_empresa.dart` | Antes do Dashboard: carrega a corretora. Se a migração ainda não foi feita, o **admin** vê o cartão de migração e os **demais** veem "o sistema está sendo atualizado". |
| `lib/widgets/migracao_empresa_card.dart` | Cartão "🏢 Dados da corretora" (só admin): **Diagnóstico** e **Copiar**. Aparece no portão e em Configurações. |
| `functions/empresa.js` | Function `migrarEmpresa`. Diagnóstico: o que há na raiz e na pasta, e a corretora de cada usuário. Copiar: raiz → pasta, só o que falta; também cria o índice do NPS, liga à corretora os usuários sem corretora e marca a corretora como migrada. **Não apaga a raiz.** |
| `functions/testes/empresa.teste.js` | 23 testes da migração, incluindo rodar duas vezes sem duplicar e a configuração real valendo mais que a padrão. |
| `functions/testes/firebase-falso.js` | O Firebase de mentira dos testes, agora com subpastas, contagem e lotes. |

**Alterados:**
| Arquivo | O que mudou |
|---|---|
| 19 arquivos em `lib/` (serviços e telas) | Cada `FirebaseFirestore.instance.collection('sinistros')` (e as outras 12 coleções) virou `EmpresaAtual.col('sinistros')`. Foram 95 trocas, só nesse padrão, mais o `import`. Nos serviços em que o campo `_db`/`_firestore` ficou sem uso, ele foi removido. |
| `lib/main.dart`, `lib/screens/auth_screen.dart` | Dashboard dentro do `PortaoEmpresa`. |
| `lib/screens/dashboard_screen.dart`, `lib/services/auth_service.dart` | Ao sair, esquece a corretora. |
| `lib/services/sla_monitor_service.dart` | Espera a corretora carregar antes de monitorar. |
| `lib/services/employee_service.dart`, `lib/services/firestore_service.dart`, `lib/screens/reports_screen.dart` | Listas de usuários filtradas por `empresaId`. |
| `lib/services/nps_service.dart` | Ao gerar o link, grava `nps_indice/{id}` com a corretora, porque o cliente responde sem login. |
| `lib/screens/settings_screen.dart` | Somente leitura para o funcionário e o cartão da migração. |
| `functions/seguranca.js` | `npsPublico` acha a corretora pelo índice (sem índice, usa a raiz, para links de antes da migração). `criarUsuario` exige que o admin tenha corretora. |
| `functions/notificacoes-telegram.js` | Percorre as corretoras: cada uma com a própria configuração e as próprias assistências. |
| `functions/index.js` | Exporta `migrarEmpresa`. |
| `functions/testes/seguranca.teste.js` | Usa o Firebase falso novo; testa o NPS dentro da pasta e o link antigo. |
| `README.md` | "Estrutura de Dados" reescrita, tabela de Functions, histórico 16, roadmap 16b. |

Fora do git: `verificar-entrega.js`. Agora ele também confere se a lista de coleções do app é **igual** à da migração.

**O que não muda:** as regras do banco e do Storage, as fotos e os documentos (os caminhos no Storage continuam os mesmos) e as coleções `users` e `corretoras`.

## Antes de tudo: confira o seu `empresaId`

Console do Firebase → Firestore Database → `users` → **o seu documento** (o UID está em Authentication) → campo **`empresaId`**.
- **Tem valor:** anote. É o id da sua corretora, e a pasta vai ser `corretoras/<esse valor>`.
- **Está vazio ou não existe:** abra a coleção `corretoras`.
  - Se houver um documento com os dados da sua cliente, use o id dele.
  - Se não houver nenhum, use um nome curto, sem espaços nem barras (ex.: `upgrade`).
  - Depois crie o campo `empresaId` (tipo string) no seu documento de `users` com esse valor.

## Aplicar

```bash
cd ~/Projects/upgrade_seguros
unzip -o ~/Downloads/entrega-16.zip verificar-entrega.js
node verificar-entrega.js --antes        # 28 arquivos iguais ao GitHub 0d24d50 + 6 novos
unzip -o ~/Downloads/entrega-16.zip 'lib/*' 'functions/*' README.md
node verificar-entrega.js --analyze      # tem que terminar em ✓ Todos (inclui os testes das Functions)
```

Se o Safari já descompactou o zip sozinho:

```bash
cp ~/Downloads/entrega-16/verificar-entrega.js .
node verificar-entrega.js --antes
cp -R ~/Downloads/entrega-16/lib ~/Downloads/entrega-16/functions . && cp ~/Downloads/entrega-16/README.md .
node verificar-entrega.js --analyze
```

Não há pacote novo.

## Ver as mudanças

```bash
git --no-pager diff --stat
# a troca mecânica — confira que é sempre o mesmo padrão:
git diff lib/ | grep '^[-+].*collection(\|^[-+].*EmpresaAtual' | head -60
# o resto, arquivo a arquivo:
git diff lib/main.dart lib/screens/auth_screen.dart lib/screens/settings_screen.dart
git diff lib/services/nps_service.dart lib/services/employee_service.dart lib/services/sla_monitor_service.dart
git diff functions/seguranca.js functions/notificacoes-telegram.js functions/index.js
# novos (abra no VS Code): lib/services/empresa_atual.dart, lib/widgets/portao_empresa.dart,
#   lib/widgets/migracao_empresa_card.dart, functions/empresa.js, functions/testes/*
```

## Publicar — NESTA ORDEM (horário tranquilo)

### Passo 1: Functions

```bash
firebase deploy --only functions
```

A partir daqui o Telegram fica em silêncio até o passo 3, porque já procura as configurações dentro da pasta, que ainda está vazia. Os links de NPS continuam funcionando.

### Passo 2: app web

```bash
flutter build web
firebase deploy --only hosting
```

A partir daqui, quem abrir o app novo e **não for administrador** vê "O sistema está sendo atualizado pelo gestor". Isso é de propósito: ninguém trabalha com a pasta vazia. Por exemplo, um sinistro novo poderia ganhar o número 1 de novo.

### Passo 3: migrar (você, como administrador)

1. Abra o app e recarregue com **Cmd+Shift+R**.
2. Entre. Vai aparecer a tela "Atualização da Etapa 16" com o cartão 🏢.
3. Clique em **Diagnóstico** e confira:
   - "Sua corretora (empresaId)" é o valor que você anotou;
   - os números da raiz batem com o que você espera (quantidade de sinistros, clientes…);
   - na lista de usuários, quem está "(sem corretora)" vai ser ligado à sua no passo seguinte. Se aparecer alguém **de outra corretora**, pare e me mande o print.
4. Clique em **Copiar** e confirme. Para centenas de documentos leva menos de 1 minuto; para milhares, alguns minutos.
5. O resumo mostra quantos documentos foram copiados por coleção.
6. Clique em **Tentar de novo**: o Dashboard abre com os dados.

### Passo 4: testar (10 min)

1. Dashboard, Sinistros, Assistências, Clientes, Tarefas, Relatórios: os mesmos números de antes.
2. Abra um sinistro antigo: fotos, vídeos e lançamentos aparecem.
3. Crie um **sinistro de teste**: a numeração continua a sequência.
4. **Configurações** com o seu usuário: altere algo e confira que salva. Volte o valor.
5. Entre com um **funcionário** (outra janela anônima): faixa "Somente leitura" em Configurações, e o resto do app normal.
6. **NPS:** gere um link novo e responda numa janela anônima. Se tiver um link antigo de antes de hoje, teste também.
7. **Telegram:** `firebase functions:log --only verificarAssistenciasAtradasTelegram`. Em até 10 minutos deve aparecer a verificação da sua corretora.

### Passo 5: no dia seguinte, copiar de novo

Se alguém ficou com uma aba antiga aberta durante a troca, o que essa pessoa gravou foi para a raiz. Em Configurações → 🏢 Dados da corretora → **Copiar** de novo: só o que faltar é copiado, sem duplicar. Depois, no **Diagnóstico**, a pasta deve ter pelo menos tantos documentos quanto a raiz, em todas as coleções.

### Se der errado depois do passo 2

Console do Firebase → **Hosting** → histórico de versões → **Reverter** para a versão anterior. O app antigo volta a ler a raiz, que **não foi apagada nem alterada**. A migração só *acrescentou*: cópias na pasta, o índice do NPS e o `empresaId` em quem não tinha. O que foi criado no app novo depois da migração fica só na pasta; me avise que eu faço a volta.

## Commit

```bash
git add lib/services/empresa_atual.dart lib/widgets/portao_empresa.dart lib/widgets/migracao_empresa_card.dart functions/empresa.js functions/testes/empresa.teste.js functions/testes/firebase-falso.js
git add -u
git commit -m "Entrega 16: 🏢 multi-tenant (preparação) — dados por corretora em corretoras/{id}/…, migração, Configurações só leitura para funcionário"
GIT_ASKPASS= git push
```

## Pronto para o celular e para a Europa

- **Android/iOS:** nada nesta etapa é exclusivo do navegador. O portão, a corretora e as Functions funcionam igual no app instalado.
- **Europa:** cada corretora tem a própria pasta e o próprio cadastro. Para a GDPR, o caminho que recomendo continua sendo um **projeto Firebase separado na região da UE**, com o mesmo código. A pasta por corretora deixa isso simples: muda só *onde* o projeto roda, não o app. Vale guardar no cadastro da corretora o país, a moeda e o idioma; isso entra na etapa do cadastro da corretora.

## Próximo: 16b (a trava)

- **Regras do banco:** cada usuário só lê e grava em `corretoras/{a corretora dele}/…`. Configurações e excluir sinistro ou assistência ficam só para o gestor, também nas regras, não só na tela.
- **Coleções antigas da raiz:** apagadas, depois de você confirmar que está tudo certo há alguns dias.
- **Storage:** pastas por corretora e links de arquivo assinados (S6).
