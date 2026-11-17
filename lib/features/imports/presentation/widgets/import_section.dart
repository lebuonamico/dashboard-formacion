import 'package:app_finnegans/core/layout/window_size.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/core/widgets/feedback.dart';
import 'package:app_finnegans/features/imports/domain/import_file.dart';
import 'package:app_finnegans/features/imports/presentation/import_file_type_labels.dart';
import 'package:app_finnegans/features/imports/presentation/providers/import_notifier.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const importConfirmKey = Key('importar_confirmar');

class ImportSection extends ConsumerWidget {
  final ImportFileType type;

  const ImportSection({super.key, required this.type});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inProgress = ref.watch(
      importProvider.select(
        (state) => state.value?.inProgress.contains(type) ?? false,
      ),
    );
    final windowSize = context.windowSize;
    final button = OutlinedButton.icon(
      key: Key('importar_${type.keySuffix}'),
      onPressed: inProgress ? null : () => _import(context, ref),
      // Desktop keeps the button's default height.
      style: windowSize == WindowSize.expanded
          ? null
          : OutlinedButton.styleFrom(minimumSize: const Size(64, 48)),
      icon: inProgress
          ? SizedBox.square(
              key: Key('loading_${type.keySuffix}'),
              dimension: 18,
              child: const CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.upload_file, size: 18),
      label: Text(type.buttonLabel),
    );
    final icon = _SectionIcon(
      icon: type.icon,
      colors: type.iconColors(context),
    );
    final title = Text(
      type.title,
      style: const TextStyle(fontWeight: FontWeight.w600),
    );
    final subtitle = Text(type.subtitle);

    // On a phone the button beside the text leaves it a few words per line.
    if (windowSize == WindowSize.compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              icon,
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DefaultTextStyle.merge(
                      style: context.textTheme.bodyLarge?.copyWith(
                        color: context.colorScheme.onSurface,
                      ),
                      child: title,
                    ),
                    const SizedBox(height: 2),
                    DefaultTextStyle.merge(
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                      child: subtitle,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          button,
        ],
      );
    }
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: icon,
      title: title,
      subtitle: subtitle,
      trailing: button,
    );
  }

  Future<void> _import(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(importProvider.notifier);

    Future<ImportFile?> pickFile() async {
      // Lets the button show its progress before the picker opens.
      await WidgetsBinding.instance.endOfFrame;
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: type.allowedExtensions,
        withData: true,
      );
      final file = picked?.files.single;
      final bytes = file?.bytes;
      return file == null || bytes == null
          ? null
          : ImportFile(name: file.name, bytes: bytes);
    }

    Future<bool> confirm(ImportFile file) async =>
        context.mounted &&
        await showConfirmationDialog(
          context,
          title: type.confirmationTitle,
          message: type.confirmationMessage(file.name),
          confirmLabel: 'Importar',
          confirmKey: importConfirmKey,
        );

    return runWithResultFeedback<ImportOutcome>(
      context,
      action: () => switch (type) {
        ImportFileType.payroll => notifier.importPayroll(
          pickFile: pickFile,
          confirm: confirm,
        ),
        ImportFileType.courseCatalog => notifier.importCourses(
          pickFile: pickFile,
          confirm: confirm,
        ),
        ImportFileType.timeEntries => notifier.importTimeEntries(
          pickFile: pickFile,
          confirm: confirm,
        ),
        ImportFileType.certifications => notifier.importCertifications(
          pickFile: pickFile,
          confirm: confirm,
        ),
      },
      success: type.successMessage,
      failure: importErrorMessage,
    );
  }
}

class _SectionIcon extends StatelessWidget {
  final IconData icon;
  final ColorPair colors;

  const _SectionIcon({required this.icon, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, color: colors.text),
    );
  }
}
