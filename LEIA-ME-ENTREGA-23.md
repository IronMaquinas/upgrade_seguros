# Entrega 23 — Módulos do plano + "Meu plano"

**Base:** GitHub `df63e18` (Etapa 22.2).

## O que muda

1. **Catálogo de módulos**, com a mesma lista no app (`lib/utils/modulos.dart`) e nas Functions (`functions/modulos.js`). O verificador confere que as duas são iguais.
   - **Atendimento:** Assistências, Vídeos, Oficinas
   - **Carteira:** Importar contrato
   - **Gestão:** Tarefas, Relatórios (exportar), Modelos de relatório
   - **Comunicação:** Pesquisa NPS e Avisos no Telegram (os dois só funcionam com Assistências ligado)
2. **Portal → corretora → Módulos do plano:**
   - **Tudo ligado** (como hoje), ou **Escolher os módulos** com caixas por área;
   - marcar NPS liga Assistências junto; desligar Assistências desliga NPS e Telegram;
   - cada mudança fica no histórico da conta e na auditoria. O detalhe da corretora mostra a linha "Módulos".
3. **No app**, um módulo fora do plano **não some**:
   - aparece com **cadeado** no menu, e a tela mostra "Fora do plano" com o botão **Ver meu plano**;
   - nos detalhes (sinistro/assistência), Vídeos, Tarefas, Oficinas e NPS viram um quadro "Fora do plano";
   - os botões Exportar e Importar contrato avisam e levam ao plano.
4. **Trava de verdade, não só na tela:**
   - **regras do Firestore:** com o módulo desligado, não dá para criar/alterar assistências, tarefas, oficinas, modelos de relatório e pesquisas NPS;
   - **Storage:** não dá para enviar vídeos;
   - **Function do Telegram:** pula a corretora sem o módulo.
   - O que já existe continua **legível**.
5. **Meu plano** (novo ícone na barra do topo) mostra o plano, a situação e os módulos incluídos e fora do plano.
6. **Correção:** no celular, o item **Configurações** do menu abria Relatórios.

**A Upgrade não muda nada:** ela é fundadora e continua em "Tudo ligado". Corretora sem conta na plataforma também fica com tudo ligado.

Ainda sem trava: gatilho/recomendação (fica para os planos-modelo, Etapa 24).

## Arquivos (27)

| Arquivo | O que mudou |
|---|---|
| `lib/utils/modulos.dart` (novo) | Catálogo, dependências, marcar/desmarcar, módulos ligados da conta. |
| `functions/modulos.js` (novo) | Mesmo catálogo no servidor. |
| `functions/plataforma.js` | Ação `contaDefinirModulos`; o resumo da conta traz os módulos. |
| `functions/notificacoes-telegram.js` | Pula a corretora sem o módulo Telegram. |
| `functions/testes/firebase-falso.js` | Suporta `FieldValue.delete()`. |
| `functions/testes/modulos.teste.js` (novo) | Catálogo e ação do portal (permissão, erros, histórico, auditoria). |
| `firestore.rules` | `moduloLigado()` nas gravações das coleções com módulo. |
| `storage.rules` | Envio de vídeo exige o módulo Vídeos. |
| `lib/services/plano_atual.dart` (novo) | Lê `plataforma_contas` da corretora ao entrar. Se der erro, considera tudo ligado. |
| `lib/screens/meu_plano_screen.dart` (novo) | Tela Meu plano, quadro "Fora do plano" e aviso. |
| `lib/widgets/portao_empresa.dart` | Carrega o plano ao entrar e limpa ao sair. |
| `lib/screens/dashboard_screen.dart` | Cadeados no menu, telas bloqueadas, ícone Meu plano, correção do Configurações no celular. |
| `lib/screens/claim_detail_screen.dart` | Vídeos, Tarefas e Oficinas conforme o plano. |
| `lib/screens/assist_detail_screen.dart` | Tarefas e NPS conforme o plano. |
| `lib/screens/spreadsheet_claim_screen.dart`, `spreadsheet_assist_screen.dart` | Vídeos e Tarefas conforme o plano. |
| `lib/screens/claim_list_screen.dart`, `assist_list_screen.dart` | Exportar conforme o plano. |
| `lib/screens/client_form_screen.dart` | Importar contrato conforme o plano. |
| `lib/screens/settings_screen.dart` | Aba Oficinas conforme o plano. |
| `lib/services/tarefas_evento_service.dart` | Não mexe em tarefas quando o módulo está desligado. |
| `lib/admin/modelos_plataforma.dart`, `plataforma_api.dart` | Módulos da conta e a chamada nova. |
| `lib/admin/modulos_corretora_dialog.dart` (novo) | Janela "Módulos do plano". |
| `lib/admin/portal_app.dart` | Linha "Módulos" e o botão no detalhe da corretora. |
| `test/modulos_test.dart` (novo) | 4 testes do catálogo. |
| `README.md` | Seção "Módulos e Meu plano" e histórico 23. |

Ver o que mudou em cada um: `git diff <arquivo>` (antes do commit). Os novos aparecem em `git status`.

## Aplicar e publicar

```bash
cd ~/Projects/upgrade_seguros
unzip -o ~/Downloads/entrega-23.zip verificar-entrega.js
node verificar-entrega.js --antes        # 20 iguais ao GitHub df63e18, 7 novos ainda não existem
unzip -o ~/Downloads/entrega-23.zip 'lib/*' 'functions/*' 'test/*' firestore.rules storage.rules README.md
node verificar-entrega.js --analyze      # ✓ Todos + ✓ catálogo de módulos igual no app e nas Functions
git diff --stat
flutter test test/modulos_test.dart
(cd functions && node testes/modulos.teste.js)

# 1) regras + Functions primeiro (o app novo depende delas)
firebase deploy --only firestore:rules,storage,functions:plataforma,functions:verificarAssistenciasAtradasTelegram

# 2) portal
flutter build web -t lib/main_admin.dart --no-tree-shake-icons
rm -rf build/admin && cp -R build/web build/admin

# 3) app
flutter build web
firebase deploy --only hosting:admin,hosting:app
```

## Testar (na Upgrade, por alguns minutos)

1. **App:** o ícone **Meu plano** no topo deve mostrar "Tudo ligado" e todos os módulos incluídos. Nada fica com cadeado.
2. **Portal → Corretoras → Upgrade → Módulos do plano → Escolher os módulos.** Desmarque **Assistências** (NPS e Telegram saem juntos) e **Tarefas** → Salvar. A linha "Módulos" mostra a lista nova.
3. **App:** recarregue a página (Cmd+Shift+R) e confira:
   - Assistências e Tarefas aparecem com **cadeado** no menu. Clicando, aparece "Fora do plano" → **Ver meu plano**;
   - no detalhe de um sinistro, o quadro Tarefas aparece como "Fora do plano";
   - **Meu plano** mostra "Personalizado", com Assistências/Tarefas/NPS/Telegram em "Fora do plano".
4. **Volte no portal → Módulos do plano → Tudo ligado → Salvar**, recarregue o app e confira que tudo voltou. ⚠️ Não esqueça este passo: enquanto estiver personalizado, a equipe não consegue criar assistências nem tarefas.
5. (Celular, opcional) menu → **Configurações** agora abre Configurações.

## Commit

```bash
git add -A lib functions test firestore.rules storage.rules README.md
git commit -m "Entrega 23: módulos do plano (cadeado na tela, regras e Functions), Meu plano e módulos no portal"
GIT_ASKPASS= git push
```
