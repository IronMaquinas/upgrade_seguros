# Entrega 28 — Beta, a assistente

**Base:** GitHub `d222b71` (Etapa 27).

## O que muda

1. **App: botão "Beta"** no canto **inferior esquerdo**, porque o direito já tem o "Novo Registro". No celular ele fica acima da barra de baixo. Abre um chat. O botão só aparece se o plano da corretora tiver o módulo **Beta**.
2. **O que ela responde**, sempre com dados do banco da corretora:
   - **telefone, e-mail e WhatsApp** de: segurado, contato do segurado, motorista do segurado, terceiro, contato do terceiro, motorista do terceiro, contato no local e oficina;
   - **veículo** segurado e do terceiro;
   - **status** do sinistro ou da assistência;
   - **ações/tarefas pendentes**;
   - **sinistros de um cliente**, pelo nome (se houver mais de um cliente parecido, ela pergunta qual);
   - **de quem é uma placa**.

   Ela acha o atendimento pelo nosso número (SN…/AS…) ou pelo número da seguradora. Cada resposta vem em cartões com botões **Ligar**, **WhatsApp**, **E-mail** e **Abrir** o atendimento.
3. **Conversa contínua:**

   > "telefone do segurado do sinistro SN2026111055446?" → (responde)
   > "e o telefone de contato do segurado?" → mesmo sinistro
   > "e do terceiro?" → mesmo sinistro, outra pessoa

   **Nova conversa** (⟳ no topo do chat) zera o assunto.
4. **Fora do escopo:** ela responde "não está no meu escopo" e guarda a pergunta. Você vê todas em **Portal → Beta → Perguntas sem resposta**. É a lista do que ensinar a ela depois.
5. **Custo:**
   - **Primeiro, regras de texto, sem IA e sem custo.** No teste, a conversa inteira acima não chamou a IA nenhuma vez.
   - Só o que as regras não entendem vai para o **Claude Haiku**. Ele só traduz a pergunta para o catálogo e não escreve a resposta. Recebe a pergunta e o assunto atual, nunca o histórico, por isso cada chamada fica pequena (cerca de 400 tokens de entrada e 40 de saída).
   - **Tudo é medido** por corretora e por mês: perguntas, quantas usaram IA, tokens e US$.
   - **Teto** por corretora (padrão **US$ 5 por mês**, ajustável no portal). Ao chegar no teto, a Beta para de chamar a IA no mês e continua respondendo as perguntas diretas. Não há conta surpresa.
6. **Portal → Beta** (novo item no menu):
   - perguntas do mês e % respondidas sem IA;
   - custo em US$ e R$ (você digita o câmbio);
   - custo por pergunta;
   - tabela por corretora com o **teto** (clique para mudar);
   - perguntas sem resposta, com o botão "Vista".

**Módulo:** a Beta entrou no catálogo como módulo **"Beta — assistente"** (área Comunicação). Planos em **Tudo ligado** já a recebem. O **Diamante** da Upgrade tem lista própria de módulos, então você **marca a Beta no Diamante** quando quiser ligar.

## Arquivos (15)

| Arquivo | O que mudou |
|---|---|
| `functions/beta-interpretar.js` (novo) | Regras de texto: intenção, de quem, número, placa, cliente; confere o que vem da IA. |
| `functions/beta.js` (novo) | Function `beta`: assunto da conversa, IA só quando precisa, buscas e respostas, medição, teto, perguntas sem resposta; resumo do portal. |
| `functions/testes/beta.teste.js` (novo) | 38 testes (a conversa do seu exemplo, terceiros, pendências, número da seguradora, escolher cliente, placa, IA falsa, fora do escopo, custo, teto, módulo, portal). |
| `functions/index.js` | Exporta `beta`. |
| `functions/plataforma.js` | Ações `betaResumo`, `betaPerguntaVista`, `contaDefinirTetoBeta`. |
| `functions/modulos.js`, `lib/utils/modulos.dart` | Módulo `beta`. |
| `functions/testes/firebase-falso.js` | `increment`, `set` com `merge`, segredo de mentira. |
| `lib/widgets/beta_chat.dart` (novo) | Botão e chat da Beta. |
| `lib/widgets/portao_empresa.dart` | Põe o botão da Beta (só com o módulo). |
| `lib/admin/aba_beta_portal.dart` (novo) | Aba Beta do portal. |
| `lib/admin/portal_app.dart`, `plataforma_api.dart`, `modelos_plataforma.dart` | Item Beta no menu e as chamadas. |
| `README.md` | Seção Beta, histórico; "28 gateway" saiu das próximas etapas (cobrança adiada). |

Ver o que mudou: `git diff <arquivo>`. Os novos aparecem em `git status`.

## Aplicar

```bash
cd ~/Projects/upgrade_seguros
unzip -o ~/Downloads/entrega-28.zip verificar-entrega.js
node verificar-entrega.js --antes        # 10 iguais ao GitHub d222b71, 5 novos ainda não existem
unzip -o ~/Downloads/entrega-28.zip 'lib/*' 'functions/*' README.md
node verificar-entrega.js --analyze      # ✓ Todos + ✓ catálogo de módulos igual
git diff --stat
```

## Chave da IA (você, no terminal — nunca no chat)

1. Em console.anthropic.com, crie uma chave de API. Se possível, use um "workspace" só para este app e defina um **limite de gasto mensal** lá também, como segunda trava.
2. No terminal, cole a chave quando o comando pedir:

```bash
firebase functions:secrets:set ANTHROPIC_API_KEY
```

O modelo e o preço por token estão no início de `functions/beta.js` (`MODELO`, `PRECO_ENTRADA_USD_MTOK`, `PRECO_SAIDA_USD_MTOK`). **Confira na tabela de preços da Anthropic** e me diga se estiver diferente; o custo mostrado no portal usa esses números.

## Publicar o servidor (para testar localmente)

É seguro: a Function é nova, e a única mudança na `plataforma` são as ações da Beta. Sem o módulo ligado, ninguém vê a Beta.

```bash
firebase deploy --only functions:beta,functions:plataforma
```

Se o chat disser "Não consegui falar com o servidor" e a Function responder 403 em HTML, libere o acesso público da `beta` no Cloud Run, como nas outras. O login é conferido no código.

## Testar (`flutter run -d chrome` e `flutter run -d chrome -t lib/main_admin.dart`)

1. **Portal → Planos → Diamante → Editar →** marque **Beta — assistente** → Salvar.
2. **App** (recarregue): o botão roxo **Beta** aparece no canto inferior esquerdo.
3. Pegue um sinistro real com terceiro e pergunte em sequência:
   - "telefone do segurado do sinistro SN…" → o telefone aparece, com os botões Ligar e WhatsApp;
   - "e o telefone de contato do segurado?";
   - "e do terceiro?" e "e o motorista do terceiro?";
   - "qual o veículo segurado?";
   - "tem ação pendente?";
   - "quais os sinistros do cliente <nome>?";
   - "de quem é a placa <placa>?".
4. Teste uma pergunta torta (ex.: "me passa o fone da funilaria desse sinistro") e uma fora do escopo (ex.: "qual a previsão do tempo?").
5. **Portal → Beta:** aparecem as perguntas, quantas usaram IA, o custo e a pergunta fora do escopo na lista.
6. Clique em **Abrir** num cartão: abre o sinistro ou a assistência.

## Publicar o site (depois de aprovar)

```bash
flutter build web -t lib/main_admin.dart --no-tree-shake-icons
rm -rf build/admin && cp -R build/web build/admin
flutter build web
firebase deploy --only hosting:admin,hosting:app
```

## Commit

```bash
git add -A lib functions README.md
git commit -m "Entrega 28: Beta, a assistente (chat no app, respostas do banco, Haiku só para entender, custo medido com teto)"
GIT_ASKPASS= git push
```
