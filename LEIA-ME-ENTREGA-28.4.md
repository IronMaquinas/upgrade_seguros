# Entrega 28.4 — Beta: apólices e bens segurados

**Base:** GitHub `f94aa1f` (Etapa 28.3).

## O que estava errado
A Beta procurava os bens só no cadastro antigo de veículos do cliente. Os bens ficam nas **apólices** (área "Apólices por Ramo"), por isso ela respondia "Não há veículo cadastrado".

## O que muda
A Beta agora lê **todas as apólices do cliente**, de todos os ramos:

| Pergunta (exemplos) | Resposta |
|---|---|
| "O Iury Guaru tem bens segurados?" / "Quais os bens segurados do Iury Guaru?" | Cada bem, com a apólice dele: tipo, marca/modelo, placa, ano, chassi, cavalo/carreta, endereço (residencial), capital (vida). |
| "Iury Guaru tem apólice?" / "Ele tem apólice vigente?" | Apólices por ramo e número: seguradora, vigência (vigente / vence em N dias / vencida), valor e quantos bens. |
| "Quais os bens e apólices Iury Guaru possui?" | Apólices com a lista de bens de cada uma. |
| "Quando vence a apólice do Iury Guaru?" | Vigência de cada apólice, da mais recente para a mais antiga. |
| "Qual o total de gastos da apólice do Iury Guaru?" | Para cada apólice: gasto com sinistros na vigência, quantidade de sinistros, gatilho e % usado. |

O gasto segue a **mesma conta da recomendação do app**:
- só contam sinistros dentro da vigência; os cancelados e negados ficam de fora;
- o sinistro conta na apólice a que está ligado ou, se não estiver ligado a nenhuma, na apólice do mesmo ramo;
- se o gatilho não foi informado, vale o % padrão de Configurações.

Tudo sem IA (regras de texto). A conversa continua: depois de perguntar das apólices, "e os sinistros dele?" usa o mesmo cliente.

## Arquivos (4)
| Arquivo | O que mudou |
|---|---|
| `functions/beta-interpretar.js` | Nova intenção "apólices" (vencimento, gastos, bens); acha "<cliente> tem/possui…". |
| `functions/beta.js` | Bens das apólices; resposta de apólices com vigência, valor, bens e gasto × gatilho. |
| `functions/testes/beta.teste.js` | 10 testes novos (cliente com 2 ramos e 3 apólices, sinistro negado fora da conta). |
| `README.md` | Seção Beta e histórico 28.4. |

## Aplicar e publicar
```bash
cd ~/Projects/upgrade_seguros
unzip -o ~/Downloads/entrega-28.4.zip verificar-entrega.js
node verificar-entrega.js --antes        # 4 iguais ao GitHub f94aa1f
unzip -o ~/Downloads/entrega-28.4.zip 'functions/*' README.md
node verificar-entrega.js --analyze      # ✓ Todos
firebase deploy --only functions:beta
```
Teste com as 6 perguntas da tabela (use **⟳ Nova conversa** entre clientes). Confira o gasto e o % do gatilho com o que aparece no cadastro do cliente (recomendação).

## Commit
```bash
git add -A functions README.md
git commit -m "Entrega 28.4: Beta responde apólices e bens segurados do cadastro"
GIT_ASKPASS= git push
```
