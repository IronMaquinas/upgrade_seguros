# Entrega 19b.4 — Ramo e nº do registro em evidência

**Base:** GitHub `cf944a4` (Etapa 19b.3).

## O que muda

1. **Detalhe do sinistro:**
   - O **ramo** aparece colorido ao lado do status (Frota, Veículo Individual, Civil Ônibus (RCO), Residencial…).
   - No canto direito do topo fica o **nosso nº de registro** (SN…), com o botão **copiar**.
2. **Detalhe da assistência:** a linha "Número" virou o mesmo quadro do nº, com **copiar**, e ganhou o ramo (**Veículo** / **Residencial**).
3. **Exportar:** os filtros **Ramo** e **Status** agora sempre aparecem.
   - Antes ficavam escondidos quando o cliente tinha um ramo só (ex.: JPC LOG, só Frota), e parecia que não havia sinistros.

> Para o **ramo sair no PDF/Excel**, inclua a coluna **"Ramo"** (seção *Ocorrência*) no modelo: "Editar modelo" → marcar "Ramo".

## Arquivos (5)

| Arquivo | O que mudou |
|---|---|
| `lib/widgets/identificacao_atendimento.dart` | **Novo.** `RamoChip` (ramo com ícone e cor) e `NumeroRegistro` (nº + copiar). |
| `lib/screens/claim_detail_screen.dart` | Topo do card: status + ramo; nº do registro à direita. |
| `lib/screens/assist_detail_screen.dart` | "Número" com copiar + ramo. |
| `lib/widgets/relatorios_modelos.dart` | Ramo/Status sempre visíveis no Exportar. |
| `README.md` | Histórico 19b.4. |

## Aplicar e publicar (só o app)

```bash
cd ~/Projects/upgrade_seguros
unzip -o ~/Downloads/entrega-19b.4.zip verificar-entrega.js
node verificar-entrega.js --antes        # 4 iguais ao GitHub cf944a4 + 1 novo
unzip -o ~/Downloads/entrega-19b.4.zip 'lib/*' README.md
node verificar-entrega.js --analyze      # ✓ Todos
git diff --stat
git diff lib/screens/claim_detail_screen.dart lib/screens/assist_detail_screen.dart
flutter build web
firebase deploy --only hosting
```

## Commit

```bash
git add -A lib README.md
git commit -m "Entrega 19b.4: ramo e nº do registro em evidência no detalhe; filtros sempre visíveis no exportar"
GIT_ASKPASS= git push
```
