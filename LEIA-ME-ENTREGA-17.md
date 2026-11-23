# Entrega 17 — Perfil da corretora: cabeçalho e rodapé padrão nos PDFs

**Base:** GitHub `701591d` (Etapa 16c.1).
**Data:** 23/11/2026.

## O que muda

Até agora o nome "Upgrade Corretora de Seguros" e a logo estavam **escritos no código** dos PDFs. Uma segunda corretora geraria PDF com a marca da Upgrade.

Agora cada corretora tem o **próprio cadastro**, e todos os PDFs saem com ele.

**Configurações → 🏢 Dados da corretora** (cartão novo, logo acima de "📝 Assinatura em PDF"):
- nome (fantasia), razão social, CNPJ, registro SUSEP, endereço, telefone, e-mail, site;
- **logo**: PNG ou JPG, até 2 MB. Vai para a pasta da corretora no Storage;
- botão **Salvar**. Antes, os 3 campos que ficavam na Assinatura gravavam no banco a cada letra digitada;
- só o gestor altera. O funcionário vê os dados, sem poder editar.

**Todos os PDFs** usam o mesmo cabeçalho e rodapé: sinistro, Relatório Executivo, relatório de clientes e tarefas por funcionário.

| Onde | O quê |
|---|---|
| Cabeçalho | logo · nome · razão social, CNPJ, SUSEP · endereço · telefone, e-mail, site · título do documento à direita |
| Rodapé | nome da corretora · **Gerado por** (nome, telefone, e-mail, conforme a "📝 Assinatura em PDF") · data e hora · Página X de Y |

**Também usam o cadastro:**
- o nome do arquivo do PDF do sinistro e do Relatório Executivo;
- a assinatura da mensagem de WhatsApp da assistência. Antes era "Upgrade Seguros" fixo.

**Enquanto você não enviar a logo,** a Upgrade continua usando a logo de hoje (`lib/assets/logo_upgrade.png`). Uma corretora nova, sem logo, sai sem logo.

**Fica para depois:** o nome "Upgrade Corretora" no menu e a logo da tela de login. O login acontece antes de o sistema saber qual é a corretora, então isso depende do domínio próprio.

## Arquivos (17: 12 alterados, 4 novos, 1 apagado)

| Arquivo | O que mudou |
|---|---|
| `lib/services/marca_pdf.dart` **(novo)** | Carrega cadastro, logo e assinatura uma vez; monta o cabeçalho e o rodapé de qualquer PDF. |
| `lib/utils/perfil_corretora.dart` **(novo)** | Textos do cabeçalho/rodapé, CNPJ formatado, nome do arquivo, regra da logo. |
| `test/perfil_corretora_test.dart` **(novo)** | 9 testes. |
| `lib/widgets/perfil_corretora_card.dart` **(novo)** | O cartão 🏢 Dados da corretora. |
| `lib/models/corretora_model.dart` | + razão social, SUSEP, site, caminho da logo; `dadosPerfil()` (grava só o perfil, sem mexer na data de criação nem nos campos da migração). |
| `lib/screens/settings_screen.dart` | Cartão novo; os 3 campos que gravavam a cada letra saíram da Assinatura (a prévia da assinatura continua igual). |
| `lib/services/pdf_services.dart` | PDF do sinistro com o cabeçalho/rodapé padrão. O resto do PDF não mudou. |
| `lib/services/pdf_report_service.dart` | Relatório Executivo idem. Cabeçalho e rodapé agora repetem em todas as páginas. |
| `lib/services/relatorio_clientes_pdf.dart`, `lib/services/tarefas_pdf.dart` | Idem, mantendo as notas de rodapé de cada um. |
| `lib/screens/claim_detail_screen.dart`, `reports_screen.dart`, `client_list_screen.dart`, `task_list_screen.dart` | Carregam a marca antes de gerar o PDF; nome do arquivo pelo cadastro. |
| `lib/screens/spreadsheet_assist_screen.dart` | Assinatura do WhatsApp pelo nome da corretora. |
| `lib/services/pdf_services_admin.dart` **(apagado)** | Cópia antiga do PDF de sinistro, que nenhuma tela usava, com logo e nome fixos. |
| `README.md` | Seção do cabeçalho/rodapé, campos do cadastro, histórico, roadmap (Etapa 18 = relatórios com modelos). |

Fora do git: `verificar-entrega.js`.

## Aplicar

```bash
cd ~/Projects/upgrade_seguros
unzip -o ~/Downloads/entrega-17.zip verificar-entrega.js
node verificar-entrega.js --antes        # 12 arquivos iguais ao GitHub 701591d e 4 novos ainda inexistentes
unzip -o ~/Downloads/entrega-17.zip 'lib/*' 'test/*' README.md
git rm lib/services/pdf_services_admin.dart
node verificar-entrega.js --analyze      # tem que terminar em ✓ Todos
```

Se o Safari descompactou sozinho: `cp -R ~/Downloads/entrega-17/lib ~/Downloads/entrega-17/test . && cp ~/Downloads/entrega-17/README.md .`

Para ver cada mudança:

```bash
git diff lib/models lib/services lib/screens
git status   # 4 novos como "Untracked" e pdf_services_admin.dart como "deleted"
```

## Publicar (pode ser durante o dia)

Não há mudança de regras nem de Functions, só o app:

```bash
flutter build web
firebase deploy --only hosting
```

## Testar (10 min)

Recarregue o app (Cmd+Shift+R).

1. **Como gestor, Configurações → 🏢 Dados da corretora:**
   - preencha razão social, CNPJ, SUSEP, endereço e site (nome, telefone e e-mail já vêm preenchidos);
   - **Enviar logo:** pode ser a `lib/assets/logo_upgrade.png` ou uma versão melhor, horizontal;
   - clique em **Salvar**.
2. **Gere os 4 PDFs** e confira cabeçalho e rodapé:
   - PDF de um sinistro;
   - Relatórios → PDF;
   - Clientes → Exportar relatório → PDF;
   - Tarefas → Exportar → PDF.
3. **Rodapé:** "Gerado por" segue a 📝 Assinatura em PDF. Se "Nome" estiver em **Funcionário**, aparece o nome de quem gerou.
4. **Como funcionário:** o cartão 🏢 aparece somente leitura, e os PDFs saem iguais.
5. **WhatsApp:** abra o WhatsApp de uma assistência. A assinatura é o nome da corretora.

Se algo sair torto (logo esticada, texto cortado), me mande o PDF ou um print.

## Commit

```bash
git add -A lib test README.md
git commit -m "Entrega 17: 🏢 perfil da corretora (dados e logo) · cabeçalho e rodapé padrão em todos os PDFs"
GIT_ASKPASS= git push
```

## Próximo: Etapa 18 (relatórios de sinistros e assistências com modelos)

Começo assim que você me mandar o modelo que a funcionária precisa. Já fica com este cabeçalho e rodapé.
