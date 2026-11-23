# Entrega 18.1 — Notificação na tela clicável

**Base:** GitHub `3964575` (Etapa 18).

## O que muda

O aviso que aparece no canto da tela não fazia nada ao ser clicado. O código já sabia qual era o atendimento, mas não usava essa informação. O README dizia que o clique abria, e por isso você lembrava disso. Agora:

| Aviso | Clique abre |
|---|---|
| 🚨 Assistência Vencida / ⚠️ Assistência em Risco | o detalhe daquela assistência |
| 📋 Tarefa Atrasada (uma) | o sinistro ou a assistência da tarefa |
| 📋 "Você tem N tarefas fora do prazo" | a lista de Tarefas |

- O aviso mostra "Clique para abrir", e o cursor vira a mãozinha.
- Ganhou um **✕** para fechar na hora. Continua sumindo sozinho em 10 segundos.

**Pendência registrada no README:** a notificação **nativa do navegador**, que apareceria mesmo com outra aba ou janela em foco. Hoje o Dashboard só pede a permissão; o aviso só aparece dentro do app.

## Arquivos (3)

| Arquivo | O que mudou |
|---|---|
| `lib/services/notification_service.dart` | Cartão clicável (com o que fazer no clique) e botão fechar. |
| `lib/services/sla_monitor_service.dart` | Passa o destino do clique: assistência, atendimento da tarefa ou lista de Tarefas. |
| `README.md` | Seção de notificações corrigida, histórico 18.1, roadmap (notificação nativa). |

## Aplicar e publicar (só o app)

```bash
cd ~/Projects/upgrade_seguros
unzip -o ~/Downloads/entrega-18.1.zip verificar-entrega.js
node verificar-entrega.js --antes        # 3 iguais ao GitHub 3964575
unzip -o ~/Downloads/entrega-18.1.zip 'lib/*' README.md
node verificar-entrega.js --analyze      # ✓ Todos
git diff lib/services
flutter build web
firebase deploy --only hosting
```

## Testar

Recarregue (Cmd+Shift+R). Quando aparecer um aviso (assistência em risco ou tarefa atrasada):
1. Clique no aviso: abre a assistência, o atendimento ou a lista de Tarefas.
2. Use o botão de voltar do app para retornar.
3. Em outro aviso, clique no ✕: ele fecha na hora.

Para forçar um aviso de tarefa: crie uma tarefa para você com prazo de ontem. Em até 30 segundos aparece "📋 Tarefa Atrasada!".

## Commit

```bash
git add -A lib README.md
git commit -m "Entrega 18.1: notificação na tela clicável (abre assistência/atendimento/Tarefas) e botão fechar"
GIT_ASKPASS= git push
```
