# Upgrade Seguros — SaaS de Gestão para Corretoras

> Plataforma web/mobile para corretoras de seguros gerenciarem sinistros, assistências, clientes, tarefas e métricas de desempenho em tempo real.

**Versão do documento:** Etapa 13 (GitHub `4dbf6a6` = Etapas 01–12 + limite de vídeo em 100 MB)
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
| `services/` | Firestore, Storage, Auth, biometria, PDF (relatório, admin, assinatura), NPS, monitor de SLA, notificações, imagem (mobile/web) |
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
| Tipo | `agendamento` / `reagendamento` / manual |

**Criação automática:**
- Agendamento informado na abertura → tarefa `tipo: agendamento`
- Reagendamento → conclui tarefa anterior, cria nova `tipo: reagendamento`

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
- Armazenamento: Firebase Storage
- Paths: `assistencias/{numero}/fotos/` e `/laudos/`
- Web: compressão via pacote `image` (sem dependência de flutter_image_compress)
- **Abertura do sinistro (Etapa 12):** cada anexo sobe **uma vez só** (`_urlAnexoEnviado`). Antes, todo salvamento — inclusive o automático a cada edição — comprimia e enviava as fotos de novo com nome novo, duplicando arquivos no Storage.

### Vídeos do sinistro (Etapa 12)
- **Onde:** abertura (dentro de "Anexos e Documentos", categoria "VÍDEOS DO SINISTRO" — desde a Etapa 13 no mesmo desenho das outras categorias: rótulo cinza, botão "+ Adicionar vídeos" com contorno e caixa onde dá para **arrastar e soltar** ou clicar) e detalhe ("Vídeos da Ocorrência", no modo edição para adicionar/excluir).
- **Limites** (Configurações → "🎬 Vídeos do sinistro", em `app_config/config`): `videoMaxMb` e `videosPorSinistro` (padrão **5**). Pensados para variar por plano. O padrão de MB nasceu em 20 (Etapa 12) e foi alterado no código para **100** pelo Marcony (commit `4dbf6a6`): a cliente tem vídeos de 60–70 MB. Um valor salvo em Configurações vale mais que o padrão do código. Teto absoluto de 100 MB (até 100 MB inclusive nas regras do Storage desde a Etapa 13).
- **Envio direto ao Storage** pelo SDK (`lib/services/video_service.dart`), com progresso — a Function `uploadFile` (base64 por HTTP) tem limite de ~10 MB e não serve para vídeo. Bucket explícito `upgrade-seguros.firebasestorage.app` (`Videos.bucket`): o `firebase_options.dart` ainda tem o nome antigo `appspot.com`.
- **Caminho:** `videos/sinistros/{nº}/{data}_{nome}`. Registro no sinistro: campo `videos` = lista de `{url, caminho, nome, tamanho_bytes, enviado_em, enviado_por}` (`VideoAnexo`, `lib/utils/videos.dart`). O tamanho fica guardado para a futura medição por plano.
- **Conversão:** `functions/converter-video.js` (gatilho de Storage, 2 GiB, 9 min) converte para MP4 720p (lado menor ≤ 720 px, CRF 28, AAC 96k, faststart) e grava por cima mantendo o token — o link salvo continua valendo. Marca `convertido=sim|falhou`. Se o original já é MP4 e a conversão não ficar menor, mantém o original. Resolve o .mov (HEVC) do iPhone, que não toca no Chrome.
- **Assistir:** `video_player` numa janela sobre a tela (play/pausa, barra de tempo, som). Na abertura, toca o arquivo local antes de enviar. `lib/widgets/videos_sinistro.dart`.
- **No detalhe**, adicionar/excluir grava direto no documento (`arrayUnion`/`arrayRemove`) e exclui o arquivo do Storage. Excluir o sinistro apaga os vídeos.
- **Arquivamento:** `storage-lifecycle.json` — vídeos com mais de 180 dias vão para **Coldline** (ativar uma vez com `gcloud storage buckets update gs://upgrade-seguros.firebasestorage.app --lifecycle-file=storage-lifecycle.json` ou pelo console do Cloud Storage → bucket → Ciclo de vida).
- **Regras do Storage** (`storage.rules`): vídeo só na pasta `videos/`, só logado, até 100 MB (inclusive — Etapa 13; antes um arquivo de exatamente 100 MB passava no app e era recusado no Storage); demais pastas como antes.

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

### Notificações do Browser
- Solicita permissão ao abrir o dashboard
- Verifica a cada 2 minutos
- Dispara alerta se SLA vencido ou ≤15min restantes
- Dispara alerta para tarefas atrasadas
- `requireInteraction: true` — não some sem interação
- Clique abre a ocorrência diretamente
- Cache de 30min por alerta (evita spam)

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

### Exportação
- **PDF** com todas as seções — gerado via `pdf` + `printing`

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

| Coleção | Conteúdo |
|---|---|
| `sinistros` | Registros de sinistros |
| `assistencias` | Registros de assistências veiculares e residenciais |
| `clientes` | Cadastro de clientes com veículos, ramos e NPS |
| `seguradoras` | Seguradoras cadastradas (campo `ativa`) |
| `tasks` | Tarefas vinculadas a sinistros e assistências |
| `nps_pesquisas` | Pesquisas NPS enviadas (status: enviada / respondida) |
| `avaliacoes` | Respostas das pesquisas NPS |
| `users` | Usuários do sistema |

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
| `uploadFile` | HTTP | Recebe base64, salva no Storage, retorna URL pública |
| `deleteFiles` | HTTP | Remove array de paths do Storage |
| `converterVideo` | Storage (arquivo finalizado em `videos/`) | Etapa 12: converte para MP4 720p no mesmo caminho (ffmpeg-static) |
| `verificarAssistenciasAtradasTelegram` | Agendada (a cada 10 min) | Lê `app_config/config` e avisa no Telegram as assistências com SLA atrasado, respeitando horário configurado |

> Storage URLs são públicas (`makePublic()`). Para produção com dados sensíveis, considerar URLs assinadas com expiração (ver Pendências de Segurança, item S6).

---

## 🔐 Pendências de Segurança

Levantadas na revisão da base (07/11/2026). O repositório no GitHub está **público**, então tudo que está no git pode ser lido por qualquer pessoa. Por isso, aqui as pendências ficam descritas de forma resumida, sem detalhes de como explorar.

### 🔴 Urgente (fazer assim que possível — depende do celular para o 2FA)
- [ ] **S1 — Trocar o token do bot do Telegram.** O token atual ficou registrado num arquivo de parâmetros dentro de `functions/` e está no histórico do git.
  1. Telegram → @BotFather → `/revoke` → escolher o bot → gerar token novo.
  2. Deploy das Functions com o token novo (`firebase deploy --only functions --set-env-vars TELEGRAM_BOT_TOKEN=...`), digitado no terminal, **sem salvar em arquivo do projeto**.
  3. `git rm --cached functions/telegram-parameters.md`, acrescentar no `.gitignore`, commit. (Continua no histórico — por isso o passo 1 é o que resolve.)
  4. Conferir: `node verificar-entrega.js` deixa de mostrar o aviso do Telegram.
- [ ] **S2 — Voltar o repositório para privado** depois de configurar o acesso de leitura do Claude (conector do GitHub em claude.ai → Configurações → Conectores). Sem isso, cada ciclo exige o repositório público.

### 🟠 Para olhar em seguida (entram no plano quando for oportuno)
- [ ] **S3 — Exigir login nas Cloud Functions de arquivo** (`uploadFile`, `deleteFiles`): validar o token do Firebase Auth do usuário e restringir os caminhos permitidos. Mexe em `functions/index.js` e em `firestore_service.dart`/`storage_service.dart` (passar o token). *Candidata natural para a próxima etapa que tocar em anexos.* As notas fiscais dos lançamentos (Etapa 02) usam a mesma função (`uploadArquivosEmPasta`), então a correção vale para elas também.
- [ ] **S4 — Restringir a chave do Google Maps/Places** no Google Cloud Console (referenciadores HTTP do domínio + package/bundle dos apps Android/iOS + só as APIs usadas). Hoje a chave está escrita em 8 arquivos de tela; numa etapa futura, centralizar em `utils/constants.dart` (uma chave, um lugar). *Restrição no console não exige entrega; a centralização entra quando alguma etapa mexer nessas telas.*
- [ ] **S5 — Regras do Firestore no repositório.** Não há `firestore.rules` no projeto: conferir no console do Firebase o que está publicado, trazer para o repositório e registrar no `firebase.json`, para que regra também passe pelo ciclo de entrega. As regras do Storage (`storage.rules`) exigem só "estar logado" — avaliar restrição por corretora/usuário.
- [ ] **S6 — URLs públicas dos anexos.** `makePublic()` deixa fotos e laudos acessíveis a quem tiver o link. Trocar por URL assinada com expiração ou download autenticado. **Pré-requisito para a Europa (GDPR) e reforça a LGPD.**
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
- [ ] Planos de armazenamento (bronze/prata/ouro ou por GB): medir uso por corretora (soma de `tamanho_bytes` / Storage) e aplicar `videoMaxMb`/`videosPorSinistro` por plano — depende do multi-tenant
- [ ] `firebase_options.dart` com o bucket antigo (`appspot.com`): regenerar com `flutterfire configure` (hoje só os vídeos usam o SDK do Storage, com o bucket fixo)
- [ ] Assistências: vídeos (mesmo componente)
- [ ] KPI "Sinistralidade (%)" do topo dos Relatórios e sinistralidade por seguradora com a mesma regra (prêmio ganho no período)

### 🔐 Segurança (ver [Pendências de Segurança](#-pendências-de-segurança))
- [ ] 🔴 S1 — Trocar token do Telegram e tirar o arquivo do git
- [ ] 🔴 S2 — Repositório de volta para privado (com conector do GitHub)
- [ ] 🟠 S3 — Login obrigatório nas Functions de arquivo
- [ ] 🟠 S4 — Restringir e centralizar a chave do Google Maps/Places
- [ ] 🟠 S5 — Regras do Firestore no repositório
- [ ] 🟠 S6 — Anexos com URL assinada em vez de pública
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
- [ ] Adequação GDPR: região dos dados (Firestore/Storage na UE), consentimento, exportação e exclusão de dados do titular, registro de acesso — depende de S5 e S6
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
