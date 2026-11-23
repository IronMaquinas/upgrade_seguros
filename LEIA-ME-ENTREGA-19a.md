# Entrega 19a — Valores da assistência

**Base:** GitHub `a489a14` (Etapa 18.1).
**Data:** 23/11/2026.

A Etapa 19 sai em duas partes. A **19a** (esta) passa a guardar o valor das assistências. A **19b** traz os relatórios com modelos salvos (criar o modelo, escolher os campos, salvar, exportar em PDF e Excel). O relatório mensal da Águia Branca precisa dos valores, por isso eles vêm primeiro.

## O que muda

**Abertura da assistência (planilha veicular):** um campo novo, **"Valor do serviço"**, ao lado da Franquia.
- É opcional.
- Se for preenchido, vira o primeiro valor da assistência.

**Detalhe da assistência:** um card novo, **💰 Valores da Assistência**. Funciona como o "Valores do Sinistro", que a equipe já conhece:
- **Novo valor:** data, tipo, valor, descrição e nota fiscal/evidência. Tipos próprios de assistência:
  - Serviço (guincho / remoção);
  - Km excedente;
  - Hora parada / espera;
  - Pedágio;
  - Diária / pernoite;
  - Mão de obra;
  - Peças / material;
  - Outro.
- **Nada é apagado nem editado.** Valor errado? Cancele com o motivo (fica riscado no histórico, com quem e quando) e lance o correto.
- **Total da assistência** no topo do card. Atualiza na hora, mesmo que outra pessoa lance.
- Assistência **residencial**: os valores são lançados pelo detalhe. A planilha residencial não ganhou o campo.

**Dashboard (correção):** "Custo médio" e "Sinistralidade" passam a contar **só sinistros**. Antes as assistências entravam com valor 0 e puxavam o custo médio para baixo. Com elas ganhando valor, misturaria. Então o custo médio deve **subir um pouco** em relação ao de hoje.

**Fica no README, para confirmar com a sua cliente:** o **gatilho mensal de assistências** da Águia Branca. É um valor que ela estipula a cada mês, sem ligação com a apólice; ao atingir, a corretora é avisada. Falta saber:
- se o valor é fixo ou muda a cada mês;
- se vale por cliente ou por frota;
- com qual % avisar;
- quem recebe o aviso.

## Arquivos (8)

| Arquivo | O que mudou |
|---|---|
| `lib/models/lancamento_model.dart` | Tipos de valor da assistência (`manuaisAssistencia`). |
| `lib/services/lancamentos_service.dart` | Grava na coleção `assistencias` quando for assistência (mesmos campos do sinistro). |
| `lib/widgets/lancamentos_widget.dart` | O mesmo card serve aos dois: na assistência mostra só o total, sem "segurado/terceiro", com os tipos de assistência e textos "da assistência". |
| `lib/screens/assist_detail_screen.dart` | Card 💰 Valores da Assistência (ao vivo). |
| `lib/screens/spreadsheet_assist_screen.dart` | Campo "Valor do serviço" na abertura → 1º lançamento. |
| `lib/widgets/dashboard_content.dart` | Custo médio e sinistralidade só com sinistros. |
| `test/lancamento_model_test.dart` | +2 testes (tipos e total da assistência). |
| `README.md` | Valores da assistência, histórico, roadmap (gatilho mensal; 19b). |

## Aplicar e publicar (só o app)

```bash
cd ~/Projects/upgrade_seguros
unzip -o ~/Downloads/entrega-19a.zip verificar-entrega.js
node verificar-entrega.js --antes        # 8 iguais ao GitHub a489a14
unzip -o ~/Downloads/entrega-19a.zip 'lib/*' 'test/*' README.md
node verificar-entrega.js --analyze      # ✓ Todos
git diff lib test
flutter build web
firebase deploy --only hosting
```

## Testar (10 min)

Recarregue (Cmd+Shift+R).
1. **Nova assistência veicular:** preencha "Valor do serviço" com R$ 350,00 e salve.
2. **Abra o detalhe:**
   - o card 💰 mostra o lançamento "Serviço (guincho / remoção)" e Total R$ 350,00;
   - **Novo valor** → Km excedente, R$ 80,00, com uma nota fiscal → Total R$ 430,00;
   - cancele um dos lançamentos com motivo: fica riscado e sai do total.
3. **Assistência antiga:** abra uma; o card aparece vazio, com "Nenhum valor lançado ainda".
4. **Como funcionário:** lançar e cancelar funcionam igual.

## Commit

```bash
git add -A lib test README.md
git commit -m "Entrega 19a: valores da assistência (valor do serviço na abertura + histórico de lançamentos no detalhe)"
GIT_ASKPASS= git push
```

## Próximo: 19b, relatórios com modelos

"Exportar relatório" nas listas de sinistros e assistências → modelos salvos da corretora → campos por seção + filtros → PDF e Excel. Com ela, o modelo da Águia Branca (mês, veículos, tipos, valores, total) você monta pela tela.
