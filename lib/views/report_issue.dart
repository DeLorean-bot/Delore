import 'dart:ffi';
import 'dart:io';

import 'package:flclashx/common/common.dart';
import 'package:flclashx/state.dart';
import 'package:flclashx/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> showReportIssue(BuildContext context) => showExtend<void>(
      context,
      props: const ExtendProps(maxWidth: 640, maxHeight: 780),
      builder: (_, type) => _ReportIssueView(type: type),
    );

class _ReportIssueView extends StatefulWidget {
  const _ReportIssueView({required this.type});

  final SheetType type;

  @override
  State<_ReportIssueView> createState() => _ReportIssueViewState();
}

class _ReportIssueViewState extends State<_ReportIssueView> {
  final _formKey = GlobalKey<FormState>();
  final _summaryController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _stepsController = TextEditingController();
  final _expectedController = TextEditingController();
  final _actualController = TextEditingController();
  final _contactController = TextEditingController();

  String _area = 'Interface';
  String _frequency = 'Every time';
  bool _anonymous = true;
  bool _includeDiagnostics = false;
  bool _submitting = false;

  bool get _russian => Localizations.localeOf(context).languageCode == 'ru';

  String _text(String ru, String en) => _russian ? ru : en;

  @override
  void dispose() {
    _summaryController.dispose();
    _descriptionController.dispose();
    _stepsController.dispose();
    _expectedController.dispose();
    _actualController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || _formKey.currentState?.validate() != true) return;
    setState(() => _submitting = true);

    final report = _buildReport();
    final uri = Uri.https(
      'github.com',
      '/$repository/issues/new',
      {
        'title': '[Bug] ${_summaryController.text.trim()}',
        'body': report,
        'labels': 'bug',
      },
    );

    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}

    if (!opened && mounted) {
      await Clipboard.setData(ClipboardData(text: report));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _text(
              'Не удалось открыть GitHub. Текст отчёта скопирован.',
              'Could not open GitHub. The report was copied.',
            ),
          ),
        ),
      );
      setState(() => _submitting = false);
      return;
    }

    if (mounted) Navigator.of(context).pop();
  }

  String _buildReport() {
    final contact = _anonymous || _contactController.text.trim().isEmpty
        ? _text('Не указан', 'Not provided')
        : _contactController.text.trim();
    final buffer = StringBuffer()
      ..writeln('## ${_text('Что произошло', 'What happened')}')
      ..writeln(_descriptionController.text.trim())
      ..writeln()
      ..writeln('## ${_text('Как воспроизвести', 'Steps to reproduce')}')
      ..writeln(_stepsController.text.trim())
      ..writeln()
      ..writeln('## ${_text('Ожидаемый результат', 'Expected result')}')
      ..writeln(_expectedController.text.trim())
      ..writeln()
      ..writeln('## ${_text('Фактический результат', 'Actual result')}')
      ..writeln(_actualController.text.trim())
      ..writeln()
      ..writeln('## ${_text('Контекст', 'Context')}')
      ..writeln('- ${_text('Раздел', 'Area')}: $_area')
      ..writeln('- ${_text('Частота', 'Frequency')}: $_frequency')
      ..writeln('- ${_text('Контакт', 'Contact')}: $contact');

    if (_includeDiagnostics) {
      final abi = Abi.current().toString().split('.').last;
      final executable = Platform.resolvedExecutable.toLowerCase();
      final installation =
          executable.contains('build${Platform.pathSeparator}windows')
              ? 'development'
              : executable.contains('program files')
                  ? 'installed'
                  : 'portable';
      buffer
        ..writeln()
        ..writeln('## Diagnostics')
        ..writeln('- Delore: ${globalState.packageInfo.version} '
            '(${globalState.packageInfo.buildNumber})')
        ..writeln('- OS: ${Platform.operatingSystem}')
        ..writeln('- OS version: ${Platform.operatingSystemVersion}')
        ..writeln('- Architecture: $abi')
        ..writeln('- Installation: $installation')
        ..writeln()
        ..writeln(
            '<!-- No profiles, subscription URLs, IP addresses or secrets '
            'are included by Delore. -->');
    }
    return buffer.toString().trim();
  }

  String? _required(String? value) => value == null || value.trim().isEmpty
      ? _text('Заполните это поле', 'This field is required')
      : null;

  @override
  Widget build(BuildContext context) => AdaptiveSheetScaffold(
        type: widget.type,
        title: _text('Сообщить о проблеме', 'Report a problem'),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Text(
                _text(
                  'Ответьте на несколько вопросов — Delore соберёт аккуратный '
                      'багрепорт для нашего GitHub.',
                  'Answer a few questions and Delore will prepare a clear bug '
                      'report for our GitHub.',
                ),
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              _field(
                controller: _summaryController,
                label: _text('Коротко: что сломалось?', 'What broke?'),
                hint: _text(
                  'Например: при открытии приложений зависает интерфейс',
                  'Example: interface freezes when opening Applications',
                ),
                maxLength: 120,
                validator: _required,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _dropdown(
                      value: _area,
                      label: _text('Раздел', 'Area'),
                      values: const [
                        'Dashboard',
                        'Applications',
                        'Browser',
                        'Connections',
                        'Profiles',
                        'Settings',
                        'Updates',
                        'Interface',
                        'Other',
                      ],
                      onChanged: (value) => setState(() => _area = value),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _dropdown(
                      value: _frequency,
                      label: _text('Как часто?', 'How often?'),
                      values: const [
                        'Every time',
                        'Often',
                        'Sometimes',
                        'Once',
                      ],
                      onChanged: (value) => setState(() => _frequency = value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _field(
                controller: _descriptionController,
                label: _text('Что произошло?', 'What happened?'),
                maxLength: 1200,
                maxLines: 4,
                validator: _required,
              ),
              const SizedBox(height: 12),
              _field(
                controller: _stepsController,
                label: _text(
                  'Шаги воспроизведения',
                  'Steps to reproduce',
                ),
                hint: _text('1. Открыл…\n2. Нажал…\n3. Произошло…',
                    '1. Opened…\n2. Clicked…\n3. Observed…'),
                maxLength: 1600,
                maxLines: 5,
                validator: _required,
              ),
              const SizedBox(height: 12),
              _field(
                controller: _expectedController,
                label: _text(
                  'Что должно было произойти?',
                  'What did you expect?',
                ),
                maxLength: 800,
                maxLines: 3,
                validator: _required,
              ),
              const SizedBox(height: 12),
              _field(
                controller: _actualController,
                label: _text(
                  'Что произошло на самом деле?',
                  'What happened instead?',
                ),
                maxLength: 800,
                maxLines: 3,
                validator: _required,
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(_text(
                    'Не указывать мои данные', 'Do not include my details')),
                subtitle: Text(
                  _text(
                    'GitHub всё равно может показать аккаунт, с которого вы '
                        'нажмёте Submit.',
                    'GitHub may still show the account used to press Submit.',
                  ),
                ),
                value: _anonymous,
                onChanged: (value) => setState(() => _anonymous = value),
              ),
              if (!_anonymous) ...[
                const SizedBox(height: 8),
                _field(
                  controller: _contactController,
                  label: _text(
                    'Имя или контакт (необязательно)',
                    'Name or contact (optional)',
                  ),
                  maxLength: 160,
                ),
              ],
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(_text('Добавить безопасную диагностику',
                    'Include safe diagnostics')),
                subtitle: Text(
                  _text(
                    'Версия Delore, ОС, архитектура и тип установки. Без IP, '
                        'подписок, конфигов и секретов.',
                    'Delore version, OS, architecture and installation type. '
                        'No IPs, subscriptions, configs or secrets.',
                  ),
                ),
                value: _includeDiagnostics,
                onChanged: (value) =>
                    setState(() => _includeDiagnostics = value),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.bug_report_outlined),
                label: Text(_text(
                    'Проверить и отправить на GitHub', 'Review on GitHub')),
              ),
            ],
          ),
        ),
      );

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    int? maxLength,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) =>
      TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label, hintText: hint),
        maxLength: maxLength,
        maxLines: maxLines,
        validator: validator,
      );

  Widget _dropdown({
    required String value,
    required String label,
    required List<String> values,
    required ValueChanged<String> onChanged,
  }) =>
      DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        items: [
          for (final item in values)
            DropdownMenuItem(value: item, child: Text(item)),
        ],
        onChanged: (next) {
          if (next != null) onChanged(next);
        },
      );
}
