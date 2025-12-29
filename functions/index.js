const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.firestore();

/// 🔑 MAPA OFICIAL DE CHAVES (BACKEND ⇄ FRONTEND)
const MAPA_CHAVES = {
  "Dispositivo de Embarque/Desembarque": "dispositivo",
  "Temperatura da Cabine": "temp_cabine",
  "Limpeza da Cabine": "limpeza_cabine",
  "Passadiço – Equipamentos": "passadico_equip",
  "Passadiço – Temperatura": "passadico_temp",
  "Comida": "comida",
  "Relacionamento com comandante/tripulação": "relacionamento",
};

/// ---------------------------------------------------------------------------
/// RECALCULA MÉDIAS AO EXCLUIR UMA AVALIAÇÃO
/// ---------------------------------------------------------------------------
exports.recalcularMediasAoExcluirAvaliacao = functions.firestore
  .document("navios/{navioId}/avaliacoes/{avaliacaoId}")
  .onDelete(async (_, context) => {
    const navioId = context.params.navioId;

    const avaliacoesRef = db
      .collection("navios")
      .doc(navioId)
      .collection("avaliacoes");

    const snapshot = await avaliacoesRef.get();

    if (snapshot.empty) {
      await db.collection("navios").doc(navioId).update({
        medias: {},
      });
      return;
    }

    const soma = {};
    const contagem = {};

    snapshot.docs.forEach((doc) => {
      const data = doc.data();
      const itens = data.itens || {};

      Object.entries(itens).forEach(([chave, valor]) => {
        const keyPadrao = MAPA_CHAVES[chave];
        const nota = valor?.nota;

        if (keyPadrao && typeof nota === "number") {
          soma[keyPadrao] = (soma[keyPadrao] || 0) + nota;
          contagem[keyPadrao] = (contagem[keyPadrao] || 0) + 1;
        }
      });
    });

    const medias = {};
    Object.keys(soma).forEach((chave) => {
      medias[chave] = Number(
        (soma[chave] / contagem[chave]).toFixed(2)
      );
    });

    await db.collection("navios").doc(navioId).update({
      medias,
    });
  });

/// ---------------------------------------------------------------------------
/// RECALCULA TODAS AS MÉDIAS (MANUAL / CORREÇÃO GLOBAL)
/// ---------------------------------------------------------------------------
exports.recalcularTodasAsMedias = functions.https.onRequest(
  async (req, res) => {
    try {
      const naviosSnapshot = await db.collection("navios").get();

      for (const navioDoc of naviosSnapshot.docs) {
        const avaliacoesSnapshot = await navioDoc.ref
          .collection("avaliacoes")
          .get();

        if (avaliacoesSnapshot.empty) {
          await navioDoc.ref.update({ medias: {} });
          continue;
        }

        const soma = {};
        const contagem = {};

        avaliacoesSnapshot.docs.forEach((doc) => {
          const data = doc.data();
          const itens = data.itens || {};

          Object.entries(itens).forEach(([chave, valor]) => {
            const keyPadrao = MAPA_CHAVES[chave];
            const nota = valor?.nota;

            if (keyPadrao && typeof nota === "number") {
              soma[keyPadrao] = (soma[keyPadrao] || 0) + nota;
              contagem[keyPadrao] = (contagem[keyPadrao] || 0) + 1;
            }
          });
        });

        const medias = {};
        Object.keys(soma).forEach((chave) => {
          medias[chave] = Number(
            (soma[chave] / contagem[chave]).toFixed(2)
          );
        });

        await navioDoc.ref.update({ medias });
      }

      res.status(200).send("Médias recalculadas com sucesso");
    } catch (err) {
      console.error(err);
      res.status(500).send("Erro ao recalcular médias");
    }
  }
);
