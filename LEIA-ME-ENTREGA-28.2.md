# Entrega 28.2 — Beta: "bem segurado que ele tem"

**Base:** GitHub `9465f17` (Etapa 28.1).

## O que estava errado
Em "qual o bem segurado que ele tem?", a Beta leu "segurado que ele tem" como **"cliente chamado 'que ele tem'"**.

## O que muda
- **"Bem segurado", "bens" e "frota"** passam a ser entendidos como **veículo**. Para um cliente, ela lista os veículos segurados do cadastro.
- **"Ele", "dele", "que ele tem", "desse cliente", "esse"…** não viram mais nome de cliente: a Beta usa o cliente ou sinistro da conversa.
- 4 testes novos, incluindo a conversa do seu print.

## Arquivos (3)
| Arquivo | O que mudou |
|---|---|
| `functions/beta-interpretar.js` | "bem segurado"/"frota" = veículo; pronomes = assunto da conversa. |
| `functions/testes/beta.teste.js` | Testes novos. |
| `README.md` | Histórico 28.2. |

## Aplicar e publicar
```bash
cd ~/Projects/upgrade_seguros
unzip -o ~/Downloads/entrega-28.2.zip verificar-entrega.js
node verificar-entrega.js --antes        # 3 iguais ao GitHub 9465f17
unzip -o ~/Downloads/entrega-28.2.zip 'functions/*' README.md
node verificar-entrega.js --analyze      # ✓ Todos
firebase deploy --only functions:beta
```
Teste (**⟳ Nova conversa**): "qual o telefone do Iury Guaru?" → "qual o bem segurado que ele tem?" → "e os sinistros dele?"

## Commit
```bash
git add -A functions README.md
git commit -m "Entrega 28.2: Beta entende 'bem segurado' e 'ele/dele' pela conversa"
GIT_ASKPASS= git push
```
