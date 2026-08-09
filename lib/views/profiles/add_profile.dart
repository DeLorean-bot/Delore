import 'package:flclashx/common/common.dart';
import 'package:flclashx/pages/scan.dart';
import 'package:flclashx/state.dart';
import 'package:flclashx/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'receive_profile_dialog.dart';

class AddProfileView extends StatelessWidget {
  const AddProfileView({
    super.key,
    required this.context,
  });
  final BuildContext context;

  Future<void> _handleAddProfileFormFile() async {
    globalState.appController.addProfileFormFile();
  }

  Future<void> _handleAddProfileFormURL(String url) async {
    globalState.appController.addProfileFormURL(url);
  }

  Future<void> _toScan() async {
    if (system.isDesktop) {
      globalState.appController.addProfileFormQrCode();
      return;
    }
    final url = await BaseNavigator.push(
      context,
      const ScanPage(),
    );
    if (url != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleAddProfileFormURL(url);
      });
    }
  }

  Future<void> _toAdd() async {
    final url = await globalState.showCommonDialog<String>(
      child: const URLFormDialog(),
    );
    if (url != null) {
      _handleAddProfileFormURL(url);
    }
  }

  Future<void> _handleReceiveFromPhone() async {
    final url = await showDialog<String>(
      context: context,
      builder: (_) => const ReceiveProfileDialog(),
    );
    if (url != null && url.isNotEmpty) {
      _handleAddProfileFormURL(url);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
        future: system.isAndroidTV,
        builder: (context, snapshot) {
          final isTV = snapshot.data ?? false;
          final actions = <Widget>[
            if (isTV)
              _AddProfileAction(
                icon: Icons.tv_outlined,
                title: appLocalizations.addFromPhoneTitle,
                subtitle: appLocalizations.addFromPhoneSubtitle,
                onTap: _handleReceiveFromPhone,
              ),
            _AddProfileAction(
              icon: Icons.qr_code_rounded,
              title: appLocalizations.qrcode,
              subtitle: appLocalizations.qrcodeDesc,
              onTap: _toScan,
            ),
            _AddProfileAction(
              icon: Icons.upload_file_rounded,
              title: appLocalizations.file,
              subtitle: appLocalizations.fileDesc,
              onTap: _handleAddProfileFormFile,
            ),
            _AddProfileAction(
              icon: Icons.cloud_download_rounded,
              title: appLocalizations.url,
              subtitle: appLocalizations.urlDesc,
              onTap: _toAdd,
            ),
          ];
          return Column(
            children: [
              for (var index = 0; index < actions.length; index++) ...[
                actions[index],
                if (index != actions.length - 1)
                  Divider(
                    height: 1,
                    indent: 52,
                    endIndent: 12,
                    color: context.colorScheme.outlineVariant
                        .withValues(alpha: 0.24),
                  ),
              ],
            ],
          );
        },
      );
}

class _AddProfileAction extends StatelessWidget {
  const _AddProfileAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          hoverColor: context.colorScheme.onSurface.withValues(alpha: 0.05),
          highlightColor: context.colorScheme.onSurface.withValues(alpha: 0.07),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Icon(
                    icon,
                    size: 20,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: context.textTheme.bodyMedium),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      );
}

class URLFormDialog extends StatefulWidget {
  const URLFormDialog({super.key});

  @override
  State<URLFormDialog> createState() => _URLFormDialogState();
}

class _URLFormDialogState extends State<URLFormDialog> {
  final urlController = TextEditingController();

  String _sanitizeUrl(String value) => value.replaceAll(RegExp(r'\s+'), '');

  void _handleSubmit() {
    final url = _sanitizeUrl(urlController.text);
    if (url.isNotEmpty) {
      Navigator.of(context).pop<String>(url);
    }
  }

  Future<void> _handlePaste() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData?.text != null) {
      urlController.text = _sanitizeUrl(clipboardData!.text!);
      urlController.selection = TextSelection.collapsed(
        offset: urlController.text.length,
      );
    }
  }

  @override
  Widget build(BuildContext context) => CommonDialog(
        title: appLocalizations.importFromURL,
        actions: [
          TextButton(
            onPressed: _handlePaste,
            child: Text(appLocalizations.pasteFromClipboard),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _handleSubmit,
            child: Text(appLocalizations.submit),
          ),
        ],
        child: Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: TextField(
            controller: urlController,
            keyboardType: TextInputType.url,
            autofocus: true,
            minLines: 1,
            maxLines: 5,
            onSubmitted: (_) => _handleSubmit(),
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: appLocalizations.url,
            ),
          ),
        ),
      );
}
