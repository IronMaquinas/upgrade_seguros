# Entrega 28.3 — Beta: "bens segurados do <cliente>" e resposta só com o nome

**Base:** GitHub `f713a86` (Etapa 28.2).

## O que estava errado (seu print)
1. Em "quais os bens segurados do Iury Guaru?", a Beta não reconheceu o nome depois de "bens segurados do" e pediu o cliente.
2. Você respondeu "Iury Guaru Transportes", mas ela tratou essa resposta como uma pergunta nova, sem relação com a anterior.

## O que muda
- O nome do cliente é reconhecido também depois de **bens / bem segurado / segurados / frota / placas / dados / carros / e-mail / celular / fone + "do/da"**.
- Quando a Beta pergunta **"De qual sinistro ou cliente?"**, ela guarda o que você tinha pedido. A resposta só com o **nome** ou o **número** completa esse pedido.
  - Isso só vale quando a resposta é curta (até 6 palavras) e não é outra pergunta. "Qual a previsão do tempo?" continua sendo uma pergunta nova.
- Trechos como "funilaria desse sinistro" não são mais lidos como nome de cliente.
- 4 testes novos (o seu print, inclusive).

## Arquivos (4)
| Arquivo | O que mudou |
|---|---|
| `functions/beta-interpretar.js` | Mais formas de achar o nome; descarta trechos que não são nome. |
| `functions/beta.js` | Resposta curta completa o pedido anterior. |
| `functions/testes/beta.teste.js` | Testes novos. |
| `README.md` | Histórico 28.3. |

## Aplicar e publicar
```bash
cd ~/Projects/upgrade_seguros
unzip -o ~/Downloads/entrega-28.3.zip verificar-entrega.js
node verificar-entrega.js --antes        # 4 iguais ao GitHub f713a86
unzip -o ~/Downloads/entrega-28.3.zip 'functions/*' README.md
node verificar-entrega.js --analyze      # ✓ Todos
firebase deploy --only functions:beta
```
Teste (**⟳ Nova conversa**): "quais os bens segurados do Iury Guaru?". Depois: "qual o veículo?" → (ela pergunta de qual) → "Iury Guaru".

## Commit
```bash
git add -A functions README.md
git commit -m "Entrega 28.3: Beta entende 'bens segurados do <cliente>' e completa a pergunta com a resposta curta"
GIT_ASKPASS= git push
```
