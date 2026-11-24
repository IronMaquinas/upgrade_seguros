# Entrega 28.1 — Beta: "telefone de contato do <cliente>"

**Base:** GitHub `1e9f3a2` (Etapa 28).

## O que estava errado
Em "qual o telefone de contato do iury guaru", a Beta pegava **"contato do iury guaru"** como se fosse o nome do cliente e não achava ninguém.

## O que muda
- As palavras da própria pergunta ("contato do", "cliente", "segurado", "telefone"…) são retiradas antes de procurar o nome, em dois lugares: ao entender a pergunta e na busca do cliente.
- "Telefone de contato do X" agora é entendido como **contato do segurado/cliente**: mostra o nome do contato e o telefone do cadastro, com Ligar e WhatsApp.
- "e os sinistros dele?" passa a ser entendido sem IA, usando o cliente da conversa.
- 5 testes novos, incluindo a pergunta do seu print.

## Arquivos (4)
| Arquivo | O que mudou |
|---|---|
| `functions/beta-interpretar.js` | Limpa o nome; "telefone de contato" = contato do segurado. |
| `functions/beta.js` | A busca por nome ignora as palavras da pergunta. |
| `functions/testes/beta.teste.js` | Testes novos. |
| `README.md` | Histórico 28.1. |

## Aplicar, publicar e testar
```bash
cd ~/Projects/upgrade_seguros
unzip -o ~/Downloads/entrega-28.1.zip verificar-entrega.js
node verificar-entrega.js --antes        # 4 iguais ao GitHub 1e9f3a2
unzip -o ~/Downloads/entrega-28.1.zip 'functions/*' README.md
node verificar-entrega.js --analyze      # ✓ Todos
firebase deploy --only functions:beta
```
Só o servidor mudou: não precisa refazer o build do app. Teste no chat (**⟳ Nova conversa** antes):
- "qual o telefone de contato do iury guaru"
- "telefone do iury guaru"
- "e os sinistros dele?"

Se alguma pergunta comum ainda falhar, me mande o print: elas também aparecem em Portal → Beta → Perguntas sem resposta.

## Commit
```bash
git add -A functions README.md
git commit -m "Entrega 28.1: Beta acha o cliente em 'telefone de contato do <cliente>'"
GIT_ASKPASS= git push
```
