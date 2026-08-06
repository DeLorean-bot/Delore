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
          return ListView(
            // The sheet's glass title bar is painted over the body, and a
            // bare ListView starts at y=0 beneath it, so the first row —
            // "QR code" — sat with its top clipped behind the bar.
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            children: [
              if (isTV)
                ListItem(
                  leading: const Icon(Icons.tv_outlined),
                  title: Text(appLocalizations.addFromPhoneTitle),
                  subtitle: Text(appLocalizations.addFromPhoneSubtitle),
                  onTap: _handleReceiveFromPhone,
                ),
              ListItem(
                leading: const Icon(Icons.qr_code_rounded),
                title: Text(appLocalizations.qrcode),
                subtitle: Text(appLocalizations.qrcodeDesc),
                onTap: _toScan,
              ),
              ListItem(
                leading: const Icon(Icons.upload_file_rounded),
                title: Text(appLocalizations.file),
                subtitle: Text(appLocalizations.fileDesc),
                onTap: _handleAddProfileFormFile,
              ),
              ListItem(
                leading: const Icon(Icons.cloud_download_rounded),
                title: Text(appLocalizations.url),
                subtitle: Text(appLocalizations.urlDesc),
                onTap: _toAdd,
              ),
            ],
          );
        },
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
