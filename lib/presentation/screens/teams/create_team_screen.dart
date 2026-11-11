import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../application/providers/auth_providers.dart';
import '../../../application/providers/repository_providers.dart';
import '../../../domain/entities/team.dart';
import '../../../domain/entities/team_member.dart';

class CreateTeamScreen extends ConsumerStatefulWidget {
  const CreateTeamScreen({super.key});

  @override
  ConsumerState<CreateTeamScreen> createState() => _CreateTeamScreenState();
}

class _CreateTeamScreenState extends ConsumerState<CreateTeamScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedColorHex = '#0F5132';
  bool _isLoading = false;

  final List<String> _colors = [
    '#0F5132', // Zümrüt Yeşili
    '#1E3A8A', // Derin Gece Mavisi
    '#7C3AED', // Mor
    '#B91C1C', // Kırmızı
    '#D97706', // Turuncu
    '#0D9488', // Teal
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = ref.read(authStateProvider).value!;
      final teamRepo = ref.read(teamRepositoryProvider);
      final teamId = const Uuid().v4();

      final newTeam = Team(
        id: teamId,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        colorHex: _selectedColorHex,
        ownerUid: user.uid,
        memberCount: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final ownerMember = TeamMember(
        uid: user.uid,
        teamId: teamId,
        displayName: user.displayName ?? 'Kullanıcı',
        email: user.email ?? '',
        role: 'owner',
        status: 'accepted',
        joinedAt: DateTime.now(),
        invitedBy: user.uid,
      );

      await teamRepo.createTeam(newTeam, ownerMember);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Takım başarıyla oluşturuldu.')),
        );
        context.pop();
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Yeni Takım Oluştur')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Takım Adı',
                hintText: 'Örn: Evimiz / Aile Bütçesi / Tatil Grubu',
                prefixIcon: Icon(Icons.groups_rounded),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Takım adını giriniz';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Açıklama (İsteğe bağlı)',
                prefixIcon: Icon(Icons.description_outlined),
              ),
            ),
            const SizedBox(height: 20),
            Text('Takım Rengi', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              children: _colors.map((hex) {
                final color = Color(int.parse(hex.replaceFirst('#', '0xFF')));
                final isSelected = _selectedColorHex == hex;
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: InkWell(
                    onTap: () => setState(() => _selectedColorHex = hex),
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected ? Border.all(color: Colors.black, width: 3) : null,
                      ),
                      child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _handleCreate,
              child: _isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Takımı Başlat'),
            ),
          ],
        ),
      ),
    );
  }
}
