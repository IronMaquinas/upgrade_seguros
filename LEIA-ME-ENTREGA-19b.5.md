# Entrega 19b.5 — Assistências: barra do topo sem corte

**Base:** GitHub `9e594c2` (Etapa 19b.4).

## O que muda

A área de busca e filtros em **Assistências** tinha 20 px a menos que em **Sinistros** (130/170 × 150/190) e espaçamento 4 × 6. O conteúdo não cabia e apertava a barra de cima: "Exportar relatório" e o botão atualizar ficavam cortados. Agora as medidas são as mesmas de Sinistros.

## Arquivos (2)

| Arquivo | O que mudou |
|---|---|
| `lib/screens/assist_list_screen.dart` | Altura 150 (190 com "Por período") e espaçamento 6, iguais a Sinistros. |
| `README.md` | Histórico 19b.5. |

## Aplicar e publicar (só o app)

```bash
cd ~/Projects/upgrade_seguros
unzip -o ~/Downloads/entrega-19b.5.zip verificar-entrega.js
node verificar-entrega.js --antes        # 2 iguais ao GitHub 9e594c2
unzip -o ~/Downloads/entrega-19b.5.zip 'lib/*' README.md
node verificar-entrega.js --analyze      # ✓ Todos
git diff lib/screens/assist_list_screen.dart
flutter build web
firebase deploy --only hosting
```

## Commit

```bash
git add -A lib README.md
git commit -m "Entrega 19b.5: Assistências com a barra do topo nas medidas de Sinistros"
GIT_ASKPASS= git push
```
