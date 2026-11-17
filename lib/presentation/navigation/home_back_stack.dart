import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'auth_redirect.dart';

/// Bir iç sayfa uygulamanın ilk ve tek sayfası olarak açılırsa (bildirime
/// dokunma, derin bağlantı, web'de adresi doğrudan açma) altına ana sayfayı
/// yerleştirir.
///
/// Böylece geri tuşu ve sayfanın geri düğmesi uygulamayı kapatmak yerine ana
/// sayfaya döner (Android'in bildirimden açılan sayfalar için önerdiği davranış).
/// Sayfa zaten başka bir sayfanın üstündeyse hiçbir şey yapmaz.
class HomeBackStack extends StatefulWidget {
  final Widget child;

  const HomeBackStack({super.key, required this.child});

  @override
  State<HomeBackStack> createState() => _HomeBackStackState();
}

class _HomeBackStackState extends State<HomeBackStack> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final router = GoRouter.maybeOf(context);
      if (router == null || router.canPop()) return;
      final location = GoRouterState.of(context).uri.toString();
      if (location == AppRoutes.dashboard) return;
      router.go(AppRoutes.dashboard);
      router.push(location);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
