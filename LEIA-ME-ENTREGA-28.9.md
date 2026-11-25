# Entrega 28.9: Beta e as pessoas do sinistro

**Base:** GitHub `fd68237` (Etapa 28.8).

## O que estava errado (seu print)
"qual o nome do condutor do SN20261124180447?" listou todos os sinistros da Lube. A frase não tinha nenhuma palavra que eu usava para reconhecer um pedido de contato (telefone, contato, WhatsApp…). A pergunta foi para a IA, e a IA errou.

## O que muda: as 3 perguntas de cada lado
Pergunta sobre condutor, motorista, proprietário, dono ou contato vai direto para a pessoa certa, sem passar pela IA.

| Lado | Pergunta | De onde vem |
|---|---|---|
| Segurado | proprietário do veículo | Proprietário legal (CRLV): nome, CPF/CNPJ e placa. Se for o próprio segurado (mesmo CPF/CNPJ), mostra o telefone e o e-mail do cadastro |
| Segurado | condutor do veículo | Motorista: nome, CPF e CNH |
| Segurado | contato do sinistro | Contato do sinistro: nome e telefone |
| Terceiro | proprietário do veículo do terceiro | nome, CPF/CNPJ, telefone, e-mail e placa |
| Terceiro | condutor do veículo do terceiro | nome, CPF, CNH, telefone e e-mail (ou o próprio proprietário, se marcado assim) |
| Terceiro | contato do sinistro do terceiro | nome e telefone |

- Campo não preenchido → **"Não há essa informação neste sinistro."**
- Sinistro sem terceiros → **"Não houve terceiros neste sinistro."**
- O cadastro do sinistro não tem telefone para o proprietário nem para o condutor do segurado. Nesses casos a Beta avisa: "Sem telefone ou e-mail cadastrados para esta pessoa no sinistro."

## Arquivos (4)
- `functions/beta.js`
- `functions/beta-interpretar.js`
- `functions/testes/beta.teste.js` (o sinistro da Lube do print, com as 6 perguntas)
- `README.md`

## Aplicar e publicar
```bash
cd ~/Projects/upgrade_seguros
unzip -o ~/Downloads/entrega-28.9.zip verificar-entrega.js
node verificar-entrega.js --antes        # 4 iguais ao GitHub fd68237
unzip -o ~/Downloads/entrega-28.9.zip 'functions/*' README.md
node verificar-entrega.js --analyze      # ✓ Todos
firebase deploy --only functions:beta
```

## Testar (no SN20261124180447 da Lube e num sinistro com terceiro)
1. "qual o nome do condutor do SN20261124180447?" → RAPHAEL RIBEIRO ERPES, com CPF e CNH.
2. "e o proprietário do veículo?" → L LOG TRANSPORTES E SERVICOS LTDA., com o CNPJ.
3. "qual o contato para o sinistro?" → o contato, ou "Não há essa informação neste sinistro."
4. "e o condutor do veículo do terceiro?" → "Não houve terceiros neste sinistro." (se a Lube não tiver terceiros)
5. Num sinistro com terceiro, faça as 3 perguntas do lado do terceiro.

## Commit
```bash
git add -A functions README.md
git commit -m "Entrega 28.9: Beta responde proprietário, condutor e contato do sinistro (segurado e terceiro)"
GIT_ASKPASS= git push
```
