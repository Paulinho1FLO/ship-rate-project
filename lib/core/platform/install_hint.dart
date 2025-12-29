// Export condicional para resolução automática de implementação
// do serviço `InstallHintService`.
//
// Este mecanismo utiliza uma feature do Dart chamada
// **Conditional Imports/Exports**, que permite selecionar
// dinamicamente qual arquivo será utilizado dependendo do
// ambiente de execução.
//
// Funcionamento:
// --------------
// • Em plataformas que NÃO possuem `dart:html`
//     → será exportado `install_hint_mobile.dart`
//
// • Em plataformas que possuem `dart:html` (Web)
//     → será exportado `install_hint_web.dart`
//
// Com isso:
//   - A UI pode importar APENAS este arquivo.
//   - E receberá automaticamente a implementação correta.
//   - Sem precisar alterar código em outras partes.
//
// Exemplo de uso:
// ```dart
// import 'install_hint.dart';
// final service = getInstallHintService();
// if (service.shouldShowInstallHint()) {
//   showInstallBanner();
// }
// ```
//
// Benefícios:
// -----------
// ✔ evita `kIsWeb` nos widgets  
// ✔ separa responsabilidades por plataforma  
// ✔ reduz duplicação de código  
// ✔ mantém o design limpo e escalável
//

export 'install_hint_mobile.dart'
    if (dart.library.html) 'install_hint_web.dart';
