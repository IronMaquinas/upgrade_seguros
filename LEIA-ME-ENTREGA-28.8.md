# Entrega 28.8: Beta não "esquece" o cliente na conversa

**Base:** GitHub `8e02a6c` (Etapa 28.7).

## O que estava errado (seu print)
"qual o telefone de contato da pluma real?" respondeu certo, mas em seguida **"e possui apólice vigente?"** recebeu "De qual sinistro ou cliente?".

**Causa:** o app grava dentro do documento do cliente um campo `id`, que fica vazio em muitos cadastros, porque o cliente é salvo antes de o Firestore gerar o código do documento. A Beta juntava o código do documento com os campos, e o `id` vazio sobrescrevia o código verdadeiro. A conversa guardava "cliente = vazio" e a pergunta seguinte ficava sem cliente. Foi o mesmo motivo do "nenhuma assistência" da 28.6: a busca por `id_cliente` usava o código vazio.

## O que muda
Em toda a Beta, o código do documento passa a valer mais que qualquer campo `id` gravado dentro dele, tanto no cliente quanto no atendimento. Nada muda no banco.

## Arquivos (3)
- `functions/beta.js`
- `functions/testes/beta.teste.js` (cliente com `id: ''`, igual ao seu banco, e a conversa do print)
- `README.md`

## Aplicar e publicar
```bash
cd ~/Projects/upgrade_seguros
unzip -o ~/Downloads/entrega-28.8.zip verificar-entrega.js
node verificar-entrega.js --antes        # 3 iguais ao GitHub 8e02a6c
unzip -o ~/Downloads/entrega-28.8.zip 'functions/*' README.md
node verificar-entrega.js --analyze      # ✓ Todos
firebase deploy --only functions:beta
```

## Testar
1. "qual o telefone de contato da pluma real?" → contato.
2. "e possui apólice vigente?" → Frota • 0531 13 9133962, Porto Seguro, vigente.
3. "e as assistências dele?" → AS20261008122926.

## Commit
```bash
git add -A functions README.md
git commit -m "Entrega 28.8: Beta usa o id do documento (o campo id gravado no cliente pode estar vazio)"
GIT_ASKPASS= git push
```
