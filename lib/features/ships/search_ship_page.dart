import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../ratings/add_rating_page.dart';
import 'rating_detail_page.dart';

/// ---------------------------------------------------------------------------
/// SEARCH & RATE SHIP PAGE
/// ---------------------------------------------------------------------------
/// Tela principal de avaliação de navios.
/// Possui duas abas:
/// • Buscar (visualizar avaliações existentes)
/// • Avaliar (registrar nova avaliação)
class SearchAndRateShipPage extends StatefulWidget {
  const SearchAndRateShipPage({super.key});

  @override
  State<SearchAndRateShipPage> createState() =>
      _SearchAndRateShipPageState();
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            const Text(
              'Avaliação de Navios',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Pesquise avaliações ou registre sua experiência',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 16),

            /// Abas
            Container(
              height: 44,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(24),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: Colors.indigo,
                  borderRadius: BorderRadius.circular(20),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.black87,
                tabs: const [
                  Tab(text: 'Buscar'),
                  Tab(text: 'Avaliar'),
                ],
              ),
            ),

            const SizedBox(height: 12),

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
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// ABA DE BUSCA DE NAVIOS
/// ---------------------------------------------------------------------------
class SearchShipTab extends StatefulWidget {
  const SearchShipTab({super.key});

  @override
  State<SearchShipTab> createState() => _SearchShipTabState();
}

class _SearchShipTabState extends State<SearchShipTab> {
  final TextEditingController _searchController = TextEditingController();

  List<QueryDocumentSnapshot> sugestoes = [];
  QueryDocumentSnapshot? navioSelecionado;
  List<QueryDocumentSnapshot>? avaliacoes;

  /// Atualiza sugestões conforme o texto digitado
  Future<void> _atualizarSugestoes(String texto) async {
    if (texto.isEmpty) {
      setState(() {
        sugestoes = [];
        navioSelecionado = null;
        avaliacoes = null;
      });
      return;
    }

    final termo = texto.toLowerCase().trim();
    final Map<String, QueryDocumentSnapshot> resultado = {};

    final snapshot =
        await FirebaseFirestore.instance.collection('navios').get();

    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final nome = (data['nome'] ?? '').toString().toLowerCase();
      final imo = (data['imo'] ?? '').toString().toLowerCase();

      if (nome.contains(termo) || (imo.isNotEmpty && imo.contains(termo))) {
        resultado[doc.id] = doc;
      }
    }

    setState(() => sugestoes = resultado.values.toList());
  }

  /// Seleciona um navio e carrega suas avaliações
  Future<void> _selecionarNavio(QueryDocumentSnapshot doc) async {
    final snap = await FirebaseFirestore.instance
        .collection('navios')
        .doc(doc.id)
        .collection('avaliacoes')
        .get();

    final lista = snap.docs;

    lista.sort((a, b) {
      final Timestamp aData =
          (a.data() as Map)['dataDesembarque'] ??
              (a.data() as Map)['data'];
      final Timestamp bData =
          (b.data() as Map)['dataDesembarque'] ??
              (b.data() as Map)['data'];
      return bData.compareTo(aData);
    });

    setState(() {
      navioSelecionado = doc;
      avaliacoes = lista;
      sugestoes = [];
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
    return Column(
      children: [
        /// Campo de busca
        TextField(
          controller: _searchController,
          onChanged: _atualizarSugestoes,
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
        if (sugestoes.isNotEmpty)
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
                itemCount: sugestoes.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: Colors.grey[200]),
                itemBuilder: (_, i) {
                  final doc = sugestoes[i];
                  return ListTile(
                    leading: const Icon(Icons.directions_boat),
                    title: _highlightMatch(
                      (doc.data() as Map)['nome'],
                      _searchController.text,
                    ),
                    onTap: () => _selecionarNavio(doc),
                  );
                },
              ),
            ),
          ),

        const SizedBox(height: 12),

        /// Avaliações do navio selecionado
        /// Avaliações do navio selecionado
if (navioSelecionado != null)
  Expanded(
    child: ListView(
      children: [
        _ShipSummaryCard(ship: navioSelecionado!),

        if (avaliacoes != null && avaliacoes!.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text(
            'Avaliações',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _RatingsList(ratings: avaliacoes!),
        ],
      ],
    ),
  ),


      ],
    );
  }
}

/// ---------------------------------------------------------------------------
/// LISTA DE AVALIAÇÕES
/// ---------------------------------------------------------------------------
class _RatingsList extends StatelessWidget {
  final List<QueryDocumentSnapshot> ratings;

  const _RatingsList({required this.ratings});

  Timestamp? _getTimestamp(Map<String, dynamic> data) {
    final v = data['createdAt'];
    return v is Timestamp ? v : null;
  }

  String _tempoRelativo(Timestamp ts) {
    final data = ts.toDate().toUtc();
    final agora = DateTime.now().toUtc();
    final diff = agora.difference(data);

    if (diff.inMinutes < 1) return 'Avaliado agora';
    if (diff.inMinutes < 60) return 'Avaliado há ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Avaliado há ${diff.inHours}h';
    if (diff.inDays == 1) return 'Avaliado ontem';
    if (diff.inDays < 7) return 'Avaliado há ${diff.inDays} dias';

    return 'Avaliado em ${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/${data.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: ratings.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final nomePratico = data['nomeGuerra'] ?? 'Prático';

        final ts = _getTimestamp(data);
        final tempo = ts == null ? 'Avaliado agora' : _tempoRelativo(ts);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            leading: const Icon(Icons.person, color: Colors.indigo),
            title: Text(
              'Prático: $nomePratico',
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
                  tempo,
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

/// ---------------------------------------------------------------------------
/// RESUMO DO NAVIO
/// ---------------------------------------------------------------------------
class _ShipSummaryCard extends StatelessWidget {
  final QueryDocumentSnapshot ship;

  const _ShipSummaryCard({required this.ship});

  Widget _item(IconData icon, String label, String value) {
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
    final medias = (data['medias'] ?? {}) as Map<String, dynamic>;
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
                  _item(Icons.groups, 'Tripulação',
                      info['nacionalidadeTripulacao']),
                if (info['numeroCabines'] != null)
                  _item(Icons.bed, 'Cabines',
                      info['numeroCabines'].toString()),
                if (info['frigobar'] != null)
                  _item(Icons.local_drink, 'Frigobar',
                      info['frigobar'] ? 'Sim' : 'Não'),
                if (info['pia'] != null)
                  _item(Icons.wash, 'Pia',
                      info['pia'] ? 'Sim' : 'Não'),
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
                if (medias['temp_cabine'] != null)
                  _item(Icons.thermostat, 'Temp. Cabine',
                      medias['temp_cabine'].toString()),
                if (medias['limpeza_cabine'] != null)
                  _item(Icons.cleaning_services, 'Limpeza',
                      medias['limpeza_cabine'].toString()),
                if (medias['passadico_equip'] != null)
                  _item(Icons.control_camera, 'Equip. Passadiço',
                      medias['passadico_equip'].toString()),
                if (medias['passadico_temp'] != null)
                  _item(Icons.device_thermostat, 'Temp. Passadiço',
                      medias['passadico_temp'].toString()),
                if (medias['comida'] != null)
                  _item(Icons.restaurant, 'Alimentação',
                      medias['comida'].toString()),
                if (medias['relacionamento'] != null)
                  _item(Icons.handshake, 'Relacionamento',
                      medias['relacionamento'].toString()),
                if (medias['dispositivo'] != null)
                  _item(Icons.transfer_within_a_station, 'Dispositivo',
                      medias['dispositivo'].toString()),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// ABA DE AVALIAÇÃO
/// ---------------------------------------------------------------------------
class RateShipTab extends StatelessWidget {
  const RateShipTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton.icon(
        icon: const Icon(Icons.rate_review),
        label: const Text('Avaliar um navio'),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AddRatingPage(imo: ''),
            ),
          );
        },
      ),
    );
  }
}
