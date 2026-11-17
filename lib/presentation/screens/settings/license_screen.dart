import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:harcama_takip/core/constants/app_constants.dart';
import 'package:harcama_takip/core/l10n/app_locale.dart';
import 'package:harcama_takip/core/theme/app_spacing.dart';
import 'package:harcama_takip/core/theme/app_theme.dart';
import '../splash/splash_screen.dart';

class _LicenseData {
  final Map<String, List<List<LicenseParagraph>>> packages = {};

  void addLicense(LicenseEntry entry) {
    for (final package in entry.packages) {
      packages.putIfAbsent(package, () => <List<LicenseParagraph>>[]).add(
        entry.paragraphs.toList(),
      );
    }
  }

  List<String> get sortedPackages {
    final list = packages.keys.toList();
    list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }
}

class AppLicensePage extends StatefulWidget {
  const AppLicensePage({super.key});

  @override
  State<AppLicensePage> createState() => _AppLicensePageState();
}

class _AppLicensePageState extends State<AppLicensePage> {
  late final Future<_LicenseData> _licensesFuture;

  @override
  void initState() {
    super.initState();
    _licensesFuture = LicenseRegistry.licenses.fold<_LicenseData>(
      _LicenseData(),
      (prev, entry) => prev..addLicense(entry),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: Text('Lisanslar'.tr),
      ),
      body: FutureBuilder<_LicenseData>(
        future: _licensesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data;
          final packageNames = data?.sortedPackages ?? [];

          return ListView.builder(
            padding: AppSpacing.screenPadding,
            itemCount: packageNames.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: Column(
                    children: [
                      const AppLogo(size: 64),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        AppConstants.appName,
                        style: context.textStyles.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '1.1.1+3',
                        style: context.textStyles.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        AppConstants.appTagline,
                        style: context.textStyles.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Powered by Faydalab', // l10n-ignore
                          style: context.textStyles.titleSmall?.copyWith(
                            color: scheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const Divider(),
                    ],
                  ),
                );
              }

              final packageName = packageNames[index - 1];
              final licenseParagraphsList = data!.packages[packageName] ?? [];

              return Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                elevation: 0,
                color: scheme.surfaceContainerLow,
                child: ExpansionTile(
                  title: Text(
                    packageName,
                    style: context.textStyles.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    '{0} lisans'.trArgs([licenseParagraphsList.length]),
                    style: context.textStyles.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  children: [
                    for (final paragraphs in licenseParagraphsList) ...[
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: SelectableText(
                          paragraphs.map((p) => p.text).join('\n\n'),
                          style: context.textStyles.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                            height: 1.4,
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
