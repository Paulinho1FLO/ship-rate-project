import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// ---------------------------------------------------------------------------
/// RATING DETAIL PAGE
/// ---------------------------------------------------------------------------
/// Exibe todos os detalhes de uma avaliação:
/// • Dados do navio
/// • Datas
/// • Informações da cabine
/// • Avaliações por categoria
/// • Observações gerais
///
/// ⚠️ Página SOMENTE de leitura
/// ⚠️ Não altera dados
class RatingDetailPage extends StatelessWidget {
  final QueryDocumentSnapshot rating;

  const RatingDetailPage({
    super.key,
    required this.rating,
  });

  /// Formata Timestamp para dd/MM/yyyy
  String _formatarData(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> data =
        rating.data() as Map<String, dynamic>;

    final String nomePratico = data['nomeGuerra'] ?? 'Prático';
    final Timestamp? dataAvaliacao = data['data'];
    final Timestamp? dataDesembarque = data['dataDesembarque'];
    final String tipoCabine = data['tipoCabine'] ?? '';
    final String observacoesGerais =
        (data['observacaoGeral'] ?? '').toString();

    final Map<String, dynamic> itensAvaliacao =
        Map<String, dynamic>.from(data['itens'] ?? {});

    final Map<String, dynamic> infoNavio =
        Map<String, dynamic>.from(data['infoNavio'] ?? {});

    /// Documento pai (navio)
    final DocumentReference navioRef =
        rating.reference.parent.parent!;

    return FutureBuilder<DocumentSnapshot>(
      future: navioRef.get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(
              child: Text('Erro ao carregar dados do navio'),
            ),
          );
        }

        final Map<String, dynamic>? navioData =
            snapshot.data?.data() as Map<String, dynamic>?;

        final String nomeNavio = navioData?['nome'] ?? 'Navio';
        final String? imo = navioData?['imo'];

        return Scaffold(
          appBar: AppBar(
            title: const Text('Detalhes da Avaliação'),
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
            centerTitle: true,
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              /// ================= CABEÇALHO =================
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nomeNavio,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      if (imo != null && imo.isNotEmpty)
                        Text('IMO: $imo'),

                      if (dataAvaliacao != null)
                        Text(
                          'Avaliado em: ${_formatarData(dataAvaliacao)}',
                          style: const TextStyle(
                            color: Colors.black54,
                          ),
                        ),

                      if (dataDesembarque != null)
                        Text(
                          'Data de desembarque: ${_formatarData(dataDesembarque)}',
                          style: const TextStyle(
                            color: Colors.black54,
                          ),
                        ),

                      if (tipoCabine.isNotEmpty)
                        Text('Tipo da cabine: $tipoCabine'),

                      const SizedBox(height: 6),

                      Text(
                        'Prático: $nomePratico',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              /// ================= INFORMAÇÕES DO NAVIO =================
              if (infoNavio.isNotEmpty) ...[
                const SizedBox(height: 16),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Informações do Navio',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.indigo,
                          ),
                        ),
                        const SizedBox(height: 12),

                        if (infoNavio['nacionalidadeTripulacao'] != null)
                          _infoLinha(
                            'Tripulação',
                            infoNavio['nacionalidadeTripulacao'],
                          ),

                        if (infoNavio['numeroCabines'] != null &&
                            infoNavio['numeroCabines'] > 0)
                          _infoLinha(
                            'Cabines',
                            infoNavio['numeroCabines'].toString(),
                          ),

                        if (infoNavio['frigobar'] != null)
                          _infoLinha(
                            'Frigobar',
                            infoNavio['frigobar'] ? 'Sim' : 'Não',
                          ),

                        if (infoNavio['pia'] != null)
                          _infoLinha(
                            'Pia',
                            infoNavio['pia'] ? 'Sim' : 'Não',
                          ),
                      ],
                    ),
                  ),
                ),
              ],

              /// ================= OBSERVAÇÕES GERAIS =================
              if (observacoesGerais.isNotEmpty) ...[
                const SizedBox(height: 16),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: const Text(
                      'Observações Gerais',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.indigo,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(observacoesGerais),
                ),
              ],

              const SizedBox(height: 24),

              /// ================= CABINE =================
              _secaoTitulo('Cabine'),
              ..._buildItens(itensAvaliacao, [
                'Temperatura da Cabine',
                'Limpeza da Cabine',
              ]),

              /// ================= PASSADIÇO =================
              _secaoTitulo('Passadiço'),
              ..._buildItens(itensAvaliacao, [
                'Passadiço – Equipamentos',
                'Passadiço – Temperatura',
              ]),

              /// ================= OUTROS =================
              _secaoTitulo('Outros'),
              ..._buildItens(itensAvaliacao, [
                'Dispositivo de Embarque/Desembarque',
                'Comida',
                'Relacionamento com comandante/tripulação',
              ]),
            ],
          ),
        );
      },
    );
  }

  /// -------------------------------------------------------------------------
  /// HELPERS DE UI
  /// -------------------------------------------------------------------------
  Widget _secaoTitulo(String titulo) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        titulo,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.bold,
          color: Colors.indigo,
        ),
      ),
    );
  }

  List<Widget> _buildItens(
    Map<String, dynamic> itens,
    List<String> ordem,
  ) {
    return ordem.where(itens.containsKey).map((nome) {
      final Map<String, dynamic> item =
          Map<String, dynamic>.from(itens[nome]);

      final dynamic nota = item['nota'];
      final String observacao =
          (item['observacao'] ?? '').toString();

      return Card(
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nome,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Nota: ${nota ?? '-'}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.indigo,
                ),
              ),
              if (observacao.isNotEmpty) ...[
                const Divider(height: 24),
                Text(observacao),
              ],
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _infoLinha(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Expanded(child: Text(valor)),
        ],
      ),
    );
  }
}
