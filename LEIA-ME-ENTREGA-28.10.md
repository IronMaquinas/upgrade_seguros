# Entrega 28.10: "contato do sinistro da <cliente>"

**Base:** GitHub `f1cfd20` (Etapa 28.9).

## O que estava errado (seu print)
"qual o telefone de contato do sinistro da GMC?" → **"Não achei cliente com 'contato'"**. Eu tomava como nome do cliente o primeiro trecho depois de "telefone de". Sobrava "contato", e a Beta procurava um cliente com esse nome.

## O que muda
- Em "… do sinistro da X" (ou da assistência), o cliente é o **X**.
- Pessoa do sinistro (contato do sinistro, proprietário, condutor, terceiros) pedida pelo **nome do cliente**, sem número:
  - **um** sinistro/assistência em andamento → a Beta responde direto com aquele (e a conversa continua nele: "e o condutor?");
  - **vários** em andamento → o mesmo dado de cada um, com o número e o botão para abrir;
  - **nenhum** em andamento → avisa e pede o número, para consultar um encerrado.
- "quem é o condutor do sinistro da lube?" não vira mais lista de sinistros.

## Arquivos (4)
- `functions/beta.js`
- `functions/beta-interpretar.js`
- `functions/testes/beta.teste.js` (o sinistro da GMC do print e a Lube com dois em andamento)
- `README.md`

## Aplicar e publicar
```bash
cd ~/Projects/upgrade_seguros
unzip -o ~/Downloads/entrega-28.10.zip verificar-entrega.js
node verificar-entrega.js --antes        # 4 iguais ao GitHub f1cfd20
unzip -o ~/Downloads/entrega-28.10.zip 'functions/*' README.md
node verificar-entrega.js --analyze      # ✓ Todos
firebase deploy --only functions:beta
```

## Testar
1. "qual o telefone de contato do sinistro da GMC?" → GUSTAVO MOULÃO, (88) 9217-3750 (se a GMC tiver só esse sinistro em andamento).
2. "e o condutor?" → LEONCIO DE CASTRO DRIUSSO.
3. "quem é o condutor do sinistro da lube?" → o condutor de cada sinistro em andamento da Lube, com o número.

## Commit
```bash
git add -A functions README.md
git commit -m "Entrega 28.10: Beta acha o cliente em 'contato do sinistro da X' e usa os sinistros em andamento dele"
GIT_ASKPASS= git push
```
