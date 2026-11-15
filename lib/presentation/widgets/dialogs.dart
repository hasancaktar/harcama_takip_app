import 'package:flutter/material.dart';

import '../../core/errors/error_messages.dart';
import '../../core/theme/app_theme.dart';

/// Onay diyaloğu. Onaylanırsa `true` döner.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Onayla',
  String cancelLabel = 'Vazgeç',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: scheme.error,
                    foregroundColor: scheme.onError,
                    minimumSize: const Size(64, 44),
                  )
                : FilledButton.styleFrom(minimumSize: const Size(64, 44)),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

/// Hassas işlemlerden önce şifre ister. Girilen şifreyi döner, vazgeçilirse `null`.
Future<String?> showPasswordPrompt(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Devam et',
  bool destructive = false,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _PasswordPromptDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      destructive: destructive,
    ),
  );
}

class _PasswordPromptDialog extends StatefulWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final bool destructive;

  const _PasswordPromptDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.destructive,
  });

  @override
  State<_PasswordPromptDialog> createState() => _PasswordPromptDialogState();
}

class _PasswordPromptDialogState extends State<_PasswordPromptDialog> {
  final _controller = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_controller.text.isEmpty) return;
    Navigator.pop(context, _controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.message),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            obscureText: _obscure,
            autofocus: true,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Mevcut şifre',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                tooltip: _obscure ? 'Şifreyi göster' : 'Şifreyi gizle',
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(
            minimumSize: const Size(64, 44),
            backgroundColor: widget.destructive ? scheme.error : null,
            foregroundColor: widget.destructive ? scheme.onError : null,
          ),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

extension SnackBarX on BuildContext {
  void showSuccess(String message) => _show(message);

  void showError(Object error) =>
      _show(ErrorMessages.from(error), isError: true);

  void showInfo(String message) => _show(message);

  void _show(String message, {bool isError = false}) {
    final messenger = ScaffoldMessenger.maybeOf(this);
    if (messenger == null) return;
    final scheme = Theme.of(this).colorScheme;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? scheme.error : null,
          showCloseIcon: isError,
          closeIconColor: isError ? scheme.onError : null,
          duration: Duration(seconds: isError ? 5 : 3),
        ),
      );
  }
}
