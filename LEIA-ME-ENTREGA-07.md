# Entrega 07 — 🎯 Gatilho da apólice + 🔍 visualização da apólice + 📊 Top 10 de risco revisado

**Base:** GitHub `c7554c0` (Etapas 01–06). Só o app. Sem migração. Grava um campo novo em `app_config/config` (`percentualGatilhoPadrao`) quando você salvar o percentual.

> ⚠️ **A limpeza do git da Etapa 06 não entrou no GitHub.** O código da 06 subiu, mas o `.gitignore` continua sem as linhas novas, e o `node_modules/` (15 mil arquivos) e o `android/build/` continuam versionados. Esta entrega traz o `.gitignore` de novo e o passo do `git rm` está abaixo. Ele é obrigatório: o verificador avisa se faltar.

## O que muda

**1. Configurações → Funcionalidades → "Gatilho padrão da apólice"**
Campo com o **% do valor da apólice** usado quando o contrato não informa o gatilho. O padrão é **70%**. Digite e clique no ✓ (ou Enter).

**2. Cadastro da apólice: valores em R$ e gatilho sugerido**
- "Valor da Apólice" e "Valor do Gatilho" aparecem e são digitados em **R$** (antes apareciam como `120000.1`).
- Ao digitar o valor da apólice, o gatilho é **sugerido** (70% × valor) com a legenda "70% do valor da apólice — pode alterar". Se você digitar outro valor, ele passa a ser o **valor do contrato**. Se apagar o campo, a sugestão volta.
- **Bug corrigido (importante):** ao abrir "Editar" e clicar em "Atualizar" **sem redigitar**, o sistema lia `120000.1` como **R$ 1.200.001,00** (e `0.01` como R$ 1,00). Isso não acontece mais. **Confira apólices editadas antes desta entrega que tenham valores absurdos**, porque elas podem ter sido gravadas assim.

**3. Apólice clicável → visualização**
No cadastro do cliente, clicar na apólice abre o mesmo modal **em modo leitura** (sem edição, sem "Adicionar Bem"), com **Fechar** e **Editar**. O lápis e a lixeira continuam funcionando como antes.

**4. Gatilho nas telas**
Quando o contrato não informa o gatilho, as telas mostram o calculado, por exemplo: "Gatilho: R$ 84.000,07 (70% — não informado no contrato)". Isso vale no cadastro do cliente, no detalhe do cliente e na abertura do sinistro. O painel do Dashboard deixa de listar "Gatilho" como campo faltando quando a apólice tem valor.

## Avaliação do gráfico "Top 10 Clientes com Maior Risco de Gatilho"

| Problema encontrado | Efeito | Correção |
|---|---|---|
| Usava o gatilho gravado (R$ 0,01) | **2.375.000.000%**, todo mundo "CRÍTICO" | Usa o **gatilho efetivo**: o do contrato ou 70% × valor da apólice |
| Somava **todos** os sinistros ligados à apólice, de qualquer época | Renovação mantida na mesma apólice acumulava anos de sinistros | Só os sinistros **ocorridos dentro da vigência** |
| Contava sinistros cancelados/negados | Inflava o uso | **Cancelado e Negado não contam** |
| % com uma casa decimal e sem limite | Números ilegíveis | % sem casas decimais |
| A abertura do sinistro calculava o "uso atual" somando **todos** os sinistros do cliente | O alerta da abertura discordava do relatório | Com apólice escolhida, usa **a mesma regra** do relatório |

**Exemplo com os seus dados (XODO, Frota, apólice R$ 120.000,10, sem gatilho no contrato):** gatilho efetivo = R$ 84.000,07. Gasto de R$ 237.500,00 dentro da vigência = **283% → 🔴 crítico de verdade**. Antes, o mesmo caso aparecia como 2.375.000.000%.

**Pontos que continuam e estão anotados no README:**
- Sinistro aberto **sem escolher apólice** (sem `apolice_id`) não entra no uso de nenhuma apólice. Uma etapa futura pode vincular os antigos automaticamente (cliente + ramo + data dentro da vigência).
- O gasto usa o **valor total do sinistro**, que desde a Etapa 02 inclui o que foi pago a terceiros. Isso está correto para o gatilho, porque é o uso total do seguro.

## Arquivos

| Arquivo | Novo? | O que mudou |
|---|---|---|
| `lib/utils/gatilho.dart` | **novo** | Regra única: gatilho efetivo, sugestão, % de uso, quais sinistros contam (vigência, sem cancelado/negado), leitura de R$. |
| `test/gatilho_test.dart` | **novo** | 10 testes da regra (rodados aqui com sucesso). |
| `lib/models/apolice_model.dart` | alterado | + `gatilhoInformado` e `gatilhoEfetivo(%)`. |
| `lib/models/config_model.dart` / `lib/services/config_service.dart` | alterado | + `percentualGatilhoPadrao` (70) e `getPercentualGatilho()` / `updatePercentualGatilho()` (com cache em memória). |
| `lib/screens/settings_screen.dart` | alterado | Campo "Gatilho padrão da apólice". |
| `lib/screens/client_form_screen.dart` | alterado | Diálogo da apólice: R$, sugestão, leitura correta, modo leitura. Cartão clicável. Gatilho efetivo no cartão. Import `/widgets/…` (com barra no início, já existia) trocado por `../widgets/…`, que o verificador apontou. |
| `lib/screens/client_detail_screen.dart` | alterado | Gatilho efetivo no cartão da apólice. |
| `lib/widgets/top_clients_widgets.dart` | alterado | Top 10 de risco com a regra nova. |
| `lib/screens/reports_screen.dart` | alterado | Passa o % das Configurações para o Top 10. |
| `lib/widgets/dashboard_content.dart` | alterado | Integridade de apólices: gatilho não informado com valor da apólice não é mais "faltando". |
| `lib/screens/spreadsheet_claim_screen.dart` | alterado | Abertura: gatilho efetivo no campo e "uso atual" pela apólice, dentro da vigência. |
| `.gitignore` | (da 06) | `node_modules/` e `android/build/`. |
| `README.md` | alterado | Seção "Gatilho da apólice", armadilhas (valores inflados por edição antiga), histórico, roadmap. |

## Aplicar (Terminal, na raiz do projeto)

```bash
cd /Users/marcony/Projects/upgrade_seguros

unzip -o ~/Downloads/entrega-07.zip verificar-entrega.js -d .
node verificar-entrega.js --antes            # "✓ Os 14 arquivos são a base esperada"

unzip -o ~/Downloads/entrega-07.zip 'lib/*' 'test/*' README.md .gitignore -d .
tail -3 .gitignore                           # tem que terminar em "android/build/"

git rm -r --cached --quiet node_modules android/build   # tira do git (continuam no disco)
node verificar-entrega.js --analyze          # tem que terminar em "✓ Todos", SEM aviso de node_modules
```

Dois avisos ⚠️ antigos continuam e são esperados: `latlong2` (importado no `workshop_widget.dart` sem estar no pubspec) e o token do Telegram (S1, depende de você revogar no @BotFather).

## Revisar antes do commit

```bash
git --no-pager diff --stat HEAD -- lib test README.md .gitignore
git --no-pager diff HEAD -- lib/models lib/services/config_service.dart lib/utils
git --no-pager diff HEAD -- lib/widgets/top_clients_widgets.dart
git diff HEAD -- lib/screens/client_form_screen.dart
```

## Roteiro de teste
1. **Configurações:** "Gatilho padrão da apólice" mostra **70%**. Mude para 75 e clique no ✓: aparece a confirmação. Volte para 70.
2. **Cliente → Adicionar apólice:** digite "Valor da Apólice" = 100000. O campo aparece como **R$ 1.000,00** a cada dígito e termina em R$ 100.000,00 (máscara de centavos). O gatilho fica **R$ 70.000,00**, com a legenda dos 70%.
3. Digite outro gatilho (ex.: 50000): a legenda muda para "Valor do contrato". Apague o gatilho: volta a sugestão.
4. **Editar uma apólice existente** (ex.: Frota 1003100119213): os valores aparecem em R$. Clique em "Atualizar" sem mexer, salve o cliente e reabra: o valor continua **R$ 120.000,10** (antes virava R$ 1.200.001,00).
5. **Clique no cartão da apólice** (fora do lápis e da lixeira): abre o modal "Apólice" só para leitura. **Editar** abre o modo edição.
6. Apólice antiga sem gatilho: o cartão mostra "Gatilho: R$ … (70% — não informado no contrato)".
7. **Relatórios → Clientes → Top 10 de risco:** percentuais realistas (sem bilhões), só com sinistros da vigência.
8. **Abertura de sinistro:** escolha o cliente e a apólice. O gatilho mostrado é o efetivo, e o alerta do "Valor do Sinistro" usa a mesma conta do relatório.

## Subir

```bash
git add lib/utils/gatilho.dart test/gatilho_test.dart
git add -u
git commit -m "Etapa 07: gatilho da apólice (% padrão, sugestão, visualização) e Top 10 de risco revisado; node_modules fora do git"
GIT_ASKPASS= git push
```

## Como foi testado aqui
- Análise antes × depois do projeto inteiro: zero erro ou aviso novo.
- Testes: 10 novos (gatilho) + 5 (filtro) + 11 (lançamentos), todos passando.
- Simulação no clone do GitHub: `--antes`, cópia, `git rm --cached`, "✓ Todos" sem avisos de node_modules/android/build.
