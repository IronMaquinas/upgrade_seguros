# Entrega 28.7: Beta acha as assistências que existem

**Base:** GitHub `3b93951` (Etapa 28.6, já aplicada por você).

## O que estava errado (seu print)
1. **"Sem Fronteiras possui assistência aberta?"** e **"pluma real possui assistência em andamento?"** → "nenhuma", mas a AS20261022102913 e a AS20261008122926 estão abertas na tela. A Beta procurava só pelo vínculo interno com o cliente (id). Registros mais antigos podem ter outro vínculo, e a tela de Assistências não usa esse campo, por isso mostrava.
2. **"Sem fronteiras está com assistência em andamento?"** → "De qual sinistro ou cliente?". "está com" não era reconhecido.
3. Em seguida, a resposta **"sem fronteiras"** fez a Beta pedir o número de novo, porque a pergunta pendente era de status.

## O que muda
- O sinistro ou a assistência é procurado pelo **vínculo do cliente, pelo CNPJ/CPF e pelo nome** gravados no atendimento, sem repetir resultados.
- "está com", "tem algum" e "possui alguma" assistência/sinistro são reconhecidos.
- **Pergunta de status ou pendência com o nome de um cliente** (em vez de um número) lista os atendimentos em andamento dele, em vez de pedir o número.

## Arquivos (4)
- `functions/beta.js`
- `functions/beta-interpretar.js`
- `functions/testes/beta.teste.js` (o seu print virou teste)
- `README.md`

## Aplicar e publicar
Só a Function `beta` muda.
```bash
cd ~/Projects/upgrade_seguros
unzip -o ~/Downloads/entrega-28.7.zip verificar-entrega.js
node verificar-entrega.js --antes        # 4 iguais ao GitHub 3b93951
unzip -o ~/Downloads/entrega-28.7.zip 'functions/*' README.md
node verificar-entrega.js --analyze      # ✓ Todos
firebase deploy --only functions:beta
```

## Testar
1. "Sem Fronteiras possui assistência aberta?" → AS20261022102913.
2. "pluma real possui assistência em andamento?" → AS20261008122926.
3. "Sem fronteiras está com assistência em andamento?" → a mesma assistência do teste 1.
4. "qual a situação?" e depois só "sem fronteiras" → os atendimentos em andamento dela.

Se algum destes ainda vier "nenhuma", me mande um print da assistência aberta (a tela de detalhe com o nome do cliente) para eu conferir como ela está ligada ao cliente.

## Commit
```bash
git add -A functions README.md
git commit -m "Entrega 28.7: Beta acha atendimentos do cliente também por CNPJ/nome; status com nome de cliente"
GIT_ASKPASS= git push
```
