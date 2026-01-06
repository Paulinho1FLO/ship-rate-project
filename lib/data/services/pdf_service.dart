// data/services/pdf_service.dart

// No topo do arquivo pdf_service.dart, substitua os imports:

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// Import condicional - só importa html no web
import 'package:universal_html/html.dart' as html;

/// ============================================================================
/// PDF SERVICE
/// ============================================================================
/// Serviço para gerar PDFs de avaliações de navios.
///
/// Funcionalidades:
/// ----------------
/// • Gerar PDF completo da avaliação
/// • Funciona em mobile (Android/iOS) e web
/// • Design profissional com logo e cores do ShipRate
/// • Salvar e compartilhar PDF
///
/// Compatibilidade:
/// ----------------
/// • Mobile: Abre dialog de compartilhamento nativo
/// • Web: Faz download automático do arquivo PDF
///
class PdfService {
  /// --------------------------------------------------------------------------
  /// Gera PDF da avaliação
  /// --------------------------------------------------------------------------
  /// Parâmetros:
  ///   • [shipName] - Nome do navio
  ///   • [shipImo] - IMO do navio (opcional)
  ///   • [evaluatorName] - Nome do prático avaliador
  ///   • [evaluationDate] - Data da avaliação
  ///   • [cabinType] - Tipo de cabine
  ///   • [disembarkationDate] - Data de desembarque
  ///   • [ratings] - Map com notas e observações por critério
  ///   • [generalObservation] - Observação geral
  ///   • [shipInfo] - Informações adicionais do navio
  ///
  /// Retorna:
  ///   • Documento PDF pronto para salvar/compartilhar
  static Future<pw.Document> generateRatingPdf({
    required String shipName,
    String? shipImo,
    required String evaluatorName,
    required DateTime evaluationDate,
    required String cabinType,
    required DateTime disembarkationDate,
    required Map<String, Map<String, dynamic>> ratings,
    String? generalObservation,
    Map<String, dynamic>? shipInfo,
  }) async {
    final pdf = pw.Document();

    // Calcula média geral das notas
    double totalRating = 0;
    int ratingCount = 0;
    ratings.forEach((key, value) {
      final nota = value['nota'] as double;
      totalRating += nota;
      ratingCount++;
    });
    final averageRating = ratingCount > 0 ? totalRating / ratingCount : 0.0;

    // Adiciona página ao PDF
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          // Header com logo e título
          _buildHeader(shipName, shipImo),
          pw.SizedBox(height: 20),

          // Informações gerais da avaliação
          _buildInfoSection(
            evaluatorName: evaluatorName,
            evaluationDate: evaluationDate,
            cabinType: cabinType,
            disembarkationDate: disembarkationDate,
            averageRating: averageRating,
          ),
          pw.SizedBox(height: 20),

          // Informações do navio (tripulação, cabines, etc)
          if (shipInfo != null) ...[
            _buildShipInfoSection(shipInfo),
            pw.SizedBox(height: 20),
          ],

          // Avaliações detalhadas por critério
          _buildRatingsSection(ratings),
          pw.SizedBox(height: 20),

          // Observação geral (se existir)
          if (generalObservation != null && generalObservation.isNotEmpty) ...[
            _buildGeneralObservationSection(generalObservation),
            pw.SizedBox(height: 20),
          ],

          // Footer com data de geração
          pw.Spacer(),
          _buildFooter(),
        ],
      ),
    );

    return pdf;
  }

  /// --------------------------------------------------------------------------
  /// Constrói header do PDF com logo e informações do navio
  /// --------------------------------------------------------------------------
  static pw.Widget _buildHeader(String shipName, String? shipImo) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#3F51B5'),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'ShipRate',
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Relatório de Avaliação de Navio',
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 14,
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Divider(color: PdfColors.white),
          pw.SizedBox(height: 8),
          pw.Text(
            shipName,
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          if (shipImo != null && shipImo.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              'IMO: $shipImo',
              style: pw.TextStyle(
                color: PdfColor.fromHex('#E8EAF6'),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// --------------------------------------------------------------------------
  /// Constrói seção de informações gerais da avaliação
  /// --------------------------------------------------------------------------
  static pw.Widget _buildInfoSection({
    required String evaluatorName,
    required DateTime evaluationDate,
    required String cabinType,
    required DateTime disembarkationDate,
    required double averageRating,
  }) {
    final dateFormat = DateFormat('dd/MM/yyyy');

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColor.fromHex('#E0E0E0')),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Informações da Avaliação',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#3F51B5'),
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            children: [
              pw.Expanded(
                child: _buildInfoItem('Prático Avaliador', evaluatorName),
              ),
              pw.Expanded(
                child: _buildInfoItem(
                  'Data da Avaliação',
                  dateFormat.format(evaluationDate),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              pw.Expanded(
                child: _buildInfoItem('Tipo de Cabine', cabinType),
              ),
              pw.Expanded(
                child: _buildInfoItem(
                  'Data de Desembarque',
                  dateFormat.format(disembarkationDate),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          _buildInfoItem(
            'Nota Média Geral',
            averageRating.toStringAsFixed(1),
          ),
        ],
      ),
    );
  }

  /// --------------------------------------------------------------------------
  /// Constrói item individual de informação
  /// --------------------------------------------------------------------------
  static pw.Widget _buildInfoItem(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 10,
            color: PdfColors.grey700,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }

  /// --------------------------------------------------------------------------
  /// Constrói seção de informações do navio
  /// --------------------------------------------------------------------------
  static pw.Widget _buildShipInfoSection(Map<String, dynamic> shipInfo) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#F5F5F7'),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Informações do Navio',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#3F51B5'),
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text(
                  'Nacionalidade da Tripulação: ${shipInfo['nacionalidadeTripulacao'] ?? 'N/A'}',
                  style: const pw.TextStyle(fontSize: 11),
                ),
              ),
              pw.Expanded(
                child: pw.Text(
                  'Quantidade de Cabines: ${shipInfo['numeroCabines'] ?? 'N/A'}',
                  style: const pw.TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Row(
            children: [
              pw.Text(
                'Frigobar: ${shipInfo['frigobar'] == true ? 'Sim' : 'Não'}',
                style: const pw.TextStyle(fontSize: 11),
              ),
              pw.SizedBox(width: 20),
              pw.Text(
                'Pia: ${shipInfo['pia'] == true ? 'Sim' : 'Não'}',
                style: const pw.TextStyle(fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// --------------------------------------------------------------------------
  /// Constrói seção de avaliações por critério
  /// --------------------------------------------------------------------------
  static pw.Widget _buildRatingsSection(
    Map<String, Map<String, dynamic>> ratings,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Avaliações por Critério',
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: PdfColor.fromHex('#3F51B5'),
          ),
        ),
        pw.SizedBox(height: 12),
        ...ratings.entries.map((entry) {
          final criterio = entry.key;
          final nota = entry.value['nota'] as double;
          final observacao = entry.value['observacao'] as String;

          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 12),
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColor.fromHex('#E0E0E0')),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        criterio,
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: pw.BoxDecoration(
                        color: _getRatingColor(nota),
                        borderRadius: const pw.BorderRadius.all(
                          pw.Radius.circular(4),
                        ),
                      ),
                      child: pw.Text(
                        nota.toStringAsFixed(1),
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                if (observacao.isNotEmpty) ...[
                  pw.SizedBox(height: 6),
                  pw.Text(
                    observacao,
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  /// --------------------------------------------------------------------------
  /// Constrói seção de observação geral
  /// --------------------------------------------------------------------------
  static pw.Widget _buildGeneralObservationSection(String observation) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#FFF9E6'),
        border: pw.Border.all(color: PdfColor.fromHex('#FFD700')),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Observação Geral',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#FF9800'),
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            observation,
            style: const pw.TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }

  /// --------------------------------------------------------------------------
  /// Constrói footer do PDF
  /// --------------------------------------------------------------------------
  static pw.Widget _buildFooter() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.grey300),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Gerado por ShipRate',
            style: pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey600,
            ),
          ),
          pw.Text(
            'Data: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
            style: pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey600,
            ),
          ),
        ],
      ),
    );
  }

  /// --------------------------------------------------------------------------
  /// Retorna cor baseada na nota (sistema de semáforo)
  /// --------------------------------------------------------------------------
  static PdfColor _getRatingColor(double rating) {
    if (rating >= 4.5) return PdfColor.fromHex('#4CAF50'); // Verde
    if (rating >= 3.5) return PdfColor.fromHex('#8BC34A'); // Verde claro
    if (rating >= 2.5) return PdfColor.fromHex('#FF9800'); // Laranja
    if (rating >= 1.5) return PdfColor.fromHex('#FF5722'); // Laranja escuro
    return PdfColor.fromHex('#F44336'); // Vermelho
  }

  /// --------------------------------------------------------------------------
  /// Salva e compartilha PDF (FUNCIONA EM MOBILE E WEB) - VERSÃO PROFISSIONAL
  /// --------------------------------------------------------------------------
  /// Mobile: Abre dialog de compartilhamento nativo do sistema
  ///         (WhatsApp, Email, Drive, salvar em arquivos, etc)
  ///
  /// Web: Faz download automático do arquivo PDF para pasta de Downloads
  ///
  /// Parâmetros:
  ///   • [pdf] - Documento PDF gerado
  ///   • [fileName] - Nome do arquivo (sem extensão)
  static Future<void> saveAndSharePdf(
    pw.Document pdf,
    String fileName,
  ) async {
    try {
      // Gera bytes do PDF
      final bytes = await pdf.save();

      if (kIsWeb) {
        // ====================================================================
        // WEB: Download direto usando universal_html
        // ====================================================================
        try {
          final blob = html.Blob([bytes], 'application/pdf');
          final url = html.Url.createObjectUrlFromBlob(blob);
          final anchor = html.document.createElement('a') as html.AnchorElement
            ..href = url
            ..style.display = 'none'
            ..download = '$fileName.pdf';
          
          html.document.body?.children.add(anchor);
          
          // Delay para garantir que o elemento foi adicionado ao DOM
          await Future.delayed(const Duration(milliseconds: 100));
          
          anchor.click();
          
          // Cleanup
          await Future.delayed(const Duration(milliseconds: 100));
          html.document.body?.children.remove(anchor);
          html.Url.revokeObjectUrl(url);
        } catch (e) {
          throw Exception('Erro ao fazer download no navegador: $e');
        }
      } else {
        // ====================================================================
        // MOBILE: Usa printing package
        // ====================================================================
        try {
          await Printing.sharePdf(
            bytes: bytes,
            filename: '$fileName.pdf',
          );
        } catch (e) {
          throw Exception('Erro ao compartilhar PDF no dispositivo: $e');
        }
      }
    } catch (e) {
      throw Exception('Erro ao salvar PDF: $e');
    }
  }

  /// --------------------------------------------------------------------------
  /// Abre preview do PDF antes de salvar (FUNCIONA EM MOBILE E WEB)
  /// --------------------------------------------------------------------------
  /// Mobile: Abre visualizador nativo com opções de compartilhar/imprimir
  /// Web: Abre PDF em nova aba do navegador
  static Future<void> previewPdf(pw.Document pdf) async {
    try {
      final bytes = await pdf.save();
      
      if (kIsWeb) {
        // ====================================================================
        // WEB: Abre em nova aba
        // ====================================================================
        try {
          final blob = html.Blob([bytes], 'application/pdf');
          final url = html.Url.createObjectUrlFromBlob(blob);
          html.window.open(url, '_blank');
          
          // Cleanup após delay
          Future.delayed(const Duration(seconds: 1), () {
            html.Url.revokeObjectUrl(url);
          });
        } catch (e) {
          throw Exception('Erro ao abrir preview no navegador: $e');
        }
      } else {
        // ====================================================================
        // MOBILE: Usa printing package
        // ====================================================================
        try {
          await Printing.layoutPdf(
            onLayout: (format) async => bytes,
          );
        } catch (e) {
          throw Exception('Erro ao abrir preview no dispositivo: $e');
        }
      }
    } catch (e) {
      throw Exception('Erro ao visualizar PDF: $e');
    }
  }
}