import 'package:flutter/material.dart';
import 'package:ship_rate/data/services/suggestion_service.dart';

/// ============================================================================
/// SUGGESTION PAGE
/// ============================================================================
/// Tela responsável por permitir que o usuário envie sugestões
/// e feedbacks para melhoria do aplicativo ShipRate.
///
/// A sugestão é enviada utilizando o [SugestaoService].
class SuggestionPage extends StatefulWidget {
  const SuggestionPage({super.key});

  @override
  State<SuggestionPage> createState() => _SuggestionPageState();
}

class _SuggestionPageState extends State<SuggestionPage> {
  /// Controllers dos campos de formulário
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  /// Controle de loading do botão
  bool _isLoading = false;

  /// --------------------------------------------------------------------------
  /// Envia a sugestão utilizando o service
  /// --------------------------------------------------------------------------
  Future<void> _submitSuggestion() async {
    setState(() => _isLoading = true);

    final success = await SugestaoService.enviar(
      email: _emailController.text.trim(),
      titulo: _titleController.text.trim(),
      mensagem: _messageController.text.trim(),
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Sugestão enviada com sucesso!'
              : 'Erro ao enviar sugestão.',
        ),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );

    if (success) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Enviar Sugestão',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sua opinião é importante',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Ajude a melhorar o ShipRate com sugestões e ideias.',
              style: TextStyle(color: Colors.grey[700]),
            ),
            const SizedBox(height: 24),

            _buildField(
              controller: _emailController,
              label: 'Seu e-mail',
              icon: Icons.email_outlined,
            ),
            const SizedBox(height: 16),

            _buildField(
              controller: _titleController,
              label: 'Título da sugestão',
              icon: Icons.title,
            ),
            const SizedBox(height: 16),

            _buildField(
              controller: _messageController,
              label: 'Mensagem',
              icon: Icons.message_outlined,
              maxLines: 5,
            ),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitSuggestion,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Enviar Sugestão',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// --------------------------------------------------------------------------
  /// Campo padrão de formulário
  /// --------------------------------------------------------------------------
  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
