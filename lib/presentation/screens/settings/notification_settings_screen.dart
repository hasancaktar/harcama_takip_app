import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../application/providers/auth_providers.dart';
import '../../../application/providers/repository_providers.dart';
import '../../../application/services/notification_service.dart';
import '../../widgets/app_card.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends ConsumerState<NotificationSettingsScreen> {
  bool _enabled = true;
  TimeOfDay _selectedTime = const TimeOfDay(hour: 21, minute: 0);
  List<int> _selectedDays = [1, 2, 3, 4, 5, 6, 7]; // Pazartesi(1) - Pazar(7)
  bool _isLoading = false;

  final List<String> _dayNames = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

  @override
  void initState() {
    super.initState();
    final profile = ref.read(userProfileProvider).value;
    if (profile != null) {
      _enabled = profile.dailyReminderEnabled;
      _selectedTime = TimeOfDay(hour: profile.dailyReminderHour, minute: profile.dailyReminderMinute);
      _selectedDays = List.from(profile.dailyReminderDays);
    }
  }

  Future<void> _handleSave() async {
    setState(() => _isLoading = true);

    try {
      final uid = ref.read(currentUserIdProvider)!;
      final userRepo = ref.read(userRepositoryProvider);

      await userRepo.updateReminderSettings(
        uid: uid,
        enabled: _enabled,
        hour: _selectedTime.hour,
        minute: _selectedTime.minute,
        days: _selectedDays,
      );

      // Yerel bildirimleri güncelle
      if (_enabled) {
        await NotificationService().scheduleDailyReminder(
          hour: _selectedTime.hour,
          minute: _selectedTime.minute,
          days: _selectedDays,
        );
      } else {
        await NotificationService().cancelAll();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bildirim tercihleri güncellendi.')),
        );
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
      appBar: AppBar(title: const Text('Bildirim Ayarları')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Ana Bildirim Aç/Kapa
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _enabled,
              title: const Text('Günlük Harcama Hatırlatıcısı', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Günün harcamalarını girmeniz için her gün bildirim alın.'),
              onChanged: (val) => setState(() => _enabled = val),
            ),
          ),
          const SizedBox(height: 20),

          if (_enabled) ...[
            Text('Hatırlatma Saati', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            AppCard(
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: _selectedTime,
                );
                if (time != null) {
                  setState(() => _selectedTime = time);
                }
              },
              child: Row(
                children: [
                  const Icon(Icons.access_time_rounded),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Bildirim Zamanı', style: TextStyle(fontWeight: FontWeight.w500)),
                        Text(
                          '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')} (Europe/Istanbul)',
                          style: TextStyle(fontSize: 12, color: theme.hintColor),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Text('Hatırlatma Günleri', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (index) {
                final dayNumber = index + 1;
                final isSelected = _selectedDays.contains(dayNumber);

                return InkWell(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        if (_selectedDays.length > 1) {
                          _selectedDays.remove(dayNumber);
                        }
                      } else {
                        _selectedDays.add(dayNumber);
                        _selectedDays.sort();
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected ? theme.colorScheme.primary : theme.colorScheme.surfaceVariant,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      _dayNames[index],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: isSelected ? Colors.white : theme.hintColor,
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),
          ],

          ElevatedButton(
            onPressed: _isLoading ? null : _handleSave,
            child: _isLoading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Tercihleri Kaydet'),
          ),
        ],
      ),
    );
  }
}
