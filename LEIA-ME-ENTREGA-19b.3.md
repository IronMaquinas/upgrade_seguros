# Entrega 19b.3 — Exportar: por cliente ou por seguradora

**Base:** GitHub `f3b6d57` (Etapa 19b.2).

## O que muda (tela "Exportar")

1. **"Relatório por": Cliente | Seguradora** (no topo).
   - **Cliente:** digita o nome ou CNPJ e o relatório traz tudo dele, de **todas as seguradoras** (frota numa, vida noutra…).
   - **Seguradora:** escolhe na lista e o relatório traz **todos os clientes** daquela seguradora (acompanhamento pedido pela seguradora).
   - Os botões PDF/Excel só ativam com **quem** (cliente ou seguradora) **e** o **período** escolhidos. Enquanto faltar algo, a tela diz o quê.
2. **Período sempre pela data da ocorrência.** O bloco "Data de referência" saiu. Quem quiser a data de abertura coloca a coluna "Abertura" no modelo.
3. **Saiu "Tipo de ocorrência"** (os dados já são só sinistros, ou só assistências).
4. **Novo filtro "Ramo"** (Frota, Veículo Individual, Residencial, Vida…), com nenhum marcado = todos. Aparece só quando o cliente ou a seguradora tem mais de um ramo. Nas assistências: Veículo / Residencial.
   - Ramo e Status mostram só as opções que existem para o cliente ou a seguradora escolhida.
5. **Seguradoras parecidas aparecem uma vez só na lista** (CHUBB = Chubb, AXA = AXA SEGUROS, EZZE = Ezze Seguros) e o filtro pega todas as grafias.
   - Erros de digitação (ex.: "AXA SEGURUROS", "EZZER") continuam separados. A limpeza de verdade entrou como pendência no README.
6. **PDF:** no recorte por seguradora, o cabeçalho mostra "Seguradora: X" e o nome do arquivo leva a seguradora no lugar do cliente.

## Arquivos (6)

| Arquivo | O que mudou |
|---|---|
| `lib/widgets/relatorios_modelos.dart` | Tela Exportar (itens 1–5). |
| `lib/utils/relatorio_modelo.dart` | Filtro: sempre pela ocorrência; seguradora por grafia agrupada; ramo; nome do arquivo com a seguradora. |
| `lib/services/relatorio_atendimentos.dart` | Ramo de cada sinistro/assistência no relatório. |
| `lib/services/relatorio_atendimentos_pdf.dart` | Linha "Seguradora: X" no cabeçalho. |
| `test/relatorio_modelo_test.dart` | Testes novos: ocorrência, grafias de seguradora, ramo, nome do arquivo (24 ✓). |
| `README.md` | Histórico 19b.3 + pendência **Seguradoras duplicadas**. |

## Aplicar e publicar (só o app)

```bash
cd ~/Projects/upgrade_seguros
unzip -o ~/Downloads/entrega-19b.3.zip verificar-entrega.js
node verificar-entrega.js --antes        # 6 iguais ao GitHub f3b6d57
unzip -o ~/Downloads/entrega-19b.3.zip 'lib/*' 'test/*' README.md
node verificar-entrega.js --analyze      # ✓ Todos
git diff --stat
git diff lib/widgets/relatorios_modelos.dart
flutter build web
firebase deploy --only hosting
```

## Commit

```bash
git add -A lib test README.md
git commit -m "Entrega 19b.3: exportar por cliente ou seguradora, filtro por ramo, sempre pela ocorrência"
GIT_ASKPASS= git push
```
