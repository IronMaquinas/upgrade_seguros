# Entrega 28.11: Beta troca de cliente no meio da conversa

**Base:** GitHub `6271270` (Etapa 28.10).

## O que estava errado (seu print)
A conversa era sobre a GMC. Depois veio **"quais os sinistros abertos da Lube?"**, e a Beta respondeu com a GMC. A palavra "abertos" no meio da frase impediu a Beta de recortar o nome "Lube", e ela continuou no cliente da conversa.

## Como a Beta decide o assunto, agora
1. **Número** (SN…/AS…) ou **placa** na frase → esse atendimento.
2. **Nome recortado** ("… da X", "cliente X", "X possui…") → esse cliente. Agora aceita "abertos", "em andamento", "encerrados" etc. entre "sinistros" e "da X".
3. **Novo: nome solto na frase.** Se nada acima achou e a frase cita uma palavra própria do nome de um cliente cadastrado ("lube", "gmc", "pluma"), ele vira o assunto.
   - Palavras genéricas não contam: ltda, transportes, distribuidora, representações e as palavras das próprias perguntas (sinistro, contato, condutor…).
   - Se dois clientes têm a mesma palavra, a Beta não adivinha e continua como estava.
4. Nada disso → continua no cliente/sinistro da conversa ("e o condutor?").

## Arquivos (4)
- `functions/beta.js`
- `functions/beta-interpretar.js`
- `functions/testes/beta.teste.js` (a conversa GMC → Lube do print)
- `README.md`

## Aplicar e publicar
```bash
cd ~/Projects/upgrade_seguros
unzip -o ~/Downloads/entrega-28.11.zip verificar-entrega.js
node verificar-entrega.js --antes        # 4 iguais ao GitHub 6271270
unzip -o ~/Downloads/entrega-28.11.zip 'functions/*' README.md
node verificar-entrega.js --analyze      # ✓ Todos
firebase deploy --only functions:beta
```

## Testar
1. "qual o telefone de contato do sinistro da GMC?" → GMC.
2. "quais os sinistros abertos da Lube?" → os sinistros da **Lube**.
3. "condutor gmc" → volta para a GMC.
4. "e o contato do sinistro?" → continua na GMC.

## Commit
```bash
git add -A functions README.md
git commit -m "Entrega 28.11: Beta troca de cliente quando a frase cita outro cliente"
GIT_ASKPASS= git push
```
