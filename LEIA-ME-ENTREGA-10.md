# Entrega 10: 🚦 Top 10 pela recomendação · 🎯 filtro + contato na lista de clientes · ✅ tarefas por funcionário

**Base:** GitHub `44f5c8f` (Etapas 01–09). Só o app.

**Mudança no banco (só acrescenta):** as tarefas passam a gravar `concluida_em` (data e hora da conclusão) quando são concluídas. Não há migração: as tarefas concluídas antes desta entrega ficam sem essa data.

## 1. Top 10 de risco (Relatórios) com a regra da recomendação

O Top 10 agora usa exatamente a conta da recomendação do cliente:
- só apólices vigentes;
- sinistros da vigência, sem Cancelado/Negado;
- sinistros sem vínculo com apólice ligados pela apólice do mesmo ramo + data;
- vale a pior apólice do cliente.

Os selos ganharam os mesmos nomes: 🔴 Não recomendado · 🟠 Atenção · 🟡 Regular · 🟢 Ótimo. Com isso, o cliente que aparece "Não recomendado" na lista tem o mesmo % no Top 10.

## 2. Lista de clientes: filtro por recomendação + exportação para contato

- Abaixo da busca há uma fileira de **filtros** com a quantidade de cada um: *Todas (N) · Não recomendado (N) · Atenção (N) · Regular (N) · Ótimo (N) · Sem apólice vigente (N) · Apólice sem valor (N)*. Só aparecem os que têm clientes.
- **Exportar relatório** usa a lista filtrada, e o relatório ganhou as colunas **Recomendação · Uso do gatilho (%) · Contato · Telefone · E-mail**.
- O filtro aparece no cabeçalho do PDF e no nome do arquivo (`relatorio_clientes_nao-recomendado_2026-11-08.csv`), e a busca por texto continua valendo junto.

Exemplo de uso: filtrar "Não recomendado" → Exportar → Planilha. Sai a lista com quem ligar, o telefone e quanto do gatilho cada um já usou.

## 3. Tarefas (lista de Tarefas)

- **Ordenar:** novo seletor *Mais recente / Mais antiga*, pela data de criação da tarefa. Tarefa antiga sem data de criação usa o prazo.
- **Exportar por funcionário:** botão na barra, com as opções Planilha (CSV/Excel) ou PDF.
  - Exporta as tarefas da lista, respeitando os filtros (status, prazo, funcionário, busca e ordem).
  - Uma seção por funcionário, com subtotal: total, abertas, concluídas (%), no prazo × fora.
  - Colunas: atendimento, cliente, descrição, status, criada em, prazo, concluída em e "prazo cumprido?".
- **No prazo / Fora do prazo** (regra única em `lib/utils/tarefas.dart`):
  - o prazo vale até o **fim do dia** marcado;
  - aberta/pendente depois disso = **fora do prazo** (atrasada);
  - concluída: compara a **data de conclusão** com o prazo.
  - **Correção:** antes, toda tarefa com prazo vencido caía em "Fora do prazo" no filtro, inclusive as concluídas dentro do prazo.
- **Sobre a sua dúvida do "No prazo / Fora do prazo":** para tarefas **abertas** funciona desde já. Para **concluídas**, o app não guardava quando a tarefa foi concluída. A partir desta entrega ele grava (ao concluir pelo detalhe do sinistro, pelo diálogo da tarefa ou no reagendamento da assistência). As concluídas antes aparecem como **"Sem data de conclusão"** e ficam fora da conta do prazo.
- O card mostra "Prazo: dd/mm · Concluída em dd/mm". O ⚠️ vermelho também aparece em concluída fora do prazo.

**Duas correções encontradas no caminho:**
- **Editar uma tarefa passava o responsável para quem editou.** Se o admin concluía a tarefa da Ana pelo diálogo, ela virava do admin. Agora o responsável é mantido. Tarefas editadas antes podem estar com o responsável trocado nas estatísticas.
- **O filtro por funcionário pelo id não funcionava:** o campo `responsavelId` não vinha na lista, então o filtro só casava pelo e-mail. Agora vem.

## 4. Relatórios → Funcionários → "Tarefas por Funcionário (período)"

Card novo, logo abaixo de "Assistências por Funcionário". Para cada funcionário: total de tarefas, **Abertas**, **Concluídas (% encerradas)**, **No prazo**, **Fora do prazo** e **% de cumprimento do prazo** (no prazo ÷ no prazo + fora). Tem uma barra de progresso das encerradas e cores de 80% e 60%.
- **Período:** tarefas criadas dentro do período escolhido no topo dos Relatórios (ou com prazo no período, se a tarefa antiga não tiver data de criação).
- Exemplo do formato que você pediu: "Marcony: 80 tarefas · 16 abertas · 64 concluídas (80%) · 50 no prazo · 10 fora · 83% de cumprimento".
- No começo quase todas as concluídas vão estar "sem data de conclusão" (aviso no rodapé do card). Os números de prazo ficam confiáveis conforme as tarefas forem sendo concluídas depois desta entrega.

## Arquivos

| Arquivo | Novo? | O que mudou |
|---|---|---|
| `lib/widgets/top_clients_widgets.dart` | alterado | Top 10 calculado por `recomendarCliente` (regra da Etapa 09). Selos com os nomes da recomendação. |
| `lib/screens/client_list_screen.dart` | alterado | Filtro por recomendação (chips com contagem), guarda o resultado de cada cliente, exportação com recomendação/uso/contato e filtro no nome do arquivo. Botão usa o componente compartilhado. |
| `lib/utils/relatorio_clientes.dart` | alterado | Campos e colunas novas: recomendação, uso do gatilho, contato, telefone, e-mail. |
| `lib/services/relatorio_clientes_pdf.dart` | alterado | Colunas Recomendação e Contato. Filtro no cabeçalho. |
| `test/relatorio_clientes_test.dart` | alterado | Colunas novas no CSV e mais 1 teste (recomendação + contato). |
| `lib/utils/tarefas.dart` | **novo** | Regras das tarefas: prazo, ordenação, resumo por funcionário, CSV agrupado. |
| `lib/services/tarefas_pdf.dart` | **novo** | PDF das tarefas por funcionário. |
| `lib/widgets/tarefas_funcionarios_card.dart` | **novo** | Card dos Relatórios. |
| `lib/widgets/botao_com_texto.dart` | **novo** | Botão ícone + texto da barra (saiu de dentro da lista de clientes para ser usado também nas tarefas). |
| `test/tarefas_test.dart` | **novo** | 12 testes: prazo (fim do dia, concluída no/fora do prazo, sem data, sem prazo), ordenação, agrupamento (id/e-mail/sem responsável), 80% encerradas, CSV com subtotal. |
| `lib/screens/task_list_screen.dart` | alterado | Seletor de ordem, botão Exportar por funcionário, filtro de prazo pela regra única, card com data de conclusão. |
| `lib/widgets/task_list_widget.dart` | alterado | Grava/apaga `concluida_em` ao mudar o status. Editar mantém o responsável. |
| `lib/services/firestore_service.dart` | alterado | `updateTaskStatus` grava/apaga `concluida_em`. Lista de tarefas traz `concluidaEm` e `responsavelId`. Novo `getTarefasResumo()` para os Relatórios. |
| `lib/screens/assist_detail_screen.dart` | alterado | Reagendamento grava `concluida_em` ao concluir as tarefas anteriores (1 linha). |
| `lib/models/claim_task_model.dart` | alterado | Campo `concluidaEm`. |
| `lib/screens/reports_screen.dart` | alterado | Carrega as tarefas e mostra o card novo na seção Funcionários. |
| `README.md` | alterado | Gestão de Tarefas (prazo, exportação, relatório), relatório de clientes com filtro e contato, Top 10, armadilhas, histórico, roadmap. |
| `verificar-entrega.js` | (fora do git) | Etapa 10. |

## Aplicar (Terminal, na raiz do projeto)

```bash
cd /Users/marcony/Projects/upgrade_seguros

unzip -o ~/Downloads/entrega-10.zip verificar-entrega.js -d .
node verificar-entrega.js --antes            # "✓ Os 17 arquivos são a base esperada"

unzip -o ~/Downloads/entrega-10.zip 'lib/*' 'test/*' README.md -d .
node verificar-entrega.js --analyze          # tem que terminar em "✓ Todos"
```
> Se o Safari abriu o zip sozinho (pasta `entrega-10` em Downloads): `cp -R ~/Downloads/entrega-10/lib ~/Downloads/entrega-10/test ~/Downloads/entrega-10/README.md ~/Downloads/entrega-10/verificar-entrega.js .` no lugar dos dois `unzip`.

Avisos ⚠️ antigos esperados: `latlong2` e o token do Telegram (S1).

## Revisar antes do commit

```bash
git --no-pager diff --stat HEAD
git --no-pager diff HEAD -- lib/widgets/top_clients_widgets.dart lib/services/firestore_service.dart lib/widgets/task_list_widget.dart lib/screens/assist_detail_screen.dart lib/models/claim_task_model.dart
git diff HEAD -- lib/screens/client_list_screen.dart lib/screens/task_list_screen.dart lib/screens/reports_screen.dart
```
Vale ler `lib/utils/tarefas.dart` inteiro: são as regras de prazo e de "% encerradas" que você vai mostrar à equipe.

## Roteiro de teste

1. **Relatórios → Clientes → Top 10:** os selos aparecem como "🔴 Não recomendado — gatilho estourou" etc. Um cliente do topo tem o mesmo % que aparece no Detalhes dele.
2. **Lista de clientes:** aparecem os chips com as quantidades. Clique em "Não recomendado": a lista filtra. **Exportar relatório → Planilha**: o arquivo se chama `relatorio_clientes_nao-recomendado_…csv` e tem as colunas Recomendação, Uso do gatilho, Contato, Telefone e E-mail. Clique em "Todas" e confira que volta tudo.
3. **Tarefas:** troque *Mais recente / Mais antiga* e confira a ordem.
4. **Tarefas → Exportar por funcionário → PDF:** uma seção por funcionário, com o subtotal no cabeçalho de cada uma.
5. Conclua uma tarefa com prazo **hoje**, pelo detalhe do sinistro: o card mostra "Concluída em (hoje)" e ela conta como **No prazo**. Uma tarefa aberta com prazo **ontem** aparece em "Fora do prazo".
6. Edite pelo diálogo uma tarefa de outro funcionário e salve: o responsável continua o mesmo.
7. **Relatórios → Funcionários:** o card "Tarefas por Funcionário" aparece com abertas, concluídas (%), no prazo e fora do prazo. Troque o período e veja os números mudarem.

## Subir

```bash
git add lib/utils/tarefas.dart lib/services/tarefas_pdf.dart lib/widgets/botao_com_texto.dart lib/widgets/tarefas_funcionarios_card.dart test/tarefas_test.dart
git add -u
git commit -m "Etapa 10: Top 10 pela recomendação; filtro e exportação com contato; tarefas por funcionário (ordenar, exportar, prazo) e nos Relatórios"
GIT_ASKPASS= git push
```

## Como foi testado aqui
- Análise antes × depois contra o GitHub `44f5c8f`: nenhum erro ou aviso novo no app. Os únicos diagnósticos novos são os matchers de teste (`isTrue`, `closeTo`), que o analisador daqui não tem; no seu `flutter test` eles existem.
- 12 testes novos de tarefas, 7 do relatório de clientes e os anteriores, todos passando.
- PDFs gerados aqui com dados de exemplo (clientes "Não recomendado" com contato; 30 tarefas em 3 grupos) e conferidos visualmente.
- Simulação no clone do GitHub: `--antes`, cópia, verificador terminando em "✓ Todos".
