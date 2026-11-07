# Entrega 06 — 🟠 Botão "Nova Assistência" de volta + 🧹 limpeza do git

**Base:** GitHub `c489e4b` (Etapas 01–05). Só o app e o `.gitignore`. Sem Firestore e sem migração.

## O que muda

**1. Botão laranja "Nova Assistência" na lista de Assistências**
- Fica no canto inferior direito, como o "Novo Sinistro" da lista de Sinistros, na cor laranja das assistências.
- Abre o **mesmo modal "Tipo de Assistência" do Dashboard**: 🟠 Veicular / 🟣 Residencial → abre a planilha da assistência. Ao salvar e voltar, a lista se atualiza.
- O modal virou **um componente só** (`assist_tipo_picker.dart`), usado pelo Dashboard e pela lista. Mudou num, muda no outro.
- O que tinha acontecido: a função que abria o modal continuava no código, mas **nada a chamava**. O botão tinha sido removido (o analisador confirmou isso).

**2. Correção no Dashboard:** em "Novo Registro → Assistência", o botão **Cancelar** desse modal dava *dois* "voltar". No Android, isso podia fechar o app. Agora fecha só o modal. O botão **Voltar** continua reabrindo "Novo Registro".

**3. Limpeza do git (item S7 do README):** `node_modules/` (≈15 mil arquivos) e `android/build/` (cache do Xcode/Flutter, que subiu no commit `535f7bd`) **saem do repositório**. Os arquivos continuam no seu computador: o app e o build não mudam em nada. O repositório fica leve e o `git diff` fica legível.

## Arquivos

| Arquivo | Novo? | O que mudou e por quê |
|---|---|---|
| `lib/widgets/assist_tipo_picker.dart` | **novo** | Modal padrão "Tipo de Assistência" (`mostrarSeletorTipoAssistencia`) + cor padrão `corAssistencia`. Visual idêntico ao que o Dashboard já usava. |
| `lib/screens/assist_list_screen.dart` | alterado | Botão "Nova Assistência" (laranja). O seletor passa a usar o modal padrão. Removido um import que sobrou. |
| `lib/screens/dashboard_screen.dart` | alterado | O modal "Tipo de Assistência" (~130 linhas) foi trocado pela chamada ao componente. "Cancelar" fecha só o modal. |
| `.gitignore` | alterado | + `node_modules/` e `android/build/` no final. |
| `README.md` | alterado | S7 concluído, componente do modal, histórico. |
| `verificar-entrega.js` | — | md5 da Etapa 06 + aviso se `node_modules/` ou `android/build/` ainda estiverem no git. |

## Aplicar (Terminal, na raiz do projeto)

```bash
cd /Users/marcony/Projects/upgrade_seguros

unzip -o ~/Downloads/entrega-06.zip verificar-entrega.js -d .
node verificar-entrega.js --antes        # "✓ Os 5 arquivos são a base esperada"

unzip -o ~/Downloads/entrega-06.zip 'lib/*' README.md .gitignore -d .
node verificar-entrega.js --analyze      # vai avisar que node_modules/ e android/build/ ainda estão no git (normal até o passo seguinte)
```

**Tirar do git (os arquivos ficam no computador):**
```bash
git rm -r --cached --quiet node_modules android/build
node verificar-entrega.js                # agora sem o aviso; tem que terminar em "✓ Todos"
```

## Revisar antes do commit

```bash
git --no-pager diff --cached --stat | tail -3   # ~15 mil arquivos "deleted": é a saída do node_modules/android/build do git
git --no-pager diff lib/screens/assist_list_screen.dart
git --no-pager diff lib/screens/dashboard_screen.dart
git --no-pager diff .gitignore
ls node_modules | head -3                        # continuam no disco
```

## Roteiro de teste
1. **Assistências:** o botão laranja "Nova Assistência" aparece no canto inferior direito.
2. Clique nele: abre o modal "Tipo de Assistência" (Veicular / Residencial), igual ao do Dashboard. **Veicular** abre a planilha veicular, e **Residencial** abre a residencial.
3. Salve uma assistência e volte: ela aparece na lista (filtro Em curso).
4. **Cancelar** no modal fecha só o modal.
5. **Dashboard → Novo Registro → Assistência:** o mesmo modal. **Voltar** reabre "Novo Registro". **Cancelar** fecha só o modal e o app continua aberto.
6. `flutter run` / build continuam funcionando (o `node_modules` segue no disco).

## Subir

```bash
git add lib/widgets/assist_tipo_picker.dart
git add -u
git commit -m "Etapa 06: botão Nova Assistência com modal padrão; node_modules e android/build fora do git"
GIT_ASKPASS= git push
```
Este push é rápido, porque a remoção do git não envia arquivos.

## Como foi testado aqui
- Análise antes × depois do projeto inteiro: zero erro ou aviso novo.
- Simulação no clone do GitHub: `--antes` ok, cópia, `git rm --cached`, "✓ Todos".
