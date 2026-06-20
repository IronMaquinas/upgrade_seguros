# Upgrade Seguros — SaaS de Gestão para Corretoras

> Plataforma web/mobile para corretoras de seguros gerenciarem sinistros, assistências, clientes, tarefas e métricas de desempenho em tempo real.

---

## Stack Tecnológica

| Camada | Tecnologia |
|---|---|
| Frontend | Flutter Web + Mobile |
| Backend | Firebase (Firestore + Storage + Auth) |
| Cloud Functions | Node.js |
| Mapas / Endereços | Google Places SDK + Google Maps Flutter |
| PDF | `pdf` + `printing` |
| Notificações | Web Notifications API (browser) |
| NPS | Link único via WhatsApp / Email (Gmail) |

---

## Navegação Principal

| Tela | Descrição |
|---|---|
| **Início (Dashboard)** | KPIs executivos, alertas de prazo, assistências ativas |
| **Sinistros** | Lista, filtros, abertura de novos registros |
| **Assistências** | Lista veicular e residencial, SLA countdown |
| **Clientes** | Cadastro, apólices, veículos, NPS score |
| **Tarefas** | Acompanhamento operacional com prazos |
| **Relatórios** | Analytics com exportação PDF |
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
| `client_form_screen.dart` | Cadastro de cliente / empresa |

---

## Gestão de Clientes

- **Busca automática de CNPJ** via BrasilAPI (preenche nome e sócio)
- **CNPJ alfanumérico** (padrão julho/2026)
- **Validação de duplicata** de CNPJ/CPF
- **Veículos segurados**: marca / modelo / cor / ano fabricação / ano modelo / placa / chassi + fotos
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
Reparo em Andamento → Concluído
    ou
Negado / Cancelado
```

**Auditoria completa:** cada mudança de status registra data, hora e responsável no histórico.

---

## Fluxo de Assistências

```
Abertura (veicular ou residencial)
    ↓ SLA countdown inicia (padrão 30min, configurável)
Aberto
    ↓ Funcionário encontra prestador
Em Andamento → define tempo de chegada → novo SLA countdown
    ↓
Concluído / Cancelado
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

### Seções do Relatório
1. Métricas gerais (total, valor, sinistralidade, tempo médio)
2. Distribuição por status
3. Funil de etapas do processo
4. Aprovações paradas (>3 dias)
5. Reparos prolongados (>7 dias)
6. Desempenho por funcionário
7. Clientes de alto risco (sinistralidade elevada)
8. Contratos próximos do vencimento (30 dias)
9. Sinistros em atraso (≥7 dias sem movimentação)

### Exportação
- **PDF** com todas as seções — gerado via `pdf` + `printing`

---

## Estrutura de Dados (Firestore)

| Coleção | Conteúdo |
|---|---|
| `sinistros` | Registros de sinistros |
| `assistencias` | Registros de assistências veiculares e residenciais |
| `clientes` | Cadastro de clientes com veículos e NPS |
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

---

## Autenticação e Segurança

- **Login** com email/senha via Firebase Auth
- **Biometria** no app mobile
- **Admin vs funcionário**: controle de permissões para exclusão
- **Dados isolados** por `responsavelEmail`
- **CNPJ duplicado**: validação antes de salvar novo cliente

---

## Cloud Functions (Node.js)

| Função | Descrição |
|---|---|
| `uploadFile` | Recebe base64, salva no Storage, retorna URL pública |
| `deleteFiles` | Remove array de paths do Storage |

> Storage URLs são públicas (`makePublic()`). Para produção com dados sensíveis, considerar URLs assinadas com expiração.

---

## Roadmap Sugerido

- [ ] Push notification no app nativo (Firebase Messaging)
- [ ] WhatsApp Business API para envio automático sem interação manual
- [ ] Email automático de vencimento de apólice (Firebase Extension "Trigger Email")
- [ ] Relatórios de assistências (NPS, SLA médio, tipos mais frequentes)
- [ ] Gráfico de evolução NPS por cliente ao longo do tempo
- [ ] Filtro múltiplo de status em Sinistros
- [ ] App nativo iOS/Android com notificações push
- [ ] Portal do cliente (acesso restrito para acompanhar seus sinistros)

## 🆕 Melhorias Recentes (Sessão Atual)

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
2. NPS Breakdown (Promotor / Neutro / Detrator)
3. Tempo Médio (Sinistros / Assistências)
4. Envolvimento de Terceiros (%)
5. Aprovações paradas (>3 dias)
6. Reparos prolongados (>7 dias)
7. Desempenho por funcionário
8. Clientes de alto risco (sinistralidade ≥60%)
9. Contratos próximos do vencimento (30 dias)
10. Sinistros em atraso (≥7 dias sem movimentação)

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

## Cloud Functions (Node.js)

| Função | Descrição |
|---|---|
| `uploadFile` | Recebe base64, salva no Storage, retorna URL pública |
| `deleteFiles` | Remove array de paths do Storage |

> Storage URLs são públicas (`makePublic()`). Para produção com dados sensíveis, considerar URLs assinadas com expiração.

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

## Roadmap

### ✅ Completo (Sessão Atual)
- [x] Dashboard com NPS integrado
- [x] Overview responsivo (mobile/tablet/desktop)
- [x] 8+ gráficos mensais
- [x] SLA compliance (sinistros e assistências)
- [x] Seletor visual de ramos
- [x] `dataConclusao` automático
- [x] Refatoração do `_load()`

### ⏳ Próximo
- [ ] **Confirmar estrutura de apólices** com cliente
- [ ] **Testar SLA** com dados novos
- [ ] Gráficos comparativos (year-over-year)
- [ ] Reorganização do Dashboard (prioridades + tarefas)

### 📋 Futuro
- [ ] Push notification no app nativo (Firebase Messaging)
- [ ] WhatsApp Business API para envio automático
- [ ] Email automático de vencimento de apólice
- [ ] Relatórios de assistências (NPS, SLA médio, tipos)
- [ ] Gráfico de evolução NPS por cliente
- [ ] Filtro múltiplo de status em Sinistros
- [ ] App nativo iOS/Android com notificações push
- [ ] Portal do cliente (acesso restrito)
- [ ] Comparações year-over-year em todos os gráficos
