# Entrega 18 — Relatórios: gráfico de dezembro, Top 10 por valor de sinistros e maiores apólices

**Base:** GitHub `e1d5941` (Etapa 17.1).
**Data:** 23/11/2026.

> A numeração mudou: o construtor de relatórios com modelos passa a ser a **Etapa 19**.

## O que muda

**1. Queda de dezembro nos gráficos mensais.** Os meses que ainda não chegaram entravam no gráfico como **zero**, então a linha despencava em dezembro. Agora a linha para no mês atual, e o eixo continua de Jan a Dez. Vale para:
- NPS;
- Contratos Ativos;
- Valor das Apólices;
- Ticket Médio;
- Taxa de Retenção;
- SLA de sinistros e de assistências.

A tabela "Evolução Mensal" do PDF executivo também vai só até o mês atual.

**2. "Top 10 Clientes por Receita" → "Top 10 Clientes por Valor de Sinistros".** O card antigo não mostrava receita. Ele lia um campo do cliente que:
- é a **soma dos sinistros**, não a receita da corretora;
- só era atualizado quando alguém salvava um sinistro pela planilha de abertura, por isso ficava desatualizado;
- contava sinistros **Cancelados e Negados**.

Agora o valor é calculado na hora, sem Cancelado/Negado, com a mesma regra do "Valor utilizado" do relatório de clientes. O card mostra também a quantidade de sinistros e de apólices de cada cliente.

**3. Novo card "📄 Maiores Apólices Vigentes",** logo abaixo do gráfico "Valor Apólices Mensais":
- as 10 apólices vigentes de maior valor: cliente, número, ramo, vigência e valor;
- **⚠️ em vermelho** as que valem 50 vezes ou mais o valor típico das apólices vigentes (e pelo menos R$ 1 milhão). É assim que se acha a apólice de **R$ 10 bilhões** que faz o gráfico de valor "saltar". Ela provavelmente foi digitada errada.

Por isso você não a encontrava no Top 10: aquele card nunca olhou o valor das apólices.

## Arquivos (6: 4 alterados, 2 novos)

| Arquivo | O que mudou |
|---|---|
| `lib/screens/reports_screen.dart` | Gráficos mensais param no mês atual (eixo Jan–Dez); cards novos na seção Clientes. |
| `lib/widgets/top_clients_widgets.dart` | Top 10 por valor de sinistros (substitui "por Receita") e Maiores Apólices Vigentes. |
| `lib/services/pdf_report_service.dart` | Tabela mensal do PDF até o mês atual. |
| `lib/utils/rankings_clientes.dart` **(novo)** | Regra dos dois rankings e do aviso de valor destoante. |
| `test/rankings_clientes_test.dart` **(novo)** | 6 testes. |
| `README.md` | Gráficos, cards 13 e 14, histórico, roadmap (Etapa 19). |

Fora do git: `verificar-entrega.js`.

## Aplicar e publicar (pode ser durante o dia; só o app muda)

```bash
cd ~/Projects/upgrade_seguros
unzip -o ~/Downloads/entrega-18.zip verificar-entrega.js
node verificar-entrega.js --antes        # 4 iguais ao GitHub e1d5941 e 2 novos
unzip -o ~/Downloads/entrega-18.zip 'lib/*' 'test/*' README.md
node verificar-entrega.js --analyze      # ✓ Todos
git diff lib/screens/reports_screen.dart lib/widgets/top_clients_widgets.dart lib/services/pdf_report_service.dart
flutter build web
firebase deploy --only hosting
```

## Testar (5 min)

Recarregue (Cmd+Shift+R) e vá em **Relatórios**:
1. **Gráficos mensais:** a linha termina em **Nov**, sem cair a zero em Dez.
2. **Seção CLIENTES:** o card se chama "Top 10 Clientes por **Valor de Sinistros**", com valores coerentes com o relatório de clientes (coluna "Valor utilizado").
3. **Abaixo de "Valor Apólices Mensais":** o card "Maiores Apólices Vigentes". Se aparecer uma linha vermelha "⚠️ confira o valor", abra o cliente, depois a apólice, clique em **Editar** e corrija.
4. **Depois de corrigir:** o gráfico de valor das apólices deixa de "saltar", e o total das apólices no Dashboard volta ao normal.

## Commit

```bash
git add -A lib test README.md
git commit -m "Entrega 18: gráficos mensais até o mês atual · Top 10 por valor de sinistros · maiores apólices vigentes"
GIT_ASKPASS= git push
```
