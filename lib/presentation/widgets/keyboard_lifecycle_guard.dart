import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Uygulama arka plana geçerken klavyeyi kapatır (Android).
///
/// Bazı cihazlarda (ör. Samsung, Android 15+) klavye açıkken uygulama arka plana
/// alınıp geri getirildiğinde sistem "klavye kapandı" bilgisini uygulamaya
/// iletmiyor; ekranın alt kısmı klavye varmış gibi boş kalıyordu. Klavyeyi,
/// pencere henüz görünürken (inactive) kapatmak bu bilginin teslim edilmesini sağlar.
class KeyboardLifecycleGuard extends StatefulWidget {
  final Widget child;

  /// Testlerde platformdan bağımsız denemek için.
  @visibleForTesting
  final bool? enabledOverride;

  const KeyboardLifecycleGuard({
    super.key,
    required this.child,
    this.enabledOverride,
  });

  @override
  State<KeyboardLifecycleGuard> createState() => _KeyboardLifecycleGuardState();
}

class _KeyboardLifecycleGuardState extends State<KeyboardLifecycleGuard> {
  AppLifecycleListener? _listener;

  bool get _enabled =>
      widget.enabledOverride ??
      (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);

  @override
  void initState() {
    super.initState();
    if (_enabled) {
      _listener = AppLifecycleListener(
        onInactive: _dismissKeyboard,
        onHide: _dismissKeyboard,
        onPause: _dismissKeyboard,
      );
    }
  }

  void _dismissKeyboard() {
    final focus = FocusManager.instance.primaryFocus;
    if (focus != null && focus.context != null) focus.unfocus();
  }

  @override
  void dispose() {
    _listener?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
