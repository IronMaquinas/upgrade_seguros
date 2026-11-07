# Entrega 03 — 🎨 Abertura com padrão visual único + CNH do motorista do terceiro

**Base:** origin/main `fdb7ce6` + Etapas 01 e 02 aplicadas.
**Sem migração, sem Firestore novo, sem deploy de Functions.** Só o app. Nenhum dado existente muda.

## O que muda na tela

1. **Veículo Segurado** ganha os mesmos títulos com ícone dos Terceiros:
   🪪 **Proprietário legal** (conforme o CRLV) → 🚗 **Veículo** → 🧍 **Motorista** (quem dirigia no momento do sinistro) → 📇 **Contato do sinistro**.
   Os campos, o botão Auto e a pergunta "O condutor é o proprietário do veículo?" funcionam como antes.
2. **Terceiros** passa a usar o mesmo campo do resto da planilha: rótulo **em cima**, caixa cinza, mesma altura e fonte. Os títulos com ícone continuam, e o terceiro ganha também o título 🚗 **Veículo**, espelhando o segurado.
3. O checkbox "O motorista é o próprio proprietário" fica no mesmo estilo do checkbox do segurado.
4. **CNH do motorista do terceiro** (novo campo), na planilha, em Adicionar/Editar Terceiro, no detalhe e no PDF.
   - Motorista diferente do proprietário: Nome | CPF | **CNH**, depois Telefone | E-mail (mesma ordem do segurado).
   - Motorista = proprietário: aparece só a **CNH**, porque o CRLV não traz a CNH.

## Arquivos (inteiros — copiar por cima)

| Arquivo | O que mudou e por quê |
|---|---|
| `lib/screens/spreadsheet_claim_screen.dart` | `_Field` ganhou `isHeader`/`headerIcon` (linha de título dentro de um grupo, desenhada pelo `_FieldCell` na cor do grupo). Veículo Segurado com 4 títulos. `_buildTerceiroField` reescrito no visual da planilha. Título "Veículo" e CNH no terceiro. Checkbox do motorista no estilo do segurado. Salva `cnhMotorista`. |
| `lib/models/third_party_model.dart` | + `cnhMotorista` (lê e grava; terceiros antigos vêm vazios). |
| `lib/widgets/terceiro_form.dart` | Diálogos Adicionar/Editar: título "Veículo", CNH e checkbox no mesmo estilo. |
| `lib/screens/claim_detail_screen.dart` | Exibição do motorista do terceiro mostra a CNH. |
| `lib/services/pdf_services.dart` | PDF do terceiro mostra a CNH do motorista. |
| `README.md` | Padrão visual da abertura (e como criar um título novo num grupo), campo `cnhMotorista`, histórico, roadmap. Só acréscimos. |
| `verificar-entrega.js` | md5 da Etapa 03 (fica fora do git). |

## Aplicar (Terminal, na raiz do projeto)

```bash
cd /Users/marcony/Projects/upgrade_seguros

unzip -o ~/Downloads/entrega-03.zip verificar-entrega.js -d .
node verificar-entrega.js --antes        # "✓ Os 6 arquivos são a base esperada"

unzip -o ~/Downloads/entrega-03.zip 'lib/*' README.md -d .
node verificar-entrega.js --analyze      # tem que terminar em "✓ Todos"
```

Se o `--antes` der ✗, **pare** e me mande o arquivo. A Etapa 02 precisa estar copiada exatamente como entreguei. Se você ajustou algo nela durante os testes, me mande o arquivo antes.

## Revisar antes do commit

```bash
git --no-pager diff --stat                                   # 6 arquivos
git --no-pager diff lib/models/third_party_model.dart        # só a CNH
git --no-pager diff lib/widgets/terceiro_form.dart
git diff lib/screens/spreadsheet_claim_screen.dart           # visual + títulos (q sai)
```

## Roteiro de teste
1. **Abertura → Veículo Segurado:** aparecem os títulos Proprietário legal / Veículo / Motorista / Contato do sinistro, com ícones verdes. O **Auto** com CRLV preenche como antes, e o checkbox do condutor copia o nome e o CPF como antes.
2. **Abertura → Terceiros:** os campos têm rótulo em cima e caixa cinza, iguais aos do segurado. Aparece o título "Veículo" antes da placa.
3. Desmarque "O motorista é o próprio proprietário": Nome | CPF | CNH e Telefone | E-mail. Marque: fica só a CNH.
4. Salve com a CNH preenchida, abra o detalhe: a CNH aparece no card Motorista do terceiro. **Gerar PDF:** a CNH aparece no grupo Motorista.
5. **Editar Terceiro** (detalhe, modo edição): título "Veículo", campo CNH e checkbox no estilo novo. Salve e confira.
6. **Celular:** abra a planilha e o diálogo de terceiro. Os títulos não quebram a tela.

## Subir

```bash
git add -u
git commit -m "Etapa 03: padrão visual único na abertura e CNH do motorista do terceiro"
git push
```

## Como foi testado aqui
- **Análise antes × depois** do projeto inteiro: zero erro ou aviso novo. Os 11 testes da Etapa 02 continuam passando.
- O visual em si (espaçamentos e cores na tela) só dá para ver rodando o app. É o roteiro acima.
