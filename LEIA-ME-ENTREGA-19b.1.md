# Entrega 19b.1 — Ajustes dos relatórios com modelos

**Base:** GitHub `4323abc` (Etapa 19b).

## O que muda

1. **Botão "Exportar relatório"** nas listas de Sinistros e Assistências. Ele ficava esticado na barra e o texto cortava. Agora é um botão de contorno, centralizado, ao lado do ↻.
2. **Cliente por busca.** A lista suspensa saiu. Agora é só digitar parte do **nome** (sem precisar de acento nem maiúscula) ou do **CNPJ/CPF** (com ou sem pontos):
   - aparecem até 20 sugestões, com **nome + CNPJ** para conferência;
   - o **✕** volta para "Todos os clientes".
3. **Cabeçalho do PDF:**
   - o título diz do que se trata: **Relatório de Sinistros** ou **Relatório de Assistências**;
   - abaixo, o nome do modelo;
   - em destaque, o **cliente: nome · CNPJ/CPF**;
   - depois, a quantidade e o período.
4. **Nome do arquivo** (PDF e Excel): `Corretora - Cliente - Modelo - AAAA-MM-DD`. Exemplo: `Upgrade Seguros - JPC LOG LTDA - Mensal - 2026-11-23.pdf`. Sem cliente escolhido, sai "Todos os clientes".
5. **Fundo branco** nos modais e na tela do modelo, no padrão do app.

## Arquivos (7)

| Arquivo | O que mudou |
|---|---|
| `lib/screens/claim_list_screen.dart`, `assist_list_screen.dart` | Botão centralizado. |
| `lib/widgets/relatorios_modelos.dart` | Busca de cliente, nome do arquivo, fundos brancos. |
| `lib/services/relatorio_atendimentos_pdf.dart` | Título por tipo e cliente no cabeçalho. |
| `lib/utils/relatorio_modelo.dart` | Busca de cliente (nome sem acento ou CNPJ) e nome do arquivo. |
| `test/relatorio_modelo_test.dart` | +4 testes (19 no total). |
| `README.md` | Ajustes e histórico 19b.1. |

## Aplicar e publicar (só o app)

```bash
cd ~/Projects/upgrade_seguros
unzip -o ~/Downloads/entrega-19b.1.zip verificar-entrega.js
node verificar-entrega.js --antes        # 7 iguais ao GitHub 4323abc
unzip -o ~/Downloads/entrega-19b.1.zip 'lib/*' 'test/*' README.md
node verificar-entrega.js --analyze      # ✓ Todos
git diff lib test
flutter build web
firebase deploy --only hosting
```

## Testar

Recarregue (Cmd+Shift+R).
1. **Botão:** "Exportar relatório" aparece inteiro, nas duas listas.
2. **Busca de cliente:** em Exportar, digite "jpc" no campo Cliente.
   - A sugestão mostra o nome e o CNPJ. Escolha.
   - A prévia muda.
   - Teste também com parte do CNPJ.
3. **PDF:**
   - o cabeçalho mostra "Relatório de Sinistros", o nome do modelo e "Cliente: JPC LOG LTDA · CNPJ/CPF …";
   - o arquivo se chama `Upgrade Seguros - JPC LOG LTDA - Teste - 2026-11-23.pdf`.
4. **Fundo branco:** os modais estão brancos.

## Commit

```bash
git add -A lib test README.md
git commit -m "Entrega 19b.1: relatórios — botão na barra, cliente por busca, cabeçalho com tipo e cliente, nome do arquivo, modais brancos"
GIT_ASKPASS= git push
```
