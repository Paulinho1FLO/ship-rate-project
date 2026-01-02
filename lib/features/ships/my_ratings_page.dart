import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'rating_detail_page.dart';

/// ============================================================================
/// MY RATINGS PAGE
/// ============================================================================
/// Tela que exibe todas as avaliações realizadas pelo usuário autenticado.
///
/// Funcionalidades:
/// ----------------
/// • Lista todas as avaliações do usuário logado
/// • Ordenação da mais recente para a mais antiga
/// • Navegação para detalhes de cada avaliação
/// • Busca distribuída (percorre todos os navios)
/// • Pull-to-refresh para recarregar dados
/// • Tratamento robusto de erros
///
/// Lógica de Busca:
/// ----------------
/// 1. Busca todos os navios da coleção `navios`
/// 2. Para cada navio, busca subcoleção `avaliacoes`
/// 3. Filtra avaliações pelo usuário atual (por UID ou nome de guerra)
/// 4. Ordena por data de criação (mais recente primeiro)
///
/// Compatibilidade:
/// ----------------
/// • Avaliações antigas: usa campo `data` (legado)
/// • Avaliações novas: usa campo `createdAt` (servidor)
/// • Identifica usuário por `usuarioId` ou `nomeGuerra` (fallback)
///
class MyRatingsPage extends StatefulWidget {
  const MyRatingsPage({super.key});

  @override
  State<MyRatingsPage> createState() => _MyRatingsPageState();
}

class _MyRatingsPageState extends State<MyRatingsPage> {
  /// Estado de carregamento
  bool _isLoading = true;

  /// Estado de erro
  String? _errorMessage;

  /// Lista de avaliações do usuário
  final List<_RatingItem> _ratings = [];

  /// --------------------------------------------------------------------------
  /// Inicialização
  /// --------------------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    _loadUserRatings();
  }

  /// --------------------------------------------------------------------------
  /// Carrega todas as avaliações do usuário autenticado
  /// --------------------------------------------------------------------------
  /// Fluxo de execução:
  ///   1. Verifica autenticação do usuário
  ///   2. Busca nome de guerra do usuário no Firestore
  ///   3. Percorre todos os navios
  ///   4. Para cada navio, busca subcoleção de avaliações
  ///   5. Filtra avaliações do usuário atual
  ///   6. Ordena por data (mais recente primeiro)
  ///
  /// Critério de Filtro:
  ///   • Por UID: usuarioId == uid (método preferencial)
  ///   • Por nome de guerra: fallback para avaliações antigas
  ///
  /// Observações:
  ///   • Operação distribuída (não há índice centralizado)
  ///   • Pode ser lenta com muitos navios cadastrados
  Future<void> _loadUserRatings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Usuário não autenticado';
        });
        return;
      }

      final uid = user.uid;

      /// Busca nome de guerra do usuário
      final userSnapshot = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uid)
          .get();

      if (!userSnapshot.exists) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Dados do usuário não encontrados';
        });
        return;
      }

      final String? callSign = userSnapshot.data()?['nomeGuerra'];

      final List<_RatingItem> results = [];

      /// Busca todos os navios
      final shipsSnapshot =
          await FirebaseFirestore.instance.collection('navios').get();

      /// Percorre cada navio
      for (final ship in shipsSnapshot.docs) {
        final shipData = ship.data();
        final shipName = shipData['nome'] ?? 'Navio sem nome';
        final shipImo = shipData['imo'] ?? '';

        /// Busca avaliações do navio
        final ratingsSnapshot =
            await ship.reference.collection('avaliacoes').get();

        /// Filtra avaliações do usuário atual
        for (final rating in ratingsSnapshot.docs) {
          final data = rating.data();

          final ratingUserId = data['usuarioId'];
          final ratingCallSign = data['nomeGuerra'];

          /// Critério de filtro:
          /// 1. Preferência: usuarioId == uid
          /// 2. Fallback: nomeGuerra == callSign (avaliações antigas)
          final belongsToUser =
              (ratingUserId != null && ratingUserId == uid) ||
              (ratingUserId == null &&
                  callSign != null &&
                  ratingCallSign == callSign);

          if (!belongsToUser) continue;

          results.add(
            _RatingItem(
              shipName: shipName,
              shipImo: shipImo,
              rating: rating,
            ),
          );
        }
      }

      /// Ordenação robusta por data (mais recente primeiro)
      /// Prioridade: createdAt > data (legado)
      results.sort((a, b) {
        final aDate = _resolveRatingDate(
          a.rating.data() as Map<String, dynamic>,
        );
        final bDate = _resolveRatingDate(
          b.rating.data() as Map<String, dynamic>,
        );
        return bDate.compareTo(aDate);
      });

      if (mounted) {
        setState(() {
          _ratings
            ..clear()
            ..addAll(results);
          _isLoading = false;
        });
      }
    } catch (error) {
      debugPrint('❌ Erro ao carregar avaliações: $error');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Erro ao carregar avaliações. Tente novamente.';
        });
      }
    }
  }

  /// --------------------------------------------------------------------------
  /// Resolve data correta da avaliação
  /// --------------------------------------------------------------------------
  /// Prioridade de campos:
  ///   1. createdAt (timestamp do servidor - preferencial)
  ///   2. data (campo legado - fallback)
  ///
  /// Retorno:
  ///   • DateTime da avaliação
  ///   • DateTime epoch (1970) se não encontrar data válida
  DateTime _resolveRatingDate(Map<String, dynamic> data) {
    final ts = data['createdAt'] ?? data['data'];

    if (ts is Timestamp) {
      return ts.toDate();
    }

    /// Fallback: data inválida retorna epoch
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  /// --------------------------------------------------------------------------
  /// Formata data para exibição
  /// --------------------------------------------------------------------------
  /// Formato: dd/MM/yyyy
  ///
  /// Exemplo: 29/12/2025
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  /// --------------------------------------------------------------------------
  /// Calcula média geral da avaliação
  /// --------------------------------------------------------------------------
  double _calculateAverageRating(Map<String, dynamic> data) {
    final itens = data['itens'] as Map<String, dynamic>?;
    if (itens == null || itens.isEmpty) return 0.0;

    double total = 0.0;
    int count = 0;

    for (final item in itens.values) {
      if (item is Map<String, dynamic>) {
        final nota = item['nota'];
        if (nota is num) {
          total += nota.toDouble();
          count++;
        }
      }
    }

    return count > 0 ? total / count : 0.0;
  }

  /// --------------------------------------------------------------------------
  /// Build principal
  /// --------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: const Text(
          'Minhas Avaliações',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF3F51B5),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  /// --------------------------------------------------------------------------
  /// Constrói corpo da página baseado no estado
  /// --------------------------------------------------------------------------
  Widget _buildBody() {
    /// Estado: Carregando
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: Color(0xFF3F51B5),
            ),
            SizedBox(height: 16),
            Text(
              'Carregando suas avaliações...',
              style: TextStyle(
                color: Colors.black54,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    /// Estado: Erro
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadUserRatings,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar Novamente'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3F51B5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    /// Estado: Vazio
    if (_ratings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF3F51B5).withAlpha(26),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.rate_review_outlined,
                  size: 64,
                  color: Color(0xFF3F51B5),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Nenhuma avaliação ainda',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Você ainda não avaliou nenhum navio.\nComece avaliando sua próxima viagem!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
      );
    }

    /// Estado: Lista de avaliações
    return RefreshIndicator(
      onRefresh: _loadUserRatings,
      color: const Color(0xFF3F51B5),
      child: Column(
        children: [
          /// Header com estatísticas
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(13),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.analytics_outlined,
                  color: Color(0xFF3F51B5),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Total: ${_ratings.length} ${_ratings.length == 1 ? 'avaliação' : 'avaliações'}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3F51B5),
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.schedule,
                  color: Colors.black54,
                  size: 16,
                ),
                const SizedBox(width: 4),
                const Text(
                  'Mais recentes primeiro',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),

          /// Lista de avaliações
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _ratings.length,
              itemBuilder: (_, index) {
                final item = _ratings[index];
                final data = item.rating.data() as Map<String, dynamic>;
                final ratingDate = _resolveRatingDate(data);
                final averageRating = _calculateAverageRating(data);
                final cabinType = data['tipoCabine'] ?? '';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    elevation: 2,
                    shadowColor: Colors.black12,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RatingDetailPage(
                              rating: item.rating,
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            /// Header do card
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF3F51B5).withAlpha(26),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.directions_boat,
                                    color: Color(0xFF3F51B5),
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.shipName,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF2C3E50),
                                        ),
                                      ),
                                      if (item.shipImo.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          'IMO: ${item.shipImo}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right,
                                  color: Color(0xFF3F51B5),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),
                            const Divider(height: 1),
                            const SizedBox(height: 12),

                            /// Informações da avaliação
                            Row(
                              children: [
                                /// Nota média
                                Expanded(
                                  child: _buildInfoChip(
                                    icon: Icons.star,
                                    label: 'Nota Média',
                                    value: averageRating.toStringAsFixed(1),
                                    color: const Color(0xFFFF9800),
                                  ),
                                ),
                                const SizedBox(width: 8),

                                /// Data de avaliação
                                Expanded(
                                  child: _buildInfoChip(
                                    icon: Icons.calendar_today,
                                    label: 'Data de Avaliação',
                                    value: _formatDate(ratingDate),
                                    color: const Color(0xFF3F51B5),
                                  ),
                                ),
                              ],
                            ),

                            if (cabinType.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              _buildInfoChip(
                                icon: Icons.bed,
                                label: 'Cabine',
                                value: cabinType,
                                color: const Color(0xFF4CAF50),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// --------------------------------------------------------------------------
  /// Widget de chip informativo
  /// --------------------------------------------------------------------------
  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: color.withAlpha(179),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ============================================================================
/// RATING ITEM (Modelo Interno)
/// ============================================================================
/// Modelo de dados interno para representar item da lista de avaliações.
///
/// Campos:
///   • [shipName] - Nome do navio avaliado
///   • [shipImo] - IMO do navio avaliado
///   • [rating] - Documento da avaliação no Firestore
///
class _RatingItem {
  /// Nome do navio
  final String shipName;

  /// IMO do navio
  final String shipImo;

  /// Documento da avaliação
  final QueryDocumentSnapshot rating;

  _RatingItem({
    required this.shipName,
    required this.shipImo,
    required this.rating,
  });
}