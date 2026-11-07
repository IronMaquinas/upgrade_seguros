# Entrega 01 — 📄 README reorganizado + pendências de segurança no plano

**Base:** origin/main `fdb7ce6`. Sem mudança de código (nenhum `.dart` ou `.js`). Sem deploy.

## O que vem no zip

| Arquivo | Vai para | O que mudou e por quê |
|---|---|---|
| `README.md` | raiz do projeto (substitui) | **Unificado:** o README antigo tinha quase tudo duas vezes (Stack, Navegação, Tipos, Fluxos, SLA, Dashboard, Relatórios, Dados…). Ficou uma cópia só, a mais completa; os detalhes que só existiam na primeira cópia foram mantidos ("Distribuição por status" e "Funil de etapas" nos relatórios, conferidos no código; redação completa dos itens do roadmap). **Novas seções:** Índice; Estrutura do Código (`lib/`); Cloud Function do Telegram na tabela de Functions; 🔐 Pendências de Segurança (S1–S7); ⚠️ Armadilhas Conhecidas; 🧪 Processo de Entrega e Verificação; 📦 Histórico de Entregas; Roadmap com as fases "Segurança" e "Expansão Europa". "Melhorias Recentes (Sessão Atual)" virou "Melhorias Anteriores (antes da Etapa 01)". |
| `.gitignore` | raiz do projeto (substitui) | Acrescenta 3 linhas no final: `verificar-entrega.js` fica fora do git (não sobe para o GitHub). Nada mais muda. |
| `verificar-entrega.js` | raiz do projeto, ao lado do `pubspec.yaml` | Já com os md5 desta etapa. **Não vai para o git.** |

> **Sobre o README ser público:** como o repositório está público, as pendências de segurança estão descritas de forma resumida, sem detalhes de como explorar.

## Aplicar (Terminal)

O `.gitignore` começa com ponto, então o Finder o esconde. Use o Terminal:

```bash
cd /Users/marcony/Projects/upgrade_seguros

# 1. o verificador primeiro (é ele que confere a base)
unzip -o ~/Downloads/entrega-01.zip verificar-entrega.js -d .
node verificar-entrega.js --antes        # tem que dar "✓ Os 2 arquivos são a base esperada"

# 2. copiar a entrega
unzip -o ~/Downloads/entrega-01.zip README.md .gitignore -d .

# 3. conferir
node verificar-entrega.js                # tem que dar "✓ Todos os 2 arquivos…"
```

Se o `--antes` der ✗, **pare** e me mande o arquivo que divergiu.

## O que o verificador vai mostrar (esperado)

Os dois avisos ⚠️ abaixo são pendências que já existiam e estão no plano. Não bloqueiam esta etapa:
- `latlong2` importado sem estar no `pubspec.yaml` (armadilha registrada; corrige quando uma etapa mexer em `workshop_widget.dart`).
- Token do Telegram no git (pendência **S1**; o aviso some quando você fizer os passos do README).

## Revisar antes do commit

```bash
git --no-pager diff --stat          # deve listar só README.md e .gitignore
git --no-pager diff .gitignore      # as 3 linhas novas
git status                          # verificar-entrega.js NÃO pode aparecer
```

Para ler o README, abra no VS Code com a pré-visualização (`Cmd+Shift+V`) ou veja no GitHub depois do push.

## Subir

```bash
git add README.md .gitignore
git commit -m "Etapa 01: README reorganizado, pendências de segurança e processo de entrega"
git push
```

## Testar
1. `node verificar-entrega.js` termina em "✓ Todos".
2. `git status` não mostra o `verificar-entrega.js`.
3. No GitHub, o README abre com o Índice e os links do Índice levam às seções.
