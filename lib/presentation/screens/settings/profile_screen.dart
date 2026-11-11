import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../application/providers/auth_providers.dart';
import '../../../application/providers/repository_providers.dart';
import '../../widgets/app_card.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authStateProvider).value;
    if (user != null) {
      _nameController.text = user.displayName ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final user = ref.read(authStateProvider).value;
      if (user != null) {
        await user.updateDisplayName(newName);
        final profile = ref.read(userProfileProvider).value;
        if (profile != null) {
          final userRepo = ref.read(userRepositoryProvider);
          await userRepo.saveProfile(profile.copyWith(displayName: newName));
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profil başarıyla güncellendi.')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Profil Bilgileri')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: CircleAvatar(
              radius: 40,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: const Icon(Icons.person, size: 48),
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Ad Soyad',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            initialValue: user?.email ?? '',
            readOnly: true,
            decoration: const InputDecoration(
              labelText: 'E-posta (Değiştirilemez)',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isLoading ? null : _handleSave,
            child: _isLoading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Profili Kaydet'),
          ),
          const SizedBox(height: 48),
          const Divider(),
          const SizedBox(height: 16),
          Text(
            'Tehlikeli Bölge',
            style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          AppCard(
            color: Colors.red.withOpacity(0.05),
            border: Border.all(color: Colors.red.withOpacity(0.3)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Hesabı Sil', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                const SizedBox(height: 4),
                const Text(
                  'Hesabınızı sildiğinizde kişisel verileriniz kalıcı olarak kaldırılır. Bu işlem geri alınamaz.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Hesabı Kalıcı Olarak Sil'),
                        content: const Text(
                          'Tüm kişisel verileriniz, harcamalarınız ve ayarlarınız silinecek. Onaylıyor musunuz?',
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: TextButton.styleFrom(foregroundColor: Colors.red),
                            child: const Text('Hesabımı Sil'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      final authRepo = ref.read(authRepositoryProvider);
                      await authRepo.deleteAccount();
                      if (context.mounted) {
                        context.go('/login');
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                  child: const Text('Hesabımı Kalıcı Olarak Sil'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
