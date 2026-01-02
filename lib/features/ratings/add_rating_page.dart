import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'rating_controller.dart';

/// ============================================================================
/// ADD RATING PAGE
/// ============================================================================
/// Tela de cadastro de avaliação de navio com design profissional.
///
/// Responsabilidades:
/// ------------------
/// • Criar nova avaliação de navio
/// • Autocomplete de navios já cadastrados
/// • Bloquear campos quando navio já existe (evitar dados duplicados)
/// • Coletar notas e observações por critério
/// • Validar dados antes de salvar
///
/// Funcionalidades:
/// ----------------
/// • Autocomplete inteligente com highlight de caracteres coincidentes
/// • Campos bloqueados automaticamente quando navio existe
/// • Slider para notas (1.0 a 5.0 com incrementos de 0.5)
/// • Design moderno com cards e ícones
/// • Validação de campos obrigatórios
/// • Persistência via RatingController
///
class AddRatingPage extends StatefulWidget {
  final String imo;

  const AddRatingPage({
    super.key,
    required this.imo,
  });

  @override
  State<AddRatingPage> createState() => _AddRatingPageState();
}

/// ============================================================================
/// ADD RATING PAGE STATE
/// ============================================================================
class _AddRatingPageState extends State<AddRatingPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final RatingController _ratingController = RatingController();

  /// --------------------------------------------------------------------------
  /// Controllers de campos principais
  /// --------------------------------------------------------------------------
  final TextEditingController _shipNameController = TextEditingController();
  final TextEditingController _imoController = TextEditingController();
  final TextEditingController _generalObservationController = TextEditingController();
  final TextEditingController _crewNationalityController = TextEditingController();
  final TextEditingController _cabinCountController = TextEditingController();
  final FocusNode _shipNameFocusNode = FocusNode();

  /// --------------------------------------------------------------------------
  /// Estado local
  /// --------------------------------------------------------------------------
  List<QueryDocumentSnapshot> _registeredShips = [];
  String _currentShipName = '';
  String? _selectedCabinType;
  DateTime? _disembarkationDate;
  bool _hasMinibar = false;
  bool _hasSink = false;
  bool _isSaving = false;
  bool _shipAlreadyExists = false;

  /// --------------------------------------------------------------------------
  /// Constantes
  /// --------------------------------------------------------------------------
  static const List<String> _cabinTypes = [
    'PRT',
    'OWNER',
    'Spare Officer',
    'Crew',
  ];

  /// Itens avaliados com ícones e cores
  static const List<Map<String, dynamic>> _ratingCriteria = [
    {
      'key': 'Dispositivo de Embarque/Desembarque',
      'icon': Icons.transfer_within_a_station,
      'color': Color(0xFF3F51B5),
    },
    {
      'key': 'Temperatura da Cabine',
      'icon': Icons.thermostat,
      'color': Color(0xFFE91E63),
    },
    {
      'key': 'Limpeza da Cabine',
      'icon': Icons.cleaning_services,
      'color': Color(0xFF4CAF50),
    },
    {
      'key': 'Passadiço – Equipamentos',
      'icon': Icons.control_camera,
      'color': Color(0xFFFF9800),
    },
    {
      'key': 'Passadiço – Temperatura',
      'icon': Icons.device_thermostat,
      'color': Color(0xFF9C27B0),
    },
    {
      'key': 'Comida',
      'icon': Icons.restaurant,
      'color': Color(0xFFF44336),
    },
    {
      'key': 'Relacionamento com comandante/tripulação',
      'icon': Icons.handshake,
      'color': Color(0xFF00BCD4),
    },
  ];

  /// Notas por item (1.0 a 5.0, padrão 3.0, incrementos de 0.5)
  late final Map<String, double> _ratingsByItem;

  /// Controllers de observações por item
  late final Map<String, TextEditingController> _observationControllers;

  /// --------------------------------------------------------------------------
  /// Inicialização
  /// --------------------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    _loadShips();

    _ratingsByItem = {
      for (final item in _ratingCriteria) item['key'] as String: 3.0,
    };

    _observationControllers = {
      for (final item in _ratingCriteria) 
        item['key'] as String: TextEditingController(),
    };
  }

  /// --------------------------------------------------------------------------
  /// Carrega navios para autocomplete
  /// --------------------------------------------------------------------------
  Future<void> _loadShips() async {
    final snapshot = await FirebaseFirestore.instance.collection('navios').get();
    if (!mounted) return;
    setState(() => _registeredShips = snapshot.docs);
  }

  /// --------------------------------------------------------------------------
  /// Limpeza
  /// --------------------------------------------------------------------------
  @override
  void dispose() {
    _shipNameFocusNode.dispose();
    _shipNameController.dispose();
    _imoController.dispose();
    _generalObservationController.dispose();
    _crewNationalityController.dispose();
    _cabinCountController.dispose();

    for (final controller in _observationControllers.values) {
      controller.dispose();
    }

    super.dispose();
  }

  /// --------------------------------------------------------------------------
  /// Destaca caracteres coincidentes no autocomplete
  /// --------------------------------------------------------------------------
  TextSpan _highlightMatch(String text, String query) {
    if (query.isEmpty) return TextSpan(text: text);

    final queryChars = query.toLowerCase().split('');

    return TextSpan(
      children: text.split('').map((char) {
        final isMatch = queryChars.contains(char.toLowerCase());
        return TextSpan(
          text: char,
          style: TextStyle(
            fontWeight: isMatch ? FontWeight.bold : FontWeight.normal,
          ),
        );
      }).toList(),
    );
  }

  /// --------------------------------------------------------------------------
  /// Salva avaliação
  /// --------------------------------------------------------------------------
  Future<void> _saveRating() async {
    if (!_formKey.currentState!.validate()) return;

    if (_disembarkationDate == null || _selectedCabinType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha todos os campos obrigatórios'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _ratingController.salvarAvaliacao(
        nomeNavio: _currentShipName.trim(),
        imoInicial: _imoController.text.trim(),
        dataDesembarque: _disembarkationDate!,
        tipoCabine: _selectedCabinType!,
        observacaoGeral: _generalObservationController.text.trim(),
        infoNavio: {
          'nacionalidadeTripulacao': _crewNationalityController.text.trim(),
          'numeroCabines': int.tryParse(_cabinCountController.text) ?? 0,
          'frigobar': _hasMinibar,
          'pia': _hasSink,
        },
        itens: {
          for (final item in _ratingCriteria)
            item['key'] as String: {
              'nota': _ratingsByItem[item['key']]!,
              'observacao': _observationControllers[item['key']]!.text.trim(),
            }
        },
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  /// --------------------------------------------------------------------------
  /// Seleciona data de desembarque
  /// --------------------------------------------------------------------------
  Future<void> _selectDisembarkationDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF3F51B5),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _disembarkationDate = picked);
    }
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
          'Avaliar Navio',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF3F51B5),
        foregroundColor: Colors.white,
        elevation: 0,
      ),

      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(13),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveRating,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3F51B5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            child: _isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Salvar Avaliação',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),

      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildShipInfoCard(),
            const SizedBox(height: 16),
            _buildEvaluationDetailsCard(),
            const SizedBox(height: 16),
            _buildRatingsHeader(),
            const SizedBox(height: 12),
            ..._buildRatingItems(),
            const SizedBox(height: 16),
            _buildGeneralObservationCard(),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  /// --------------------------------------------------------------------------
  /// Card de informações do navio
  /// --------------------------------------------------------------------------
  Widget _buildShipInfoCard() {
    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.directions_boat, color: Color(0xFF3F51B5), size: 24),
                SizedBox(width: 12),
                Text(
                  'Dados do Navio',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3F51B5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildShipAutocomplete(),
            const SizedBox(height: 16),
            _buildImoField(),
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 20),
            Row(
              children: const [
                Icon(Icons.info_outline, color: Color(0xFF3F51B5), size: 20),
                SizedBox(width: 8),
                Text(
                  'Informações Adicionais',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3F51B5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _crewNationalityController,
              enabled: !_shipAlreadyExists,
              decoration: InputDecoration(
                labelText: 'Nacionalidade da tripulação',
                prefixIcon: const Icon(Icons.flag, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: _shipAlreadyExists ? Colors.grey[100] : Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _cabinCountController,
              enabled: !_shipAlreadyExists,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Quantidade de cabines',
                prefixIcon: const Icon(Icons.bed, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: _shipAlreadyExists ? Colors.grey[100] : Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Possui frigobar'),
                    secondary: const Icon(Icons.kitchen, color: Color(0xFF3F51B5)),
                    value: _hasMinibar,
                    activeColor: const Color(0xFF3F51B5),
                    onChanged: _shipAlreadyExists
                        ? null
                        : (v) => setState(() => _hasMinibar = v),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Possui pia'),
                    secondary: const Icon(Icons.water_drop, color: Color(0xFF3F51B5)),
                    value: _hasSink,
                    activeColor: const Color(0xFF3F51B5),
                    onChanged: _shipAlreadyExists
                        ? null
                        : (v) => setState(() => _hasSink = v),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// --------------------------------------------------------------------------
  /// Card de detalhes da avaliação
  /// --------------------------------------------------------------------------
  Widget _buildEvaluationDetailsCard() {
    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.assignment, color: Color(0xFF3F51B5), size: 24),
                SizedBox(width: 12),
                Text(
                  'Detalhes da Avaliação',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3F51B5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildCabinTypeDropdown(),
            const SizedBox(height: 16),
            _buildDisembarkationDatePicker(),
          ],
        ),
      ),
    );
  }

  /// --------------------------------------------------------------------------
  /// Header das avaliações
  /// --------------------------------------------------------------------------
  Widget _buildRatingsHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: const [
          Icon(Icons.star, color: Color(0xFF3F51B5), size: 24),
          SizedBox(width: 12),
          Text(
            'Avaliações por Critério',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3F51B5),
            ),
          ),
        ],
      ),
    );
  }

  /// --------------------------------------------------------------------------
  /// Constrói lista de itens de avaliação
  /// --------------------------------------------------------------------------
  List<Widget> _buildRatingItems() {
    return _ratingCriteria.map((criteria) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _buildRatingItem(
          criteria['key'] as String,
          criteria['icon'] as IconData,
          criteria['color'] as Color,
        ),
      );
    }).toList();
  }

  /// --------------------------------------------------------------------------
  /// Item individual de avaliação
  /// --------------------------------------------------------------------------
  Widget _buildRatingItem(String item, IconData icon, Color color) {
    final valor = _ratingsByItem[item]!;
    
    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withAlpha(26),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text(
                  '1.0',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: color,
                      inactiveTrackColor: color.withAlpha(51),
                      thumbColor: color,
                      overlayColor: color.withAlpha(51),
                      valueIndicatorColor: color,
                      valueIndicatorTextStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: Slider(
                      value: valor,
                      min: 1,
                      max: 5,
                      divisions: 8,
                      label: valor.toStringAsFixed(1),
                      onChanged: (v) => setState(() => _ratingsByItem[item] = v),
                    ),
                  ),
                ),
                const Text(
                  '5.0',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: color.withAlpha(26),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.star, color: color, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    valor.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _observationControllers[item],
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Observações sobre ${item.toLowerCase()}...',
                hintStyle: TextStyle(fontSize: 14, color: Colors.grey[400]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: color, width: 2),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// --------------------------------------------------------------------------
  /// Card de observação geral
  /// --------------------------------------------------------------------------
  Widget _buildGeneralObservationCard() {
    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.notes, color: Color(0xFF3F51B5), size: 24),
                SizedBox(width: 12),
                Text(
                  'Observação Geral',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3F51B5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _generalObservationController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Comentários adicionais sobre a experiência geral no navio...',
                hintStyle: TextStyle(fontSize: 14, color: Colors.grey[400]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// --------------------------------------------------------------------------
  /// Autocomplete de nome do navio
  /// --------------------------------------------------------------------------
  Widget _buildShipAutocomplete() {
    return RawAutocomplete<QueryDocumentSnapshot>(
      textEditingController: _shipNameController,
      focusNode: _shipNameFocusNode,
      displayStringForOption: (opt) => opt['nome'],
      optionsBuilder: (value) {
        if (value.text.isEmpty) {
          return const Iterable<QueryDocumentSnapshot>.empty();
        }

        return _registeredShips.where((doc) {
          final nome = doc['nome'].toString().toLowerCase();
          return nome.contains(value.text.toLowerCase());
        });
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmit) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: 'Nome do navio',
            prefixIcon: const Icon(Icons.directions_boat, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          validator: (v) =>
              v == null || v.isEmpty ? 'Informe o nome do navio' : null,
          onChanged: (v) {
            _currentShipName = v;
            setState(() => _shipAlreadyExists = false);
          },
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        if (options.isEmpty) {
          return const SizedBox.shrink();
        }

        return Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: options.length,
            itemBuilder: (_, index) {
              final opt = options.elementAt(index);
              final data = opt.data() as Map<String, dynamic>;
              final info = (data['info'] ?? {}) as Map<String, dynamic>;

              return ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3F51B5).withAlpha(26),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.directions_boat,
                    color: Color(0xFF3F51B5),
                  ),
                ),
                title: RichText(
                  text: _highlightMatch(
                    data['nome'],
                    _shipNameController.text,
                  ),
                ),
                onTap: () {
                  onSelected(opt);

                  setState(() {
                    _shipAlreadyExists = true;
                    _shipNameController.text = data['nome'];
                    _currentShipName = data['nome'];
                    _imoController.text = data['imo'] ?? '';

                    _crewNationalityController.text =
                        info['nacionalidadeTripulacao'] ?? '';
                    _cabinCountController.text =
                        info['numeroCabines']?.toString() ?? '';
                    _hasMinibar = info['frigobar'] ?? false;
                    _hasSink = info['pia'] ?? false;
                  });
                },
              );
            },
          ),
        );
      },
    );
  }

  /// --------------------------------------------------------------------------
  /// Campo de IMO
  /// --------------------------------------------------------------------------
  Widget _buildImoField() {
    return TextFormField(
      controller: _imoController,
      enabled: !_shipAlreadyExists,
      decoration: InputDecoration(
        labelText: 'IMO (opcional)',
        prefixIcon: const Icon(Icons.numbers, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: _shipAlreadyExists ? Colors.grey[100] : Colors.white,
      ),
    );
  }

  /// --------------------------------------------------------------------------
  /// Dropdown de tipo de cabine
  /// --------------------------------------------------------------------------
  Widget _buildCabinTypeDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedCabinType,
      decoration: InputDecoration(
        labelText: 'Tipo da cabine',
        prefixIcon: const Icon(Icons.bed, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      items: _cabinTypes
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: (v) => setState(() => _selectedCabinType = v),
    );
  }

  /// --------------------------------------------------------------------------
  /// Seletor de data de desembarque
  /// --------------------------------------------------------------------------
  Widget _buildDisembarkationDatePicker() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF3F51B5).withAlpha(26),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.event,
            color: Color(0xFF3F51B5),
          ),
        ),
        title: const Text(
          'Data de desembarque',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          _disembarkationDate == null
              ? 'Toque para selecionar'
              : '${_disembarkationDate!.day.toString().padLeft(2, '0')}/${_disembarkationDate!.month.toString().padLeft(2, '0')}/${_disembarkationDate!.year}',
          style: TextStyle(
            color: _disembarkationDate == null
                ? Colors.grey
                : const Color(0xFF3F51B5),
            fontWeight: _disembarkationDate == null
                ? FontWeight.normal
                : FontWeight.w600,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: Color(0xFF3F51B5)),
        onTap: _selectDisembarkationDate,
      ),
    );
  }
}