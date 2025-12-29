import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Controlador responsável por autenticação e gerenciamento de usuários.
///
/// Objetivo:
/// ---------
/// Centralizar a lógica de autenticação (login, registro, logout e reset de senha),
/// abstraindo completamente a camada de Firebase Authentication e Firestore.
///
/// Estrutura operacional:
/// ----------------------
/// • FirebaseAuth → gerencia sessão, criação e validação de credenciais.
/// • Firestore → armazena dados complementares do usuário:
///       - email
///       - nome de guerra (identificação pública no app)
///       - createdAt
///
/// Fluxo típico:
///  1) Usuário se registra via [register]
///  2) Dados extras são persistidos em `usuarios/{uid}`
///  3) Sessão é mantida automaticamente pelo Firebase
///  4) UI reage via `StreamBuilder<AuthGate>`
///
/// Tratamento de erros:
/// --------------------
/// • Os métodos convertem erros do FirebaseAuth em mensagens claras ao usuário
///   lançando [AuthException].
/// • No login, diferentes códigos de erro são normalizados:
///     - invalid-email
///     - wrong-password / invalid-credential
///     - user-not-found
///     - too-many-requests
///
/// Segurança e validação:
/// ----------------------
/// • Campos obrigatórios são validados antes da chamada ao Firebase.
/// • Confirmação de senha é tratada no registro.
/// • Reset de senha exige e-mail válido.
///
class AuthController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Registra um novo usuário no Firebase Authentication e salva dados adicionais no Firestore.
  ///
  /// Parâmetros:
  ///   • [email] — e-mail institucional ou pessoal do prático
  ///   • [password] — senha definida pelo usuário
  ///   • [confirmPassword] — confirmação da senha
  ///   • [nomeGuerra] — identificação usada nas avaliações
  ///
  /// Fluxo:
  ///   1) valida campos
  ///   2) valida senha = confirmação
  ///   3) cria credencial auth
  ///   4) cria documento `usuarios/{uid}`
  ///
  /// Exceções:
  ///   • [AuthException] para erros conhecidos/validados
  ///   • FirebaseAuthException convertida para mensagem amigável
  Future<void> register({
    required String email,
    required String password,
    required String confirmPassword,
    required String nomeGuerra,
  }) async {
    if (email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty ||
        nomeGuerra.isEmpty) {
      throw AuthException('Preencha todos os campos.');
    }

    if (password != confirmPassword) {
      throw AuthException('As senhas não coincidem.');
    }

    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await _firestore
          .collection('usuarios')
          .doc(userCredential.user!.uid)
          .set({
        'email': email,
        'nomeGuerra': nomeGuerra,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.message ?? 'Erro ao cadastrar usuário.');
    }
  }

  /// Realiza login via Firebase Authentication.
  ///
  /// Parâmetros:
  ///   • [email] — credencial de acesso
  ///   • [password] — senha associada
  ///
  /// Mapeamento inteligente de erros:
  ///   invalid-email → mensagem clara
  ///   wrong-password, invalid-credential → credenciais incorretas
  ///   too-many-requests → rate limit
  ///
  /// Retorna:
  ///   • `Future<void>`
  ///   • Lança [AuthException] em caso de falha
  Future<void> login({
    required String email,
    required String password,
  }) async {
    if (email.isEmpty || password.isEmpty) {
      throw AuthException('Preencha todos os campos.');
    }

    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuth login error: ${e.code} - ${e.message}');

      switch (e.code) {
        case 'invalid-email':
          throw AuthException('O e-mail informado é inválido.');
        case 'user-disabled':
          throw AuthException('Esta conta foi desativada.');
        case 'user-not-found':
          throw AuthException('Nenhuma conta encontrada com este e-mail.');
        case 'wrong-password':
        case 'invalid-credential':
        case 'invalid-login-credentials':
          throw AuthException('E-mail ou senha incorretos. Tente novamente.');
        case 'too-many-requests':
          throw AuthException('Muitas tentativas. Aguarde alguns minutos.');
        default:
          throw AuthException(
            'Não foi possível realizar o login. Verifique suas credenciais.',
          );
      }
    }
  }

  /// Realiza logout da sessão do usuário atual.
  ///
  /// Finaliza token e sessão local, delegando redirecionamento ao AuthGate.
  Future<void> logout() async {
    await _auth.signOut();
  }

  /// Envia e-mail de recuperação de senha padrão do Firebase.
  ///
  /// Parâmetros:
  ///   • [email] — deve corresponder a uma conta existente.
  ///
  /// Fluxo:
  ///   − dispara o fluxo automático do Firebase
  ///   − depende do template configurado no console
  ///
  /// Exceções:
  ///   • [AuthException] em erros controlados
  Future<void> sendPasswordReset(String email) async {
    if (email.isEmpty) {
      throw AuthException('Informe o e-mail.');
    }

    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.message ?? 'Erro ao enviar e-mail.');
    }
  }
}

/// Exceção customizada usada para encapsular erros de autenticação.
///
/// A função principal é permitir mensagens legíveis e controladas na UI,
/// evitando expor diretamente códigos internos do Firebase.
class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}
