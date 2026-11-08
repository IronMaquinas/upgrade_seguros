# Entrega 08: 🔍 apólice clicável no Detalhes · ⏱️ SLA RCO/Empresarial · 📊 relatório de clientes · 🧹 .gitignore

**Base:** GitHub `7301670` (Etapas 01–07). Só o app. Sem migração: o SLA de RCO e Empresarial aparece com o padrão (7 e 10) e é gravado no Firestore na primeira vez que você alterar qualquer SLA de sinistro na tela.

## 1. O erro do `.gitignore`: o que aconteceu

O `.gitignore` **estava** no zip das Etapas 06 e 07. Só que no Mac **arquivo com nome começando por ponto fica escondido no Finder** (para ver: Cmd+Shift+.). Quem copia os arquivos pelo Finder não leva o `.gitignore`. Por isso ele nunca chegou ao projeto, e o `node_modules/` (15 mil arquivos) e o `android/build/` continuam no GitHub.

A correção não depende mais do zip:
- O `.gitignore` **não vem mais no zip**. O passo abaixo acrescenta as duas linhas com um comando.
- O verificador confere o `.gitignore` **pelo conteúdo** (tem que ter `verificar-entrega.js`, `node_modules/` e `android/build/`). Ele não exige mais o arquivo idêntico, então você pode ter outras linhas suas.
- `node_modules/` ou `android/build/` ainda no git agora dá **✗** (antes era só aviso ⚠️).

## 2. Apólice clicável no Detalhes do Cliente

Na tela **Detalhes do Cliente**, clicar em uma apólice de "Apólices por Ramo" abre a **visualização** com ramo, seguradora, número, valor, gatilho (com a legenda "70% do valor da apólice" ou "Valor do contrato"), vigência e bens segurados com os documentos. Não é mais preciso entrar em "Editar Cliente".
- **Fechar** volta para o detalhe.
- **Editar** abre o cadastro do cliente **já com a edição daquela apólice aberta**. Depois de "Atualizar", ainda é preciso **Salvar o cliente**, como sempre.
- O cabeçalho da apólice ganhou um ícone de 👁 para indicar que é clicável.

A visualização virou **um componente só** (`lib/widgets/apolice_visualizacao_dialog.dart`), usado no Detalhes e no cadastro. Antes ela era um "modo leitura" dentro do diálogo de edição. O diálogo de edição voltou a ser só edição.

## 3. SLA de sinistro: Civil Ônibus (RCO) = 7 e Empresarial = 10

Em Configurações → SLAs → *Tempo Padrão para Resolução de Sinistros*, aparecem agora **🚌 Civil Ônibus (RCO)** e **🏢 Empresarial**, na ordem dos ramos. Na abertura, "Dias para Encerramento" passa a vir com 7 e 10. Antes vinha **10** para os dois, o valor "reserva" de quando o ramo não existe na configuração.

**Correção junto:** os sinistros de vida gravam o ramo **"Vidas"**, e o SLA estava salvo como **"Vida"**. Nunca batiam, e a abertura usava o 10 reserva. Agora "Vidas" usa o SLA de "Vida". Se você mudar o SLA de Vida, a abertura passa a respeitar.

Observação: no sistema o ramo se chama **"Civil Ônibus (RCO)"** (você escreveu ROC). Mantive o nome que já existe nos sinistros, senão o SLA não casaria.

## 4. Relatório de clientes (auditoria)

Na **lista de clientes**, há um botão novo **⬇** na barra de cima (ao lado do "Atualizar"), com duas opções:
- **Planilha (CSV / Excel)**: abre direto no Excel em português. Os números saem sem ponto de milhar e com vírgula decimal, então somam e dá para filtrar.
- **PDF**: A4 deitado, cabeçalho repetido em cada página, total no final.

O relatório traz os clientes da lista (todos, ou só os da busca, se houver texto na busca), **ordenados pelo valor total das apólices**, com uma linha de TOTAL no fim:

| Coluna | Como é calculada |
|---|---|
| Cliente / CNPJ-CPF | Do cadastro |
| Valor total das apólices | Soma de **todas** as apólices do cliente, vigentes ou não. É o mesmo "Total das Apólices" do Detalhes |
| Qtd. apólices | Todas as cadastradas |
| **Maior apólice (nº e R$)** | Coluna a mais, para achar o erro de digitação: um cliente com R$ 10 bi vai aparecer **na primeira linha**, com o número da apólice culpada |
| Qtd. sinistros | Todos os do cliente, inclusive cancelados |
| Valor total utilizado | Soma dos sinistros **sem Cancelado/Negado** (mesma regra do gatilho) |
| % da apólice usada | Utilizado ÷ valor total das apólices |
| Qtd. assistências | Todas as do cliente |

**Sobre os R$ 10 bi:** o total do relatório deve bater com a soma das apólices do sistema. Ordenando por valor, as apólices com valor errado ficam no topo. Corrija cada uma no cadastro: depois da Etapa 07 o campo já mostra o valor em R$, e o erro fica visível na tela.

Registros sem cliente vinculado (`id_cliente` vazio) não entram.

## Arquivos

| Arquivo | Novo? | O que mudou |
|---|---|---|
| `lib/widgets/apolice_visualizacao_dialog.dart` | **novo** | Visualização da apólice (somente leitura), componente único. Devolve "quer editar?" para quem chamou. |
| `lib/screens/client_detail_screen.dart` | alterado | Apólice clicável (abre a visualização); `_editClient` aceita a apólice a editar; ícone 👁 no cabeçalho. |
| `lib/screens/client_form_screen.dart` | alterado | Novo parâmetro `editarApoliceId` (abre a edição daquela apólice ao entrar). O clique no cartão usa o componente novo. O diálogo de edição perde o modo leitura da Etapa 07 (volta a ser só edição). |
| `lib/models/config_model.dart` | alterado | `slaSinistrosPadrao` com os 8 ramos (RCO 7, Empresarial 10), `mesclarSlaSinistros` (salvo + padrões) e `chaveSlaRamo` ("Vidas" → "Vida"). |
| `lib/services/config_service.dart` | alterado | Leitura e gravação do SLA de sinistro usam `chaveSlaRamo`. |
| `lib/screens/settings_screen.dart` | alterado | Ícones 🚌 e 🏢 dos ramos novos. |
| `lib/utils/relatorio_clientes.dart` | **novo** | Regra do relatório (linhas, ordem, totais) e geração do CSV. Dart puro. |
| `lib/services/relatorio_clientes_pdf.dart` | **novo** | PDF do relatório com os mesmos números. |
| `lib/screens/client_list_screen.dart` | alterado | Botão ⬇ com CSV/PDF. Baixa sinistros e assistências só na hora de exportar. |
| `test/relatorio_clientes_test.dart` | **novo** | 6 testes (ordem, maior apólice, cancelado/negado, sem valor, CSV, proteção contra fórmula). |
| `test/config_sla_test.dart` | **novo** | 4 testes (documento antigo ganha RCO/Empresarial, ordem, mapa alterável, Vidas→Vida). |
| `README.md` | alterado | Seções do relatório e do SLA por ramo, verificador e `.gitignore`, armadilha do import resolvida, histórico, roadmap. |
| `verificar-entrega.js` | (fora do git) | Etapa 08 + `.gitignore` por conteúdo + `node_modules`/`android/build` no git = ✗. |

## Aplicar (Terminal, na raiz do projeto)

```bash
cd /Users/marcony/Projects/upgrade_seguros

unzip -o ~/Downloads/entrega-08.zip verificar-entrega.js -d .
node verificar-entrega.js --antes            # "✓ Os 12 arquivos são a base esperada"

unzip -o ~/Downloads/entrega-08.zip 'lib/*' 'test/*' README.md -d .

# Pendente desde a Etapa 06 (agora sem depender do zip):
printf '\nnode_modules/\nandroid/build/\n' >> .gitignore
git rm -r --cached --quiet node_modules android/build    # sai do git, continua no disco

node verificar-entrega.js --analyze          # tem que terminar em "✓ Todos"
```

> Se o Safari abriu o zip sozinho (aparece a pasta `entrega-08` em Downloads, sem o `.zip`), use `cp -R ~/Downloads/entrega-08/lib ~/Downloads/entrega-08/test ~/Downloads/entrega-08/README.md ~/Downloads/entrega-08/verificar-entrega.js .` no lugar dos dois `unzip`.

Avisos ⚠️ antigos que continuam e são esperados: `latlong2` (no `workshop_widget.dart`) e o token do Telegram (S1).

## Revisar antes do commit

```bash
git --no-pager diff --stat HEAD
git --no-pager diff HEAD -- .gitignore lib/models/config_model.dart lib/services/config_service.dart
git --no-pager diff HEAD -- lib/screens/client_detail_screen.dart lib/screens/client_list_screen.dart
git diff HEAD -- lib/screens/client_form_screen.dart
```
O `--stat` vai listar uns 15 mil arquivos apagados (`node_modules/…` e `android/build/…`). Eles saem **só do git**: os arquivos continuam na sua pasta, e o `.gitignore` impede que voltem.

## Roteiro de teste

1. **Detalhes do Cliente** (ex.: MAIS ALIMENTOS): clique na apólice Frota 31.69.2026.0488237. Abre a visualização com R$ 59.611,01 e gatilho R$ 41.727,71 "70% do valor da apólice". Clique em **Fechar**.
2. Clique de novo e escolha **Editar**: abre o cadastro com o diálogo "Editar Apólice" já aberto. Cancele e volte.
3. **Cadastro do cliente**: clicar no cartão da apólice abre a mesma visualização. O lápis continua abrindo direto a edição.
4. **Configurações → SLAs**: aparecem 🚌 Civil Ônibus (RCO) **7** e 🏢 Empresarial **10**. Mude um deles e confira que fica salvo ao reabrir.
5. **Abertura de sinistro** com um cliente de RCO: "Dias para Encerramento" = **7**. Com Empresarial: **10**.
6. **Lista de clientes → ⬇ → Planilha**: abra no Excel. Os clientes vêm do maior valor para o menor, os acentos aparecem certos e a última linha é o TOTAL. Some a coluna de valor e compare com o total.
7. **⬇ → PDF**: mesmo conteúdo, cabeçalho em todas as páginas.
8. Digite um nome na busca e exporte: só os clientes da busca, com um aviso.

## Subir

```bash
git add lib/widgets/apolice_visualizacao_dialog.dart lib/utils/relatorio_clientes.dart lib/services/relatorio_clientes_pdf.dart test/relatorio_clientes_test.dart test/config_sla_test.dart .gitignore
git add -u
git commit -m "Etapa 08: apólice clicável no detalhe, SLA RCO/Empresarial, relatório de clientes; node_modules e android/build fora do git"
GIT_ASKPASS= git push
```
O push vai ser maior que o normal por causa da remoção dos 15 mil arquivos (só a remoção, sem conteúdo novo).

## Como foi testado aqui
- Análise antes × depois dos arquivos alterados: nenhum erro ou aviso novo.
- Testes: 6 + 4 novos, mais os 26 anteriores, todos passando.
- PDF e CSV gerados aqui com 45 clientes de exemplo (um deles com R$ 9,8 bi, que foi para a primeira linha). Conferi o PDF página por página: acentos, cabeçalho repetido, total.
- Simulação no clone do GitHub: `--antes`, cópia, `printf` + `git rm --cached`, verificador terminando em "✓ Todos".
