// @ts-nocheck
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");

if (!admin.apps.length) {
  admin.initializeApp();
}

// ⚠️ Não use mais TELEGRAM_CHAT_ID do .env.yaml para envio
// Apenas para fallback de segurança (opcional), mas vamos usar só o Firestore
const TELEGRAM_BOT_TOKEN = process.env.TELEGRAM_BOT_TOKEN || "";

/**
 * Envia mensagem para um chat_id específico
 */
async function enviarTelegram(mensagem, chatId) {
  if (!TELEGRAM_BOT_TOKEN || !chatId) {
    console.warn("⚠️ Token ou chat_id inválido.");
    return;
  }
  try {
    const url = `https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage`;
    const response = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        chat_id: chatId,
        text: mensagem,
      }),
    });
    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`HTTP ${response.status}: ${errorText}`);
    }
    console.log(`✅ Telegram enviado para chat_id: ${chatId}`);
  } catch (error) {
    console.error(`❌ Erro ao enviar para ${chatId}:`, error);
    throw error;
  }
}

/**
 * Verifica se o horário atual está dentro do período de silêncio
 */
function isSilencePeriod(horarioInicio, horarioFim) {
  const agora = new Date();
  const horaAtual = agora.getHours();
  const minutoAtual = agora.getMinutes();
  const minutosAtual = horaAtual * 60 + minutoAtual;

  const [hInicio, mInicio] = horarioInicio.split(':').map(Number);
  const [hFim, mFim] = horarioFim.split(':').map(Number);
  const inicioMin = hInicio * 60 + mInicio;
  const fimMin = hFim * 60 + mFim;

  if (inicioMin < fimMin) {
    return minutosAtual >= inicioMin && minutosAtual < fimMin;
  } else {
    return minutosAtual >= inicioMin || minutosAtual < fimMin;
  }
}

exports.verificarAssistenciasAtradasTelegram = onSchedule(
  "every 10 minutes",
  async () => {
    try {
      const db = admin.firestore();
      const agora = new Date();

      // 1. Carregar configuração do Firestore (app_config/config)
      const configDoc = await db.collection('app_config').doc('config').get();
      const config = configDoc.exists ? configDoc.data() : {};

      // 2. Extrair configurações de notificação
      const notificacoesAtivas = config.notificacoesAtivas ?? true;
      const horarioInicio = config.notificacaoHorarioInicio ?? "22:00";
      const horarioFim = config.notificacaoHorarioFim ?? "08:00";
      const intervaloReenvio = config.notificacaoIntervaloMinutos ?? 30;
      const atrasoMinimo = config.notificacaoAtrasoMinimo ?? 30;
      const chatIds = config.notificacaoTelegramChatIds ?? [];

      // 3. Verificar se há chat_ids configurados
      if (chatIds.length === 0) {
        console.log("🔇 Nenhum chat_id configurado no Firestore. Notificações desabilitadas.");
        return; // Interrompe a execução
      }

      // 4. Verificar se notificações estão ativas globalmente
      if (!notificacoesAtivas) {
        console.log("🔇 Notificações desativadas globalmente.");
        return;
      }

      // 5. Verificar período de silêncio
      if (isSilencePeriod(horarioInicio, horarioFim)) {
        console.log(`🔇 Período de silêncio (${horarioInicio} - ${horarioFim}). Notificações suprimidas.`);
        return;
      }

      console.log("🔍 Verificando assistências atrasadas...");

      // 6. Buscar assistências em "Aberto" e "Em Andamento"
      const statusList = ["Aberto", "Em Andamento"];
      let allDocs = [];
      for (const status of statusList) {
        const snapshot = await db
          .collection("assistencias")
          .where("status_atual", "==", status)
          .get();
        allDocs = allDocs.concat(snapshot.docs);
      }

      console.log(`📊 Total com status 'Aberto' ou 'Em Andamento': ${allDocs.length}`);

      // 7. Processar cada assistência
      for (const doc of allDocs) {
        const assist = doc.data();

        const numeroSinistro = assist.numero_sinistro || "N/A";
        const cliente = assist.client_nome || "Cliente";
        const tipo = assist.tipo_ocorrencia || "Tipo não informado";
        const slaAtendimento = assist.sla_atendimento?.toDate?.();
        const tempoEstimado = assist.tempo_sla_minutos ?? 0;
        const dataAbertura = assist.data_abertura?.toDate?.() || new Date();
        const ultimaNotificacao = assist.ultima_notificacao_atraso?.toDate?.() || null;
        const statusAtual = assist.status_atual || "Desconhecido";

        let atrasado = false;
        let minutosAtraso = 0;

        if (slaAtendimento) {
          atrasado = agora > slaAtendimento;
          minutosAtraso = Math.round((agora.getTime() - slaAtendimento.getTime()) / 60000);
        } else if (tempoEstimado > 0) {
          const slaCalculado = new Date(dataAbertura.getTime() + tempoEstimado * 60000);
          atrasado = agora > slaCalculado;
          minutosAtraso = Math.round((agora.getTime() - slaCalculado.getTime()) / 60000);
        } else {
          console.log(`⏭️ ${numeroSinistro} sem SLA e sem tempo estimado.`);
          continue;
        }

        if (atrasado && minutosAtraso >= atrasoMinimo) {
          let deveNotificar = false;

          if (!ultimaNotificacao) {
            deveNotificar = true;
          } else {
            const diffMinutos = Math.round((agora.getTime() - ultimaNotificacao.getTime()) / 60000);
            if (diffMinutos >= intervaloReenvio) {
              deveNotificar = true;
            }
          }

          if (deveNotificar) {
            console.log(`⚠️ ${numeroSinistro} ATRASADA! (${minutosAtraso} min) - Status: ${statusAtual}`);

            const mensagem = 
              `ASSISTENCIA ATRASADA\n\n` +
              `Numero: ${numeroSinistro}\n` +
              `Tipo: ${tipo}\n` +
              `Status: ${statusAtual}\n` +
              `Estimado: ${tempoEstimado} min\n` +
              `Atraso: +${minutosAtraso} min\n` +
              `Cliente: ${cliente}`;

            // 8. Enviar para TODOS os chat_ids da lista
            for (const chatId of chatIds) {
              await enviarTelegram(mensagem, chatId);
            }

            // 9. Atualizar última notificação
            await db.collection("assistencias").doc(doc.id).update({
              ultima_notificacao_atraso: admin.firestore.FieldValue.serverTimestamp(),
            });

            console.log(`✅ Notificações enviadas para ${chatIds.length} destinatário(s).`);
          } else {
            console.log(`⏳ ${numeroSinistro} já notificada recentemente.`);
          }
        }
      }
    } catch (error) {
      console.error("❌ Erro geral:", error);
    }
  }
);