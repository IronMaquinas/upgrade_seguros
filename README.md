# Upgrade Seguros — SaaS de Gestão para Corretoras

> Plataforma web/mobile para corretoras de seguros gerenciarem sinistros, assistências, clientes, tarefas e métricas de desempenho em tempo real.

**Versão do documento:** Etapa 16b (GitHub `99cc809` = Etapas 01–16)
**Última atualização:** 08/11/2026
**Status:** app em uso; ciclo de entregas com verificação por md5 em andamento. Etapa 02: terceiros identificados por personagem (proprietário / motorista / contato) e **histórico de valores do sinistro** (lançamentos com nota fiscal, segurado + terceiros). Pendências de segurança abertas — ver [🔐 Pendências de Segurança](#-pendências-de-segurança).

---

## 📋 Índice

1. [Stack Tecnológica](#stack-tecnológica)
2. [Navegação Principal](#navegação-principal)
3. [Tipos de Registro](#tipos-de-registro)
4. [Fluxos de Sinistros e Assistências](#fluxo-de-sinistros)
   - [Terceiros (Reclamados)](#terceiros-reclamados)
   - [Valores do Sinistro — histórico de lançamentos](#valores-do-sinistro--histórico-de-lançamentos)
   - [Listas — filtro de status "Em curso"](#listas--filtro-de-status-em-curso)
   - [Gatilho da apólice](#gatilho-da-apólice)
5. [Dashboard e Relatórios](#dashboard--painéis-de-gestão)
6. [Estrutura de Dados (Firestore)](#estrutura-de-dados-firestore)
7. [Cloud Functions](#cloud-functions-nodejs)
8. [🔐 Pendências de Segurança](#-pendências-de-segurança)
9. [⚠️ Armadilhas Conhecidas](#️-armadilhas-conhecidas)
10. [🧪 Processo de Entrega e Verificação](#-processo-de-entrega-e-verificação)
11. [📦 Histórico de Entregas](#-histórico-de-entregas)
12. [⚠️ Questão Aberta — Apólices por Ramo](#️-questão-aberta--apólices-por-ramo)
13. [🗺️ Roadmap](#️-roadmap)

---

## Stack Tecnológica

| Camada | Tecnologia |
|---|---|
| Frontend | Flutter Web + Mobile |
| Backend | Firebase (Firestore + Storage + Auth) |
| Cloud Functions | Node.js |
| Mapas / Endereços | Google Places SDK + Google Maps Flutter |
| Gráficos | fl_chart (LineChart, BarChart, PieChart) |
| PDF | `pdf` + `printing` |
| Notificações | Web Notifications API (browser) |
| NPS | Link único via WhatsApp / Email (Gmail) |

---

## Navegação Principal

| Tela | Descrição |
|---|---|
| **Início (Dashboard)** | KPIs executivos, alertas de prazo, assistências ativas, NPS |
| **Sinistros** | Lista, filtros, abertura de novos registros |
| **Assistências** | Lista veicular e residencial, SLA countdown |
| **Clientes** | Cadastro, apólices, veículos, ramos, NPS score |
| **Tarefas** | Acompanhamento operacional com prazos |
| **Relatórios** | Analytics com 10 gráficos + exportação PDF |
| **Configurações** | Perfil e preferências do usuário |

---

## Tipos de Registro

### Sinistros
| Ramo | Subtipos / Observações |
|---|---|
| Veículo Individual | Vidros com múltipla seleção de peças |
| Frota | — |
| Transporte | — |
| Máquinas e Equipamentos | — |
| Residencial | — |
| Vida | — |

**Subtipos de vidro (seleção múltipla):** Para-brisa · Farol · Retrovisor · Lanterna · Vidro Lateral · Vidro Traseiro · Farol de Milha · Pequenos Reparos · Outro (campo livre)

---

### Assistências Veiculares
| Tipo | Código |
|---|---|
| Guincho | `guincho` |
| Vidro Quebrado | `vidro` |
| Combustível | `combustivel` |
| Pane Elétrica | `pane_eletrica` |
| Carga de Bateria | `carga_bateria` |
| Falta de Peça | `falta` |
| Reboque | `reboque` |
| Outro | `outro` |

**Número gerado:** `AS{YYYYMMDDHHMMSS}`

---

### Assistências Residenciais
| Tipo | Código |
|---|---|
| Eletricista | `eletricista` |
| Encanador | `encanador` |
| Reparo de Equipamentos | `reparo_equipamentos` |
| Chaveiro | `chaveiro` |
| Vidraceiro | `vidraceiro` |
| Pintura | `pintura` |
| Limpeza | `limpeza` |
| Outro | `outro` |

**Número gerado:** `AR{YYYYMMDDHHMMSS}`

---

## Formulários de Entrada

| Arquivo | Finalidade |
|---|---|
| `spreadsheet_claim_screen.dart` | Sinistro completo — planilha inteligente com todas as seções |
| `quick_claim_screen.dart` | Sinistro rápido simplificado |
| `spreadsheet_assist_screen.dart` | Assistência veicular completa |
| `spreadsheet_assist_residencial_screen.dart` | Assistência residencial |
| `client_form_screen.dart` | Cadastro de cliente / empresa + seletor de ramos |

---

## Estrutura do Código (`lib/`)

| Pasta | Conteúdo |
|---|---|
| `screens/` | Telas (19): dashboard, sinistros, assistências veicular/residencial, clientes, tarefas, relatórios, NPS, usuários, configurações, login/cadastro |
| `widgets/` | Componentes reutilizáveis (timer de SLA, busca de cliente, oficina, NPS, desempenho por funcionário, vigência) |
| `models/` | Modelos de dados (claim, client, apólice, veículo, residência, vida, transporte, máquinas, terceiros, oficina, config de SLA…) |
| `services/` | Firestore, Storage, Auth, biometria, PDF (sinistro, relatório, assinatura; cabeçalho/rodapé padrão em `marca_pdf.dart`), NPS, monitor de SLA, notificações, imagem (mobile/web) |
| `parsers/` | Leitura de apólice em PDF por seguradora: Tokio Marine, Porto Seguro, Ezze, AXA (`ParserFactory` escolhe pelo texto) |
| `helpers/`, `dialogs/`, `formatter/`, `utils/` | Assinatura em PDF, seleção de apólice, máscaras e formatação, constantes |

---

## Gestão de Clientes

- **Busca automática de CNPJ** via BrasilAPI (preenche nome e sócio)
- **CNPJ alfanumérico** (padrão julho/2026)
- **Validação de duplicata** de CNPJ/CPF
- **Veículos segurados**: marca / modelo / cor / ano fabricação / ano modelo / placa / chassi + fotos
- **Ramos de Seguro**: Seleção múltipla com chips visuais (🚗 Veículo · 🏠 Residencial · 🚚 Frota · ⚙️ Máquinas · 💓 Vida · 📦 Transporte · 🚌 Civil Ônibus (RCO) · 🏢 Empresarial)
- **Vigência de apólice** com alerta de vencimento (badge laranja nos últimos 30 dias)
- **Recomendação do cliente**: Ótimo / Regular / Atenção / Não recomendado pelo **uso do gatilho** da pior apólice vigente; selo cinza "Sem apólice vigente" / "Apólice sem valor" (Etapa 09). Ver [Recomendação do cliente](#recomendação-do-cliente)
- **NPS Score** acumulado por cliente (−100 a +100)
- **Valor da apólice** e **valor gatilho**
- **Apólice clicável** no Detalhes do Cliente e no cadastro: abre a visualização (somente leitura) com "Editar" — componente único `lib/widgets/apolice_visualizacao_dialog.dart` (Etapa 08). No Detalhes, "Editar" abre o cadastro já na edição daquela apólice (depois de "Atualizar", ainda é preciso **salvar o cliente**).
- **Importar contrato (PDF)** — botão com texto na barra do cadastro (antes só ícone; Etapa 09).
- **Relatório de clientes (auditoria)** — botão "Exportar relatório" na barra da lista de clientes, em CSV (Excel) ou PDF (Etapa 08). Ver [Relatório de clientes](#relatório-de-clientes-auditoria).

---

## Fluxo de Sinistros

```
Abertura (quick ou planilha)
    ↓
Em Análise → Aguardando Aprovação → Aprovado
    ↓
Reparo em Andamento → Concluído [dataConclusao = Timestamp.now()]
    ou
Negado / Cancelado
```

**Auditoria completa:** cada mudança de status registra data, hora e responsável no histórico.

**Encerramento (Etapa 02):** ao escolher "Concluído", o sistema mostra o resumo dos lançamentos (segurado, terceiros, total). Sem nenhum valor lançado, não encerra: oferece "Novo lançamento". Sinistros antigos, com valor digitado antes do histórico, encerram normalmente.

---

## Terceiros (Reclamados)

Cada terceiro é identificado por personagem (Etapa 02), na abertura (planilha), nos diálogos "Adicionar/Editar Terceiro" e no PDF:

| Grupo | Campos |
|---|---|
| **Proprietário do veículo** (conforme CRLV) | Nome, CPF/CNPJ, telefone, e-mail, endereço, placa, chassi, marca, modelo, cor, ano fabricação, ano modelo |
| **Motorista** | "O motorista é o próprio proprietário" **ou** nome, CPF, telefone, e-mail. **CNH** sempre (Etapa 03), inclusive quando é o proprietário |
| **Contato** | Nome e telefone de quem a corretora aciona |
| **Sinistro do terceiro** | Nº do registro na seguradora do terceiro, relato |
| **Valores pagos a este terceiro** | Subtotal dos lançamentos do terceiro (ver abaixo) |

- O botão **Auto** (CRLV) preenche o proprietário (nome/CPF do CRLV) e o veículo; a pergunta "condutor é o proprietário?" marca o grupo Motorista.
- Cada terceiro tem um `id` estável, que liga os lançamentos de valor a ele. Terceiros antigos ganham o `id` no primeiro lançamento.
- **Padrão visual (Etapa 03):** a planilha de abertura usa o mesmo campo em todos os grupos (rótulo em cima, caixa cinza) e os mesmos títulos com ícone. Veículo Segurado e Terceiros ficam espelhados: 🪪 Proprietário (CRLV) → 🚗 Veículo → 🧍 Motorista → 📇 Contato. Para um título novo dentro de um grupo da planilha, use `_Field(isHeader: true, headerIcon: …, label: …, hint: subtítulo)`.
- **Ordem dos cards na abertura (Etapa 04):** Apólice/Seguro → bem segurado (Veículo Segurado, Transporte, Imóvel, Empresa, Máquina ou Vida) → **Anexos e Documentos** → Terceiros → Danos → Acompanhamento → *Concluir e Salvar*. A regra fica em `_inserirAnexos()`: Anexos entra antes do primeiro grupo entre terceiros/danos/acompanhamento.
- **Detalhe do sinistro (Etapa 04):** o Veículo Segurado espelha a abertura — Proprietário legal (CRLV) / Veículo / Motorista / Contato do sinistro, com os mesmos ícones. O Proprietário legal passou a aparecer (antes não era exibido). Nos ramos de veículo, o contato do sinistro saiu do card Cliente e foi para "Contato do sinistro" (com WhatsApp).

---

## Valores do Sinistro — histórico de lançamentos

Seção **Valores do Sinistro** no detalhe do sinistro (Etapa 02). Cada custo vira um **lançamento**:

| Campo | Exemplo |
|---|---|
| Data do evento | 10/10/2026 |
| A quem se refere | Segurado **ou** um terceiro |
| Tipo | Reparo · Peças · Mão de obra · Indenização · Guincho/Remoção · Locação de veículo · Honorários/Perícia · Outro |
| Valor | R$ 1.200,00 |
| Descrição | "Troca do para-choque — NF 1234 — Oficina X" |
| Nota fiscal / evidências | PDF, imagem, XML (Storage: `sinistros/{numero}/lancamentos/`) |
| Registrado por / em | automático |

**Regras:**
- **Total do sinistro = soma dos lançamentos ativos (segurado + terceiros).** É o `valor_total_sinistro`, então sinistralidade, dashboard, relatórios e total por cliente passam a incluir o que foi pago a terceiros. Subtotais em `valor_segurado` e `valor_terceiros`.
- **Nada é apagado nem editado.** Lançamento errado → **Cancelar** com motivo obrigatório: fica riscado no histórico com quem/quando/motivo e deixa de somar. Depois lança-se o correto.
- **Valor da abertura:** o "Valor do Sinistro" digitado na planilha de abertura vira o 1º lançamento ("Valor informado na abertura", do segurado). O alerta de gatilho da apólice continua. Quando os custos reais forem lançados, cancele esse lançamento com o motivo "substituído pelos lançamentos reais".
- **Sinistros antigos** (valor digitado antes do histórico): o valor aparece como "registrado antes do histórico" e, no primeiro lançamento novo, entra no histórico como "Valor registrado antes do histórico" — o total continua batendo.
- O campo "Valor Total do Sinistro" do detalhe passou a ser **somente leitura** (calculado).
- Gravação por **transação** do Firestore: dois usuários lançando ao mesmo tempo não se sobrescrevem.
- **PDF do sinistro:** nova seção "Valores do Sinistro" (totais + tabela do histórico, cancelados riscados, nomes das NFs). **Excel (CSV):** colunas valor segurado, valor terceiros e quantidade de lançamentos.

---

## Listas — filtro de status "Em curso"

Sinistros e Assistências usam a mesma regra (Etapa 05, `lib/utils/filtro_status.dart`):

| Opção | Mostra |
|---|---|
| **Em curso** (padrão ao abrir) | Tudo que não está finalizado. Sinistros: Rascunho, Aberto, Vistoria em Andamento, Aguardando Aprovação, Aguardando Peças, Reparo em Andamento. Assistências: Aberto, Em Andamento, Aguardando Cliente |
| **Todos** | Todos mesmo, inclusive Concluído e Cancelado |
| Um status | Só ele |

**Finalizados:** `Concluído`, `Cancelado`, `Negado` (`FiltroStatus.finalizados`).

**Carregamento:** a tela abre buscando no Firestore **só o que está em curso** (`where status_atual not-in finalizados`, sem `orderBy` → não precisa de índice composto; a ordenação é feita no app). O histórico só é baixado quando o filtro pede ("Todos" ou um status finalizado), com o aviso "Carregando histórico…", e fica em memória enquanto a tela estiver aberta.

### Busca da lista de Sinistros (Etapa 11)
A busca procura em: nº do sinistro, nº na seguradora, segurado (nome, CPF/CNPJ), placa, **proprietário (CRLV) e condutor do veículo segurado** (nome e CPF; motorista do transporte), **contato do segurado** (contato do sinistro e contato no local, nome e telefone) e, em cada **terceiro**: proprietário (nome, CPF, telefone, e-mail, placa), motorista (nome, telefone), contato (nome, telefone), **registro na seguradora do terceiro** e nº do sinistro do terceiro.
- Regra em `lib/utils/busca.dart` (teste `test/busca_test.dart`): sem diferença de maiúscula/acento; várias palavras em qualquer ordem; a partir de 4 dígitos compara só os números (telefone com ou sem máscara, CPF, registro).
- A busca vale para o que está carregado: com o filtro "Em curso", sinistros finalizados só aparecem trocando para "Todos".

---

## Gatilho da apólice

O **gatilho** é o valor de sinistros, dentro da vigência da apólice, a partir do qual o uso do seguro fica crítico (a corretora pode recomendar não acionar). Regra única em `lib/utils/gatilho.dart` (Etapa 07):

| Situação | Gatilho que vale |
|---|---|
| Contrato informa o valor | O valor informado na apólice |
| Contrato não informa (campo vazio, R$ 0,00 ou R$ 0,01) | **% padrão da corretora × valor da apólice** |

- **% padrão:** Configurações → Funcionalidades → *Gatilho padrão da apólice* (padrão **70%**; campo `percentualGatilhoPadrao` em `app_config/config`).
- **Cadastro da apólice:** valores em R$; ao digitar o valor da apólice, o gatilho é **sugerido** com o % padrão. Se o usuário digitar outro valor, ele passa a valer como "valor do contrato"; apagando o campo, volta a sugestão. O valor salvo fica gravado na apólice.
- **Visualização:** clicar na apólice (no Detalhes do Cliente ou no cadastro) abre o modal em modo leitura, com botão "Editar" (Etapa 08: componente único `apolice_visualizacao_dialog.dart`).
- **Uso do gatilho** = soma de `valor_total_sinistro` dos sinistros **ligados à apólice** (`apolice_id`), **ocorridos dentro da vigência** e **não cancelados/negados**, ÷ gatilho efetivo. Mesma regra no alerta do "Valor do Sinistro" na abertura. O **Top 10 de risco** (Relatórios) usa, desde a Etapa 10, a regra da [Recomendação do cliente](#recomendação-do-cliente) (só apólices vigentes, sinistros sem vínculo ligados por ramo + data, pior apólice), com os mesmos nomes: 🔴 Não recomendado / 🟠 Atenção / 🟡 Regular / 🟢 Ótimo.
- Status: 🔴 > 100% (estourou) · 🟠 ≥ 80% · 🟡 ≥ 60%.

---

## Recomendação do cliente

Regra única em `lib/utils/recomendacao_cliente.dart` (Etapa 09; teste `test/recomendacao_cliente_test.dart`), usada pela lista de clientes, pelo Detalhes do Cliente e pelo encerramento do sinistro (que grava `recomendacao_manutencao`). Ponte com os modelos: `lib/services/recomendacao_service.dart`; selo e cores: `lib/widgets/recomendacao_chip.dart`.

1. Só contam as apólices **vigentes hoje** (início ≤ hoje ≤ fim). Nenhuma → **Sem apólice vigente** (cinza). Vigente sem valor e sem gatilho → **Apólice sem valor** (cinza).
2. Para cada apólice vigente: **uso do gatilho** = sinistros da vigência, sem Cancelado/Negado ÷ gatilho efetivo (mesma regra do [Gatilho da apólice](#gatilho-da-apólice)). Sinistro **sem vínculo** com apólice (ou ligado a apólice apagada) conta na apólice do **mesmo ramo** cuja vigência cobre a data — só no cálculo, nada é gravado. "Vidas" (sinistro) = "Vida" (apólice).
3. Vale a **pior** apólice do cliente:

| Uso do gatilho | Recomendação |
|---|---|
| < 60% | 🟢 Ótimo |
| 60% a < 80% | 🟡 Regular |
| 80% a 100% | 🟠 Atenção |
| > 100% | 🔴 Não recomendado |

- Acima do gatilho e acima do próprio **valor da apólice** são ambos "Não recomendado"; o Detalhes do Cliente mostra ao lado do selo os dois números (ex.: "Uso do gatilho: 283% · 198% do valor da apólice (Frota 31.69…) — acima do valor da apólice").
- Antes da Etapa 09 havia 4 contas diferentes (lista e detalhe: todos os sinistros ÷ 100% das apólices vigentes; salvar cliente: quantidade de sinistros; encerrar sinistro: outra faixa e outros rótulos) e cliente sem apólice vigente aparecia "Não recomendado" mesmo sem sinistros.

---

## Fluxo de Assistências

```
Abertura (veicular ou residencial)
    ↓ SLA countdown inicia (padrão 30min, configurável)
Aberto
    ↓ Funcionário encontra prestador
Em Andamento → define tempo de chegada → novo SLA countdown
    ↓
Concluído [dataConclusao = Timestamp.now()] / Cancelado
```

**Reagendamento:** cria nova tarefa automaticamente, registra `Reagendamento #N` no histórico, conclui tarefa anterior. Alerta visual a partir do 2º reagendamento.

---

### Valores da assistência (Etapa 19a)
- **Abertura (planilha veicular):** campo opcional **"Valor do serviço"** ao lado da Franquia. Preenchido, vira o 1º lançamento ("Serviço (guincho / remoção)", origem abertura).
- **Detalhe da assistência:** card **💰 Valores da Assistência** — o mesmo histórico de lançamentos do sinistro (`LancamentosSinistroCard`, que reconhece `claim.tipo == 'assistencia'`): valor do serviço e cada adicional (km excedente, hora parada, pedágio, diária, mão de obra, peças, outro) com data, descrição, nota fiscal e quem registrou; cancelamento com motivo; **Total da assistência**. Atualiza ao vivo. Assistência residencial: valores pelo detalhe.
- Grava nos mesmos campos do sinistro (`lancamentos`, `valor_total_sinistro`), na coleção `assistencias` (`LancamentosService(colecao: 'assistencias')`); notas fiscais em `corretoras/{id}/assistencias/{nº}/lancamentos/`.
- Dashboard: **Custo médio** e **Sinistralidade** passam a considerar só sinistros (antes as assistências entravam com valor 0 e baixavam o custo médio).

## SLA — Service Level Agreement

| Campo | Descrição |
|---|---|
| `slaPrevisto` | Data/hora limite — countdown da abertura |
| `slaAtendimento` | Data/hora limite — countdown do técnico a caminho |
| `tempoSlaMinutos` | Tempo configurado para o atendimento |
| `slaExcedido` | Flag para filtragem rápida |
| **🆕 `dataConclusao`** | **Timestamp de conclusão — preenchido automaticamente** |

**Cores do countdown:**
- 🟢 Verde — dentro do prazo
- 🟠 Laranja — ≤15 min restantes
- 🔴 Vermelho — vencido

**Prazo padrão de encerramento do sinistro, por ramo** (Configurações → SLAs → *Tempo Padrão para Resolução de Sinistros*; preenche o "Dias para Encerramento" da abertura): lista de ramos e padrões em `AppConfig.slaSinistrosPadrao` (`lib/models/config_model.dart`) — Veículo Individual 10 · Frota 7 · **Civil Ônibus (RCO) 7** · Transporte 5 · Máquinas 10 · Residencial 10 · **Empresarial 10** · Vida 10 (RCO e Empresarial entraram na Etapa 08). O que está salvo no Firestore vale; ramo novo aparece com o padrão até ser alterado. Os sinistros gravam o ramo **"Vidas"** e o SLA é salvo como **"Vida"** — `AppConfig.chaveSlaRamo()` faz a ponte.

**Botão "Adicionar Tempo":** rastreado no histórico como `+Xmin adicionados`. Aparece em qualquer status exceto Concluído/Cancelado.

---

## Gestão de Tarefas

| Campo | Valores |
|---|---|
| Status | Aberta / Pendente / Concluída |
| `concluida_em` | Data/hora da conclusão (Etapa 10) |
| Prazo | Data com alerta visual colorido |
| Tipo | `agendamento` / `reagendamento` / `contato_cliente` (Etapa 14) / manual |
| `motivoConclusao` | Por que foi concluída, quando não foi à mão (Etapa 14) |
| `conclusao_automatica` | `true` = concluída pelo sistema (Etapa 14) |

**Criação automática:**
- Agendamento informado na abertura → tarefa `tipo: agendamento`
- Reagendamento → conclui tarefa anterior, cria nova `tipo: reagendamento`
- Sinistro → status "Aguardando Peças" / "Reparo em Andamento" ou "Atualizar previsão" → tarefa de contato com o cliente (`tipo: contato_cliente` desde a Etapa 14)

**Ligação com o atendimento (Etapa 14)** — regras em `lib/utils/tarefas_evento.dart`, gravações em `lib/services/tarefas_evento_service.dart`, telas em `lib/widgets/tarefas_evento_dialog.dart`, teste `test/tarefas_evento_test.dart`:
- **Encerrar o sinistro / concluir ou cancelar a assistência** → janela com as tarefas abertas do atendimento, todas marcadas; as marcadas são concluídas ("Concluída ao encerrar o sinistro em dd/mm/aaaa"). "Voltar" cancela o encerramento.
- **Excluir o atendimento** → todas as tarefas abertas dele são concluídas ("Atendimento excluído em …"). Antes ficavam órfãs: sumiam da tela de Tarefas, mas contavam nos Relatórios e no Dashboard.
- **Nova comunicação de status ou previsão do sinistro** → as tarefas de contato anteriores daquele sinistro são concluídas ("Substituída pela atualização de …").
- **Janela "Comunicar cliente"** ganhou **"Já informei por outro meio"** (telefone, presencial): conclui a tarefa (conta como conclusão do funcionário).
- **Configurações → 🧹 Tarefas esquecidas** (só admin): analisa e mostra a lista antes de concluir — tarefas abertas de atendimentos já encerrados, de atendimentos excluídos e contatos repetidos (fica o mais novo).
- Concluída **pelo sistema** fica "Encerrada pelo sistema": não entra no "no prazo / fora do prazo" do funcionário (aparece como "Pelo sistema" nos Relatórios e com 🤖 + motivo na lista). Nada é apagado.
- Tarefas de assistência passam a gravar `responsavelId` (antes só o e-mail — o funcionário não as via no Dashboard; o Dashboard agora também casa pelo e-mail).

**Cores de prazo:**
- 🟢 Verde — mais de 2 dias
- 🟠 Laranja — 1–2 dias
- 🔴 Vermelho — vencida (não concluída) ou concluída fora do prazo

**No prazo / Fora do prazo** (Etapa 10, regra única em `lib/utils/tarefas.dart`, teste `test/tarefas_test.dart`):
- O prazo vale até o **fim do dia** marcado.
- Aberta/Pendente depois do fim do dia do prazo → **Fora do prazo** (atrasada).
- Concluída → compara `concluida_em` com o prazo. `concluida_em` é gravado ao concluir (detalhe do sinistro, diálogo da tarefa, reagendamento da assistência) e apagado se a tarefa for reaberta. Concluída antes da Etapa 10 → **Sem data de conclusão**.
- Editar a tarefa **mantém o responsável** (antes passava para quem editou).

**Lista de Tarefas** (Etapa 10): ordenar por **Mais recente / Mais antiga** (data de criação; sem ela, o prazo) e **Exportar por funcionário** (CSV/Excel ou PDF) com as tarefas da lista (respeita filtros): uma seção por funcionário com subtotal (total, abertas, concluídas e %, no prazo × fora). PDF em `lib/services/tarefas_pdf.dart`.

**Relatórios → Funcionários → Tarefas por Funcionário (período)** (Etapa 10, `lib/widgets/tarefas_funcionarios_card.dart`): tarefas criadas no período, por funcionário — abertas, concluídas (% encerradas), no prazo, fora do prazo e % de cumprimento do prazo.

---

## Anexos e Arquivos

| Categoria | Formatos | Compressão |
|---|---|---|
| Fotos da Ocorrência | JPG, PNG, GIF, WEBP | Sim (quality 50, maxWidth 1024) — mobile e web; no detalhe do sinistro desde a Etapa 12 |
| Documentos / Laudos | PDF, DOC, DOCX, qualquer | Não |
| **Vídeos do Sinistro** (Etapa 12) | MP4, MOV, M4V, 3GP, WEBM | No servidor: MP4 720p H.264 (Cloud Function `converterVideo`) |

- Upload via clique ou **drag & drop**
- Sanitização de nome (remove `# ? & % espaços`)
- Armazenamento: Firebase Storage (bucket `upgrade-seguros.firebasestorage.app`)
- **Pasta por corretora (Etapa 16c):** tudo em `corretoras/{empresaId}/…` — ex.: `corretoras/{id}/sinistros/{nº}/fotos/`, `…/laudos/`, `…/terceiros/`, `corretoras/{id}/clientes/{id}/apolices/…`, `corretoras/{id}/videos/sinistros/{nº}/`. O app continua pedindo `sinistros/{nº}/fotos/…` e a Function `uploadFile` acrescenta a pasta da corretora do usuário (não dá para gravar na pasta de outra). Até a 16b os arquivos ficavam nessas mesmas pastas, só que na raiz do bucket (comuns a todas as corretoras).
- **Links protegidos (Etapa 16c):** o upload não deixa mais o arquivo público. O link gravado é o do Firebase com chave de acesso (`firebasestorage.googleapis.com/v0/b/…/o/…?alt=media&token=…`, o mesmo formato que os vídeos já usavam). Para ler caminho, nome e extensão de um link use `lib/utils/arquivos.dart` (`Arquivos.caminhoDoArquivo` / `nomeDoArquivo` / `extensao`) — no formato novo, `url.split('/').last` devolve o caminho codificado com o token.
- **Arquivos antigos → pasta da corretora:** Configurações → 📁 Arquivos da corretora (só administrador; Function `arquivosEmpresa`): "Diagnóstico", "Passar arquivos" (copia em lotes de 100 e troca os links nos documentos; o original fica) e "Apagar originais" (7 dias depois da conversão; apaga das pastas antigas só o que tem cópia — os links públicos antigos param de abrir).
- Web: compressão via pacote `image` (sem dependência de flutter_image_compress)
- **Abertura do sinistro (Etapa 12):** cada anexo sobe **uma vez só** (`_urlAnexoEnviado`). Antes, todo salvamento — inclusive o automático a cada edição — comprimia e enviava as fotos de novo com nome novo, duplicando arquivos no Storage.

### Vídeos do sinistro (Etapa 12)
- **Onde:** abertura (dentro de "Anexos e Documentos", categoria "VÍDEOS DO SINISTRO" — desde a Etapa 13 no mesmo desenho das outras categorias: rótulo cinza, botão "+ Adicionar vídeos" com contorno e caixa onde dá para **arrastar e soltar** ou clicar) e detalhe ("Vídeos da Ocorrência", no modo edição para adicionar/excluir).
- **Limites** (Configurações → "🎬 Vídeos do sinistro", em `app_config/config`): `videoMaxMb` e `videosPorSinistro` (padrão **5**). Pensados para variar por plano. O padrão de MB nasceu em 20 (Etapa 12) e foi alterado no código para **100** pelo Marcony (commit `4dbf6a6`): a cliente tem vídeos de 60–70 MB. Um valor salvo em Configurações vale mais que o padrão do código. Teto absoluto de 100 MB (até 100 MB inclusive nas regras do Storage desde a Etapa 13).
- **Envio direto ao Storage** pelo SDK (`lib/services/video_service.dart`), com progresso — a Function `uploadFile` (base64 por HTTP) tem limite de ~10 MB e não serve para vídeo. Bucket explícito `upgrade-seguros.firebasestorage.app` (`Videos.bucket`): o `firebase_options.dart` ainda tem o nome antigo `appspot.com`.
- **Caminho:** `corretoras/{empresaId}/videos/sinistros/{nº}/{data}_{nome}` (Etapa 16c; antes `videos/sinistros/…`). Registro no sinistro: campo `videos` = lista de `{url, caminho, nome, tamanho_bytes, enviado_em, enviado_por}` (`VideoAnexo`, `lib/utils/videos.dart`). O tamanho fica guardado para a futura medição por plano.
- **Conversão:** `functions/converter-video.js` (gatilho de Storage, 2 GiB, 9 min) converte para MP4 720p (lado menor ≤ 720 px, CRF 28, AAC 96k, faststart) e grava por cima mantendo o token — o link salvo continua valendo. Marca `convertido=sim|falhou`. Se o original já é MP4 e a conversão não ficar menor, mantém o original. Resolve o .mov (HEVC) do iPhone, que não toca no Chrome.
- **Assistir:** `video_player` numa janela sobre a tela (play/pausa, barra de tempo, som). Na abertura, toca o arquivo local antes de enviar. `lib/widgets/videos_sinistro.dart`.
- **No detalhe**, adicionar/excluir grava direto no documento (`arrayUnion`/`arrayRemove`) e exclui o arquivo do Storage. Excluir o sinistro apaga os vídeos.
- **Arquivamento:** `storage-lifecycle.json` — vídeos com mais de 180 dias vão para **Coldline** (desde a 16c a regra reconhece os vídeos dentro de `corretoras/` pela extensão; reaplicar depois de mudar o arquivo, com `gcloud storage buckets update gs://upgrade-seguros.firebasestorage.app --lifecycle-file=storage-lifecycle.json` ou pelo console do Cloud Storage → bucket → Ciclo de vida).
- **Regras do Storage** (`storage.rules`): vídeo só na pasta `videos/` da corretora, só usuário ativo da corretora, até 100 MB (inclusive — Etapa 13; antes um arquivo de exatamente 100 MB passava no app e era recusado no Storage). Etapa 16c: cada corretora só lê/grava/apaga em `corretoras/{o empresaId dele}/…`; as pastas antigas (`sinistros/`, `clientes/`, `videos/`, `veiculos/`) só leitura/exclusão, e só pela corretora que recebeu os dados antigos; o resto do bucket (ex.: `backups/`) fechado para o app.

---

## Comunicação com Clientes

### WhatsApp (`wa.me`)
| Momento | Conteúdo da mensagem |
|---|---|
| Abertura de assistência | Tipo, veículo, local, agendamento, previsão de atendimento |
| Atualização de status | Status atual + dados do atendimento por tipo (guincho / bateria / combustível) |
| Pesquisa NPS | Link único + instruções |

### Email (Gmail)
| Momento | Assunto |
|---|---|
| Pesquisa NPS | "A Upgrade Seguros quer ouvir você — Atendimento {numero}" |

> Nota: WhatsApp abre o aplicativo/web com texto pré-preenchido. O funcionário confirma o envio.

---

## Pesquisa de Satisfação (NPS)

```
Atendimento concluído
    ↓
Funcionário clica "Salvar e Enviar Pesquisa"
    ↓
Sistema gera link único com token (salvo em nps_pesquisas)
    ↓
Enviado via WhatsApp ou Email
    ↓
Cliente acessa link → preenche nota (0–10) + pontos fortes/fracos
    ↓
Sistema salva em avaliacoes + atualiza claim + recalcula NPS do cliente
```

**Categorias NPS:**
- 🟢 Promotor — nota ≥ 9
- 🟡 Neutro — nota 7–8
- 🔴 Detrator — nota ≤ 6

**Pontos fortes:** Agilidade no atendimento · Comunicação clara · Profissionalismo · Resolução eficiente · Cortesia · Acompanhamento · Rapidez na regulação · Preço justo

**Pontos fracos:** Demora no atendimento · Falta de comunicação · Dificuldade no processo · Demora na regulação · Falta de transparência · Preço elevado · Dificuldade de contato · Outros

---

## Dashboard — Painéis de Gestão

### KPIs Executivos
- Total de sinistros no período
- Valor total em sinistros (R$)
- Sinistralidade (%) — sinistros do período ÷ soma das apólices vigentes hoje (ainda a conta antiga; ver roadmap)
- Tempo médio de resolução (dias)
- **🆕 NPS (Satisfação da Carteira)** — média das avaliações com status colorido (Verde ≥70, Laranja 50-70, Vermelho <50)

### Overview — Responsivo
- ✅ **Mobile (<600px):** Layout em coluna única
- ✅ **Tablet (600-1000px):** 2 colunas (3+2)
- ✅ **Desktop (>1000px):** Row completo com todos KPIs

### Performance por Ramo
- Card por tipo com contador e ticket médio
- **Card Assistências**: No prazo / Em risco / Vencidas com badge colorido
- Clique navega para lista filtrada

### Atenção aos Prazos
- Mini-relógios digitais `HH:MM` por assistência ativa
- Ordenados: vencidas → em risco → no prazo
- Clique navega para a assistência

### Notificações na tela
Aviso flutuante no canto superior direito (`lib/services/notification_service.dart`), disparado pelo monitor de SLA (`lib/services/sla_monitor_service.dart`, a cada 30 s):
- Assistência com SLA vencido ou com ≤15 min restantes (vermelho/laranja).
- Tarefas atrasadas — desde a Etapa 14 de verdade (antes nunca disparava: procurava um campo que não existe): **um** aviso com o total de tarefas atrasadas de quem está logado, quando o total aumenta ou no máximo de hora em hora. O monitor lê só as tarefas abertas.
- **Clique abre** (Etapa 18.1 — antes o cartão não respondia ao clique, embora este README dissesse que abria): assistência → detalhe da assistência; uma tarefa atrasada → o atendimento dela; várias → lista de Tarefas. Botão ✕ fecha; some sozinho em 10 s.
- O Dashboard pede permissão de notificação do navegador, mas **ainda não há notificação nativa** (fora da aba) — ver Roadmap.

---

## Relatórios

### Filtros de Período
- Últimos 7 dias
- Últimos 30 dias
- Mês corrente
- Este ano
- Período customizado (data início + data fim)

### Gráficos Disponíveis
- 📊 Distribuição Sinistros vs Assistências (Pizza)
- 📊 Sinistros por Ramo (Barras coloridas)
- 📊 Sinistros por Horário (Madrugada/Manhã/Tarde/Noite)
- 📊 Sinistros por Dia (Dias de Semana vs Fim de Semana)
- 🚗 Assistências por Tipo (Guincho/Vidro/Combustível/etc)
- 📈 **NPS Mensal** (Janeiro → Hoje)
- 📊 **Sinistros Mensais** (contagem)
- 🚗 **Assistências Mensais** (contagem)
- 📉 **Sinistralidade Mensal** (%) — Etapa 11: duas linhas, **mensal** e **acumulado no ano**, e a linha tracejada do **gatilho** (% das Configurações). Sinistralidade = sinistros **ocorridos** (sem Cancelado/Negado) ÷ **prêmio ganho** (cada apólice "ganha" seu valor proporcional aos dias de vigência dentro do mês). Regra em `lib/utils/sinistralidade.dart` (teste `test/sinistralidade_test.dart`). Antes dividia os sinistros do mês pela soma **anual** das apólices vigentes hoje (≈ 1/12 do real, e com o denominador inflado pelos valores errados de apólice), por isso o gráfico ficava no zero.
- ✅ **SLA Compliance Sinistros Mensais** (% dentro de 10 dias)
- ✅ **SLA Compliance Assistências Mensais** (% conforme prazo)
- 💰 **Valor Apólices Mensais** (R$ mil)
- 📋 **Contratos Ativos Mensais** (contagem)
- 🎫 **Ticket Médio Mensal** (R$ mil)
- 📊 **Taxa de Retenção Mensal** (%)

> Etapa 18: os gráficos de linha mensais param no **mês atual** (eixo de Jan a Dez). Antes os meses que ainda não chegaram entravam como 0 e a linha "despencava" em dezembro. A tabela "Evolução Mensal" do PDF também vai só até o mês atual.

### Cards de Análise
1. Métricas gerais (total, valor, sinistralidade, tempo médio)
2. Distribuição por status (também no PDF)
3. Funil de etapas do processo
4. NPS Breakdown (Promotor / Neutro / Detrator)
5. Tempo Médio (Sinistros / Assistências)
6. Envolvimento de Terceiros (%)
7. Aprovações paradas (>3 dias)
8. Reparos prolongados (>7 dias)
9. Desempenho por funcionário
10. Clientes de alto risco (sinistralidade ≥60%)
11. Contratos próximos do vencimento (30 dias)
12. Sinistros em atraso (≥7 dias sem movimentação)
13. **💰 Top 10 Clientes por Valor de Sinistros** (Etapa 18) — soma, na hora, do valor dos sinistros de cada cliente, sem Cancelado/Negado (regra do "Valor utilizado" do relatório de clientes). Antes: "Top 10 Clientes por **Receita**", lido do campo `total_receita` do cliente — que é soma de sinistros (não receita), só era atualizado ao salvar pela planilha de abertura e contava cancelados/negados. Regra em `lib/utils/rankings_clientes.dart` (teste `test/rankings_clientes_test.dart`).
14. **📄 Maiores Apólices Vigentes** (Etapa 18) — logo abaixo do gráfico "Valor Apólices Mensais": as 10 vigentes de maior valor, com ⚠️ nas que valem 50× ou mais a mediana das vigentes (e ≥ R$ 1 milhão) — para achar valor digitado errado que faz o gráfico saltar.

### Exportação
- **PDF** com todas as seções — gerado via `pdf` + `printing`

### Cabeçalho e rodapé padrão dos PDFs (Etapa 17)
Todos os PDFs (sinistro, Relatório Executivo, relatório de clientes, tarefas por funcionário) usam `lib/services/marca_pdf.dart`:
- **Cabeçalho:** logo + nome + razão social · CNPJ · SUSEP / endereço / telefone · e-mail · site, do cadastro da corretora (**Configurações → 🏢 Dados da corretora**, só o gestor altera). O CNPJ vem primeiro, com 🔍 **consulta à Receita** (BrasilAPI, a mesma do cadastro de clientes; Etapa 17.1): confere os dígitos, avisa se a empresa não está ATIVA e preenche a razão social (nome fantasia, endereço e telefone só se estiverem vazios). Textos montados em `lib/utils/perfil_corretora.dart` (teste `test/perfil_corretora_test.dart`).
- **Rodapé:** "Nome da corretora · Gerado por {assinatura} · data/hora" + "Página X de Y". A assinatura segue **📝 Assinatura em PDF** (nome/telefone/e-mail do funcionário logado ou da corretora).
- **Logo:** PNG/JPG até 2 MB, em `corretoras/{id}/perfil/` no Storage. Sem logo enviada: a corretora que recebeu os dados antigos usa `lib/assets/logo_upgrade.png` (como antes); corretora nova sai sem logo.
- Nome do arquivo e assinatura da mensagem de WhatsApp da assistência também saem do cadastro (antes "Upgrade Seguros" fixo).
- Novo PDF: `final marca = await MarcaPdf.carregar();` e `header: (ctx) => marca.cabecalho(titulo: …)`, `footer: (ctx) => marca.rodape(ctx)`.

### Relatórios de sinistros e assistências com modelos (Etapa 19b)
Listas de **Sinistros** e **Assistências** → botão **Exportar relatório** → modelos salvos da corretora (todos veem e usam; sem nenhum, a tela leva a "Criar modelo"):
- **Modelo:** nome + campos escolhidos por seção (Ocorrência, Cliente, Bem/veículo, Proprietário (CRLV), Condutor, Terceiros — só sinistro —, Atendimento da assistência — só assistência —, Valores), em ordem (arrastar). Editar, duplicar, excluir.
- **Medidor de largura** no editor: 🟢 cabe em tabela na A4 deitada · 🟡 apertado (letra menor) · 🔴 não cabe → o PDF sai em **ficha** (um bloco por ocorrência). O Excel sai sempre completo.
- **Exportar:** período (mês atual, mês anterior, este ano, datas, tudo; sinistro pela data de abertura ou da ocorrência), cliente (busca digitando nome ou CNPJ — 19b.1), seguradora, tipo, status → prévia (quantidade e valor total) → **PDF** (cabeçalho/rodapé da corretora; título "Relatório de Sinistros/Assistências", nome do modelo e o cliente com CNPJ em destaque — 19b.1; linha de TOTAL) ou **Excel (CSV)** (`;`, vírgula decimal, valores em número).
- **Nome do arquivo** (19b.1): `corretora - cliente - modelo - AAAA-MM-DD` (sem cliente: "Todos os clientes"), para achar o de cada cliente.
- "Composição do valor" lista os lançamentos ativos ("Km excedente: R$ 80,00"). "Valor total" = soma dos lançamentos (Etapa 19a).
- Regras em `lib/utils/relatorio_modelo.dart` (teste `test/relatorio_modelo_test.dart`); leitura dos atendimentos e modelos em `lib/services/relatorio_atendimentos.dart`; PDF em `lib/services/relatorio_atendimentos_pdf.dart`; telas em `lib/widgets/relatorios_modelos.dart`. Campo novo: acrescentar no `CatalogoRelatorio` e em `RelatorioAtendimentosService.registroDe`.

### Relatório de clientes (auditoria)
Lista de clientes → filtro por **recomendação** (seletor ao lado da busca, com a cor e a quantidade de cada uma — Etapa 10, visual da Etapa 11) → botão **Exportar relatório** (barra superior) → **Planilha (CSV / Excel)** ou **PDF** (Etapa 08). Exporta os clientes da lista (todos, ou só os da busca), **ordenados pelo valor total das apólices**, com uma linha de TOTAL no final. Regra única em `lib/utils/relatorio_clientes.dart` (teste `test/relatorio_clientes_test.dart`); PDF em `lib/services/relatorio_clientes_pdf.dart`.

| Coluna | Como é calculada |
|---|---|
| Valor total das apólices | Soma do "Valor da Apólice" de **todas** as apólices do cliente (vigentes ou não) — o "Total das Apólices" do Detalhes |
| Qtd. apólices | Todas as apólices cadastradas |
| Maior apólice (nº e R$) | A de maior valor — serve para achar valor digitado errado |
| Qtd. sinistros | Todos os sinistros ligados ao cliente (inclusive cancelados) |
| Valor total utilizado | Soma do valor total dos sinistros **sem Cancelado/Negado** |
| % da apólice usada | Valor utilizado ÷ valor total das apólices |
| Qtd. assistências | Todas as assistências ligadas ao cliente |

- CSV com `;` e vírgula decimal, sem separador de milhar e com BOM: abre direto no Excel em português e os números somam. Texto que começa com `= + - @` ganha um apóstrofo (não vira fórmula).
- Registros sem cliente vinculado (`id_cliente` vazio) não entram.
- **Etapa 10:** o relatório respeita o filtro de recomendação e traz **Recomendação, Uso do gatilho (%), Contato, Telefone e E-mail** — para a corretora contatar, por exemplo, todos os "Não recomendado". O filtro aparece no cabeçalho do PDF e no nome do arquivo (`relatorio_clientes_nao-recomendado_AAAA-MM-DD.csv`).

---

## Estrutura de Dados (Firestore)

**Desde a Etapa 16 (multi-tenant), cada corretora tem a própria pasta:** `corretoras/{empresaId}/<coleção>/…`. O app descobre a corretora do usuário em `users/{uid}.empresaId` (`lib/services/empresa_atual.dart`, carregado por `lib/widgets/portao_empresa.dart` antes do Dashboard) e lê/grava só ali (`EmpresaAtual.col('sinistros')` etc.). Pastas em vez de um campo `empresaId` em cada documento: as consultas e os índices do Firestore continuam os mesmos (o índice é pelo nome da coleção).

| Onde | Coleção | Conteúdo |
|---|---|---|
| raiz | `users` | Usuários (login, papel, `ativo`, **`empresaId`**) |
| raiz | `corretoras` | Cadastro de cada corretora: perfil (`nome`, `razaoSocial`, `cnpj`, `susep`, `endereco`, `telefone`, `email`, `site`, `logo` + `logoCaminho` — Etapa 17) e controle da migração (`migradoEtapa16`, `migradoEm`, `arquivosConvertidosEm`…) |
| raiz | `nps_indice` | `{claimId}` → `empresaId` (o cliente responde o NPS sem login; Etapa 16) |
| corretora | `sinistros` | Registros de sinistros |
| corretora | `assistencias` | Registros de assistências veiculares e residenciais |
| corretora | `clientes` | Cadastro de clientes com veículos, ramos e NPS |
| corretora | `seguradoras` | Seguradoras cadastradas (campo `ativa`) |
| corretora | `tasks` | Tarefas vinculadas a sinistros e assistências |
| corretora | `workshops` | Oficinas |
| corretora | `modelos_relatorio` | Modelos de relatório de sinistros/assistências (Etapa 19b): `nome`, `tipo`, `campos` (ids em ordem), quem criou/editou. Todos da corretora veem, usam, editam e excluem |
| corretora | `app_config`, `sla_configs`, `pdf_signatures` | Configurações da corretora |
| corretora | `nps_pesquisas`, `avaliacoes` | Pesquisas NPS enviadas e respostas |
| corretora | `cotacoes`, `employees` | Cotações; funcionários (cadastro antigo) |

A lista das coleções da corretora está em `EmpresaAtual.colecoes` (app) e `COLECOES` (`functions/empresa.js`) — **as duas precisam ser iguais**.

**Regras por corretora (Etapa 16b, `firestore.rules`):** cada usuário só lê e grava em `corretoras/{o empresaId dele}/…`; em `users/` só vê colegas da mesma corretora (as listas do app filtram por `empresaId`) e o administrador só cria/edita usuários da própria corretora. Dentro da corretora: excluir sinistro, assistência ou cliente e alterar `app_config`, `sla_configs`, `pdf_signatures`, `seguradoras`, `workshops` e o cadastro da corretora = **só gestor (administrador)**. As coleções antigas da raiz ficam bloqueadas e podem ser apagadas pelo cartão 🏢 Dados da corretora → "Apagar dados antigos" (só 7 dias depois da migração; apaga apenas o que tem cópia na pasta).

### Campos Chave do Claim (sinistro ou assistência)

| Campo | Tipo | Descrição |
|---|---|---|
| `tipo` | String | `sinistro` ou `assistencia` |
| `tipoAssistencia` | String? | `guincho`, `vidro`, `residencial`, etc. |
| `ramoSinistro` | String | Ramo do seguro |
| `statusAtual` | String | Status atual do processo |
| `slaPrevisto` | Timestamp? | Prazo inicial do SLA |
| `slaAtendimento` | Timestamp? | Prazo do técnico a caminho |
| `tempoSlaMinutos` | int? | Tempo configurado em minutos |
| `totalReagendamentos` | int | Contador de reagendamentos |
| `npsAvaliada` | bool | Se pesquisa foi respondida |
| `npsSatisfacao` | double? | Nota NPS recebida |
| `npsCategoria` | String? | `promotor` / `neutro` / `detrator` |
| `telefoneCliente` | String? | Copiado do cadastro na abertura |
| `nomeContatoOficina` | String? | Contato no prestador de serviço |
| `telefoneContatoOficina` | String? | Telefone do prestador |
| `dataAgendamento` | Timestamp? | Data do agendamento |
| `horaAgendamento` | String? | Hora no formato HH:mm |
| **🆕 `dataConclusao`** | **Timestamp?** | **Data de conclusão — preenchida ao marcar "Concluído"** |
| `valor_total_sinistro` | double | Soma dos lançamentos ativos (Etapa 02); em sinistros antigos, o valor digitado |
| **🆕 `lancamentos`** | List<Map> | Histórico de valores (Etapa 02): `id`, `data`, `tipo`, `descricao`, `valor`, `beneficiario` (`segurado`/`terceiro`), `terceiro_id`, `terceiro_nome`, `anexos` [{`nome`,`url`}], `origem` (`manual`/`abertura`/`anterior_ao_historico`), `registrado_por(_email)`, `registrado_em`, `cancelado`, `motivo_cancelamento`, `cancelado_por(_email)`, `cancelado_em` |
| **🆕 `valor_segurado`** / **`valor_terceiros`** | double | Subtotais dos lançamentos ativos (Etapa 02) |

### Campos do Terceiro (`terceiros[]` dentro do claim)

| Campo | Descrição |
|---|---|
| **🆕 `id`** | Identificador estável (liga os lançamentos ao terceiro) — Etapa 02 |
| `nome`, `cpf`, `contato`, `email`, `endereco_terceiro` | **Proprietário** (CRLV) — `contato` é o telefone |
| `placa`, `chassi`, `cor`, `marcaTerceiro`, `modeloTerceiro`, `anoFabricacaoTerceiro`, `anoModeloTerceiro`, `veiculo` | Veículo do proprietário |
| **🆕 `motoristaMesmoProprietario`**, **`nomeMotorista`**, **`cpfMotorista`**, **`telefoneMotorista`**, **`emailMotorista`** | **Motorista** — Etapa 02 |
| **🆕 `cnhMotorista`** | CNH do motorista (vale mesmo quando é o proprietário) — Etapa 03 |
| `nomeContatoTerceiro`, `telefoneContatoTerceiro` | **Contato** |
| `registroSeguradoraTerceiro`, `relato` | Sinistro do terceiro |
| `fotosUrls`, `documentosUrls`, `franquia`, `numeroSinistroTerceiro` | Anexos e campos históricos |

### Campos Chave do Client (cliente)

| Campo | Tipo | Descrição |
|---|---|---|
| `nome` | String | Nome do cliente |
| `cnpjCpf` | String | CNPJ ou CPF |
| `email` | String | Email |
| `contatoTelefone` | String | Telefone |
| `numeroApolice` | String | Número da apólice |
| `valorApolice` | double | Valor da apólice (R$) |
| `valorGatilho` | double | Valor gatilho |
| `dataVigenciaInicio` | DateTime | Início da vigência |
| `dataVigenciaFim` | DateTime | Fim da vigência |
| `veiculosSegurados` | List<Vehicle> | Lista de veículos |
| **🆕 `ramos`** | **List<String>** | **Ramos de seguro: ['Veículo Individual', 'Residencial', 'Frota', ...]** |
| `nps` | double | Média de NPS |
| `npsScore` | int | Score NPS (-100 a +100) |

---

## Autenticação e Segurança

- **Login** com email/senha via Firebase Auth
- **Biometria** no app mobile
- **Admin vs funcionário**: controle de permissões para exclusão
- **Dados isolados** por `responsavelEmail`
- **CNPJ duplicado**: validação antes de salvar novo cliente

---

---

## Cloud Functions (Node.js)

| Função | Tipo | Descrição |
|---|---|---|
| `uploadFile` | HTTP (login) | Recebe base64 e salva no Storage **dentro da pasta da corretora do usuário**; devolve link com chave de acesso (não público) — Etapa 16c, `functions/arquivos.js`. Exige usuário ativo desde a Etapa 15 |
| `deleteFiles` | HTTP (login) | Remove arquivos (aceita caminho ou link, nos dois formatos). Etapa 16c: só da pasta da própria corretora (e das pastas antigas, para a corretora que recebeu os dados antigos); devolve `{excluidos, recusados}` |
| `arquivosEmpresa` | HTTP (só admin) | Etapa 16c: `diagnostico` (links antigos por coleção/pasta), `converter` (copia um lote para `corretoras/{id}/…` e troca os links nos documentos, em transação; repete até `terminou`) e `apagarOriginais` (confirmação `APAGAR`, 7 dias após a conversão, só o que tem cópia, por partes com `cursor`) |
| `npsPublico` | HTTP (público) | Etapa 15: pesquisa NPS do cliente final — confere o token, devolve só o necessário para a tela, grava a avaliação e recalcula o NPS do cliente |
| `apoioLogin` | HTTP (público) | Etapa 15: "usuário" ou "matrícula" → e-mail (só o e-mail) para o login |
| `criarUsuario` | HTTP (só admin) | Etapa 15: cria a conta (senha aleatória) e o cadastro em `users/`, herdando a empresa do administrador; o app manda o e-mail de definir senha |
| `migrarEmpresa` | HTTP (só admin) | Etapa 16: `diagnostico` (raiz × pasta da corretora, usuários, dias desde a migração) e `copiar` (raiz → `corretoras/{empresaId}/…`, só o que falta; índice do NPS; usuários sem empresa). Etapa 16b: `apagarRaiz` (confirmação `APAGAR`, 7 dias após a migração, só documentos com cópia) |
| `converterVideo` | Storage (arquivo finalizado em `videos/` ou `corretoras/{id}/videos/`) | Etapa 12: converte para MP4 720p no mesmo caminho (ffmpeg-static) |
| `plataforma` | HTTP (só admin da plataforma) | Etapa 21, `functions/plataforma.js`: o portal admin. Confere a marca `plataforma` no login + `plataforma_admins/{uid}` ativo + não ser usuário de corretora. Ações: `eu`, `corretoras`, `auditoria`, `criarContasQueFaltam`; Etapa 22: `catalogo`, `catalogoImportar`, `catalogoUso`, `catalogoAprovar`, `catalogoEditar`, `catalogoJuntar`, `catalogoRecusar`. Tudo vai para `plataforma_auditoria` |
| `catalogoSeguradoras` | HTTP (login) | Etapa 22, `functions/catalogo.js`: a corretora informa o CNPJ de uma seguradora que não está na lista; o **servidor** consulta a Receita (BrasilAPI) e cria a entrada **pendente** com o nome oficial (`consultarCnpj`, `sugerir`). Só depois que o catálogo foi montado |
| `verificarAssistenciasAtradasTelegram` | Agendada (a cada 10 min) | Lê `app_config/config` e avisa no Telegram as assistências com SLA atrasado, respeitando horário configurado. Token do bot no Secret Manager (`TELEGRAM_BOT_TOKEN`, Etapa 15) |

> Desde a Etapa 16c os anexos não são mais públicos: o link gravado tem uma chave de acesso do Firebase (ver Pendências de Segurança, item S6).

---

## 🏢 Plataforma (SaaS) — portal admin, planos e cobrança

Modelo inspirado no QuotaFlow (resumo de 24/11/2026), adaptado ao Firebase: a trava real fica nas **regras do Firestore** e nas **Functions**, não só na tela.

### Portal admin (Etapa 21)
- **Site separado** no mesmo projeto: `lib/main_admin.dart` + `lib/admin/` (o app das corretoras não importa nada disso). Endereço provisório `https://upgrade-seguros-admin.web.app` (alvo `admin` no `firebase.json`; o app é o alvo `app`).
- **Admin da plataforma ≠ usuário de corretora:** conta com e-mail próprio, criada **só** pelo script `functions/scripts/admin-plataforma.js` (`adicionar` / `remover` / `listar`, senha digitada escondida, mínimo 10 caracteres). Não existe tela para criar admin.
- **Dupla checagem:** marca `plataforma: true` no login **e** `plataforma_admins/{uid}` com `ativo: true` **e** sem `users/{uid}`. O `remover` desliga na hora e encerra as sessões.
- O portal **não lê o Firestore direto**: tudo pela Function `plataforma`, com registro em `plataforma_auditoria`.
- **Conta da corretora** (plano, situação, cortesia) em `plataforma_contas/{empresaId}` + `historico/`. Não fica em `corretoras/{id}` porque lá o gestor da corretora pode gravar. O app só lê a própria conta; ninguém grava pelo app.
- Situações previstas: `teste` (14 dias) · `teste_encerrado` (só leitura) · `ativa` · `inadimplente` · `suspensa` · `cancelada`.

### Catálogo único de seguradoras (Etapa 22)
- `catalogo_seguradoras/{id}`: nome, chave, CNPJ, razão social, SUSEP, **apelidos**, situação (`aprovada` · `pendente` · `inativa` · `juntada` · `recusada`). Só o servidor grava; as corretoras leem as aprovadas + as pendentes que elas mesmas sugeriram.
- O que é de cada corretora (telefone, e-mail, contato, "não trabalho com essa") continua em `corretoras/{id}/seguradoras`, com `catalogoId`.
- **Registros guardam o nome** (não o id): o catálogo garante nome único e, ao **renomear** ou **juntar** no portal, o servidor troca o nome em sinistros, assistências e apólices de **todas** as corretoras; o nome antigo vira apelido (quem digitar o antigo cai no novo).
- **Seguradora nova:** só pelo **CNPJ** (Configurações → Seguradoras → Nova, ou "Não achou? Cadastrar pelo CNPJ" no campo). O nome vem da Receita (nome fantasia ou razão social — escolhe, não digita). Entra pendente, a corretora já usa, o admin aprova / junta / recusa no portal.
- **Consulta à Receita (22.1):** feita **no navegador** (`lib/services/receita_cnpj.dart`, como na 17.1). A BrasilAPI recusa (403) chamadas que saem dos servidores do Google; o servidor só tenta conferir e, se não conseguir, usa o que o app consultou — a pendente fica marcada "consultada pelo app" para o admin conferir.
- **Admin:** portal → Seguradoras → **Nova seguradora** (CNPJ → Consultar na Receita → nome/SUSEP → já entra aprovada). Na edição, o ícone ao lado do CNPJ consulta a Receita e grava a razão social.
- Antes da importação no portal (catálogo sem aprovadas), o app continua com o cadastro de cada corretora (Etapa 20) e o servidor não aceita sugestões.

### Módulos e "Meu plano" (Etapa 23)
- Catálogo de módulos em `lib/utils/modulos.dart` e `functions/modulos.js` (os dois iguais; o `verificar-entrega.js` confere): **Atendimento** — Assistências, Vídeos, Oficinas · **Carteira** — Importar contrato · **Gestão** — Tarefas, Relatórios (exportar), Modelos de relatório · **Comunicação** — Pesquisa NPS e Avisos no Telegram (os dois dependem de Assistências).
- Plano da conta (`plataforma_contas/{id}`): **Tudo ligado** (sem lista; fundadoras e quem não tem conta) ou **Personalizado** (lista `modulos`). O admin escolhe no portal → corretora → **Módulos do plano** (com histórico e auditoria).
- **Trava em três lugares:** tela (item com cadeado e página "Fora do plano" com atalho para **Meu plano**, em vez de sumir), **regras** (Firestore: criar/alterar assistências, tarefas, oficinas, modelos de relatório e pesquisas NPS; Storage: enviar vídeos) e **Functions** (avisos do Telegram). Ler o que já existe continua liberado.
- **Meu plano** (ícone na barra do topo): plano, situação e módulos incluídos / fora do plano.
- Ainda sem trava: gatilho/recomendação (fica para quando os planos-modelo existirem).

### Planos (Etapa 24)
- Portal → **Planos**: planos-modelo com nome, descrição, **preço mensal**, **franquias** (usuários, GB de arquivos, GB de vídeos — quantidade incluída + preço por unidade a mais, ou sem limite) e módulos. Ativo / desativado (desativado não entra em corretora nova; quem já está continua). Excluir só sem corretoras.
- Portal → Corretoras → corretora → **Plano da corretora**: Tudo ligado · plano da lista · Personalizado (módulos, preço e franquias só dela) + **cortesia** com validade opcional e motivo (histórico).
- A conta guarda uma **cópia** do plano (`plano.planoId`, nome, preço, franquias + `modulos`): as regras continuam lendo só a conta. Editar um plano-modelo em uso regrava as corretoras que estão nele (com histórico).
- App: botão **"Plano: …"** na barra do topo (no celular, ícone); Meu plano mostra preço, franquias e cortesia.
- Medição do uso (GB, vídeos) e cobrança ficam para as Etapas 25–28; o portal já mostra usuários × franquia. Gatilho/recomendação continua sem trava.

### Autocadastro, teste grátis e situação da conta (Etapa 25)
- Tela de entrada do app → **"Sua corretora ainda não usa? Teste 14 dias grátis"**: CNPJ (consulta à Receita no navegador; só CNPJ ativo), nome da corretora, responsável, e-mail e telefone. Vira um **pedido** (Function pública `autocadastro`, coleção `plataforma_pedidos`) — nada é criado antes da aprovação.
- Portal → **Pedidos** (com contador no menu e aviso na Visão geral): **Aprovar** cria a corretora, o responsável como **gestor** e a conta em **teste** (14 dias, plano escolhido na aprovação; padrão Tudo ligado) e manda o e-mail do Firebase para ele criar a senha. **Recusar** com motivo.
- **Só leitura:** teste vencido, `teste_encerrado`, `suspensa` e `cancelada` — as regras do Firestore e do Storage barram criar/alterar/apagar (pela data do teste, sem depender de rotina agendada); `criarUsuario` também recusa. `inadimplente` ainda grava (aviso no app).
- App: faixa no topo com os dias de teste ou o modo só leitura (+ "Ver meu plano"). Meu plano (gestor): **planos disponíveis** e **"Quero este plano" / "Falar sobre o meu plano"** → pedido de contratação no portal (Function `minhaConta`).
- Portal → corretora → **Situação**: teste (com data), ativa, inadimplente, suspensa, cancelada, teste encerrado — com motivo no histórico. A lista mostra a situação efetiva (teste vencido = "Teste terminou").

### Financeiro (Etapa 26)
- Portal → **Financeiro**: **receita do mês (MRR)** estimada pelo plano de cada corretora, ticket médio, parte vinda de usuários extras, **em atraso** (inadimplentes), **cortesias** (quanto deixam de pagar) e **potencial dos testes**; avisos de testes acabando/terminados, cortesias vencendo em 30 dias e inadimplentes; tabela por corretora com **Copiar tabela** (cola no Excel/Planilhas). A Visão geral mostra a receita do mês.
- Regra (`lib/admin/financeiro.dart`): mensalidade = preço do plano + usuários acima da franquia × excedente; cobrável = ativa ou inadimplente sem cortesia valendo (cortesia vale até a data; sem data, sem fim). Só portal — nada muda no app nem no servidor. GB e vídeos entram com a medição (Etapa 27).

### Uso por corretora (Etapa 27)
- Function agendada **`medirUsoDiario`** (todo dia 03:30, horário de Brasília) e botão **"Medir uso agora"** no Financeiro (ação `medirUso` da `plataforma`): soma, no Storage, os **GB de arquivos** (`corretoras/{id}/`, sem a pasta de vídeos) e os **GB de vídeos** (`corretoras/{id}/videos/`) e conta os **usuários**; grava em `plataforma_contas/{id}.uso`. Só lista nomes e tamanhos — não baixa nada. As pastas antigas da raiz não entram.
- Financeiro: colunas Arquivos/Vídeos, cartões **GB extras** e **Armazenamento**; a mensalidade passa a somar os **GB acima da franquia** (arredondados para cima) × preço por GB.
- Portal → corretora: arquivos, vídeos e data da medição. App → **Meu plano**: "Usado: X de Y" em cada franquia com limite.

### Beta — assistente (Etapa 28)
- Botão **Beta** no canto inferior esquerdo do app (módulo `beta` do plano). Chat que responde **só com dados do banco** da corretora: telefone/e-mail/WhatsApp do segurado, contato do segurado, motorista, terceiro, contato e motorista do terceiro, contato no local, oficina; veículo segurado e do terceiro; status; tarefas pendentes; sinistros de um cliente; dono de uma placa; apólices do cliente (ramos, vencimento, valor, bens e gasto × gatilho — 28.4). Cartões com botões **Ligar**, **WhatsApp**, **E-mail** e **Abrir** o atendimento.
- **Continuidade:** o servidor guarda o assunto (último sinistro/cliente) em `corretoras/{id}/beta_conversas/{uid}` — "e do terceiro?" usa o sinistro anterior.
- **Barato:** regras de texto resolvem a maior parte (`functions/beta-interpretar.js`); só o que elas não entendem vai ao **Claude Haiku**, que apenas transforma a pergunta num pedido do catálogo (nunca escreve a resposta) e recebe só o assunto, não o histórico.
- **Custo medido** por corretora e mês (`plataforma_contas/{id}.beta.{AAAA-MM}`: perguntas, com IA, tokens, US$) com **teto** (padrão US$ 5; `betaTetoUsd`) — no teto, segue só com as regras. Portal → **Beta**: uso, custo em US$/R$, teto por corretora e **perguntas sem resposta** (`plataforma_beta_perguntas`).
- Chave da IA: segredo `ANTHROPIC_API_KEY` (`firebase functions:secrets:set ANTHROPIC_API_KEY`). Modelo e preço por token em `functions/beta.js` (conferir na tabela da Anthropic).

### Publicar
- **App das corretoras:** `flutter build web` → `firebase deploy --only hosting:app`.
- **Portal:** `flutter build web -t lib/main_admin.dart --no-tree-shake-icons` (22.1: com a fonte de ícones completa, ícone novo não depende de o navegador baixar a fonte de novo), copiar `build/web` para `build/admin`, `flutter build web` de novo (devolve o app em `build/web`) → `firebase deploy --only hosting:admin`.
- ⚠️ Desde a Etapa 21, `firebase deploy --only hosting` (sem `:app`) tenta publicar os dois sites.

### Próximas etapas
22 ✅ catálogo global de seguradoras · 23 ✅ módulos (bloqueio na tela + regras + Functions, "Meu plano") · 24 ✅ planos-modelo e plano por corretora · 25 ✅ autocadastro com CNPJ validado + aprovação, teste de 14 dias → só leitura · 26 ✅ painel financeiro · 27 ✅ uso por corretora · 28 ✅ Beta, a assistente · cobrança automática (gateway): adiada.

---

## 🔐 Pendências de Segurança

Levantadas na revisão da base (07/11/2026). O repositório no GitHub está **público**, então tudo que está no git pode ser lido por qualquer pessoa. Por isso, aqui as pendências ficam descritas de forma resumida, sem detalhes de como explorar.

### 🔴 Urgente (fazer assim que possível — depende do celular para o 2FA)
- [x] **S1 — Trocar o token do bot do Telegram** (Etapa 15). Token revogado no @BotFather em 09/11/2026; o novo fica só no **Secret Manager** (`firebase functions:secrets:set TELEGRAM_BOT_TOKEN`), lido por `defineSecret` em `functions/notificacoes-telegram.js`. Os arquivos `.env` e de parâmetros saíram do projeto e `functions/.env*` está no `.gitignore`. O token antigo continua no histórico do git, mas não funciona mais.
- [ ] **S2 — Voltar o repositório para privado** depois de configurar o acesso de leitura do Claude (conector do GitHub em claude.ai → Configurações → Conectores). Sem isso, cada ciclo exige o repositório público.

### 🟠 Para olhar em seguida (entram no plano quando for oportuno)
- [x] **S3 — Exigir login nas Cloud Functions de arquivo** (Etapa 15): `uploadFile` e `deleteFiles` só atendem usuário logado e ativo (ID token no cabeçalho `Authorization`, conferido em `functions/seguranca.js`; o app manda via `lib/services/funcoes_nuvem.dart`, que monta o endereço do Cloud Run — Etapa 15.1). Pendente: restringir os caminhos permitidos (entra com o multi-tenant).
- [ ] **S4 — Restringir a chave do Google Maps/Places** no Google Cloud Console (referenciadores HTTP do domínio + package/bundle dos apps Android/iOS + só as APIs usadas). Hoje a chave está escrita em 8 arquivos de tela; numa etapa futura, centralizar em `utils/constants.dart` (uma chave, um lugar). *Restrição no console não exige entrega; a centralização entra quando alguma etapa mexer nessas telas.*
- [x] **S5 — Regras do Firestore no repositório** (Etapa 15): `firestore.rules` versionado e registrado no `firebase.json`. Só **usuário ativo** (logado + cadastro em `users/{uid}` não desativado) lê e grava; `users/` só o administrador cria, apaga ou muda papel/ativo/empresa. O Storage segue a mesma regra (consulta o cadastro pelo Firestore). Fluxos sem login passam pelo servidor: pesquisa NPS (`npsPublico`), login por usuário/matrícula (`apoioLogin`) e criação de usuário pelo administrador (`criarUsuario`). Próximo: isolamento por corretora (multi-tenant).
- [x] **S6 — URLs públicas dos anexos** (Etapa 16c). O upload não usa mais `makePublic()`: os arquivos ficam na pasta da corretora e o link gravado tem chave de acesso do Firebase (não dá para chegar ao arquivo só sabendo o caminho). Os arquivos antigos passam para a pasta da corretora pelo cartão 📁 de Configurações e os originais públicos são apagados depois de 7 dias. Limite conhecido: quem tiver o link completo abre (como os links do Firebase em geral). **Se a Europa (GDPR) pedir, o próximo passo é link com validade (URL assinada) gerado na hora de abrir.**
- [ ] **S8 — Autocadastro público** (Etapa 25): a Function `autocadastro` aceita pedidos sem login. Hoje: só vira pedido (nada é criado sem aprovação), CNPJ válido, um pendente por CNPJ/e-mail, teto de pedidos pendentes e isca contra robôs. Se aparecer spam, ligar o **App Check** (reCAPTCHA) no app e na Function.
- [x] **S7 — Tirar `node_modules/` do git** (Etapa 06, junto com `android/build/`) (~15 mil arquivos versionados na raiz): `git rm -r --cached node_modules`, acrescentar no `.gitignore`. Não muda o funcionamento; deixa o repositório leve e o diff legível.

---

## ⚠️ Armadilhas Conhecidas

- **Análise no ambiente do Claude (desde a Etapa 02):** o SDK do Flutter não baixa lá (Google Storage bloqueado), mas o Claude monta uma análise parcial: Dart SDK do conda-forge + código do Flutter e dos plugins principais (Firestore, Auth, Storage, pickers, pdf/printing) clonados do GitHub nas versões do `pubspec.lock`. Compara os erros/avisos **antes × depois** da mudança — qualquer diagnóstico novo aparece. Plugins sem código lá (mapas, Places, Font Awesome, url_launcher, máscara, Syncfusion, uuid, desktop_drop) ficam sem checagem de tipo. O `flutter analyze` + `flutter test` completos continuam no Mac (`--analyze` do verificador).
- **Lista "Em curso" e documentos sem `status_atual`:** a consulta `whereNotIn` do Firestore não traz documentos que não têm o campo `status_atual`. Todo sinistro/assistência gravado pelo app tem esse campo; se algum registro antigo/importado não tiver, ele só aparece em "Todos".
- **Dashboard e Relatórios ainda baixam tudo:** precisam do histórico para calcular. Quando a base crescer (milhares de registros), a solução é ter totais pré-calculados (roadmap).
- **Lançamentos só por transação:** gravar o sinistro inteiro (`updateClaim` / `Claim.toMap()`) regrava a lista `lancamentos` com o que está em memória. Hoje só o encerramento faz isso, com o estado atualizado pelo listener. Lançar/cancelar valor **sempre** pelo `LancamentosService` (transação), nunca editando a lista e salvando o claim.
- **Marca/modelo do terceiro editado antes da Etapa 02:** o diálogo de edição antigo gravava marca, modelo e anos só dentro de `veiculo` (a tela mostrava vazio). O `ThirdParty.fromMap` agora cai para `veiculo` quando o campo próprio está vazio; ao salvar de novo, os dois ficam preenchidos.
- **Pacote importado sem estar no `pubspec.yaml`:** `latlong2` é importado em `widgets/workshop_widget.dart`, mas só chega como dependência de outro pacote. Compila hoje; quebra se o outro pacote deixar de usá-lo. Corrigir quando a etapa mexer nesse arquivo (o import parece não ser usado — `hide LatLng`).
- **Valores em moeda na apólice:** ler sempre com `GatilhoApolice.lerMoeda()` (aceita "R$ 1.234,56" com espaço especial). Antes da Etapa 07, o diálogo abria com `120000.1` e o `parseFromMoeda` lia como 1.200.001 se o usuário salvasse sem redigitar — **apólices editadas antes da Etapa 07 podem ter valor/gatilho inflados**: conferir as que parecerem absurdas — o relatório de clientes (Etapa 08) ordena por valor e mostra a maior apólice de cada um.
- **Sinistros sem `apolice_id`** (abertos sem escolher apólice) não entram no "uso atual" da abertura. A recomendação do cliente (Etapa 09) e o Top 10 de risco (Etapa 10) os ligam por ramo + data, só no cálculo.
- **Tarefas concluídas antes da Etapa 10** não têm `concluida_em`: aparecem como "Sem data de conclusão" e ficam fora do "no prazo / fora do prazo".
- **Editar tarefa trocava o responsável** para quem editou (até a Etapa 09). Tarefas editadas antes podem estar com o responsável errado nas estatísticas por funcionário.
- **Modal "Tipo de Assistência" é um componente só** (Etapa 06): `lib/widgets/assist_tipo_picker.dart` → `mostrarSeletorTipoAssistencia()`, usado pelo Dashboard e pelo botão laranja "Nova Assistência" da lista. Cor padrão das assistências: `corAssistencia` (`Colors.orange.shade600`).
- **Link de arquivo (Etapa 16c):** nunca tirar nome/extensão com `url.split('/')` ou `url.split('.')` — no link novo o caminho vem codificado (`%2F`) e com `?alt=media&token=…` no fim. Usar `Arquivos.nomeDoArquivo` / `Arquivos.extensao` (`lib/utils/arquivos.dart`).
- **Fotos de veículo pelo celular** (`client_detail_screen` / `client_form_screen`, `putFile`): só funcionam no app mobile (no navegador o envio é pela Function). Desde a 16c usam o bucket certo e a pasta da corretora; antes iam para o bucket padrão antigo (`appspot.com`).
- **Arquivos auxiliares na raiz/lib:** `ROTEIRO_REFATORACAO_PICKER_RAMO.md` (o picker global já existe em `dashboard_screen.dart` — confirmar que o roteiro foi concluído e apagar) e `lib/readme.dart` (anotações soltas em comentário).

---

## 🧪 Processo de Entrega e Verificação

Combinado em 07/11/2026 — mesmo ritual usado no QuotaFlow, adaptado para Flutter + Firebase.

### Regras
- **O Claude só lê o GitHub.** Nunca faz push, PR ou commit. Quem aplica, revisa e sobe é o Marcony.
- **Entrega = zip com arquivos inteiros** (nunca trechos para copiar à mão) + `LEIA-ME-ENTREGA-<etapa>.md` + `verificar-entrega.js` atualizado + este README inteiro (só com acréscimos) quando mudar.
- **O passo a passo nunca se chama `README.md`**, para não sobrescrever este arquivo.
- **Toda mudança é explicada.** O LEIA-ME de cada etapa traz, arquivo por arquivo, o que mudou e por quê, e o comando `git --no-pager diff <arquivo>` para revisar linha a linha antes do commit.

### Ritual de cada entrega
1. Claude lê a versão atual no GitHub e anota o commit-base.
2. Marcony manda a solicitação da cliente.
3. Claude desenvolve e confere (imports, pubspec, sintaxe das Functions, revisão).
4. Na raiz do projeto (`/Users/marcony/Projects/upgrade_seguros`):
   1. `node verificar-entrega.js --antes` — se algum arquivo divergir da base, **parar e mandar o arquivo** (pode ter mudança sua que a entrega apagaria).
   2. Copiar os arquivos do zip.
   3. `node verificar-entrega.js --analyze` — tem que terminar em "✓ Todos".
   4. `git --no-pager diff` para revisar; rodar o app; testar o roteiro do LEIA-ME.
   5. `git add` dos arquivos novos, commit, push.

### O verificador
- Fica na **raiz do projeto**, ao lado do `pubspec.yaml`, e **fora do git** (está no `.gitignore`). Uma cópia fica no Project do Claude (`claude/verificar-entrega.js`); em conversa nova o Claude parte dessa cópia.
- Confere por md5 (ignora CRLF e espaço no final) se cada arquivo entregue está idêntico ao testado; imports Dart; pacotes × `pubspec.yaml`; `require` × `functions/package.json`; arquivo entregue fora do git; segredo exposto em arquivo do git.
- **`.gitignore` (desde a Etapa 08):** conferido pelo **conteúdo** (tem que ter as linhas `verificar-entrega.js`, `node_modules/` e `android/build/`), não por md5 — pode ter outras linhas suas. `node_modules/` ou `android/build/` ainda no git passa a ser ✗.
- **Arquivos que começam com ponto** (`.gitignore`) ficam escondidos no Finder (mostrar: Cmd+Shift+.). Por isso, desde a Etapa 08, o `.gitignore` não vai no zip: o LEIA-ME traz o comando que acrescenta as linhas.

---

## 📦 Histórico de Entregas

| Etapa | Data | Base | O que mudou |
|---|---|---|---|
| 12 | 08/11/2026 | `c348350` | **Vídeos do sinistro** na abertura e no detalhe: limites configuráveis (20 MB, 5 por sinistro), envio direto ao Storage com progresso, player na própria tela, conversão para MP4 720p no servidor (`converterVideo`), arquivamento em Coldline depois de 180 dias, regras do Storage para vídeo. **Fotos:** abertura não envia mais as mesmas fotos a cada salvamento automático (duplicava no Storage); foto adicionada no detalhe passa a ser comprimida. Teste novo: `videos_test.dart`. Pacotes novos: `video_player` (app), `ffmpeg-static` (Functions). |
| 13 | 08/11/2026 | `4dbf6a6` | **Vídeos na abertura no mesmo desenho dos anexos** (rótulo "VÍDEOS DO SINISTRO", botão "+ Adicionar vídeos" com contorno, caixa cinza com arrastar e soltar). Regra do Storage aceita exatamente 100 MB. Teste de vídeos não depende mais do padrão de MB (que o Marcony passou de 20 para 100 no `4dbf6a6`). |
| 14 | 09/11/2026 | `fa5b317` | **Tarefas ligadas ao atendimento:** ao encerrar o sinistro ou concluir/cancelar a assistência, o sistema mostra as tarefas abertas e conclui as marcadas; excluir o atendimento conclui as tarefas dele (antes ficavam órfãs e inflavam Relatórios/Dashboard); nova comunicação de status/previsão substitui o contato anterior; botão "Já informei por outro meio"; limpeza das tarefas esquecidas em Configurações (admin, com lista antes). Concluída pelo sistema não conta como atraso. Alerta de tarefa atrasada passa a funcionar (agrupado, do usuário logado) e o monitor lê só as abertas. Tarefas de assistência gravam o responsável. Teste novo: `tarefas_evento_test.dart`. |
| 15 | 09/11/2026 | `ec4a608` | **Segurança:** regras do Firestore no repositório (só usuário ativo; `users/` protegido) e Storage com a mesma regra; Functions `npsPublico`, `apoioLogin` e `criarUsuario` (fluxos sem login e criação de usuário pelo servidor); `uploadFile`/`deleteFiles` exigem login; token do Telegram como segredo do Firebase e arquivos `.env` fora do projeto. Teste novo: `functions/testes/seguranca.teste.js`. |
| 15.1 | 09/11/2026 | Etapa 15 | Endereço das Functions: as de 2ª geração respondem no Cloud Run (`https://<nome>-hwtlk2s4qq-uc.a.run.app`), não em `…cloudfunctions.net/<nome>` (404) — afetava `apoioLogin`, `npsPublico`, `criarUsuario` e `deleteFiles`. |
| 16 | 10/11/2026 | `0d24d50` | **Multi-tenant (preparação):** cada corretora com a própria pasta no banco (`corretoras/{id}/…`); app lê/grava pela corretora do usuário (`EmpresaAtual`), listas de usuários só da corretora; `PortaoEmpresa` antes do Dashboard (segura as telas até a migração); Function `migrarEmpresa` (diagnóstico + cópia idempotente, raiz preservada); NPS e Telegram por corretora; Configurações somente leitura para funcionário. Testes: `functions/testes/empresa.teste.js` (+ `firebase-falso.js`). |
| 16b | 23/11/2026 | `99cc809` | **Multi-tenant, trava:** regras do banco por corretora (membro lê/grava a própria pasta; excluir atendimento/cliente e configurações só gestor; `users` só da mesma corretora; raiz antiga bloqueada); "Apagar dados antigos" (`migrarEmpresa` `apagarRaiz`: 7 dias após a migração, só o que tem cópia, confirmação digitada); data da 1ª migração preservada. Migração feita em 23/11/2026. |
| 16c | 23/11/2026 | `81e6d14` | **Multi-tenant, arquivos:** `uploadFile` grava em `corretoras/{id}/…` e devolve link com chave (fim do `makePublic`, S6); `deleteFiles` só na pasta da corretora; regras do Storage por corretora (pastas antigas só leitura/exclusão); vídeos e fotos de veículo na pasta da corretora; Function `arquivosEmpresa` + cartão 📁 em Configurações (passar arquivos antigos em lotes, trocar os links, apagar originais após 7 dias). Nome/extensão de arquivo lidos por `lib/utils/arquivos.dart` (o formato novo quebrava `split('/')`). Testes novos: `functions/testes/arquivos.teste.js`, `test/arquivos_test.dart`. |
| 16c.1 | 23/11/2026 | Etapa 16c | `storage.rules`: regra das pastas antigas reescrita (lê o cadastro do usuário uma vez com `let`); a versão da 16c dava erro no Playground. |
| 17 | 23/11/2026 | `701591d` | **Perfil da corretora:** cartão 🏢 Dados da corretora em Configurações (nome, razão social, CNPJ, SUSEP, endereço, telefone, e-mail, site e logo; só o gestor altera; salva com botão — antes nome/telefone/e-mail da assinatura gravavam a cada letra). **Cabeçalho e rodapé padrão** em todos os PDFs (`marca_pdf.dart`): logo e dados do cadastro em cima; quem gerou, data e página embaixo. Nome do arquivo e assinatura do WhatsApp da assistência pelo cadastro. Removido `pdf_services_admin.dart` (cópia antiga sem uso). Teste novo: `perfil_corretora_test.dart`. |
| 17.1 | 23/11/2026 | Etapa 17 | 🏢 Dados da corretora: **CNPJ primeiro**, com validação dos dígitos e consulta à Receita (preenche razão social; nome fantasia, endereço e telefone se vazios; avisa se não estiver ATIVA); razão social e nome fantasia logo abaixo. +3 testes em `perfil_corretora_test.dart`. |
| 18 | 23/11/2026 | `e1d5941` | **Relatórios:** gráficos de linha mensais (NPS, contratos, valor das apólices, ticket médio, retenção, SLA) param no mês atual — antes dezembro aparecia como 0 ("queda"); tabela mensal do PDF idem. **Top 10 Clientes por Valor de Sinistros** no lugar do "por Receita" (calculado na hora, sem Cancelado/Negado). **Maiores Apólices Vigentes** com ⚠️ no valor destoante (para achar a apólice digitada errada). Teste novo: `rankings_clientes_test.dart`. |
| 18.1 | 23/11/2026 | Etapa 18 | **Notificação na tela clicável:** assistência vencida/em risco abre o detalhe da assistência; tarefa atrasada abre o atendimento (ou a lista de Tarefas, se forem várias); botão ✕ para fechar. Antes o clique não fazia nada. README: seção de notificações corrigida (dizia que o clique já abria) e notificação nativa do navegador no roadmap. |
| 19a | 23/11/2026 | `a489a14` | **Valores da assistência:** "Valor do serviço" (opcional) na abertura veicular vira o 1º lançamento; card 💰 Valores da Assistência no detalhe com o histórico de lançamentos do sinistro (adicionais, nota fiscal, cancelamento com motivo, total). Dashboard: custo médio e sinistralidade só com sinistros. +2 testes em `lancamento_model_test.dart`. Roadmap: gatilho mensal de assistências por cliente (a confirmar). |
| 19b | 23/11/2026 | `9ad1a4e` | **Relatórios com modelos:** botão "Exportar relatório" em Sinistros e Assistências; modelos da corretora (coleção nova `modelos_relatorio`, também na lista de coleções da Function de migração); editor com campos por seção, ordem arrastável e medidor de largura do PDF; exportação com período, cliente, seguradora, tipo e status, prévia, PDF (tabela, compacta ou ficha) e Excel (CSV). Testes novos: `relatorio_modelo_test.dart`. |
| 19b.1 | 23/11/2026 | Etapa 19b | Ajustes dos relatórios: botão "Exportar relatório" centralizado na barra (cortava); cliente por busca (nome ou CNPJ) no lugar da lista suspensa; PDF com "Relatório de Sinistros/Assistências" + modelo + cliente (nome e CNPJ) no cabeçalho; arquivo `corretora - cliente - modelo - data`; modais em fundo branco. +4 testes. |
| 19b.2 | 23/11/2026 | Etapa 19b.1 | Exportar: abre sem período escolhido — a prévia e os botões PDF/Excel só aparecem/ativam depois de escolher; prévia mostra o valor total só se o modelo tiver esse campo; "Data de referência" em bloco próprio, com espaço. |
| 19b.3 | 23/11/2026 | Etapa 19b.2 | Exportar mais enxuto: relatório **por cliente ou por seguradora**; filtro por **ramo** (Frota, Residencial, Vida…); período sempre pela **data da ocorrência** (sai "Data de referência"); sai "Tipo de ocorrência"; seguradoras com grafias parecidas aparecem uma vez só. PDF mostra a seguradora no cabeçalho e no nome do arquivo. |
| 19b.4 | 23/11/2026 | Etapa 19b.3 | Detalhe do sinistro: ramo em destaque ao lado do status e nosso nº de registro no topo, com botão copiar; assistência: nº com botão copiar + ramo (Veículo/Residencial). Exportar: filtros Ramo e Status sempre visíveis (com um ramo só, sumiam). |
| 19b.5 | 23/11/2026 | Etapa 19b.4 | Assistências: barra do topo com as mesmas medidas de Sinistros — "Exportar relatório" e os filtros não ficam mais cortados. |
| 20 | 23/11/2026 | Etapa 19b.5 | Seguradora só do cadastro: campo único com sugestões (abertura de sinistro, assistências, apólice, edição do sinistro) e conferência ao salvar; contrato importado e apólice copiada usam o nome cadastrado; cadastro barra nome parecido; ferramenta **Corrigir nomes nos registros** em Configurações → Seguradoras. |
| 21 | 24/11/2026 | Etapa 20 | **Portal da plataforma (fundação):** site separado (`lib/main_admin.dart`), admin criado só por script, dupla checagem (marca + registro ativo + não ser usuário de corretora), Function `plataforma` com auditoria, lista de corretoras com contagens, contas da plataforma (`plataforma_contas`) com "Criar contas que faltam" (fundadoras: ativa, Tudo ligado, cortesia). Hospedagem em dois alvos (`app` e `admin`). |
| 22 | 24/11/2026 | Etapa 21 | **Catálogo único de seguradoras:** lista única para todas as corretoras (`catalogo_seguradoras`), importada dos cadastros pelo portal (grafias parecidas viram uma, com apelidos); seguradora nova só pelo **CNPJ** com nome da Receita, pendente até a aprovação; portal com aprovar / juntar / recusar / editar (renomear e juntar trocam o nome nos registros de todas as corretoras); Configurações → Seguradoras mostra o catálogo + os contatos da corretora. Functions `catalogoSeguradoras` e novas ações em `plataforma`. |
| 22.1 | 24/11/2026 | Etapa 22 | Consulta do CNPJ no **navegador** (a BrasilAPI barra o servidor do Google com 403), servidor só confere quando consegue; portal: botão **Nova seguradora** (admin cria já aprovada) e consulta à Receita ao editar (para pôr CNPJ nas importadas); portal compilado com `--no-tree-shake-icons`. |
| 22.2 | 24/11/2026 | Etapa 22.1 | "Já está na lista" aparece **na consulta** do CNPJ (pelo CNPJ ou nome parecido, ex.: SUHAI SEGURADORA S.A. × SUHAI), não mais só ao clicar em Adicionar/Criar; no portal, "Completar" abre a existente com os dados da Receita; edição: Buscar CNPJ → nome da Receita já preenchido ("Manter" volta ao antigo, que vira apelido) → Salvar; dados da Receita copiáveis; app consulta no navegador se o servidor der qualquer erro. |
| 23 | 24/11/2026 | Etapa 22.2 | **Módulos e Meu plano:** catálogo de módulos (app e Functions iguais); portal → corretora → **Módulos do plano** (Tudo ligado ou escolher); no app, módulo fora do plano aparece com **cadeado** e página "Fora do plano"; trava também nas regras do Firestore/Storage e nos avisos do Telegram; tela **Meu plano**. Corrige no celular o item Configurações do menu (abria Relatórios). Fundadoras seguem Tudo ligado. |
| 24 | 24/11/2026 | Etapa 23 | **Planos:** aba **Planos** no portal (planos-modelo com preço mensal, franquias de usuários/GB/vídeo com preço do excedente, módulos; ativo/desativado); **Plano da corretora** (Tudo ligado, plano da lista ou personalizado, cortesia com validade, motivo no histórico); editar um plano em uso atualiza as corretoras dele; no app, botão **"Plano: …"** na barra do topo e Meu plano com preço e franquias. Function `plataforma` com as ações novas (`functions/planos.js`). |
| 25 | 24/11/2026 | Etapa 24 | **Autocadastro e teste grátis:** "Teste 14 dias grátis" na entrada do app (CNPJ pela Receita → pedido); portal → **Pedidos** (aprovar cria corretora + gestor + conta em teste e manda o e-mail de senha; recusar); **só leitura** nas regras para teste vencido/encerrado, suspensa e cancelada; faixa no app com os dias de teste ou o modo só leitura; Meu plano com planos disponíveis e "Quero este plano"; portal → corretora → **Situação**. Functions novas `autocadastro` e `minhaConta`. |
| 26 | 24/11/2026 | Etapa 25 | **Financeiro no portal:** receita do mês (MRR) pelo plano de cada corretora (preço + usuários acima da franquia), ticket médio, em atraso, cortesias, potencial dos testes, avisos (testes acabando/terminados, cortesias vencendo, inadimplentes) e tabela por corretora com Copiar tabela; receita do mês na Visão geral. Só portal. |
| 27 | 24/11/2026 | Etapa 26 | **Uso por corretora:** medição diária (03:30) e sob demanda dos GB de arquivos e de vídeos no Storage e dos usuários (`functions/uso.js`, `medirUsoDiario`); Financeiro soma os GB acima da franquia e mostra arquivos/vídeos por corretora; detalhe da corretora com o uso; Meu plano com "Usado: X de Y". |
| 28 | 24/11/2026 | Etapa 27 | **Beta, a assistente:** chat no app (botão no canto inferior esquerdo, módulo `beta`) que responde do banco contatos (segurado, contato, motorista, terceiro, contato/motorista do terceiro, local, oficina), veículos, status, pendências, sinistros do cliente e dono da placa, com botões Ligar/WhatsApp/E-mail/Abrir; continua a conversa pelo assunto; regras de texto + Claude Haiku só para entender a pergunta; custo medido por corretora com teto; portal → Beta (uso, custo, teto, perguntas sem resposta). |
| 28.1 | 24/11/2026 | Etapa 28 | Beta: "telefone de contato do <cliente>" pegava "contato do" junto com o nome e não achava o cliente; agora limpa as palavras da pergunta antes de buscar e entende como contato do segurado. |
| 28.2 | 24/11/2026 | Etapa 28.1 | Beta: "bem segurado"/"frota" = veículos; "que ele tem", "dele", "desse cliente" usam o cliente da conversa em vez de virar nome de cliente. |
| 28.3 | 24/11/2026 | Etapa 28.2 | Beta: "bens segurados do <cliente>" (e frota/placas/e-mail/celular do <cliente>) acha o nome; quando ela pergunta "de qual sinistro ou cliente?", a resposta só com o nome ou número completa o pedido anterior (só se for curta e não for outra pergunta). |
| 28.4 | 24/11/2026 | Etapa 28.3 | Beta: **apólices e bens do cadastro** — "<cliente> tem bens segurados?", "quais os bens e apólices <cliente> possui?", "<cliente> tem apólice?", "quando vence a apólice…", "total de gastos da apólice…" (sinistros na vigência × gatilho, mesma conta da recomendação). Bens vêm de todas as apólices/ramos. |
| 28.6 | 24/11/2026 | Etapa 28.4 | Beta: inclui a 28.5 (cliente com apólice sem bens cadastrados recebe essa resposta, com a lista das apólices). Entende "qual sinistro/assistência da <cliente>?" no singular e "o cliente X possui assistência em andamento?": o cliente citado vale mais que o atendimento da conversa, e a lista traz só sinistros ou só assistências e só os em andamento, conforme a pergunta. |
| 28.7 | 24/11/2026 | Etapa 28.6 | Beta: acha sinistros/assistências do cliente também pelo CNPJ/CPF e pelo nome gravados no atendimento (registros antigos); entende "está com assistência"; pergunta de status/pendência com nome de cliente lista os atendimentos em andamento dele. |
| 28.8 | 24/11/2026 | Etapa 28.7 | Beta: o código do documento vale mais que o campo "id" gravado dentro do cliente (vazio em muitos cadastros). A conversa não "esquece" mais o cliente ("e possui apólice vigente?") e os atendimentos ligados pelo id_cliente voltam a ser achados. |
| 28.9 | 24/11/2026 | Etapa 28.8 | Beta: as 3 pessoas de cada lado do sinistro. Segurado: proprietário do veículo (CRLV), condutor e contato do sinistro. Terceiro: proprietário, condutor e contato do sinistro. Campo vazio → "não há essa informação neste sinistro"; sem terceiros → "não houve terceiros neste sinistro". "Nome do condutor" deixa de ir para a IA. |
| 28.10 | 24/11/2026 | Etapa 28.9 | Beta: "contato do sinistro da <cliente>" acha o cliente (antes lia "contato" como nome). Pessoa do sinistro pedida pelo cliente, sem número: um sinistro em andamento → responde direto; vários → o dado de cada um, com o número. |
| 28.11 | 25/11/2026 | Etapa 28.10 | Beta: troca de cliente no meio da conversa. "sinistros abertos/em andamento da X" acha o X. Se a frase cita um cliente cadastrado que não foi recortado, ele vira o assunto (palavra própria do nome; dois clientes com a mesma palavra → não adivinha). |
| 11 | 08/11/2026 | `9159bd1` | **Busca de Sinistros** também por terceiros (proprietário, motorista, contato, registro na seguradora deles), proprietário/condutor do veículo segurado e contato do segurado; sem acento, várias palavras, telefone sem máscara (`lib/utils/busca.dart`). **Filtro de recomendação** da lista de clientes vira seletor no padrão dos filtros de Sinistros, ao lado da busca. **Sinistralidade Mensal** recalculada (sinistros ocorridos ÷ prêmio ganho), com linha acumulada e linha do gatilho (`lib/utils/sinistralidade.dart`). Testes novos: `busca_test.dart`, `sinistralidade_test.dart`. |
| 10 | 08/11/2026 | `44f5c8f` | **Top 10 de risco** com a regra da recomendação (vigentes, sem vínculo por ramo + data) e os mesmos nomes. **Lista de clientes:** filtro por recomendação ligado à exportação, que passa a trazer recomendação, uso do gatilho e contato (nome, telefone, e-mail). **Tarefas:** ordenar Mais recente/Mais antiga; exportar agrupado por funcionário (CSV/PDF); `concluida_em` gravado ao concluir; "no prazo / fora do prazo" pela regra única (antes concluída no prazo com data vencida contava como fora); editar não troca mais o responsável; o filtro por funcionário pelo id passou a funcionar (o campo não vinha na lista). **Relatórios:** Tarefas por Funcionário (abertas, concluídas %, no prazo × fora). Testes novos: `tarefas_test.dart` (+1 em `relatorio_clientes_test.dart`). |
| 09 | 08/11/2026 | `4d14169` | **Recomendação do cliente unificada pelo uso do gatilho** (pior apólice vigente; faixas 60/80/100%; sinistros sem vínculo ligados por ramo + data; "Sem apólice vigente" e "Apólice sem valor" em cinza; Detalhes mostra uso do gatilho e % do valor da apólice). Substitui 4 contas diferentes. Botões com texto: **"Exportar relatório"** na lista de clientes e **"Importar contrato (PDF)"** no cadastro. Teste novo: `recomendacao_cliente_test.dart`. |
| 08 | 08/11/2026 | `7301670` | **Apólice clicável no Detalhes do Cliente** (visualização com "Editar", que abre o cadastro direto na edição daquela apólice); visualização vira componente único (`apolice_visualizacao_dialog.dart`) usado também no cadastro. **SLA de sinistro para Civil Ônibus (RCO) = 7 e Empresarial = 10** (faltavam na tela e na abertura caía em 10); ramo "Vidas" passa a usar o SLA de "Vida". **Relatório de clientes (auditoria)** em CSV/PDF na lista de clientes, ordenado pelo valor das apólices, com maior apólice e total. **`.gitignore` sem depender do zip:** o verificador confere as linhas e trata `node_modules/`/`android/build/` no git como erro. Testes novos: `relatorio_clientes_test.dart`, `config_sla_test.dart`. |
| 07 | 07/11/2026 | `c7554c0` | **Gatilho da apólice:** % padrão em Configurações (70%); gatilho efetivo = contrato ou % × valor da apólice (fim do R$ 0,01). Cadastro da apólice com valores em R$, gatilho sugerido e editável, e **correção do bug que inflava valor/gatilho ao salvar sem redigitar**. Apólice clicável abre visualização (modo leitura + "Editar"). **Top 10 de risco revisado:** gatilho efetivo, só sinistros da vigência e não cancelados/negados, % sem casas decimais; abertura do sinistro usa a mesma regra no "uso atual". Dashboard deixa de apontar "Gatilho faltando" quando há valor da apólice. Reaplica a limpeza do git da Etapa 06 (não tinha sido aplicada). |
| 06 | 07/11/2026 | `c489e4b` | **Botão laranja "Nova Assistência"** de volta na lista de Assistências, abrindo o modal padrão Veicular/Residencial — agora um componente único com o Dashboard (`assist_tipo_picker.dart`). No Dashboard, o "Cancelar" desse modal fechava duas telas (podia fechar o app no Android); agora fecha só o modal. **Limpeza do git:** `node_modules/` (≈15 mil arquivos) e `android/build/` (cache) saem do repositório e entram no `.gitignore`. |
| 05 | 07/11/2026 | `2c48c4c` | **Filtro de status nas listas de Sinistros e Assistências:** "Em curso" (padrão, inclui Rascunho) · "Todos" (todos mesmo, inclusive Concluído/Cancelado) · cada status. Acabou o "Todos" duplicado em Sinistros. **Carregamento:** abre buscando só o que está em curso; o histórico é baixado quando o filtro pede. Regra única em `lib/utils/filtro_status.dart` + teste `test/filtro_status_test.dart`. |
| 04 | 07/11/2026 | `7295764` | **Abertura:** "Anexos e Documentos" logo após o bem segurado (antes de Terceiros). **Detalhe:** Veículo Segurado espelhando a abertura (Proprietário legal / Veículo / Motorista / Contato do sinistro); Proprietário legal passa a ser exibido; contato do sinistro com WhatsApp. |
| 03 | 07/11/2026 | `fdb7ce6` + 01 + 02 | **Harmonia visual da abertura:** Terceiros com o mesmo campo da planilha (rótulo em cima, caixa cinza); Veículo Segurado com os títulos e ícones dos Terceiros (Proprietário legal / Veículo / Motorista / Contato do sinistro); título "Veículo" também no terceiro (planilha e diálogos); checkbox do motorista no mesmo estilo nos dois. **CNH do motorista do terceiro** (planilha, diálogos, detalhe, PDF). |
| 02 | 07/11/2026 | `fdb7ce6` + 01 | **Terceiros por personagem** (proprietário CRLV / motorista / contato / sinistro do terceiro) na abertura, nos diálogos e no PDF. **Histórico de valores do sinistro**: lançamentos com data, tipo, valor, segurado ou terceiro, NF/evidências, quem registrou; cancelamento com motivo; total = segurado + terceiros; encerramento exige lançamento; valor da abertura vira 1º lançamento. Correções: telefone do terceiro não aparecia ao reabrir a planilha; editar terceiro apagava marca/modelo/anos da tela; WhatsApp do contato abria o telefone do proprietário. Teste novo: `test/lancamento_model_test.dart`. |
| 01 | 07/11/2026 | `fdb7ce6` | README reorganizado (seções duplicadas unificadas, sem perder informação); novas seções de Pendências de Segurança, Armadilhas, Processo de Entrega e Histórico; Cloud Function do Telegram e estrutura de `lib/` documentadas; `verificar-entrega.js` no `.gitignore`. Sem mudança de código. |

---

## 🆕 Melhorias Anteriores (antes da Etapa 01)

### Dashboard
- ✅ **NPS integrado** como 6º KPI executivo
- ✅ **Overview responsivo** para mobile, tablet e desktop
- ✅ Correção de problemas de renderização em telas pequenas

### Relatórios & Gráficos
- ✅ **8 gráficos mensais** com dados anuais de janeiro a dezembro:
  - 📈 NPS Mensal (0-10)
  - 📊 Sinistros Mensais (quantidade)
  - 🚗 Assistências Mensais (quantidade)
  - 📉 Sinistralidade Mensal (%)
  - 💰 Valor Apólices Mensais (R$ mil)
  - 📋 Contratos Ativos Mensais
  - 🎫 Ticket Médio Mensal (R$ mil)
  - 📊 Taxa de Retenção Mensal (%)

- ✅ **SLA em 2 gráficos separados:**
  - ✅ SLA Compliance Sinistros (prazo fixo 10 dias)
  - ✅ SLA Compliance Assistências (conforme slaPrevisto/slaAtendimento)

- ✅ **Refatoração do `_load()`** — loop único otimizado (não duplicado)
- ✅ **Tooltips melhorados** — background claro + formatação de valores

### Dados & Models
- ✅ **Novo campo:** `dataConclusao` (Timestamp) — preenchido automaticamente ao marcar "Concluído"
- ✅ **Novo campo:** `ramos` (List<String>) — múltiplos ramos por cliente
- ✅ **Seletor visual** de ramos no formulário de cliente (chips com ícones)

### SLA & Tracking
- ✅ **Preenchimento automático** de `dataConclusao` em sinistros e assistências
- ✅ **Fallback para dados antigos** usando `historicoStatus`
- ✅ **Suporte a período filtrado** em todos os gráficos

---

## ⚠️ Questão Aberta — Apólices por Ramo

**Atualmente:** 1 apólice por cliente (campos únicos)

**Necessário confirmar com cliente:**
- ❓ Cada ramo tem seu próprio número de apólice?
- ❓ Valores e gatilho variam por ramo?
- ❓ Datas de vigência são diferentes?

**Se SIM em qualquer:** Refatorar para estrutura aninhada:
```
apolices: [
  { ramo: "Veículo Individual", numero: "123-VA", valor: 5000, ... },
  { ramo: "Residencial", numero: "123-RES", valor: 3000, ... }
]
```

---

## 🗺️ Roadmap

### ✅ Completo
- [x] Dashboard com NPS integrado
- [x] Overview responsivo (mobile/tablet/desktop)
- [x] 8+ gráficos mensais
- [x] SLA compliance (sinistros e assistências)
- [x] Seletor visual de ramos
- [x] `dataConclusao` automático
- [x] Refatoração do `_load()`
- [x] Processo de entrega com verificador (Etapa 01)
- [x] Terceiros identificados por proprietário / motorista / contato (Etapa 02)
- [x] Histórico de valores do sinistro com NF e cancelamento rastreável (Etapa 02)
- [x] Abertura com padrão visual único entre Veículo Segurado e Terceiros + CNH do motorista do terceiro (Etapa 03)
- [x] Anexos logo após o bem segurado na abertura; Veículo Segurado espelhado no detalhe (Etapa 04)
- [x] Listas com filtro "Em curso" (padrão) e "Todos" de verdade; carregamento só do que está em curso (Etapa 05)
- [x] Gatilho da apólice com % padrão configurável, sugestão no cadastro, visualização da apólice e Top 10 de risco revisado (Etapa 07)
- [x] Apólice clicável no Detalhes do Cliente, SLA de RCO/Empresarial e relatório de clientes para auditoria (Etapa 08)
- [x] Recomendação do cliente unificada pelo uso do gatilho; botões "Exportar relatório" e "Importar contrato" com texto (Etapa 09)
- [x] Top 10 de risco pela recomendação; filtro por recomendação + exportação com contato; tarefas com ordenação, exportação por funcionário, data de conclusão e prazo; tarefas por funcionário nos Relatórios (Etapa 10)
- [x] Busca ampla de sinistros; filtro de recomendação no padrão visual; sinistralidade mensal por prêmio ganho (Etapa 11)
- [x] Vídeos do sinistro com limite, conversão 720p, player na tela e arquivamento; fim das fotos duplicadas (Etapa 12)
- [x] Vídeos na abertura no desenho das outras categorias de anexos, com arrastar e soltar (Etapa 13)
- [x] Tarefas ligadas ao atendimento: concluir ao encerrar/excluir, contato substituído, "já informei por outro meio", limpeza das esquecidas, alerta de atraso funcionando (Etapa 14)
- [x] Segurança: regras do Firestore e do Storage (só usuário ativo), Functions com login, NPS/login/criação de usuário pelo servidor, token do Telegram como segredo (Etapa 15)
- [x] Multi-tenant, preparação: dados por corretora (`corretoras/{id}/…`), migração, Configurações só leitura para funcionário (Etapa 16)
- [x] Multi-tenant, trava (16b): regras isolando cada corretora; excluir e configurar só gestor nas regras; limpeza das coleções antigas da raiz
- [x] Multi-tenant, arquivos (16c): Storage por corretora, links com chave no lugar dos públicos (S6), passagem dos arquivos antigos e limpeza dos originais; leitura única de nome/extensão dos links
- [x] Perfil da corretora (Etapa 17): dados e logo no cadastro; cabeçalho e rodapé padrão em todos os PDFs
- [x] Relatórios (Etapa 18): gráficos mensais param no mês atual (fim da "queda" de dezembro); Top 10 por valor de sinistros no lugar do "por Receita"; Maiores Apólices Vigentes com aviso de valor destoante
- [x] Notificação na tela clicável: abre a assistência, o atendimento da tarefa ou a lista de Tarefas; botão fechar (Etapa 18.1)
- [ ] Notificação **nativa do navegador** (aparece mesmo com outra aba/janela em foco), com clique abrindo o atendimento — hoje o Dashboard só pede a permissão
- [x] Valores da assistência (Etapa 19a): valor do serviço na abertura + adicionais no detalhe, mesmo histórico de lançamentos do sinistro
- [ ] **Gatilho mensal de assistências por cliente** (pedido do cliente da corretora — ex.: Águia Branca): valor estipulado pelo cliente a cada mês, **não ligado à apólice**; avisar a corretora ao atingir. A confirmar com a cliente: valor fixo ou por mês, por cliente ou por frota, % de aviso, quem é avisado
- [x] Relatórios de sinistros e assistências com modelos salvos (Etapa 19b): campos por seção, medidor de largura (tabela × ficha), filtros, PDF e Excel
- [x] Exportar relatório por **cliente** (todas as seguradoras dele) ou por **seguradora** (todos os clientes dela), com filtro por ramo; período sempre pela data da ocorrência (Etapa 19b.3)
- [x] **Seguradoras duplicadas** (Etapa 20). Causa: o campo Seguradora da abertura não sugeria nada (a lista chegava depois de o campo ser montado) e gravava qualquer texto; o mesmo nas assistências, na apólice e na edição do sinistro; a importação de contrato gravava o nome do PDF. Agora: campo único que sugere e só aceita seguradora do cadastro; nome importado/copiado vira o cadastrado; o cadastro barra nome parecido (CHUBB × Chubb, AXA × AXA Seguros). Registros antigos: **Configurações → Seguradoras → Corrigir nomes nos registros** (o gestor confere a sugestão de cada grafia e corrige em lote). Se renomear uma seguradora no cadastro, rode a correção de novo para atualizar os registros
- [ ] Marca da corretora na tela (white-label): nome "Upgrade Corretora" no menu e logo da tela de login ainda fixos (o login vem antes de saber a corretora — depende do domínio próprio)
- [ ] Planos de armazenamento (bronze/prata/ouro ou por GB): medir uso por corretora (soma de `tamanho_bytes` / Storage) e aplicar `videoMaxMb`/`videosPorSinistro` por plano — depende do multi-tenant
- [ ] `firebase_options.dart` com o bucket antigo (`appspot.com`): regenerar com `flutterfire configure` (hoje só os vídeos usam o SDK do Storage, com o bucket fixo)
- [ ] Assistências: vídeos (mesmo componente)
- [ ] KPI "Sinistralidade (%)" do topo dos Relatórios e sinistralidade por seguradora com a mesma regra (prêmio ganho no período)

### 🔐 Segurança (ver [Pendências de Segurança](#-pendências-de-segurança))
- [x] 🔴 S1 — Trocar token do Telegram e tirar o arquivo do git (Etapa 15)
- [ ] 🔴 S2 — Repositório de volta para privado (com conector do GitHub)
- [x] 🟠 S3 — Login obrigatório nas Functions de arquivo (Etapa 15)
- [ ] 🟠 S4 — Restringir e centralizar a chave do Google Maps/Places
- [x] 🟠 S5 — Regras do Firestore no repositório (Etapa 15)
- [x] 🟠 S6 — Anexos sem link público, na pasta da corretora (Etapa 16c)
- [x] 🟠 S7 — `node_modules/` fora do git (Etapa 06)

### ⏳ Próximo
- [ ] **Melhorias solicitadas pela cliente** (próximas etapas)
- [ ] Relatórios: separar segurado × terceiros nos gráficos de valor/sinistralidade (os dados já existem em `valor_segurado` / `valor_terceiros`)
- [ ] Danos materiais / corporais com lançamentos próprios (hoje o lançamento é do segurado ou de um terceiro de veículo)
- [ ] Detalhe do sinistro, próximos passos de harmonia (avaliados na Etapa 04, deixados para depois): mesma ordem de cards da abertura (Anexos em card próprio), modo edição no estilo da planilha (rótulo em cima, caixa cinza), cores/ícones dos cards iguais aos da abertura
- [x] Tirar `android/build/` e `node_modules/` do git (aplicado na Etapa 08)
- [ ] Gatilho: vincular de vez (gravar `apolice_id`) os sinistros antigos sem vínculo — a recomendação e o Top 10 já ligam por ramo + data só no cálculo; o "uso atual" da abertura ainda não
- [ ] Card da lista de clientes: "Vigência" mostra o fim da apólice que vence primeiro, mesmo já vencida — mostrar a da apólice vigente
- [ ] Escala: Dashboard e Relatórios com totais pré-calculados (hoje baixam todos os sinistros e assistências); listas com paginação do histórico se "Todos" ficar lento
- [ ] **Confirmar estrutura de apólices** com cliente
- [ ] **Testar SLA** com dados novos
- [ ] Gráficos comparativos (year-over-year)
- [ ] Reorganização do Dashboard (prioridades + tarefas)

### 🌍 Expansão Europa (a planejar)
- [ ] Adequação GDPR: região dos dados (Firestore/Storage na UE), consentimento, exportação e exclusão de dados do titular, registro de acesso, talvez link com validade nos anexos — S5 e S6 feitos
- [ ] Internacionalização (idiomas, moeda, formatos de data e documento — hoje CNPJ/CPF e R$)

### 📋 Futuro
- [ ] Push notification no app nativo (Firebase Messaging)
- [ ] WhatsApp Business API para envio automático sem interação manual
- [ ] Email automático de vencimento de apólice (Firebase Extension "Trigger Email")
- [ ] Relatórios de assistências (NPS, SLA médio, tipos mais frequentes)
- [ ] Gráfico de evolução NPS por cliente ao longo do tempo
- [ ] Filtro múltiplo de status em Sinistros
- [ ] App nativo iOS/Android com notificações push
- [ ] Portal do cliente (acesso restrito para acompanhar seus sinistros)
- [ ] Comparações year-over-year em todos os gráficos
