import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'rating_detail_page.dart';

/// ============================================================================
/// MY RATINGS PAGE
/// ============================================================================
/// Exibe todas as avaliações realizadas pelo usuário autenticado,
/// ordenadas da mais recente para a mais antiga.
///
/// A busca percorre todos os navios e filtra apenas as avaliações
/// pertencentes ao usuário logado.
class MyRatingsPage extends StatefulWidget {
  const MyRatingsPage({super.key});

  @override
  State<MyRatingsPage> createState() => _MyRatingsPageState();
}

class _MyRatingsPageState extends State<MyRatingsPage> {
  bool _estaCarregando = true;
  final List<_ItemAvaliacao> _avaliacoes = [];

  @override
  void initState() {
    super.initState();
    _carregarAvaliacoesUsuario();
  }

  /// --------------------------------------------------------------------------
  /// Carrega todas as avaliações do usuário autenticado
  /// --------------------------------------------------------------------------
  Future<void> _carregarAvaliacoesUsuario() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _estaCarregando = false);
        return;
      }

      final uid = user.uid;

      final userSnapshot = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uid)
          .get();

      final String? nomeGuerra = userSnapshot.data()?['nomeGuerra'];

      final List<_ItemAvaliacao> resultado = [];

      final naviosSnapshot =
          await FirebaseFirestore.instance.collection('navios').get();

      for (final navio in naviosSnapshot.docs) {
        final nomeNavio = navio.data()['nome'] ?? 'Navio';

        final avaliacoesSnapshot =
            await navio.reference.collection('avaliacoes').get();

        for (final avaliacao in avaliacoesSnapshot.docs) {
          final data = avaliacao.data();



          final usuarioId = data['usuarioId'];
          final nomeGuerraAvaliacao = data['nomeGuerra'];

          final pertenceAoUsuario =
              (usuarioId != null && usuarioId == uid) ||
              (usuarioId == null &&
                  nomeGuerra != null &&
                  nomeGuerraAvaliacao == nomeGuerra);

          if (!pertenceAoUsuario) continue;

          resultado.add(
            _ItemAvaliacao(
              nomeNavio: nomeNavio,
              avaliacao: avaliacao,
            ),
          );
        }
      }

      /// Ordenação robusta:
      /// prioridade para createdAt, com fallback para data (legado)
      resultado.sort((a, b) {
        final aData = _resolverDataAvaliacao(
          a.avaliacao.data() as Map<String, dynamic>,
        );
        final bData = _resolverDataAvaliacao(
          b.avaliacao.data() as Map<String, dynamic>,
        );
        return bData.compareTo(aData);
      });

      setState(() {
        _avaliacoes
          ..clear()
          ..addAll(resultado);
        _estaCarregando = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar avaliações: $e');
      setState(() => _estaCarregando = false);
    }
  }

  /// --------------------------------------------------------------------------
  /// Resolve a data correta da avaliação
  /// Prioridade:
  /// 1) createdAt
  /// 2) data (legado)
  /// --------------------------------------------------------------------------
  DateTime _resolverDataAvaliacao(Map<String, dynamic> data) {
    final ts = data['createdAt'] ?? data['data'];

    if (ts is Timestamp) {
      return ts.toDate();
    }

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  /// --------------------------------------------------------------------------
  /// Formata data para exibição (dd/MM/yyyy)
  /// --------------------------------------------------------------------------
  String _formatarData(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/${data.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas Avaliações'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: _estaCarregando
          ? const Center(child: CircularProgressIndicator())
          : _avaliacoes.isEmpty
              ? const Center(
                  child: Text(
                    'Você ainda não avaliou nenhum navio.',
                    style: TextStyle(color: Colors.black54),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text(
                        '📌 Ordenadas da mais recente para a mais antiga',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _avaliacoes.length,
                        separatorBuilder: (_, __) => const Divider(
                          height: 28,
                          thickness: 1,
                          color: Colors.black12,
                        ),
                        itemBuilder: (_, index) {
                          final item = _avaliacoes[index];
                          final data =
                              item.avaliacao.data() as Map<String, dynamic>;

                          final dataAvaliacao =
                              _resolverDataAvaliacao(data);

                          return Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: ListTile(
                              leading: const Icon(
                                Icons.directions_boat,
                                color: Colors.indigo,
                              ),
                              title: Text(
                                item.nomeNavio,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                'Avaliado em ${_formatarData(dataAvaliacao)}',
                                style: const TextStyle(
                                  color: Colors.black54,
                                ),
                              ),
                              trailing:
                                  const Icon(Icons.chevron_right),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => RatingDetailPage(
                                      rating: item.avaliacao,
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}

/// ============================================================================
/// MODELO INTERNO DE ITEM DE AVALIAÇÃO
/// ============================================================================
class _ItemAvaliacao {
  final String nomeNavio;
  final QueryDocumentSnapshot avaliacao;

  _ItemAvaliacao({
    required this.nomeNavio,
    required this.avaliacao,
  });
}
