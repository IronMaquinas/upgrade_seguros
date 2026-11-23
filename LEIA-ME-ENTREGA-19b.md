# Entrega 19b — Relatórios de sinistros e assistências com modelos

**Base:** GitHub `9ad1a4e` (Etapa 19a).
**Data:** 23/11/2026.

## O que muda

Nas listas de **Sinistros** e de **Assistências** aparece o botão **Exportar relatório**.

**1. Modelos.** O botão abre os modelos de relatório da corretora:
- **Todos veem e usam todos os modelos.** Se alguém sai de férias, outro exporta o relatório do cliente.
- Cada modelo pode ser **editado, duplicado ou excluído**.
- Sem nenhum modelo, a tela leva direto para **Criar modelo**.

**2. Criar ou editar um modelo:**
- **Nome**, por exemplo "Águia Branca — assistências do mês".
- **Campos por seção.** Você marca o que deve sair:

| Seção | Campos |
|---|---|
| Ocorrência | nº, nº na seguradora, seguradora, datas, tipo, ramo, status, conclusão, local, relato, responsável |
| Cliente | nome, CNPJ/CPF |
| Bem / veículo | placa, marca/modelo, ano, cor, chassi |
| Proprietário (CRLV) | nome, CPF/CNPJ |
| Condutor | nome, CPF, CNH |
| Terceiros (só sinistro) | houve?, quantidade, nomes, placas, condutores |
| Atendimento (só assistência) | destino, oficina/prestador, agendamento |
| Valores | valor total, composição do valor, franquia, quantidade de lançamentos |

- **Ordem das colunas:** é só arrastar.
- **Medidor de largura do PDF** (folha A4 deitada), atualizado a cada campo marcado:
  - 🟢 **cabe**: PDF em tabela;
  - 🟡 **apertado**: tabela com letra menor;
  - 🔴 **não cabe**: o PDF sai em **ficha**, um bloco por ocorrência com todos os campos.

  O **Excel sai sempre completo**, uma coluna por campo.

**3. Exportar:**
- **Período:** mês atual, mês anterior, este ano, datas escolhidas ou tudo. No sinistro, escolha se vale a data de **abertura** ou da **ocorrência**.
- **Cliente, seguradora, tipo** (guincho, vidro…) e **status**.
- **Prévia:** quantidade de ocorrências e valor total, antes de gerar.
- **PDF:** cabeçalho e rodapé da corretora (Etapa 17), uma linha de **TOTAL** e os filtros escritos no cabeçalho.
- **Excel (CSV):** abre no Excel com acentos certos e valores em número, que dá para somar.

**Exemplo, Águia Branca (você monta pela tela):** modelo de **assistência** com os campos:
1. Nº da ocorrência;
2. Abertura (data e hora);
3. Placa;
4. Veículo;
5. Tipo;
6. Composição do valor;
7. Valor total.

Para exportar: período **Mês anterior** e cliente **Águia Branca**. Cabe em tabela (🟢).

## Arquivos (10: 5 alterados, 5 novos)

| Arquivo | O que mudou |
|---|---|
| `lib/utils/relatorio_modelo.dart` **(novo)** | Catálogo de campos, modelo, medidor de largura, filtros, montagem, totais e CSV. |
| `lib/services/relatorio_atendimentos.dart` **(novo)** | Modelos no banco (`modelos_relatorio`); converte cada sinistro/assistência nos valores dos campos. |
| `lib/services/relatorio_atendimentos_pdf.dart` **(novo)** | PDF em tabela, tabela compacta ou ficha. |
| `lib/widgets/relatorios_modelos.dart` **(novo)** | Lista de modelos, editor e tela de exportação. |
| `test/relatorio_modelo_test.dart` **(novo)** | 15 testes. |
| `lib/screens/claim_list_screen.dart`, `assist_list_screen.dart` | Botão "Exportar relatório". |
| `lib/services/empresa_atual.dart` + `functions/empresa.js` | Coleção nova `modelos_relatorio` na lista da corretora. O verificador confere se as duas listas são iguais. |
| `README.md` | Seção dos relatórios com modelos, coleção nova, histórico, roadmap. |

As regras do banco **não mudam**: a regra geral da corretora já deixa qualquer funcionário criar, editar e excluir nessa coleção.

## Aplicar e publicar

```bash
cd ~/Projects/upgrade_seguros
unzip -o ~/Downloads/entrega-19b.zip verificar-entrega.js
node verificar-entrega.js --antes        # 5 iguais ao GitHub 9ad1a4e e 5 novos
unzip -o ~/Downloads/entrega-19b.zip 'lib/*' 'test/*' 'functions/*' README.md
node verificar-entrega.js --analyze      # ✓ Todos
git diff lib/screens lib/services/empresa_atual.dart functions/empresa.js
flutter build web
firebase deploy --only hosting,functions:migrarEmpresa,functions:arquivosEmpresa
```

As duas Functions só ganham o nome da coleção nova na lista. Elas sobem juntas para o código publicado continuar igual ao do GitHub.

## Testar (15 min)

Recarregue (Cmd+Shift+R).

**Assistências:**
1. Abra **Assistências** → **Exportar relatório** → **Criar modelo**.
2. Dê o nome "Teste mensal" e marque os campos do exemplo acima.
3. Confira que o medidor fica 🟢. Arraste "Valor total" para o fim e clique em **Salvar**.
4. Clique em **Exportar** → **Mês atual**. A prévia mostra a quantidade e o total.
5. Gere o **PDF** e o **Excel**:
   - no PDF, confira o cabeçalho da corretora, a tabela e a linha TOTAL;
   - no Excel, a soma da coluna "Valor total" tem que bater com o PDF.

**Sinistros:**
6. Crie um modelo marcando **muitos** campos, até o medidor ficar 🔴. O PDF sai em ficha e o Excel com todas as colunas.

**Como funcionário:**
7. Os modelos criados por você aparecem, e ele consegue exportar.

## Commit

```bash
git add -A lib test functions README.md
git commit -m "Entrega 19b: relatórios de sinistros e assistências com modelos salvos (campos, largura, filtros, PDF e Excel)"
GIT_ASKPASS= git push
```
