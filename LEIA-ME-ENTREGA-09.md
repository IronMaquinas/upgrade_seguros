# Entrega 09: 🚦 recomendação do cliente pelo gatilho + 🏷️ botões com texto

**Base:** GitHub `4d14169` (Etapas 01–08; a limpeza do git da 06 entrou: `node_modules` e `android/build` fora do git ✓). Só o app. Sem migração e sem `.gitignore` nesta etapa.

## 1. Botões com texto

- **Lista de clientes:** o ícone ⬇ virou o botão **"Exportar relatório"** (ícone + texto, com contorno), que abre o mesmo menu Planilha / PDF. Em tela estreita (celular) o texto fica só "Exportar".
- **Cadastro do cliente:** o ícone de importar virou o botão **"Importar contrato (PDF)"** na barra azul (no celular, "Importar contrato"). A função é a mesma de antes, `_importarContrato`.

## 2. Recomendação do cliente: o que estava errado

A recomendação era calculada de **4 jeitos diferentes**, e nenhum usava o gatilho:

| Onde | Antes |
|---|---|
| Lista de clientes | Todos os sinistros de qualquer época (inclusive cancelados) ÷ **100%** do valor das apólices vigentes. Sem apólice vigente = "Não recomendado" |
| Detalhes do cliente | A mesma conta, somando também as assistências |
| Salvar o cliente | **Quantidade** de sinistros (≥ 5 Crítico, ≥ 3 Regular, senão Bom), gravada no banco |
| Encerrar sinistro | % do valor da apólice com outros rótulos (Ótimo / Bom / Atenção / Crítico), gravada no banco |

Por isso o IURY GUARU (apólice vencida em 24/09/2026) e o TONY GUILHERME apareciam "Não recomendado" com 0 sinistros. E um cliente que já tinha passado do gatilho (70%) ainda aparecia "Regular".

## 3. Regra nova (uma só, nas três telas)

1. Só contam as apólices **vigentes hoje**.
   - Nenhuma vigente → selo cinza **"Sem apólice vigente"**.
   - Vigente, mas sem valor e sem gatilho → selo cinza **"Apólice sem valor"** (provavelmente o caso do TONY).
2. Para cada apólice vigente, **uso do gatilho** = sinistros da vigência (sem Cancelado/Negado) ÷ gatilho efetivo. É a mesma regra do Top 10 de risco.
3. Sinistro antigo **sem vínculo** com apólice conta na apólice do **mesmo ramo** cuja vigência cobre a data dele. Isso vale só para o cálculo: nada é gravado.
4. Vale a **pior** apólice do cliente:

| Uso do gatilho | Recomendação |
|---|---|
| < 60% | Ótimo |
| 60% a < 80% | Regular |
| 80% a 100% | Atenção |
| > 100% | Não recomendado |

**Sua dúvida (acima do gatilho × acima da apólice):** os dois são "Não recomendado". O **Detalhes do Cliente** mostra ao lado do selo de onde veio a recomendação, por exemplo:
- "Uso do gatilho: 45% · 32% do valor da apólice (Frota 31.69.2026.0488237)"
- "Uso do gatilho: 120% · 84% do valor da apólice (Frota …) — acima do gatilho"
- "Uso do gatilho: 283% · 198% do valor da apólice (Frota …) — **acima do valor da apólice**"
- "Nenhuma apólice vigente hoje: renovar ou cadastrar a apólice."

**Uma diferença a saber:** o Top 10 de risco (Relatórios) ainda **não** liga os sinistros sem vínculo por ramo + data. Então um cliente pode estar "Não recomendado" aqui e com uso menor no Top 10. Alinhar o Top 10 com a mesma regra ficou no roadmap: é uma mudança pequena, se você quiser na próxima.

O valor gravado no banco (`recomendacao_manutencao`) não aparece em nenhuma tela: a lista e o detalhe recalculam ao abrir. Agora ele é gravado com a regra nova ao encerrar um sinistro, e **salvar o cliente não sobrescreve mais** com a conta pela quantidade de sinistros.

## Arquivos

| Arquivo | Novo? | O que mudou |
|---|---|---|
| `lib/utils/recomendacao_cliente.dart` | **novo** | A regra (Dart puro): apólices vigentes, ligação dos sinistros, uso do gatilho, faixas, explicação. |
| `lib/services/recomendacao_service.dart` | **novo** | `recomendarCliente(cliente, claims, %)`: converte Client/Claim para a regra. |
| `lib/widgets/recomendacao_chip.dart` | **novo** | Cores do selo (inclusive cinza para os casos sem apólice) e o `RecomendacaoChip`. |
| `test/recomendacao_cliente_test.dart` | **novo** | 19 testes: vencida/futura/sem valor, faixas, gatilho do contrato, acima do gatilho × da apólice, cancelado/negado/fora da vigência, sem vínculo por ramo, Vidas/Vida, renovação, pior apólice. |
| `lib/screens/client_list_screen.dart` | alterado | Usa a regra nova e o % das Configurações. Cores pelo componente. Botão "Exportar relatório" com texto. Sai a função antiga. |
| `lib/screens/client_detail_screen.dart` | alterado | Usa a regra nova (só sinistros) e mostra a explicação ao lado do selo. Sai a função antiga. |
| `lib/screens/client_form_screen.dart` | alterado | Botão "Importar contrato (PDF)" com texto. Ao salvar, mantém a recomendação gravada (não calcula mais pela quantidade). |
| `lib/services/firestore_service.dart` | alterado | `atualizarRecomendacaoManutencao` (chamado ao encerrar sinistro) grava pela regra nova. |
| `README.md` | alterado | Seção "Recomendação do cliente", armadilha do Top 10, histórico, roadmap. |
| `verificar-entrega.js` | (fora do git) | Etapa 09. |

## Aplicar (Terminal, na raiz do projeto)

```bash
cd /Users/marcony/Projects/upgrade_seguros

unzip -o ~/Downloads/entrega-09.zip verificar-entrega.js -d .
node verificar-entrega.js --antes            # "✓ Os 9 arquivos são a base esperada"

unzip -o ~/Downloads/entrega-09.zip 'lib/*' 'test/*' README.md -d .
node verificar-entrega.js --analyze          # tem que terminar em "✓ Todos"
```
> Se o Safari abriu o zip sozinho (pasta `entrega-09` em Downloads): `cp -R ~/Downloads/entrega-09/lib ~/Downloads/entrega-09/test ~/Downloads/entrega-09/README.md ~/Downloads/entrega-09/verificar-entrega.js .` no lugar dos dois `unzip`.

Avisos ⚠️ antigos esperados: `latlong2` e o token do Telegram (S1).

## Revisar antes do commit

```bash
git --no-pager diff --stat HEAD
git --no-pager diff HEAD -- lib/services/firestore_service.dart lib/screens/client_list_screen.dart
git diff HEAD -- lib/screens/client_detail_screen.dart lib/screens/client_form_screen.dart
```
Os três arquivos novos (regra, ponte e selo) são curtos e comentados: vale ler o `lib/utils/recomendacao_cliente.dart` inteiro. É a regra que você vai explicar para a cliente.

## Roteiro de teste

1. **Lista de clientes:** o botão "Exportar relatório" aparece com texto e abre Planilha / PDF.
2. **IURY GUARU** (apólice vencida): selo cinza **"Sem apólice vigente"**. **TONY GUILHERME**: "Sem apólice vigente" ou "Apólice sem valor". Abra o detalhe para ver a explicação.
3. **MAIS ALIMENTOS** (1 sinistro, apólice de R$ 59.611,01, gatilho R$ 41.727,71): abra o detalhe. A linha ao lado do selo mostra o uso do gatilho e o % do valor da apólice. Confira se o selo bate com a tabela de faixas.
4. Um cliente com sinistros altos (o XODÓ do Top 10, por exemplo): "Não recomendado", com "acima do gatilho" ou "acima do valor da apólice" na explicação.
5. **Novo Cliente:** o botão "Importar contrato (PDF)" aparece com texto na barra azul e importa como antes.
6. Edite e salve um cliente, volte à lista: o selo continua o mesmo (antes o salvar regravava "Bom/Regular/Crítico" no banco).

## Subir

```bash
git add lib/utils/recomendacao_cliente.dart lib/services/recomendacao_service.dart lib/widgets/recomendacao_chip.dart test/recomendacao_cliente_test.dart
git add -u
git commit -m "Etapa 09: recomendação do cliente pelo uso do gatilho; botões Exportar relatório e Importar contrato com texto"
GIT_ASKPASS= git push
```

## Como foi testado aqui
- Análise antes × depois contra o GitHub `4d14169`: nenhum erro ou aviso novo.
- 19 testes novos da recomendação, mais os 36 anteriores, todos passando.
- Simulação no clone do GitHub: `--antes`, cópia, verificador terminando em "✓ Todos".
