# Entrega 05 — 🔎 Filtro "Em curso" / "Todos" nas listas + carregamento rápido

**Base:** GitHub `2c48c4c` (Etapas 01–04). Só o app. Sem migração, **sem índice novo no Firestore**.

## O que muda (Sinistros e Assistências, mesma regra)

| Opção do filtro de status | Mostra |
|---|---|
| **Em curso** ← padrão ao abrir | Tudo que não está finalizado. **Sinistros:** Rascunho, Aberto, Vistoria em Andamento, Aguardando Aprovação, Aguardando Peças, Reparo em Andamento. **Assistências:** Aberto, Em Andamento, Aguardando Cliente |
| **Todos** | **Todos mesmo**, inclusive Concluído e Cancelado |
| Cada status | Só ele |

- O **"Todos" duplicado** dos Sinistros sumiu. O primeiro "Todos" era, na verdade, "tudo menos Concluído", e agora se chama **Em curso**.
- O "Todos" das Assistências escondia os Concluídos. Agora mostra tudo.
- **Carregamento:** a lista abre buscando no banco **só o que está em curso**. Sinistros e assistências encerrados nem são baixados, então a abertura continua rápida mesmo com milhares de registros. Ao escolher **Todos**, **Concluído** ou **Cancelado**, aparece "Carregando histórico…" uma vez, e depois a troca de filtro é instantânea enquanto a tela estiver aberta.
- Os atalhos do Dashboard (ramo, SLA em risco/vencido) e os demais filtros (período, tipo, oficina, funcionário, busca) continuam iguais. Eles agem sobre o que estiver carregado.
- Em Assistências, a lista deixou de baixar todos os sinistros junto. No modo "Em curso" ela só traz o que está em curso.

## Arquivos

| Arquivo | Novo? | O que mudou e por quê |
|---|---|---|
| `lib/utils/filtro_status.dart` | **novo** | Regra única: o que é "Em curso", o que é "Todos", quais status são finalizados (`Concluído`, `Cancelado`, `Negado`) e quando é preciso baixar o histórico. As duas telas usam esta mesma regra, então nunca ficam diferentes. |
| `test/filtro_status_test.dart` | **novo** | 5 testes da regra acima (rodados aqui com sucesso). |
| `lib/services/firestore_service.dart` | alterado | + `getSinistrosEmCurso()` e `getAllClaimsEmCurso()`: buscam no Firestore com `status_atual not-in [finalizados]`, sem `orderBy` (por isso não precisa de índice composto). A ordenação, mais recente primeiro, é feita no app. Nada existente mudou. |
| `lib/screens/claim_list_screen.dart` | alterado | Filtro: Em curso / Todos / cada status. Carrega só em curso e busca o histórico quando o filtro pede. Aviso "Carregando histórico…". Removida a regra antiga que escondia só Concluído. |
| `lib/screens/assist_list_screen.dart` | alterado | O mesmo, para Assistências. |
| `README.md` | alterado | Seção "Listas — filtro de status 'Em curso'", armadilhas, histórico, roadmap (totais pré-calculados para Dashboard/Relatórios). |
| `verificar-entrega.js` | — | md5 da Etapa 05. |

## Aplicar (Terminal, na raiz do projeto)

```bash
cd /Users/marcony/Projects/upgrade_seguros

unzip -o ~/Downloads/entrega-05.zip verificar-entrega.js -d .
node verificar-entrega.js --antes        # "✓ Os 6 arquivos são a base esperada"

unzip -o ~/Downloads/entrega-05.zip 'lib/*' 'test/*' README.md -d .
node verificar-entrega.js --analyze      # tem que terminar em "✓ Todos" (inclui os testes)
```

## Revisar antes do commit

```bash
git --no-pager diff --stat
git --no-pager diff lib/services/firestore_service.dart     # só as 2 consultas novas
git --no-pager diff lib/screens/claim_list_screen.dart
git --no-pager diff lib/screens/assist_list_screen.dart
```

## Roteiro de teste
1. **Sinistros:** abre com o filtro em **Em curso**. Não aparece nenhum Concluído, e os Rascunhos aparecem.
2. Abra o filtro: só existe **um** "Todos". Escolha **Todos**: aparece "Carregando histórico…" e depois os Concluídos entram na lista.
3. Volte para **Em curso** e depois para **Concluído**: a troca é instantânea (o histórico já está em memória).
4. **Assistências:** abre em **Em curso**, sem Concluídos e sem Cancelados. **Todos** mostra tudo. **Cancelado** mostra só os cancelados.
5. Atalho do Dashboard (card de um ramo, ou SLA Em Risco/Vencidos): a lista abre filtrada como antes.
6. Crie um sinistro novo e volte para a lista: ele aparece em **Em curso**.

## Subir

```bash
git add lib/utils/filtro_status.dart test/filtro_status_test.dart
git add -u
git commit -m "Etapa 05: filtro Em curso/Todos nas listas e carregamento só do que está em curso"
GIT_ASKPASS= git push
```

## Como foi testado aqui
- Análise antes × depois do projeto inteiro: zero erro ou aviso novo. A consulta `whereNotIn` foi conferida contra o `cloud_firestore` 5.6.12 do seu `pubspec.lock`.
- 5 testes novos + 11 da Etapa 02 passando.
- **Atenção a um detalhe:** a consulta "em curso" não traz registros que não têm o campo `status_atual`. Todo registro gravado pelo app tem esse campo. Se existir algum muito antigo ou importado sem ele, ele só aparece em **Todos**.
