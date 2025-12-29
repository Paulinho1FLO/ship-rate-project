import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'rating_controller.dart';

/// ---------------------------------------------------------------------------
/// TELA DE CADASTRO DE AVALIAÇÃO DE NAVIO
/// ---------------------------------------------------------------------------
/// Responsável por:
/// • Criar nova avaliação
/// • Autocomplete de navios existentes
/// • Bloquear campos quando o navio já existe
/// • Coletar notas e observações
class AddRatingPage extends StatefulWidget {
  final String imo;

  const AddRatingPage({
    super.key,
    required this.imo,
  });

  @override
  State<AddRatingPage> createState() => _AddRatingPageState();
}

/// ---------------------------------------------------------------------------
/// STATE DA TELA DE AVALIAÇÃO
/// ---------------------------------------------------------------------------
class _AddRatingPageState extends State<AddRatingPage> {
  /// Form
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  /// Controller de negócio
  final RatingController _ratingController = RatingController();

  /// Controllers de campos principais
  final TextEditingController nomeNavioController = TextEditingController();
  final TextEditingController imoController = TextEditingController();
  final TextEditingController observacaoGeralController =
      TextEditingController();
  final TextEditingController nacionalidadeTripulacaoController =
      TextEditingController();
  final TextEditingController numeroCabinesController =
      TextEditingController();

  /// FocusNode persistente para evitar bugs no autocomplete
  final FocusNode nomeNavioFocusNode = FocusNode();

  /// Lista local de navios (autocomplete)
  List<QueryDocumentSnapshot> _naviosCadastrados = [];

  /// Estado atual
  String _nomeNavioAtual = '';
  String? tipoCabine;
  DateTime? dataDesembarque;

  bool possuiFrigobar = false;
  bool possuiPia = false;
  bool isSaving = false;
  bool navioJaExiste = false;

  /// Tipos de cabine disponíveis
  static const List<String> tiposCabine = [
    'PRT',
    'OWNER',
    'Spare Officer',
    'Crew',
  ];

  /// Itens avaliados (ordem oficial)
  static const List<String> _itensAvaliacao = [
    'Dispositivo de Embarque/Desembarque',
    'Temperatura da Cabine',
    'Limpeza da Cabine',
    'Passadiço – Equipamentos',
    'Passadiço – Temperatura',
    'Comida',
    'Relacionamento com comandante/tripulação',
  ];

  /// Notas e observações por item
  late final Map<String, double> notasPorItem;
  late final Map<String, TextEditingController> observacoesPorItemController;

  /// -------------------------------------------------------------------------
  /// INIT
  /// -------------------------------------------------------------------------
  @override
  void initState() {
    super.initState();

    _carregarNavios();

    notasPorItem = {
      for (final item in _itensAvaliacao) item: 3.0,
    };

    observacoesPorItemController = {
      for (final item in _itensAvaliacao) item: TextEditingController(),
    };
  }

  /// -------------------------------------------------------------------------
  /// CARREGA NAVIOS PARA AUTOCOMPLETE
  /// -------------------------------------------------------------------------
  Future<void> _carregarNavios() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('navios').get();

    if (!mounted) return;

    setState(() {
      _naviosCadastrados = snapshot.docs;
    });
  }

  /// -------------------------------------------------------------------------
  /// DISPOSE
  /// -------------------------------------------------------------------------
  @override
  void dispose() {
    nomeNavioFocusNode.dispose();
    nomeNavioController.dispose();
    imoController.dispose();
    observacaoGeralController.dispose();
    nacionalidadeTripulacaoController.dispose();
    numeroCabinesController.dispose();

    for (final controller in observacoesPorItemController.values) {
      controller.dispose();
    }

    super.dispose();
  }

  /// -------------------------------------------------------------------------
  /// DESTAQUE EM NEGRITO DAS LETRAS EM COMUM (AUTOCOMPLETE)
  /// -------------------------------------------------------------------------
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

  /// -------------------------------------------------------------------------
  /// SALVAR AVALIAÇÃO
  /// -------------------------------------------------------------------------
  Future<void> _salvarAvaliacao() async {
    if (!_formKey.currentState!.validate()) return;

    if (dataDesembarque == null || tipoCabine == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha todos os campos obrigatórios'),
        ),
      );
      return;
    }

    setState(() => isSaving = true);

    try {
      await _ratingController.salvarAvaliacao(
        nomeNavio: _nomeNavioAtual.trim(),
        imoInicial: imoController.text.trim(),
        dataDesembarque: dataDesembarque!,
        tipoCabine: tipoCabine!,
        observacaoGeral: observacaoGeralController.text.trim(),
        infoNavio: {
          'nacionalidadeTripulacao':
              nacionalidadeTripulacaoController.text.trim(),
          'numeroCabines':
              int.tryParse(numeroCabinesController.text) ?? 0,
          'frigobar': possuiFrigobar,
          'pia': possuiPia,
        },
        itens: {
          for (final item in _itensAvaliacao)
            item: {
              'nota': notasPorItem[item]!,
              'observacao':
                  observacoesPorItemController[item]!.text.trim(),
            }
        },
      );

      if (!mounted) return;

      Navigator.pop(context, true);
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  /// -------------------------------------------------------------------------
  /// SELECIONAR DATA DE DESEMBARQUE
  /// -------------------------------------------------------------------------
  Future<void> _selecionarDataDesembarque() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() => dataDesembarque = picked);
    }
  }

  /// -------------------------------------------------------------------------
  /// BUILD
  /// -------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Avaliar Navio'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),

      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: isSaving ? null : _salvarAvaliacao,
          child: Text(isSaving ? 'Salvando...' : 'Salvar Avaliação'),
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildAutocompleteNavio(),
              const SizedBox(height: 12),
              _buildCampoIMO(),
              const Divider(height: 32),
              _buildTipoCabine(),
              const SizedBox(height: 16),
              _buildDataDesembarque(),
              const Divider(height: 32),
              _buildInfoNavio(),
              const Divider(height: 32),
              for (final item in _itensAvaliacao) _buildItemAvaliacao(item),
              const Divider(height: 32),
              _buildObservacaoGeral(),
            ],
          ),
        ),
      ),
    );
  }

  /// -------------------------------------------------------------------------
  /// WIDGETS AUXILIARES
  /// -------------------------------------------------------------------------
  Widget _buildAutocompleteNavio() {
  return RawAutocomplete<QueryDocumentSnapshot>(
    textEditingController: nomeNavioController,
    focusNode: nomeNavioFocusNode,
    displayStringForOption: (opt) => opt['nome'],
    optionsBuilder: (value) {
      if (value.text.isEmpty) {
        return const Iterable<QueryDocumentSnapshot>.empty();
      }

      return _naviosCadastrados.where((doc) {
        final nome = doc['nome'].toString().toLowerCase();
        return nome.contains(value.text.toLowerCase());
      });
    },
    fieldViewBuilder: (context, controller, focusNode, onSubmit) {
      return TextFormField(
        controller: controller,
        focusNode: focusNode,
        decoration: const InputDecoration(labelText: 'Nome do navio'),
        validator: (v) =>
            v == null || v.isEmpty ? 'Informe o nome do navio' : null,
        onChanged: (v) {
          _nomeNavioAtual = v;
          setState(() => navioJaExiste = false);
        },
      );
    },
    optionsViewBuilder: (context, onSelected, options) {
      if (options.isEmpty) {
        return const SizedBox.shrink(); // 🔒 NÃO abre overlay
      }

      return Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(12),
        child: ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: options.length,
          itemBuilder: (_, index) {
            final opt = options.elementAt(index);
            final data = opt.data() as Map<String, dynamic>;
            final info = (data['info'] ?? {}) as Map<String, dynamic>;

            return ListTile(
              leading: const Icon(Icons.directions_boat),
              title: RichText(
                text: _highlightMatch(
                  data['nome'],
                  nomeNavioController.text,
                ),
              ),
              onTap: () {
                onSelected(opt);

                setState(() {
                  navioJaExiste = true;
                  nomeNavioController.text = data['nome'];
                  _nomeNavioAtual = data['nome'];
                  imoController.text = data['imo'] ?? '';

                  nacionalidadeTripulacaoController.text =
                      info['nacionalidadeTripulacao'] ?? '';
                  numeroCabinesController.text =
                      info['numeroCabines']?.toString() ?? '';
                  possuiFrigobar = info['frigobar'] ?? false;
                  possuiPia = info['pia'] ?? false;
                });
              },
            );
          },
        ),
      );
    },
  );
}


  Widget _buildCampoIMO() {
    return TextFormField(
      controller: imoController,
      enabled: !navioJaExiste,
      decoration:
          const InputDecoration(labelText: 'IMO (opcional)'),
    );
  }

  Widget _buildTipoCabine() {
    return DropdownButtonFormField<String>(
      value: tipoCabine,
      decoration:
          const InputDecoration(labelText: 'Tipo da cabine'),
      items: tiposCabine
          .map((e) =>
              DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: (v) => setState(() => tipoCabine = v),
    );
  }

  Widget _buildDataDesembarque() {
    return ListTile(
      leading: const Icon(Icons.event),
      title: const Text('Data de desembarque'),
      subtitle: Text(
        dataDesembarque == null
            ? 'Selecionar'
            : '${dataDesembarque!.day}/${dataDesembarque!.month}/${dataDesembarque!.year}',
      ),
      onTap: _selecionarDataDesembarque,
    );
  }

  Widget _buildInfoNavio() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Informações do navio',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.indigo,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: nacionalidadeTripulacaoController,
          enabled: !navioJaExiste,
          decoration: const InputDecoration(
            labelText: 'Nacionalidade da tripulação',
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: numeroCabinesController,
          enabled: !navioJaExiste,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Quantidade de cabines',
          ),
        ),
        SwitchListTile(
          title: const Text('Possui frigobar'),
          value: possuiFrigobar,
          onChanged:
              navioJaExiste ? null : (v) => setState(() => possuiFrigobar = v),
        ),
        SwitchListTile(
          title: const Text('Possui pia'),
          value: possuiPia,
          onChanged:
              navioJaExiste ? null : (v) => setState(() => possuiPia = v),
        ),
      ],
    );
  }

  Widget _buildItemAvaliacao(String item) {
    final valor = notasPorItem[item]!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item,
                style:
                    const TextStyle(fontWeight: FontWeight.bold)),
            Slider(
              value: valor,
              min: 1,
              max: 5,
              divisions: 40,
              label: valor.toStringAsFixed(1),
              onChanged: (v) =>
                  setState(() => notasPorItem[item] = v),
            ),
            TextField(
              controller: observacoesPorItemController[item],
              decoration: const InputDecoration(
                hintText: 'Observação (opcional)',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildObservacaoGeral() {
    return TextFormField(
      controller: observacaoGeralController,
      maxLines: 4,
      decoration:
          const InputDecoration(labelText: 'Observação geral'),
    );
  }
}
