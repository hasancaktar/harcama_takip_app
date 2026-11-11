import 'package:flutter/material.dart';

class FirebaseSetupGuideScreen extends StatelessWidget {
  final String? errorMessage;

  const FirebaseSetupGuideScreen({super.key, this.errorMessage});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Firebase Kurulum Yönergesi'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amber),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 36),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Firebase Henüz Yapılandırılmadı',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Uygulama hazır! Kendi Firebase projenizi bağlamak için aşağıdaki 3 adımı terminalde çalıştırınız.',
                        style: TextStyle(color: theme.hintColor, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('Kurulum Adımları:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          _StepItem(
            stepNumber: '1',
            title: 'Firebase CLI ve FlutterFire CLI Yükleyin',
            code: 'npm install -g firebase-tools\ndart pub global activate flutterfire_cli',
          ),
          const SizedBox(height: 12),
          _StepItem(
            stepNumber: '2',
            title: 'Firebase Projenizi Bağlayın',
            code: 'flutterfire configure --project=YOUR_FIREBASE_PROJECT_ID',
          ),
          const SizedBox(height: 12),
          _StepItem(
            stepNumber: '3',
            title: 'Firestore Rules ve Indexleri Yükleyin',
            code: 'firebase deploy --only firestore:rules,firestore:indexes',
          ),
          const SizedBox(height: 24),
          if (errorMessage != null) ...[
            Text('Hata Detayı:', style: TextStyle(color: theme.hintColor, fontSize: 12)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                errorMessage!,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StepItem extends StatelessWidget {
  final String stepNumber;
  final String title;
  final String code;

  const _StepItem({
    required this.stepNumber,
    required this.title,
    required this.code,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Text(stepNumber, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              code,
              style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
