# Entrega 28.12: Beta responde quem abriu o atendimento / com quem ele está

**Base:** GitHub `854c491` (Etapa 28.11).

## Perguntas novas (sinistro ou assistência)
- "Quem é o dono do sinistro SN…?"
- "Quem abriu o sinistro SN…?" / "quem abriu a assistência AS…?"
- "Com quem está o sinistro SN…?"
- "quem é o responsável pelo sinistro da Lube?" (pelo cliente → os em andamento dele)
- "e quem abriu?" (continuação da conversa)

A resposta traz o **nome, o telefone e o e-mail** do usuário, com os botões Ligar, WhatsApp e E-mail.

## De onde vem
- `responsavel_id` do sinistro/assistência: o usuário que abriu. É o mesmo campo do "Filtrar por Funcionário" das listas.
- Os dados vêm de `users/{id}`, que fica na raiz, fora da corretora.
- **Separação por corretora:** o usuário só aparece se `users/{id}.empresaId` for a corretora de quem pergunta. Se não for, a resposta é "Não há usuário responsável registrado neste atendimento.". Um usuário de outra corretora nunca aparece.
- Atendimento sem `responsavel_id` → procura pelo `responsavel_email`, também só dentro da corretora.

"Dono **do veículo**" continua sendo o proprietário (CRLV); só "dono **do sinistro/da assistência**" é o responsável.

## Arquivos (4)
- `functions/beta.js`
- `functions/beta-interpretar.js`
- `functions/testes/beta.teste.js` (inclui um usuário de outra corretora, que não pode aparecer)
- `README.md`

## Aplicar e publicar
```bash
cd ~/Projects/upgrade_seguros
unzip -o ~/Downloads/entrega-28.12.zip verificar-entrega.js
node verificar-entrega.js --antes        # 4 iguais ao GitHub 854c491
unzip -o ~/Downloads/entrega-28.12.zip 'functions/*' README.md
node verificar-entrega.js --analyze      # ✓ Todos
firebase deploy --only functions:beta
```

## Testar
1. "Quem abriu o sinistro SN20261113173311?" → Alessandra, 27999520770, sinistro01@upgradeseguros.com.br.
2. "Com quem está o sinistro SN20261023101604?" → o responsável desse.
3. "quem abriu a assistência AS…?" → numa assistência.
4. "e o condutor?" e depois "e quem abriu?" → as duas respostas no mesmo sinistro.

## Commit
```bash
git add -A functions README.md
git commit -m "Entrega 28.12: Beta responde quem abriu / com quem está o sinistro ou a assistência"
GIT_ASKPASS= git push
```
