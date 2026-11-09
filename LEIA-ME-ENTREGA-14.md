# Entrega 14 — Tarefas ligadas ao sinistro e à assistência

**Base:** GitHub `fa5b317` (Etapas 01–13).
**Data:** 09/11/2026.

## O problema (verificação feita a seu pedido)

Antes desta entrega, só a tarefa de contato com o cliente era concluída pelo sistema, e só quando o funcionário clicava em WhatsApp, Outlook ou Gmail e respondia "Sim". Todo o resto ficava aberto para sempre:

- **"Fazer depois", "Não", fechar a janela ou avisar por telefone** → a tarefa de contato ficava aberta.
- **Cada nova mudança de status ou previsão** criava outra tarefa de contato, e a anterior, já desatualizada, continuava aberta.
- **Encerrar o sinistro** ou **concluir/cancelar a assistência** não mexia nas tarefas dele.
- **Excluir o atendimento** deixava as tarefas órfãs. Elas sumiam da tela de Tarefas, mas continuavam contando nos Relatórios e no Dashboard. Isso inflava os números.
- No caminho achei mais três problemas:
  - tarefas de assistência não gravavam o responsável, então o funcionário não as via no Dashboard;
  - o alerta "📋 Tarefa Atrasada!" nunca disparava;
  - o monitor de alertas lia **todas** as tarefas do banco a cada 30 segundos (cada leitura é cobrada pelo Firestore).

## O que muda para quem usa

1. **Encerrar o sinistro / concluir ou cancelar a assistência.** Depois da confirmação de sempre, se houver tarefas abertas, aparece a janela **"Tarefas abertas deste sinistro"**:
   - a lista vem com todas as tarefas marcadas, e o funcionário pode desmarcar alguma;
   - o botão diz **"Concluir N e encerrar"**, ou **"Encerrar sem concluir tarefas"** se ele desmarcar todas;
   - **"Voltar"** cancela o encerramento. Na assistência, o status volta ao que era.
2. **Excluir um sinistro ou uma assistência** conclui as tarefas abertas dele, com o motivo "Atendimento excluído em dd/mm/aaaa". Elas **não são apagadas**: o histórico fica.
3. **Nova comunicação de status ou previsão do sinistro** conclui a tarefa de contato anterior daquele sinistro, com o motivo "Substituída pela atualização de …". Fica aberta só a mais nova.
4. **Janela "Comunicar cliente"** ganhou o botão **"Já informei por outro meio"** (telefone, presencial). Ele conclui a tarefa.
5. **Configurações → 🧹 Tarefas esquecidas** (só aparece para administrador): o botão **"Analisar"** procura, sem mudar nada:
   - tarefas abertas de atendimentos já encerrados (Concluído, Cancelado ou Negado);
   - tarefas de atendimentos que foram excluídos;
   - contatos com o cliente repetidos no mesmo sinistro (fica só o mais novo).

   Ele mostra quantas há em cada grupo e a lista com o motivo. Só conclui quando você clicar em **"Concluir N"**. Recomendo rodar uma vez logo depois de publicar, para zerar o acúmulo.
6. **Concluída pelo sistema não conta como atraso do funcionário.** Tarefas concluídas nos itens 1, 2, 3 e 5:
   - ficam como **"Encerrada pelo sistema"** e saem do "no prazo / fora do prazo";
   - nos Relatórios aparecem como **"Pelo sistema"**;
   - na lista de Tarefas mostram 🤖 com o motivo.

   Sem isso, concluir hoje uma tarefa vencida há meses contaria como "fora do prazo" para quem a criou. O "Já informei por outro meio" é diferente: é o funcionário que conclui, então conta normalmente no prazo.
7. **Alerta de tarefa atrasada funcionando**, mas sem enxurrada:
   - **um** aviso com o total de tarefas atrasadas **de quem está logado**;
   - repete só quando o total aumenta ou, no máximo, de hora em hora.
8. **Tarefas de assistência gravam o responsável.** O Dashboard do funcionário também passa a achar as antigas pelo e-mail.

Se alguém reabrir uma tarefa concluída pelo sistema, ou mudar o status dela à mão, ela deixa de ser "pelo sistema".

## Arquivos (18)

| Arquivo | O que mudou |
|---|---|
| `lib/utils/tarefas_evento.dart` (novo) | Regras: o que é tarefa de contato (pelo `tipo` novo ou pela descrição antiga), textos dos motivos e o plano da limpeza (3 grupos). Dart puro, testado. |
| `lib/services/tarefas_evento_service.dart` (novo) | Gravações: lista as tarefas abertas do atendimento, conclui em lote com motivo e `conclusao_automatica`, conclui tudo do atendimento excluído, substitui contatos, analisa e executa a limpeza. |
| `lib/widgets/tarefas_evento_dialog.dart` (novo) | Janela "Tarefas abertas deste …" e cartão "🧹 Tarefas esquecidas". |
| `test/tarefas_evento_test.dart` (novo) | 7 testes: contato antigo × novo, substituição, limpeza (encerrado, cancelado, excluído, sem vínculo, contatos repetidos, Rascunho em curso), prazo do funcionário, motivos. |
| `lib/utils/tarefas.dart` | "Encerrada pelo sistema" fora da conta de prazo; contador `encerradasPeloSistema`. |
| `lib/models/claim_task_model.dart` | Campo opcional `tipo`. |
| `lib/screens/claim_detail_screen.dart` | Substitui o contato anterior ao criar um novo (status e previsão), grava `tipo: contato_cliente`, botão "Já informei por outro meio", janela de tarefas ao encerrar. |
| `lib/screens/assist_detail_screen.dart` | Janela de tarefas ao concluir/cancelar ("Voltar" desfaz o status); reagendamento grava `responsavelId`. |
| `lib/screens/spreadsheet_assist_screen.dart`, `lib/screens/spreadsheet_assist_residencial_screen.dart` | Tarefas criadas na abertura gravam `responsavelId`. |
| `lib/services/firestore_service.dart` | Excluir atendimento conclui as tarefas; concluir/reabrir à mão limpa o "pelo sistema"; lista e relatórios trazem motivo e "pelo sistema". |
| `lib/widgets/task_list_widget.dart` | Mudar o status à mão limpa o "pelo sistema". |
| `lib/screens/task_list_screen.dart` | Mostra 🤖 com o motivo; prazo em cinza para concluída pelo sistema. |
| `lib/widgets/tarefas_funcionarios_card.dart` | Mostra "Pelo sistema" nos Relatórios. |
| `lib/widgets/dashboard_content.dart` | Funcionário vê também as tarefas sem `responsavelId` que têm o e-mail dele. |
| `lib/services/sla_monitor_service.dart` | Alerta de tarefa atrasada corrigido e agrupado; lê só tarefas abertas. |
| `lib/screens/settings_screen.dart` | Cartão "🧹 Tarefas esquecidas" depois do cartão de vídeos. |
| `README.md` | Seção "Gestão de Tarefas" (ligação com o atendimento), notificações, histórico 14, roadmap. |

Fora do git: **`verificar-entrega.js`** com os md5 da Etapa 14.

**Campos novos no banco** (coleção `tasks`, só acréscimos):
- `tipo: 'contato_cliente'`;
- `motivoConclusao` (texto);
- `conclusao_automatica` (`true`/`false`).

Nada é apagado e nenhum campo existente muda de sentido.

## Aplicar (na raiz do projeto, terminal do VS Code)

```bash
cd ~/Projects/upgrade_seguros
unzip -o ~/Downloads/entrega-14.zip verificar-entrega.js
node verificar-entrega.js --antes        # 14 arquivos iguais ao GitHub fa5b317 + 4 novos
unzip -o ~/Downloads/entrega-14.zip 'lib/*' 'test/*' README.md
node verificar-entrega.js --analyze      # tem que terminar em ✓ Todos
```

Se o Safari já tiver descompactado o zip sozinho (pasta `~/Downloads/entrega-14`):

```bash
cp ~/Downloads/entrega-14/verificar-entrega.js .
node verificar-entrega.js --antes
cp -R ~/Downloads/entrega-14/lib ~/Downloads/entrega-14/test . && cp ~/Downloads/entrega-14/README.md .
node verificar-entrega.js --analyze
```

Não há pacote novo e não há nada para publicar no Firebase (nem regras, nem Functions).

**Sobre os avisos ⚠️ do Telegram/.env:** são os mesmos da Etapa 13 (token exposto no repositório). Continuam até você revogar o token e tirar os arquivos do git.

**Se aparecer um aviso de índice:** a consulta das tarefas abertas usa um filtro simples (`status ≠ Concluída`), que o Firestore aceita sem índice novo. Se mesmo assim aparecer, no console do navegador, um link "create index", clique nele e confirme. É de graça e leva alguns minutos.

## Ver as mudanças linha a linha (antes do commit)

```bash
git --no-pager diff --stat
git diff lib/screens/claim_detail_screen.dart
git diff lib/screens/assist_detail_screen.dart
git diff lib/services/firestore_service.dart
git diff lib/services/sla_monitor_service.dart
git diff lib/utils/tarefas.dart
git diff lib/models/claim_task_model.dart
git diff lib/screens/task_list_screen.dart lib/widgets/task_list_widget.dart
git diff lib/widgets/dashboard_content.dart lib/widgets/tarefas_funcionarios_card.dart
git diff lib/screens/spreadsheet_assist_screen.dart lib/screens/spreadsheet_assist_residencial_screen.dart
git diff lib/screens/settings_screen.dart
git diff README.md
# arquivos novos (ainda fora do git): abra no VS Code
#   lib/utils/tarefas_evento.dart  lib/services/tarefas_evento_service.dart
#   lib/widgets/tarefas_evento_dialog.dart  test/tarefas_evento_test.dart
```

## Testar

1. **Limpeza primeiro.** Entre como admin, vá em Configurações → 🧹 Tarefas esquecidas → **Analisar**.
   - Confira os números e a lista.
   - Se fizer sentido, clique em **Concluir**.
   - Em Tarefas e em Relatórios, os totais de abertas devem cair, e as concluídas aparecem com 🤖 e o motivo.
2. **Contato substituído.** Num sinistro em curso, mude o status para "Aguardando Peças" e escolha **Fazer depois**. Depois clique em "Atualizar previsão" e de novo **Fazer depois**. Em Tarefas deve haver só **uma** tarefa de contato aberta, e a anterior aparece concluída com 🤖 "Substituída…".
3. **Já informei por outro meio.** Repita a mudança de status e clique no botão novo. A tarefa fica concluída, sem 🤖, com o motivo.
4. **Encerrar sinistro com tarefas abertas.** Crie uma tarefa manual no sinistro e mude o status para Concluído.
   - Depois da confirmação dos valores, a janela deve listar as tarefas marcadas.
   - Teste **Voltar**: o sinistro não é encerrado.
   - Encerre de novo, agora concluindo as tarefas.
5. **Assistência.** Numa assistência com agendamento, clique em "Marcar como Concluído". Deve aparecer a janela com a tarefa de agendamento. Teste também mudar para Cancelado e clicar em **Voltar**: o status volta ao anterior.
6. **Excluir.** Exclua um atendimento de teste que tenha tarefa. Em Relatórios → Tarefas por Funcionário, ela aparece como concluída "Pelo sistema", não como aberta.
7. **Alerta.** Com uma tarefa sua vencida e aberta, em até 30 segundos aparece **um** aviso "📋 Tarefa Atrasada!". Ele não deve se repetir na mesma hora, a menos que surja mais uma atrasada.

## Commit

```bash
git add lib/utils/tarefas_evento.dart lib/services/tarefas_evento_service.dart lib/widgets/tarefas_evento_dialog.dart test/tarefas_evento_test.dart
git add -u
git commit -m "Entrega 14: ✅ tarefas ligadas ao atendimento (encerrar/excluir/substituir) · 🧹 limpeza das esquecidas · 📋 alerta de atraso funcionando"
GIT_ASKPASS= git push
```

## O que ficou de fora (para você decidir depois)

- **Status "Cancelado" e "Negado" no sinistro:** o seletor de status do detalhe do sinistro só oferece até "Concluído". Se um sinistro for negado pela seguradora, hoje não há como marcar. A janela de tarefas já está pronta para "cancelar" quando esse status existir.
- **A tarefa de contato tem como prazo a data da previsão de conclusão**, que pode estar a semanas. Se a ideia é avisar o cliente logo, um prazo de 1–2 dias faria mais sentido. Não mudei porque é regra de negócio.
