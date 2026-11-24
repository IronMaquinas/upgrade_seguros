# Entrega 26 — Financeiro no portal

**Base:** GitHub `5d19351` (Etapa 25).

## O que muda

**Portal → Financeiro** (novo item no menu, entre Planos e Seguradoras):

- **Números do mês**:
  - **Receita do mês (MRR):** soma do que as corretoras pagantes deveriam pagar hoje pelo plano.
  - **Ticket médio.**
  - **Usuários extras:** a parte do MRR que vem de usuários acima da franquia.
  - **Em atraso:** inadimplentes.
  - **Cortesias:** quanto deixam de pagar.
  - **Potencial dos testes:** quanto entraria se as corretoras em teste, ou que acabaram de testar, contratassem o plano atual.
- **Para acompanhar:**
  - testes que terminam em até 3 dias;
  - testes terminados (estão só leitura — hora de oferecer um plano);
  - cortesias que vencem em 30 dias;
  - inadimplentes.
- **Por corretora:** situação, plano, preço, usuários × franquia, extras, total/mês e "cobrar / cortesia / em teste / não cobra".
- **Copiar tabela:** copia a tabela inteira; é só colar no Excel ou no Planilhas.
- A **Visão geral** ganha o cartão "Receita do mês".

**Como conta:**
- Mensalidade = preço do plano + (usuários − incluídos) × preço por usuário a mais.
- Entra no MRR quem está **Ativa** ou **Inadimplente**, sem cortesia valendo.
- A cortesia vale até a data de fim; sem data, não acaba.
- "Tudo ligado" não tem preço.
- GB e vídeos ainda não entram, porque não há medição (Etapa 27).
- É uma estimativa pelo cadastro: ainda não existe cobrança de verdade (Etapa 28).

**Só o portal muda.** Nada muda no app, nas regras ou nas Functions. Também não é preciso fazer deploy de servidor.

## Arquivos (5)

| Arquivo | O que mudou |
|---|---|
| `lib/admin/financeiro.dart` (novo) | As contas: mensalidade, cobrável, MRR, atraso, cortesias, testes, tabela. |
| `test/financeiro_test.dart` (novo) | 5 testes. |
| `lib/admin/aba_financeiro_portal.dart` (novo) | A tela Financeiro. |
| `lib/admin/portal_app.dart` | Item Financeiro no menu; Receita do mês na Visão geral. |
| `README.md` | Seção Financeiro (Etapa 26) e histórico. |

Ver o que mudou: `git diff lib/admin/portal_app.dart README.md`. Os novos aparecem em `git status`.

## Aplicar e testar localmente

```bash
cd ~/Projects/upgrade_seguros
unzip -o ~/Downloads/entrega-26.zip verificar-entrega.js
node verificar-entrega.js --antes        # 2 iguais ao GitHub 5d19351, 3 novos ainda não existem
unzip -o ~/Downloads/entrega-26.zip 'lib/*' 'test/*' README.md
node verificar-entrega.js --analyze      # ✓ Todos
flutter run -d chrome -t lib/main_admin.dart
```

### Roteiro
1. **Financeiro:** com a Upgrade em "Tudo ligado (cortesia)", a receita do mês fica R$ 0,00 e a Upgrade aparece como "cortesia".
2. Se a corretora de teste da Etapa 25 ainda existir, ela aparece em "Potencial dos testes". Para ver o MRR com valor, ponha essa corretora (**não a Upgrade**) no plano Essencial, Situação **Ativa** e sem cortesia, e volte para Financeiro.
3. **Copiar tabela** → cole numa planilha nova: uma linha por corretora, 11 colunas.

## Publicar (depois de aprovar)

```bash
flutter build web -t lib/main_admin.dart --no-tree-shake-icons
rm -rf build/admin && cp -R build/web build/admin
flutter build web
firebase deploy --only hosting:admin
```
(O app não mudou: o `hosting:app` não é necessário.)

## Commit

```bash
git add -A lib test README.md
git commit -m "Entrega 26: financeiro no portal (receita do mês, atraso, cortesias, testes, tabela)"
GIT_ASKPASS= git push
```
