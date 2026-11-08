# Entrega 11: 🔎 busca ampla de sinistros · 🎨 seletor de recomendação · 📉 sinistralidade mensal corrigida

**Base:** GitHub `9159bd1` (Etapas 01–10). Só o app. Sem mudança no banco.

## 1. Busca da lista de Sinistros

A busca agora também procura em:

| Pedido da cliente | Campos |
|---|---|
| Número do registro na seguradora do terceiro | `registroSeguradoraTerceiro` (e o nº do sinistro do terceiro) |
| Nome do terceiro | proprietário do veículo do terceiro (nome, CPF, e-mail, placa) e o motorista dele |
| Contato do terceiro | nome e telefone do contato do terceiro, telefone do proprietário e do motorista |
| Proprietário do veículo segurado | proprietário legal / CRLV (nome e CPF/CNPJ) |
| Condutor do veículo segurado | condutor (nome e CPF); no Transporte, o motorista |
| Contato do segurado | contato do sinistro e contato no local (nome e telefone) |

Continua procurando também nº do sinistro, nº na seguradora, segurado, CPF/CNPJ e placa.

**Para facilitar quem atende o telefone o dia inteiro:**
- Não diferencia maiúscula de minúscula nem acento: "joao" acha "João".
- Aceita várias palavras em qualquer ordem: "silva joão" acha "João da Silva".
- Telefone, CPF e registro, a partir de 4 dígitos, são comparados só pelos números. "99863-8469", "27998638469" e "(27) 99863 8469" se acham entre si.

**Limite:** a busca vale para o que está carregado na lista. Com o filtro "Em curso" (o padrão), sinistros já finalizados só aparecem trocando o filtro para "Todos". Se a equipe sentir falta, dá para a busca carregar o histórico sozinha quando não achar nada em curso. Fica como sugestão.

## 2. Filtro de recomendação: novo visual

Os chips coloridos viraram um **seletor no mesmo padrão dos filtros da lista de Sinistros**: contorno cinza, fundo branco, ícone à esquerda. Ele fica **ao lado da busca**, na mesma linha, como os filtros de Sinistros.
- Cada opção tem a bolinha da cor da recomendação e a quantidade, por exemplo "● Não recomendado (5)".
- A primeira opção é "Todas as recomendações (271)".
- A ligação com o "Exportar relatório" continua igual.
- Em tela estreita (celular), o seletor fica embaixo da busca.

## 3. Sinistralidade Mensal: era erro de fórmula

A conta era: **sinistros do mês ÷ soma ANUAL de todas as apólices vigentes hoje**. Ela tinha três problemas:
1. Comparava **um mês** de sinistros com **um ano inteiro** de apólice, o que dá cerca de 1/12 do valor real.
2. O denominador incluía os valores inflados de apólice (os R$ 10 bi da auditoria). Com um denominador desse tamanho, qualquer sinistro vira 0,00…%. Por isso a linha ficava colada no zero.
3. Usava as apólices vigentes **hoje**, não as que estavam vigentes em cada mês.

**Agora** (regra em `lib/utils/sinistralidade.dart`, com 10 testes) a conta é a de mercado: **sinistralidade = sinistros ÷ prêmio ganho**.
- **Prêmio ganho no mês:** cada apólice "ganha" seu valor de forma proporcional aos dias de vigência dentro do mês. Uma apólice anual de R$ 120.000 ganha cerca de R$ 10.000 por mês enquanto está vigente.
- **Sinistros do mês:** valor total dos sinistros **ocorridos** no mês, sem Cancelado/Negado (mesma regra do gatilho).
- **Duas linhas:** 🟠 **Mensal** e 🔵 **Acumulado no ano** (janeiro até o mês). O acumulado é o número para comparar com a **linha tracejada vermelha do gatilho** (70%, ou o % das Configurações).
- **Linha embaixo do título:** mostra a conta do acumulado, por exemplo "Acumulado até Nov: 38,2% (R$ 412.000 ÷ R$ 1.078.000)". Assim dá para conferir o número na hora.

**Para os números ficarem certos, dois cuidados com os dados:**
- **Valor das apólices:** apólice com valor inflado ainda distorce o denominador. O relatório de clientes ordenado por valor (Etapa 08) mostra quais corrigir.
- **Valor dos sinistros:** sinistro aberto sem valor lançado conta como R$ 0. Se a equipe só lança o valor no fim, a linha do mês corrente fica baixa até lá.

**Ainda com a conta antiga** (fora do pedido, anotado no roadmap): o KPI "Sinistralidade (%)" do topo dos Relatórios e a sinistralidade por seguradora. Alinhar os dois com a mesma regra é pequeno, se quiser.

## Arquivos

| Arquivo | Novo? | O que mudou |
|---|---|---|
| `lib/utils/busca.dart` | **novo** | Busca tolerante: acento, várias palavras, dígitos. |
| `test/busca_test.dart` | **novo** | 6 testes. |
| `lib/screens/claim_list_screen.dart` | alterado | `_camposParaBusca` com todos os campos da tabela acima e uso da `Busca`. Texto de dica da busca. |
| `lib/screens/client_list_screen.dart` | alterado | Seletor de recomendação no lugar dos chips, ao lado da busca (embaixo em tela estreita). |
| `lib/utils/sinistralidade.dart` | **novo** | Prêmio ganho por dia de vigência, sinistralidade mensal e acumulada. |
| `test/sinistralidade_test.dart` | **novo** | 10 testes (prêmio ganho, mensal, acumulado, cancelado, mês sem apólice, ano passado/futuro). |
| `lib/screens/reports_screen.dart` | alterado | Calcula com a regra nova. Gráfico com as linhas Mensal e Acumulado, a linha do gatilho, a legenda e a conta do acumulado. |
| `README.md` | alterado | Busca de Sinistros, Sinistralidade Mensal, histórico e roadmap. |
| `verificar-entrega.js` | (fora do git) | Etapa 11. |

## Aplicar (Terminal, na raiz do projeto)

```bash
cd /Users/marcony/Projects/upgrade_seguros

unzip -o ~/Downloads/entrega-11.zip verificar-entrega.js -d .
node verificar-entrega.js --antes            # "✓ Os 8 arquivos são a base esperada"

unzip -o ~/Downloads/entrega-11.zip 'lib/*' 'test/*' README.md -d .
node verificar-entrega.js --analyze          # tem que terminar em "✓ Todos"
```
> Se o Safari abriu o zip sozinho: `cp -R ~/Downloads/entrega-11/lib ~/Downloads/entrega-11/test ~/Downloads/entrega-11/README.md ~/Downloads/entrega-11/verificar-entrega.js .` no lugar dos dois `unzip`.

## Revisar antes do commit

```bash
git --no-pager diff --stat HEAD
git --no-pager diff HEAD -- lib/screens/claim_list_screen.dart lib/screens/client_list_screen.dart
git diff HEAD -- lib/screens/reports_screen.dart
```
Vale ler `lib/utils/sinistralidade.dart` inteiro (cerca de 100 linhas, comentadas): é a definição de sinistralidade que você vai defender com a cliente.

## Roteiro de teste

1. **Sinistros:** busque pelo nome do condutor de um sinistro, depois pelo telefone do contato do terceiro **sem a máscara** e pelo registro na seguradora do terceiro. O sinistro aparece nos três casos. Busque o nome sem acento.
2. **Clientes:** o seletor "Todas as recomendações (N)" aparece ao lado da busca. Escolha "Não recomendado": a lista filtra. Exportar → o arquivo sai com o filtro, como antes.
3. **Relatórios → gráfico "Sinistralidade Mensal":** aparecem as linhas laranja (mensal) e azul (acumulado) e a tracejada vermelha do gatilho. Confira a conta mostrada embaixo do título.
4. Se o acumulado parecer baixo demais: exporte o relatório de clientes e veja se ainda há apólice com valor inflado no topo.

## Subir

```bash
git add lib/utils/busca.dart lib/utils/sinistralidade.dart test/busca_test.dart test/sinistralidade_test.dart
git add -u
git commit -m "Etapa 11: busca ampla de sinistros; seletor de recomendação; sinistralidade mensal por prêmio ganho"
GIT_ASKPASS= git push
```

## Como foi testado aqui
- Análise antes × depois contra o GitHub `9159bd1`: nenhum erro ou aviso novo. Desde esta etapa o ambiente daqui também confere o `fl_chart` (v0.71.0, a do seu `pubspec.lock`), então o gráfico novo foi checado tipo a tipo.
- 6 + 10 testes novos e todos os anteriores passando.
- Simulação no clone do GitHub: `--antes`, cópia, verificador terminando em "✓ Todos".
