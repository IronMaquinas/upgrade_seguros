# Entrega 04 — 📎 Anexos logo após o Veículo + 🚗 Veículo Segurado espelhado no detalhe

**Base:** GitHub `7295764` (Etapas 01–03). Só o app. Sem migração e sem mudança de dados.

## O que muda

**1. Abertura do sinistro — nova ordem dos cards**
```
Apólice / Seguro
Veículo Segurado        (ou Transporte / Imóvel / Empresa / Máquina / Vida, conforme o ramo)
Anexos e Documentos     ← subiu para cá
Terceiros (Reclamados)
Danos Corporais / Danos Materiais
Acompanhamento
[Concluir e Salvar Sinistro]
```
Nos ramos sem terceiros nem danos, Anexos continua no fim, antes do botão.

**2. Visualizar Sinistro (detalhe) — Veículo Segurado espelhando a abertura**
O bloco único "Veículo" virou quatro grupos, com os mesmos ícones dos Terceiros:
- 🪪 **Proprietário legal (CRLV):** nome e CPF/CNPJ. **Antes não aparecia no detalhe**, embora fosse digitado na abertura.
- 🚗 **Veículo:** placa, marca, modelo, cor, chassi e anos (ano zerado aparece como "-").
- 🧍 **Motorista:** condutor, CPF e CNH.
- 📇 **Contato do sinistro:** nome e telefone, com botão de **WhatsApp**. Nos ramos de veículo, esse contato saiu do card "Cliente", para não aparecer duas vezes. Nos outros ramos continua no card Cliente, como antes.

Tudo continua editável no modo edição e é salvo do mesmo jeito.

## Arquivos (inteiros — copiar por cima)

| Arquivo | O que mudou e por quê |
|---|---|
| `lib/screens/spreadsheet_claim_screen.dart` | Método novo `_inserirAnexos()`: coloca o card de Anexos antes do primeiro grupo entre Terceiros/Danos/Acompanhamento. O card em si não mudou. |
| `lib/screens/claim_detail_screen.dart` | Veículo Segurado em 4 grupos (helper `_campoVeiculoSegurado` para ler/editar cada campo). Proprietário legal exibido. Contato do sinistro no grupo do veículo (com WhatsApp) e oculto no card Cliente só nos ramos de veículo. |
| `README.md` | Ordem dos cards da abertura, espelho do detalhe, histórico e roadmap. Também registra o que ficou para depois no detalhe (ordem dos cards, estilo do modo edição, cores) e a limpeza de `android/build/`. |
| `verificar-entrega.js` | md5 da Etapa 04 (fica fora do git). |

## Aplicar (Terminal, na raiz do projeto)

```bash
cd /Users/marcony/Projects/upgrade_seguros

unzip -o ~/Downloads/entrega-04.zip verificar-entrega.js -d .
node verificar-entrega.js --antes        # "✓ Os 3 arquivos são a base esperada"

unzip -o ~/Downloads/entrega-04.zip 'lib/*' README.md -d .
node verificar-entrega.js --analyze      # tem que terminar em "✓ Todos"
```

## Revisar antes do commit

```bash
git --no-pager diff --stat                                   # 3 arquivos
git --no-pager diff lib/screens/spreadsheet_claim_screen.dart   # curto: só a ordem
git diff lib/screens/claim_detail_screen.dart                # Veículo Segurado (q sai)
```

## Roteiro de teste
1. **Abertura, ramo Veículo/Frota:** Anexos e Documentos aparece logo abaixo de Veículo Segurado e acima de Terceiros. Arraste um arquivo e salve: os anexos continuam funcionando.
2. **Abertura, outro ramo** (Residencial, Transporte): Anexos aparece depois do bem segurado (Imóvel / Transporte).
3. **Detalhe de um sinistro de veículo:** os 4 grupos com ícones. O Proprietário legal mostra o nome e o CPF digitados na abertura.
4. O WhatsApp em "Contato do sinistro" abre o número certo. O card Cliente não repete o contato.
5. **Modo edição:** altere a placa, o proprietário e o telefone de contato, salve, saia e entre de novo. Os valores ficaram gravados.
6. **Detalhe de um sinistro Residencial/Empresarial:** o contato continua no card Cliente, como antes.

## Subir

```bash
git add -u
git commit -m "Etapa 04: anexos após o veículo na abertura e veículo segurado espelhado no detalhe"
GIT_ASKPASS= git push          # no terminal do VS Code
```

## Como foi testado aqui
- Análise antes × depois: zero erro ou aviso novo nos dois arquivos alterados.
- Simulação do zip em cima do GitHub atual: `--antes` ok, cópia, "✓ Todos".
