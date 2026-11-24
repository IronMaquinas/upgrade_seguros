# Entrega 20 — Seguradora só do cadastro (+ correção dos registros antigos)

**Base:** GitHub `b2af9a3` (Etapa 19b.5).

## Por que havia nomes diferentes

- **Abertura de sinistro:** o campo Seguradora não sugeria nada.
  - A lista do cadastro chegava *depois* de o campo ser montado, e o campo continuava com a lista vazia.
  - Como ele aceitava qualquer texto, cada pessoa digitava de um jeito.
- **Assistência (veículo e residencial), apólice no cadastro do cliente e edição no detalhe do sinistro:** também gravavam texto livre.
- **Importação de contrato:** gravava o nome que vem no PDF (ex.: "AXA SEGUROS"). Na abertura, esse nome era copiado da apólice.
- **Cadastro em Configurações:** só barrava nome *exatamente* igual. Se a consulta falhasse, deixava passar.

## O que muda

1. **Campo Seguradora único** em todas essas telas:
   - sugere as seguradoras cadastradas enquanto você digita (sem diferença de acento ou maiúsculas);
   - a **seta** abre a lista completa, com busca;
   - ao sair do campo, "chubb" vira "Chubb";
   - se o texto não corresponder a nenhuma cadastrada, o campo é limpo e mostra o aviso;
   - valor vindo de apólice antiga fora do cadastro aparece com aviso em vermelho.
2. **Conferência ao salvar:**
   - registrar sinistro, salvar assistência, salvar apólice e salvar a edição do sinistro **não aceitam** seguradora fora do cadastro;
   - o salvamento automático da abertura não bloqueia, mas grava o nome cadastrado quando houver correspondência.
3. **Contrato importado e apólice copiada:** o nome do PDF vira o nome cadastrado ("AXA SEGUROS" → "AXA").
4. **Cadastro (Configurações → Seguradoras):** barra nome **parecido** ("CHUBB" com "Chubb" já cadastrada) e diz qual já existe.
5. **Corrigir nomes nos registros:** botão novo na aba Seguradoras, só para o gestor.
   - Lê sinistros, assistências e as apólices dos clientes.
   - Lista cada grafia fora do cadastro e quantos registros usam cada uma.
   - Já marca uma **sugestão**: AXA SEGURUROS → AXA, EZZER → EZZE, CHUBB → Chubb.
   - Você confere, troca o que precisar ou escolhe "Não mudar", e confirma. A troca é feita em lote.

## Depois de publicar (gestor)

1. **Configurações → Seguradoras:** confira se todas as seguradoras que vocês usam estão cadastradas e **ativas**. Se faltar alguma (ex.: uma que só existe nos registros), cadastre antes.
2. Clique em **Corrigir nomes nos registros**, confira cada linha e clique em **Corrigir N registro(s)**.
3. Clique em **Verificar de novo**: deve aparecer "Tudo certo".

> Dica: antes do passo 2, rode o backup do Firestore (o mesmo comando da pendência de 30/11). A troca não se desfaz sozinha.

## Arquivos (13)

| Arquivo | O que mudou |
|---|---|
| `lib/utils/seguradoras.dart` | **Novo.** Regras puras: achar a cadastrada, sugestões, palpite para grafias erradas, levantamento e troca nas apólices. |
| `lib/services/seguradoras_cadastradas.dart` | **Novo.** Lista das ativas lida uma vez para o app; conferência ao salvar. |
| `lib/widgets/campo_seguradora.dart` | **Novo.** O campo único (sugestões, lista completa, aviso). |
| `lib/widgets/corrigir_seguradoras_dialog.dart` | **Novo.** Ferramenta "Corrigir nomes nos registros". |
| `test/seguradoras_test.dart` | **Novo.** 9 testes. |
| `lib/screens/spreadsheet_claim_screen.dart` | Abertura de sinistro: campo novo + conferência ao registrar. |
| `lib/screens/spreadsheet_assist_screen.dart` | Assistência veicular: campo novo (2 lugares) + conferência ao salvar. |
| `lib/screens/spreadsheet_assist_residencial_screen.dart` | Assistência residencial: idem. |
| `lib/screens/client_form_screen.dart` | Apólice: campo novo + conferência; contrato importado com o nome cadastrado. |
| `lib/screens/claim_detail_screen.dart` | Editar sinistro: campo novo + conferência. |
| `lib/screens/settings_screen.dart` | Botão "Corrigir nomes nos registros"; mensagem de erro mais limpa. |
| `lib/services/seguradora_service.dart` | Barra nome parecido; avisa o app quando o cadastro muda. |
| `README.md` | Histórico 20 + pendência resolvida. |

## Aplicar e publicar (só o app)

```bash
cd ~/Projects/upgrade_seguros
unzip -o ~/Downloads/entrega-20.zip verificar-entrega.js
node verificar-entrega.js --antes        # 8 iguais ao GitHub b2af9a3 + 5 novos
unzip -o ~/Downloads/entrega-20.zip 'lib/*' 'test/*' README.md
node verificar-entrega.js --analyze      # ✓ Todos
git diff --stat
git diff lib/screens/spreadsheet_claim_screen.dart
flutter build web
firebase deploy --only hosting
```

## Commit

```bash
git add -A lib test README.md
git commit -m "Entrega 20: seguradora só do cadastro + correção dos nomes nos registros"
GIT_ASKPASS= git push
```
