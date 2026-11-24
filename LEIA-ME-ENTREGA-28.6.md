# Entrega 28.6: Beta (inclui a 28.5)

**Base:** GitHub `925a425` (Etapa 28.4). A 28.5 não foi aplicada separadamente: ela já vem dentro desta entrega. Pode descartar o zip da 28.5.

## O que estava errado (seus prints)
1. **"qual sinistro da fibra minas?"** → "fora do escopo". A Beta só entendia o plural ("sinistros da…").
2. **"qual a assistência da Sem Fronteiras?"** → mesmo problema.
3. **"o cliente Sem Fronteiras possui assistência em andamento?"** → respondeu com o sinistro da Fibra Minas, que era o assunto anterior. "Andamento" virava pergunta de status, e o nome do cliente era ignorado porque já havia um sinistro na conversa.
4. (28.5) **"quais os bens segurados da Mais Alimentos?"** → "Não há veículo cadastrado". O cliente tem apólice, mas sem bens cadastrados nela.

## O que muda
- "qual sinistro / qual a assistência / tem sinistro / possui assistência … da <cliente>" é entendido sem IA.
- **O cliente citado na pergunta vale mais que o atendimento da conversa.**
- A lista respeita a pergunta:
  - fala só de assistência → só assistências;
  - fala só de sinistro → só sinistros;
  - "em andamento", "aberto" ou "em curso" → tira Concluído, Cancelado e Negado (a mesma regra do filtro "Em curso" das listas).
- Exemplo: **"SEM FRONTEIRAS: 1 assistência(s) em andamento."**, ou **"… não tem nenhuma assistência em andamento."**
- (28.5) Apólice sem bens: **"MAIS ALIMENTOS LTDA tem 1 apólice(s), mas nenhum bem cadastrado nelas."**, com a lista das apólices.

## Arquivos (4)
- `functions/beta.js`
- `functions/beta-interpretar.js`
- `functions/testes/beta.teste.js` (testes novos da 28.5 e da 28.6)
- `README.md`

## Aplicar e publicar
Só a Function `beta` muda. O app e o portal não precisam ser publicados.
```bash
cd ~/Projects/upgrade_seguros
unzip -o ~/Downloads/entrega-28.6.zip verificar-entrega.js
node verificar-entrega.js --antes        # 4 iguais ao GitHub 925a425
unzip -o ~/Downloads/entrega-28.6.zip 'functions/*' README.md
node verificar-entrega.js --analyze      # ✓ Todos
firebase deploy --only functions:beta
```

## Testar (no app, com flutter run -d chrome)
1. "qual sinistro da fibra minas?" → lista os sinistros da Fibra Minas.
2. "qual a assistência da Sem Fronteiras?" → só as assistências dela.
3. Pergunte o contato de um sinistro de outro cliente. Depois: "o cliente Sem Fronteiras possui assistência em andamento?" → só as assistências **em andamento** da Sem Fronteiras.
4. "quais os bens segurados da mais alimentos?" → a apólice, com o aviso de que não tem bens cadastrados.
5. Confirme que as perguntas antigas continuam funcionando: "e o telefone de contato do segurado?" e "tem ação pendente?".

## Commit
```bash
git add -A functions README.md
git commit -m "Entrega 28.6: Beta entende sinistro/assistência do cliente no singular e em andamento (inclui 28.5)"
GIT_ASKPASS= git push
```
