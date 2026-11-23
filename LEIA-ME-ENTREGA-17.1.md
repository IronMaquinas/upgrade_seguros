# Entrega 17.1 — Dados da corretora: CNPJ primeiro, com consulta à Receita

**Base:** a entrega 17 já copiada (sem problema se ainda não fez o commit da 17).

## O que muda

No cartão **🏢 Dados da corretora**:
- **CNPJ** fica em cima, ao lado do Registro SUSEP. A 🔍 no campo consulta a Receita Federal pela BrasilAPI, a mesma consulta que o cadastro de clientes já usa.
  - antes de consultar, confere os dígitos verificadores, o que pega erro de digitação;
  - preenche a **razão social** com o que está na Receita;
  - preenche nome fantasia, endereço e telefone **só se estiverem vazios**, sem apagar o que você já digitou;
  - avisa se a empresa não estiver **ATIVA** na Receita.
- **Razão social e nome fantasia** ficam logo abaixo.
- Ao salvar, um CNPJ com dígito errado é recusado.

Os dados da Receita vêm em MAIÚSCULAS. Ajuste o endereço como quiser antes de salvar.

## Arquivos (4)

| Arquivo | O que mudou |
|---|---|
| `lib/widgets/perfil_corretora_card.dart` | Nova ordem dos campos, botão 🔍 e validação do CNPJ. |
| `lib/utils/perfil_corretora.dart` | `cnpjValido` (dígitos verificadores) e `lerReceita` (razão social, endereço montado, telefone formatado, situação). |
| `test/perfil_corretora_test.dart` | +3 testes (12 no total). |
| `README.md` | Nota da consulta e histórico 17.1. |

## Aplicar e publicar

```bash
cd ~/Projects/upgrade_seguros
unzip -o ~/Downloads/entrega-17.1.zip verificar-entrega.js
node verificar-entrega.js --antes        # 4 arquivos iguais à entrega 17
unzip -o ~/Downloads/entrega-17.1.zip 'lib/*' 'test/*' README.md
node verificar-entrega.js --analyze      # ✓ Todos
git diff lib/widgets/perfil_corretora_card.dart lib/utils/perfil_corretora.dart
flutter build web
firebase deploy --only hosting
```

## Testar

Recarregue o app (Cmd+Shift+R) e abra Configurações → 🏢 Dados da corretora:
1. **CNPJ com um dígito trocado** → 🔍: o app avisa "CNPJ inválido" e não consulta.
2. **CNPJ certo** → 🔍: a razão social é preenchida e aparece "Empresa encontrada".
3. Complete SUSEP, site e logo, e clique em **Salvar**.
4. Gere um PDF e confira o cabeçalho.

## Commit (17 e 17.1 juntos, se a 17 ainda não foi)

```bash
git add -A lib test README.md
git commit -m "Entrega 17.1: Dados da corretora com CNPJ primeiro e consulta à Receita"
GIT_ASKPASS= git push
```
