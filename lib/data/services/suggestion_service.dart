import 'package:cloud_firestore/cloud_firestore.dart';

/// Serviço responsável pelo envio e registro de sugestões no Firestore.
///
/// Função e objetivo:
/// -------------------
/// Este serviço abstrai o processo de salvar sugestões dos usuários
/// em uma coleção dedicada no Firestore chamada `sugestoes`.
///
/// Ele permite que o app:
///   • colete feedback de pilotos/usuários
///   • registre melhorias solicitadas
///   • tenha histórico de pedidos
///   • consulte posteriormente no painel Firebase
///
/// Não existe resposta por e-mail aqui — o envio é apenas persistido
/// para posterior leitura e análise.
///
/// Modelo salvo no Firestore:
/// ```json
/// {
///   "email": "usuario@exemplo.com",
///   "titulo": "Melhorar UI",
///   "mensagem": "A busca poderia ser mais rápida",
///   "createdAt": <timestamp>
/// }
/// ```
///
/// Detalhes técnicos:
/// ------------------
/// • Usa `FieldValue.serverTimestamp()` para garantir horário oficial.
/// • Em caso de erro:
///   - não lança exceção
///   - retorna `false`
///   - loga no console (útil para debug)
///
/// Este design simplifica o uso no front-end ― permitindo:
/// ```dart
/// final ok = await SugestaoService.enviar(...);
/// if (ok) showSuccess();
/// else showError();
/// ```
class SugestaoService {

  /// Envia uma sugestão para o Firestore.
  ///
  /// Parâmetros obrigatórios:
  ///   • [email] — contato do usuário (quem enviou)
  ///   • [titulo] — assunto resumido da sugestão
  ///   • [mensagem] — descrição detalhada
  ///
  /// Retorno:
  ///   • true → sugestão salva com sucesso
  ///   • false → ocorreu erro no Firestore
  static Future<bool> enviar({
    required String email,
    required String titulo,
    required String mensagem,
  }) async {
    try {
      await FirebaseFirestore.instance.collection("sugestoes").add({
        "email": email,
        "titulo": titulo,
        "mensagem": mensagem,
        "createdAt": FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      // Log simples para depuração (não quebra a UI)
      print("Erro ao salvar sugestão: $e");
      return false;
    }
  }
}
