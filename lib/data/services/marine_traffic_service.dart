import 'package:universal_html/html.dart' as html;

/// ============================================================================
/// MARINE TRAFFIC SERVICE
/// ============================================================================
/// Serviço para abrir o site MarineTraffic.
/// Abre a página principal para o prático fazer a busca manualmente.
///
class MarineTrafficService {
  /// Abre MarineTraffic
  ///
  /// Parâmetros:
  ///   • [shipName] - Nome do navio (não usado, mantido para compatibilidade)
  ///   • [imo] - IMO do navio (opcional, abre página direta se disponível)
  ///
  /// Retorna:
  ///   • true se abriu com sucesso
  ///   • false se houve erro
  static Future<bool> openMarineTraffic({
    required String shipName,
    String? imo,
  }) async {
    try {
      String url;

      // Se tiver IMO válido, abre a página específica do navio
      if (imo != null && 
          imo.isNotEmpty && 
          imo != 'N/A' && 
          imo != '0' &&
          imo != 'null') {
        url = 'https://www.marinetraffic.com/en/ais/details/ships/imo:$imo';
      }
      // Senão, abre a página principal
      else {
        url = 'https://www.marinetraffic.com';
      }

      html.window.open(url, '_blank');
      return true;
    } catch (e) {
      return false;
    }
  }
}