# Entrega 19b.2 — Exportar: período escolhido antes da prévia

**Base:** GitHub `40d440b` (Etapa 19b.1).

## O que muda (tela "Exportar")

1. **Abre sem período escolhido.** Antes já vinha marcado "Mês atual", e a faixa azul aparecia antes de qualquer escolha. Agora:
   - aparece "Escolha o período para ver a prévia e exportar.";
   - os botões **PDF** e **Excel** só ativam depois que o período é escolhido;
   - a faixa azul virou **"Prévia: …"** e só mostra o **valor total** se o modelo tiver o campo "Valor total".
2. **"Data de referência"** (sinistros) ganhou bloco próprio, com título e espaço. Antes ficava colada nos botões do período.

## Arquivos (2)

| Arquivo | O que mudou |
|---|---|
| `lib/widgets/relatorios_modelos.dart` | Os dois ajustes acima. |
| `README.md` | Histórico 19b.2. |

## Aplicar e publicar (só o app)

```bash
cd ~/Projects/upgrade_seguros
unzip -o ~/Downloads/entrega-19b.2.zip verificar-entrega.js
node verificar-entrega.js --antes        # 2 iguais ao GitHub 40d440b
unzip -o ~/Downloads/entrega-19b.2.zip 'lib/*' README.md
node verificar-entrega.js --analyze      # ✓ Todos
git diff lib/widgets/relatorios_modelos.dart
flutter build web
firebase deploy --only hosting
```

## Commit

```bash
git add -A lib README.md
git commit -m "Entrega 19b.2: exportar sem período pré-escolhido; data de referência com espaço"
GIT_ASKPASS= git push
```
