# Upgrade Seguros — SaaS de Gestão para Corretoras

> Plataforma web/mobile para corretoras de seguros gerenciarem sinistros, assistências, clientes, tarefas e métricas de desempenho em tempo real.

**Versão do documento:** Etapa 02 (base `fdb7ce6` + Etapa 01)
**Última atualização:** 07/11/2026
**Status:** app em uso; ciclo de entregas com verificação por md5 em andamento. Etapa 02: terceiros identificados por personagem (proprietário / motorista / contato) e **histórico de valores do sinistro** (lançamentos com nota fiscal, segurado + terceiros). Pendências de segurança abertas — ver [🔐 Pendências de Segurança](#-pendências-de-segurança).

---

## 📋 Índice

1. [Stack Tecnológica](#stack-tecnológica)
2. [Navegação Principal](#navegação-principal)
3. [Tipos de Registro](#tipos-de-registro)
4. [Fluxos de Sinistros e Assistências](#fluxo-de-sinistros)
   - [Terceiros (Reclamados)](#terceiros-reclamados)
   - [Valores do Sinistro — histórico de lançamentos](#valores-do-sinistro--histórico-de-lançamentos)
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
- **Ramos de Seguro**: Seleção múltipla com chips visuais (🚗 Veículo · 🏠 Residencial · 🚚 Frota · ⚙️ Máquinas · 💓 Vida · 📦 Transporte)
- **Vigência de apólice** com alerta de vencimento (badge laranja nos últimos 30 dias)
- **Score de recomendação**: Bom / Regular / Crítico (baseado em número de sinistros)
- **NPS Score** acumulado por cliente (−100 a +100)
- **Valor da apólice** e **valor gatilho**

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
| **Motorista** | "O motorista é o próprio proprietário" **ou** nome, CPF, telefone, e-mail |
| **Contato** | Nome e telefone de quem a corretora aciona |
| **Sinistro do terceiro** | Nº do registro na seguradora do terceiro, relato |
| **Valores pagos a este terceiro** | Subtotal dos lançamentos do terceiro (ver abaixo) |

- O botão **Auto** (CRLV) preenche o proprietário (nome/CPF do CRLV) e o veículo; a pergunta "condutor é o proprietário?" marca o grupo Motorista.
- Cada terceiro tem um `id` estável, que liga os lançamentos de valor a ele. Terceiros antigos ganham o `id` no primeiro lançamento.

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

**Botão "Adicionar Tempo":** rastreado no histórico como `+Xmin adicionados`. Aparece em qualquer status exceto Concluído/Cancelado.

---

## Gestão de Tarefas

| Campo | Valores |
|---|---|
| Status | Aberta / Pendente / Em andamento / Concluída |
| Prazo | Data com alerta visual colorido |
| Tipo | `agendamento` / `reagendamento` / manual |

**Criação automática:**
- Agendamento informado na abertura → tarefa `tipo: agendamento`
- Reagendamento → conclui tarefa anterior, cria nova `tipo: reagendamento`

**Cores de prazo:**
- 🟢 Verde — mais de 2 dias
- 🟠 Laranja — 1–2 dias
- 🔴 Vermelho — vencida (não concluída)

---

## Anexos e Arquivos

| Categoria | Formatos | Compressão |
|---|---|---|
| Fotos da Ocorrência | JPG, PNG, GIF, WEBP | Sim (quality 50, maxWidth 1024) — mobile e web |
| Documentos / Laudos | PDF, DOC, DOCX, qualquer | Não |

- Upload via clique ou **drag & drop**
- Sanitização de nome (remove `# ? & % espaços`)
- Armazenamento: Firebase Storage
- Paths: `assistencias/{numero}/fotos/` e `/laudos/`
- Web: compressão via pacote `image` (sem dependência de flutter_image_compress)

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
- Sinistralidade (%)
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
- 📉 **Sinistralidade Mensal** (%)
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
- [ ] **S7 — Tirar `node_modules/` do git** (~15 mil arquivos versionados na raiz): `git rm -r --cached node_modules`, acrescentar no `.gitignore`. Não muda o funcionamento; deixa o repositório leve e o diff legível.

---

## ⚠️ Armadilhas Conhecidas

- **Análise no ambiente do Claude (desde a Etapa 02):** o SDK do Flutter não baixa lá (Google Storage bloqueado), mas o Claude monta uma análise parcial: Dart SDK do conda-forge + código do Flutter e dos plugins principais (Firestore, Auth, Storage, pickers, pdf/printing) clonados do GitHub nas versões do `pubspec.lock`. Compara os erros/avisos **antes × depois** da mudança — qualquer diagnóstico novo aparece. Plugins sem código lá (mapas, Places, Font Awesome, url_launcher, máscara, Syncfusion, uuid, desktop_drop) ficam sem checagem de tipo. O `flutter analyze` + `flutter test` completos continuam no Mac (`--analyze` do verificador).
- **Lançamentos só por transação:** gravar o sinistro inteiro (`updateClaim` / `Claim.toMap()`) regrava a lista `lancamentos` com o que está em memória. Hoje só o encerramento faz isso, com o estado atualizado pelo listener. Lançar/cancelar valor **sempre** pelo `LancamentosService` (transação), nunca editando a lista e salvando o claim.
- **Marca/modelo do terceiro editado antes da Etapa 02:** o diálogo de edição antigo gravava marca, modelo e anos só dentro de `veiculo` (a tela mostrava vazio). O `ThirdParty.fromMap` agora cai para `veiculo` quando o campo próprio está vazio; ao salvar de novo, os dois ficam preenchidos.
- **Pacote importado sem estar no `pubspec.yaml`:** `latlong2` é importado em `widgets/workshop_widget.dart`, mas só chega como dependência de outro pacote. Compila hoje; quebra se o outro pacote deixar de usá-lo. Corrigir quando a etapa mexer nesse arquivo (o import parece não ser usado — `hide LatLng`).
- **Import com barra no início:** `screens/client_form_screen.dart` importa `'/widgets/vigencia_date_range_widget.dart'`. Trocar por `package:upgrade_seguros/widgets/...` quando a etapa mexer nesse arquivo.
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

---

## 📦 Histórico de Entregas

| Etapa | Data | Base | O que mudou |
|---|---|---|---|
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

### 🔐 Segurança (ver [Pendências de Segurança](#-pendências-de-segurança))
- [ ] 🔴 S1 — Trocar token do Telegram e tirar o arquivo do git
- [ ] 🔴 S2 — Repositório de volta para privado (com conector do GitHub)
- [ ] 🟠 S3 — Login obrigatório nas Functions de arquivo
- [ ] 🟠 S4 — Restringir e centralizar a chave do Google Maps/Places
- [ ] 🟠 S5 — Regras do Firestore no repositório
- [ ] 🟠 S6 — Anexos com URL assinada em vez de pública
- [ ] 🟠 S7 — `node_modules/` fora do git

### ⏳ Próximo
- [ ] **Melhorias solicitadas pela cliente** (próximas etapas)
- [ ] Relatórios: separar segurado × terceiros nos gráficos de valor/sinistralidade (os dados já existem em `valor_segurado` / `valor_terceiros`)
- [ ] Danos materiais / corporais com lançamentos próprios (hoje o lançamento é do segurado ou de um terceiro de veículo)
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
