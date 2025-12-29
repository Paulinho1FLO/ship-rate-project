import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../auth/login_page.dart';
import '../ships/search_ship_page.dart';
import 'home_controller.dart';
import '../suggestions/suggestion_page.dart';
import '../ships/my_ratings_page.dart';

/// ---------------------------------------------------------------------------
/// TELA PRINCIPAL (HOME) DO APLICATIVO
/// ---------------------------------------------------------------------------
/// Responsável por:
/// • Controlar o Drawer
/// • Verificar versão remota do app
/// • Forçar atualização de dados ao abrir / retornar ao app
/// • Exibir banner de atualização
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

/// ---------------------------------------------------------------------------
/// STATE DA TELA PRINCIPAL
/// ---------------------------------------------------------------------------
/// Implementa [WidgetsBindingObserver] para escutar eventos
/// de ciclo de vida do app (ex: app voltou para foreground)
class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  /// Indica se o banner de atualização deve ser exibido
  bool _showUpdateBanner = false;

  /// Versão remota obtida do Firestore

  /// Chave usada para forçar rebuild completo do body
  Key _rebuildKey = UniqueKey();

  @override
  void initState() {
    super.initState();

    /// Observa mudanças no ciclo de vida do app
    WidgetsBinding.instance.addObserver(this);

    /// Força atualização inicial ao abrir o app
    _forceRefresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// -------------------------------------------------------------------------
  /// CALLBACK DO CICLO DE VIDA
  /// -------------------------------------------------------------------------
  /// Sempre que o app retorna para o foreground,
  /// força atualização dos dados.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _forceRefresh();
    }
  }

  /// -------------------------------------------------------------------------
  /// LIMPA CACHE LOCAL + FORÇA REBUILD DA UI
  /// -------------------------------------------------------------------------
  /// • Limpa cache local do Firestore (quando possível)
  /// • Força rebuild completo da árvore de widgets
  /// • Revalida versão remota do app
  Future<void> _forceRefresh() async {
    if (!mounted) return;

    setState(() {
      _rebuildKey = UniqueKey();
    });
  }

  /// -------------------------------------------------------------------------
  /// LOGOUT DO USUÁRIO
  /// -------------------------------------------------------------------------
  Future<void> _handleLogout() async {
    final controller = MainScreenController();
    await controller.logout();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  /// -------------------------------------------------------------------------
  /// BANNER DE ATUALIZAÇÃO
  /// -------------------------------------------------------------------------
  Widget _buildUpdateBanner() {
    if (!_showUpdateBanner) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: Colors.amber.shade700,
      child: const Text(
        'Nova atualização disponível.\n'
        'Feche o app e abra novamente para aplicar.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// -------------------------------------------------------------------------
  /// BUILD
  /// -------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ShipRate',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),

      /// =========================
      /// DRAWER PRINCIPAL
      /// =========================
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// HEADER
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF3F51B5),
                      Color(0xFF2F3E9E),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    bottomRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Icon(
                      Icons.directions_boat_filled,
                      size: 48,
                      color: Colors.white,
                    ),
                    SizedBox(height: 14),
                    Text(
                      'ShipRate',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Avaliação profissional de navios',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              _drawerItem(
                icon: Icons.search,
                label: 'Buscar / Avaliar Navios',
                onTap: () => Navigator.pop(context),
              ),

              _drawerItem(
                icon: Icons.assignment_turned_in_outlined,
                label: 'Minhas Avaliações',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MyRatingsPage(),
                    ),
                  );
                },
              ),

              _drawerItem(
                icon: Icons.lightbulb_outline,
                label: 'Enviar Sugestão',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SuggestionPage(),
                    ),
                  );
                },
              ),

              const Divider(
                height: 32,
                thickness: 1,
              ),

              /// LOGOUT
              _drawerItem(
                icon: Icons.logout,
                label: 'Sair',
                color: Colors.redAccent,
                onTap: _handleLogout,
              ),
            ],
          ),
        ),
      ),

      /// =========================
      /// BODY COM REBUILD CONTROLADO
      /// =========================
      body: KeyedSubtree(
        key: _rebuildKey,
        child: Column(
          children: [
            _buildUpdateBanner(),
            const Expanded(child: SearchAndRateShipPage()),
          ],
        ),
      ),
    );
  }

  /// -------------------------------------------------------------------------
  /// ITEM PADRÃO DO DRAWER
  /// -------------------------------------------------------------------------
  Widget _drawerItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.black87),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: color ?? Colors.black87,
        ),
      ),
      onTap: onTap,
    );
  }
}
