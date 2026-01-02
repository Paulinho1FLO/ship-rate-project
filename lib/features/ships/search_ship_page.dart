import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../ratings/add_rating_page.dart';
import 'rating_detail_page.dart';
import '../../data/services/marine_traffic_service.dart';

/// ============================================================================
/// SEARCH & RATE SHIP PAGE
/// ============================================================================
/// Tela principal de avaliação de navios.
/// Possui duas abas:
/// • Buscar (visualizar avaliações existentes)
/// • Avaliar (registrar nova avaliação)
class SearchAndRateShipPage extends StatefulWidget {
  const SearchAndRateShipPage({super.key});

  @override
  State<SearchAndRateShipPage> createState() => _SearchAndRateShipPageState();
}

class _SearchAndRateShipPageState extends State<SearchAndRateShipPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// -----------------------------
          /// TOPO (clean, sem bloco azul)
          /// -----------------------------
          Container(
            width: double.infinity,
            color: const Color(0xFFF7F7F9),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Avaliação de Navios',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Pesquise avaliações ou registre sua experiência',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 14,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 14),

                /// Abas (segment control bem proporcional)
                Container(
                  height: 42,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE9EAEE),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    indicator: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    labelColor: const Color(0xFF2F3E9E),
                    unselectedLabelColor: Colors.black87,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    tabs: const [
                      Tab(text: 'Buscar'),
                      Tab(text: 'Avaliar'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          /// Linha sutil para "fechar" o topo
          const Divider(height: 1, thickness: 1, color: Color(0xFFE6E6EA)),

          /// -----------------------------
          /// CONTEÚDO DAS ABAS
          /// -----------------------------
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                SearchShipTab(),
                RateShipTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ============================================================================
/// ABA DE BUSCA DE NAVIOS
/// ============================================================================
class SearchShipTab extends StatefulWidget {
  const SearchShipTab({super.key});

  @override
  State<SearchShipTab> createState() => _SearchShipTabState();
}

class _SearchShipTabState extends State<SearchShipTab>
    with AutomaticKeepAliveClientMixin {
  
  final TextEditingController _searchController = TextEditingController();

  List<QueryDocumentSnapshot> _suggestions = [];
  QueryDocumentSnapshot? _selectedShip;
  List<QueryDocumentSnapshot>? _ratings;

  @override
  bool get wantKeepAlive => true;

  /// Atualiza sugestões conforme o texto digitado
  Future<void> _updateSuggestions(String text) async {
    if (text.isEmpty) {
      setState(() {
        _suggestions = [];
        _selectedShip = null;
        _ratings = null;
      });
      return;
    }

    final term = text.toLowerCase().trim();
    final Map<String, QueryDocumentSnapshot> results = {};

    final snapshot = await FirebaseFirestore.instance.collection('navios').get();

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final name = (data['nome'] as String? ?? '').toLowerCase();
      final imo = (data['imo'] as String? ?? '').toLowerCase();

      if (name.contains(term) || (imo.isNotEmpty && imo.contains(term))) {
        results[doc.id] = doc;
      }
    }

    setState(() => _suggestions = results.values.toList());
  }

  /// Seleciona um navio e carrega suas avaliações
  Future<void> _selectShip(QueryDocumentSnapshot doc) async {
    final snap = await FirebaseFirestore.instance
        .collection('navios')
        .doc(doc.id)
        .collection('avaliacoes')
        .get();

    final list = snap.docs;

    list.sort((a, b) {
      final Timestamp aData =
          (a.data() as Map)['dataDesembarque'] ?? (a.data() as Map)['data'];
      final Timestamp bData =
          (b.data() as Map)['dataDesembarque'] ?? (b.data() as Map)['data'];
      return bData.compareTo(aData);
    });

    setState(() {
      _selectedShip = doc;
      _ratings = list;
      _suggestions = [];
      _searchController.text = (doc.data() as Map)['nome'];
    });
  }

  /// Destaca letras coincidentes na busca
  Widget _highlightMatch(String text, String query) {
    if (query.isEmpty) return Text(text);

    final queryChars = query.toLowerCase().split('');

    return RichText(
      text: TextSpan(
        style: const TextStyle(color: Colors.black),
        children: text.split('').map((char) {
          final isMatch = queryChars.contains(char.toLowerCase());
          return TextSpan(
            text: char,
            style: TextStyle(
              fontWeight: isMatch ? FontWeight.bold : FontWeight.normal,
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Column(
      children: [
        /// Campo de busca
        TextField(
          controller: _searchController,
          onChanged: _updateSuggestions,
          decoration: InputDecoration(
            hintText: 'Buscar por nome do navio ou IMO',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),

        /// Lista de sugestões
        if (_suggestions.isNotEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 250),
            child: Container(
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 8),
                ],
              ),
              child: ListView.separated(
                itemCount: _suggestions.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: Colors.grey[200]),
                itemBuilder: (_, i) {
                  final doc = _suggestions[i];
                  return ListTile(
                    leading: const Icon(Icons.directions_boat),
                    title: _highlightMatch(
                      (doc.data() as Map)['nome'],
                      _searchController.text,
                    ),
                    onTap: () => _selectShip(doc),
                  );
                },
              ),
            ),
          ),

        const SizedBox(height: 12),

        /// IMAGEM DE ESTADO INICIAL
        if (_selectedShip == null && _suggestions.isEmpty)
          Expanded(
            child: Opacity(
              opacity: 0.95,
              child: SizedBox.expand(
                child: Image.asset(
                  'assets/images/navio3.jpg',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),

        /// Avaliações do navio selecionado
        if (_selectedShip != null)
          Expanded(
            child: ListView(
              children: [
                _ShipSummaryCard(ship: _selectedShip!),

                if (_ratings != null && _ratings!.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Text(
                    'Avaliações',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _RatingsList(ratings: _ratings!),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// ============================================================================
/// LISTA DE AVALIAÇÕES
/// ============================================================================
class _RatingsList extends StatelessWidget {
  final List<QueryDocumentSnapshot> ratings;

  const _RatingsList({required this.ratings});

  Timestamp? _getTimestamp(Map<String, dynamic> data) {
    final v = data['createdAt'];
    return v is Timestamp ? v : null;
  }

  String _relativeTime(Timestamp ts) {
    final date = ts.toDate().toUtc();
    final now = DateTime.now().toUtc();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Avaliado agora';
    if (diff.inMinutes < 60) return 'Avaliado há ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Avaliado há ${diff.inHours}h';
    if (diff.inDays == 1) return 'Avaliado ontem';
    if (diff.inDays < 7) return 'Avaliado há ${diff.inDays} dias';

    return 'Avaliado em ${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: ratings.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final callSign = data['nomeGuerra'] ?? 'Prático';

        final ts = _getTimestamp(data);
        final time = ts == null ? 'Avaliado agora' : _relativeTime(ts);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            leading: const Icon(Icons.person, color: Colors.indigo),
            title: Text(
              'Prático: $callSign',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Visualizar avaliação',
                  style: TextStyle(
                    color: Colors.indigo,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  time,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RatingDetailPage(rating: doc),
                ),
              );
            },
          ),
        );
      }).toList(),
    );
  }
}

/// ============================================================================
/// RESUMO DO NAVIO
/// ============================================================================
class _ShipSummaryCard extends StatelessWidget {
  final QueryDocumentSnapshot ship;

  const _ShipSummaryCard({required this.ship});

  Widget _buildItem(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.indigo),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.black),
                children: [
                  TextSpan(text: '$label: '),
                  TextSpan(
                    text: value,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = ship.data() as Map<String, dynamic>;
    final averages = (data['medias'] ?? {}) as Map<String, dynamic>;
    final info = (data['info'] ?? {}) as Map<String, dynamic>;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              data['nome'],
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 16),

            /// BOTÃO MARINETRAFFIC
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final success = await MarineTrafficService.openMarineTraffic(
                    shipName: data['nome'],
                    imo: data['imo'],
                  );

                  if (!success && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Não foi possível abrir MarineTraffic'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.waves, size: 20),
                label: const Text(
                  'Ver Detalhes no MarineTraffic',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),
            const Text('Informações Gerais',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 3.2,
              children: [
                if (info['nacionalidadeTripulacao'] != null)
                  _buildItem(Icons.groups, 'Tripulação',
                      info['nacionalidadeTripulacao']),
                if (info['numeroCabines'] != null)
                  _buildItem(Icons.bed, 'Cabines', info['numeroCabines'].toString()),
                if (info['frigobar'] != null)
                  _buildItem(Icons.local_drink, 'Frigobar',
                      info['frigobar'] ? 'Sim' : 'Não'),
                if (info['pia'] != null)
                  _buildItem(Icons.wash, 'Pia', info['pia'] ? 'Sim' : 'Não'),
              ],
            ),

            const Divider(height: 32),

            const Text('Médias das Avaliações',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 3.2,
              children: [
                if (averages['temp_cabine'] != null)
                  _buildItem(Icons.thermostat, 'Temp. Cabine',
                      averages['temp_cabine'].toString()),
                if (averages['limpeza_cabine'] != null)
                  _buildItem(Icons.cleaning_services, 'Limpeza',
                      averages['limpeza_cabine'].toString()),
                if (averages['passadico_equip'] != null)
                  _buildItem(Icons.control_camera, 'Equip. Passadiço',
                      averages['passadico_equip'].toString()),
                if (averages['passadico_temp'] != null)
                  _buildItem(Icons.device_thermostat, 'Temp. Passadiço',
                      averages['passadico_temp'].toString()),
                if (averages['comida'] != null)
                  _buildItem(Icons.restaurant, 'Alimentação',
                      averages['comida'].toString()),
                if (averages['relacionamento'] != null)
                  _buildItem(Icons.handshake, 'Relacionamento',
                      averages['relacionamento'].toString()),
                if (averages['dispositivo'] != null)
                  _buildItem(Icons.transfer_within_a_station, 'Dispositivo',
                      averages['dispositivo'].toString()),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// ============================================================================
/// ABA DE AVALIAÇÃO
/// ============================================================================
class RateShipTab extends StatelessWidget {
  const RateShipTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        /// IMAGEM DE FUNDO
        Image.asset(
          'assets/images/navio2.png',
          fit: BoxFit.cover,
        ),

        /// OVERLAY ESCURO (legibilidade)
        Container(
          color: Colors.black.withAlpha(115),
        ),

        /// CONTEÚDO CENTRAL
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Nova Avaliação de Navio',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),

                const SizedBox(height: 12),

                const Text(
                  'Registre sua avaliação técnica de forma rápida e segura',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 30),

                /// BOTÃO PROFISSIONAL
                SizedBox(
                  width: 240,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2F3E9E),
                      foregroundColor: Colors.white,
                      elevation: 3,
                      shadowColor: Colors.black.withAlpha(64),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AddRatingPage(imo: ''),
                        ),
                      );
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.assignment_turned_in_outlined, size: 18),
                        SizedBox(width: 10),
                        Text(
                          'Iniciar avaliação',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}