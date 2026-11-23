# Entrega 16b — Multi-tenant, parte 2 (a trava): cada corretora só vê a própria pasta

**Base:** GitHub `99cc809` (Etapa 16, migração feita em 23/11/2026).
**Data:** 23/11/2026.

## O que muda

Na Etapa 16 cada corretora ganhou a própria pasta no banco e o app passou a usar só a dela. Mas as **regras do banco** ainda deixavam qualquer usuário ativo ler qualquer pasta. Com uma corretora só, não faz diferença. Com a segunda, faria.

Agora as **regras do banco** garantem a separação, mesmo para quem tentar acessar o banco por fora do app:

| Quem | Pode |
|---|---|
| Qualquer usuário ativo | Ler e gravar **só** na pasta da própria corretora: sinistros, assistências, clientes, tarefas, NPS… |
| Funcionário | **Não** exclui sinistro, assistência nem cliente. **Não** altera configurações, SLA, seguradoras, oficinas, assinatura do PDF nem o cadastro da corretora (só vê). |
| Gestor (administrador) | Tudo isso, só na própria corretora. Também cria e edita usuários **só da própria corretora**. |
| Usuários | Cada um vê só os colegas da mesma corretora. |
| Coleções antigas da raiz | **Bloqueadas** para todos, até serem apagadas. |

Para quem usa, nada muda: a tela já seguia essas regras (o botão Excluir só aparece para o gestor e Configurações já era somente leitura). Agora o banco também segue.

**Limpeza das coleções antigas.** O cartão 🏢 Dados da corretora (Configurações) ganhou o botão **"Apagar dados antigos"**. Ele tem três proteções:
- o servidor só aceita **7 dias depois da migração**, ou seja, a partir de **30/11/2026**;
- só apaga da raiz o que **já tem cópia** na pasta da corretora; o resto fica e aparece no relatório;
- só funciona digitando **APAGAR**.

O Diagnóstico agora mostra há quantos dias a migração foi feita.

## Arquivos (6)

| Arquivo | O que mudou |
|---|---|
| `firestore.rules` | Reescrito: `membro(e)` e `gestor(e)` por corretora, `users` só da mesma corretora, `nps_indice` só com a própria corretora, raiz bloqueada. Os comentários explicam cada bloco. |
| `functions/empresa.js` | Nova ação `apagarRaiz` (7 dias, só o que tem cópia, confirmação `APAGAR`). O Diagnóstico mostra os dias desde a migração. O "Copiar" de novo não reinicia mais a data da migração. |
| `functions/testes/empresa.teste.js` | +13 testes, 34 no total: confirmação, permissão, prazo de 7 dias, só apaga o que tem cópia, pasta intacta. |
| `functions/testes/firebase-falso.js` | O Firebase de mentira aprendeu a apagar. |
| `lib/widgets/migracao_empresa_card.dart` | Botão "Apagar dados antigos" com confirmação digitada; dias desde a migração no Diagnóstico. |
| `README.md` | Regras por corretora, tabela de Functions, histórico 16b, roadmap 16c. |

Fora do git: `verificar-entrega.js`.

## Aplicar

```bash
cd ~/Projects/upgrade_seguros
unzip -o ~/Downloads/entrega-16b.zip verificar-entrega.js
node verificar-entrega.js --antes        # 6 arquivos iguais ao GitHub 99cc809
unzip -o ~/Downloads/entrega-16b.zip 'lib/*' 'functions/*' README.md firestore.rules
node verificar-entrega.js --analyze      # tem que terminar em ✓ Todos
git diff firestore.rules functions/empresa.js lib/widgets/migracao_empresa_card.dart
```

Se o Safari descompactou sozinho: `cp -R ~/Downloads/entrega-16b/lib ~/Downloads/entrega-16b/functions . && cp ~/Downloads/entrega-16b/README.md ~/Downloads/entrega-16b/firestore.rules .`

## Publicar (pode ser durante o dia; a equipe não é bloqueada)

### Passo 1: Functions e app

```bash
firebase deploy --only functions:migrarEmpresa
flutter build web
firebase deploy --only hosting
```

### Passo 2: simular as regras no Playground (10 min)

Console → Firestore Database → **Regras**. Cole o conteúdo do novo `firestore.rules` no editor, **sem publicar**, e abra o **Playground de regras**.

Valores que você vai usar:
- `<E>` = `WjuMRrs8wfSwomP3b4nEO8Zg2CW2` (a sua corretora).
- `<S>` = o id de um sinistro qualquer. Abra `corretoras/<E>/sinistros` no Firestore e copie um.
- O seu UID é o mesmo que o `<E>`.
- O UID de um funcionário está em Authentication → Users.

| # | Tipo | Caminho | UID | Esperado |
|---|---|---|---|---|
| 1 | get | `corretoras/<E>/sinistros/<S>` | o seu | ✅ Permitido |
| 2 | get | `corretoras/<E>/sinistros/<S>` | de um funcionário | ✅ Permitido |
| 3 | get | `corretoras/OUTRA/sinistros/<S>` | o seu | ❌ Negado |
| 4 | get | `sinistros/<S>` (raiz antiga) | o seu | ❌ Negado |
| 5 | delete | `corretoras/<E>/sinistros/<S>` | de um funcionário | ❌ Negado |
| 6 | delete | `corretoras/<E>/sinistros/<S>` | o seu | ✅ Permitido (é só simulação, não apaga) |
| 7 | update | `corretoras/<E>/app_config/config` com `{"x": 1}` | de um funcionário | ❌ Negado |
| 8 | update | `corretoras/<E>/tasks/<id de uma tarefa>` com `{"status": "Pendente"}` | de um funcionário | ✅ Permitido |
| 9 | get | `corretoras/<E>/sinistros/<S>` | Não autenticado | ❌ Negado |

Se os 9 baterem, siga. Se algum der diferente, **não publique** e me mande o print.

### Passo 3: publicar as regras

```bash
firebase deploy --only firestore:rules
```

### Passo 4: testar (10 min)

- **Como gestor (você):** Dashboard, Sinistros, Assistências, Clientes, Tarefas e Relatórios abrem. Altere e volte uma configuração. Usuários lista a equipe.
- **Como funcionário:**
  - abre e edita sinistros e assistências;
  - cria e conclui tarefas;
  - gera link de NPS;
  - anexa foto;
  - Configurações abre como somente leitura.
- **Responder um NPS** numa janela anônima.

Se alguma tela mostrar erro de "permission-denied" (ou "permissão negada"), me mande o print. A volta é pelo console: Firestore → Regras → **Histórico** → restaurar a versão anterior.

### Passo 5: a partir de 30/11, apagar os dados antigos

1. **Backup antes.** No terminal:
   ```bash
   gcloud firestore export gs://upgrade-seguros.firebasestorage.app/backups/2026-11-30
   ```
   Isso guarda uma cópia completa do banco no armazenamento. O custo é de centavos. Se o comando pedir para ativar alguma API, responda **Y**.
2. App → Configurações → 🏢 Dados da corretora:
   - **Diagnóstico:** confira se a pasta tem pelo menos tantos documentos quanto a raiz, em todas as coleções;
   - **Copiar:** para garantir;
   - **Apagar dados antigos:** digite APAGAR.
3. O relatório mostra quantos foram apagados por coleção. Se aparecer algum "SEM cópia (mantidos)", me mande o print.

## Commit

```bash
git add -u
git commit -m "Entrega 16b: 🔒 regras do banco por corretora (só gestor exclui e configura) · limpeza das coleções antigas após 7 dias"
GIT_ASKPASS= git push
```

## Próximo: 16c, arquivos por corretora e links protegidos

- **Fotos, documentos e vídeos novos** passam a ficar na pasta da corretora no armazenamento.
- **Links públicos viram links protegidos do Firebase.** Hoje, quem tiver o link de uma foto abre sem login (pendência S6).
- **Fotos antigas:** os links delas são convertidos.
- **Imagens no Chrome:** isso deve resolver as que às vezes não aparecem, porque os links do Firebase já vêm com o CORS e o cache certos.
