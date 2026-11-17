import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_language.dart';
import '../services/app_update_service.dart';

class AppUpdateGate extends StatefulWidget {
  const AppUpdateGate({super.key, required this.child, this.service});
  final Widget child;
  final AppUpdateService? service;
  @override
  State<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends State<AppUpdateGate>
    with WidgetsBindingObserver {
  AppUpdateService get service => widget.service ?? AppUpdateService.instance;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => service.check());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) service.check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final notice = service.notice;
        if (notice == null) return widget.child;
        return PopScope(
            canPop: !notice.required,
            child: Stack(children: [
              widget.child,
              if (notice.required)
                const Positioned.fill(
                    child: ModalBarrier(
                        dismissible: false, color: Colors.black54)),
              Positioned.fill(
                  child: SafeArea(
                      child: Align(
                alignment:
                    notice.required ? Alignment.center : Alignment.topCenter,
                child: SingleChildScrollView(
                    child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: AppUpdateCard(
                      notice: notice,
                      onLater: notice.required ? null : service.dismiss,
                      onRetry: () => service.check(force: true)),
                )),
              ))),
            ]));
      });
}

class AppUpdateCard extends StatefulWidget {
  const AppUpdateCard(
      {super.key, required this.notice, this.onLater, this.onRetry});
  final AppUpdateNotice notice;
  final VoidCallback? onLater, onRetry;
  @override
  State<AppUpdateCard> createState() => _AppUpdateCardState();
}

class _AppUpdateCardState extends State<AppUpdateCard> {
  bool failed = false;
  @override
  Widget build(BuildContext context) {
    final notice = widget.notice;
    return ListenableBuilder(
        listenable: AppLanguage.instance,
        builder: (context, _) => Card(
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppText(
                        notice.required
                            ? 'Update required'
                            : notice.strongReminder
                                ? 'Please update this app'
                                : 'Update available',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text('${tr('Latest version')}: ${notice.latest}'),
                    const SizedBox(height: 8),
                    AppText(notice.required
                        ? 'This version is no longer supported. Update the app to continue.'
                        : notice.strongReminder
                            ? 'You are more than two releases behind. Update for the latest fixes and improvements.'
                            : 'A new version of this app is available. You can update now or later.'),
                    if (notice
                            .messages[AppLanguage.instance.code]?.isNotEmpty ==
                        true) ...[
                      const SizedBox(height: 8),
                      Text(notice.messages[AppLanguage.instance.code]!),
                    ],
                    if (failed) ...[
                      const SizedBox(height: 8),
                      const AppText(
                          'Could not open the store. Please try again.')
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          if (widget.onLater != null)
                            TextButton(
                                onPressed: widget.onLater,
                                child: const AppText('Later')),
                          if (notice.required && widget.onRetry != null)
                            TextButton(
                                onPressed: widget.onRetry,
                                child: const AppText('Check again')),
                          FilledButton(
                              onPressed: () async {
                                bool opened = false;
                                try {
                                  opened = await launchUrl(notice.storeUrl,
                                      mode: LaunchMode.externalApplication);
                                } catch (_) {}
                                if (mounted) setState(() => failed = !opened);
                              },
                              child: const AppText('Update now')),
                        ]),
                  ],
                ))));
  }
}
