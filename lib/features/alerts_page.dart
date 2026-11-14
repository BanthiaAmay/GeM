import 'dart:async';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../data/app_store.dart';
import 'components.dart';
import 'widgets.dart' show openLink;

class AlertsPage extends StatelessWidget {
  final AppStore store;
  const AlertsPage({super.key, required this.store});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(store.t('Bid alerts', 'बोली अलर्ट'))),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpace.gutter),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: AlertsBody(store: store),
          ),
        ),
      ),
    ),
  );
}

class AlertsBody extends StatefulWidget {
  final AppStore store;
  const AlertsBody({super.key, required this.store});
  @override
  State<AlertsBody> createState() => _AlertsBodyState();
}

class _AlertsBodyState extends State<AlertsBody> {
  final form = GlobalKey<FormState>();
  final keywords = TextEditingController();
  final states = TextEditingController();
  bool inApp = true, busy = false, dirty = false;
  bool? _feedbackOk;
  String? feedback;
  AppStore get s => widget.store;

  @override
  void initState() {
    super.initState();
    hydrate();
    unawaited(refresh());
  }

  void hydrate() {
    final p = s.alertPreferences;
    keywords.text = s.bidKeywords.join(', ');
    states.text = List<String>.from(p['states'] ?? []).join(', ');
    inApp = p['in_app_enabled'] != false;
  }

  Future<void> refresh() async {
    await s.loadAlerts();
    if (mounted && !dirty) setState(hydrate);
  }

  List<String> split(String value) => value
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toSet()
      .toList();

  String? filterError(String? value) {
    final entries = split(value ?? '');
    return entries.length > 10 || entries.any((v) => v.length > 80)
        ? s.t(
            'Use up to 10 filters, each under 81 characters.',
            'अधिकतम 10 फ़िल्टर दें, प्रत्येक 81 अक्षरों से छोटा।',
          )
        : null;
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      feedback = null;
      _feedbackOk = null;
    });
    try {
      await s.saveAlertPreferences(
        inApp: inApp,
        keywords: split(keywords.text),
        states: split(states.text),
      );
      if (mounted) {
        setState(() {
          dirty = false;
          _feedbackOk = true;
          feedback = s.t('Preferences saved.', 'पसंद सहेजी गई।');
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _feedbackOk = false;
          feedback = s.t(
            'Could not save. Check your connection and retry.',
            'सहेजा नहीं गया। इंटरनेट जाँचकर फिर कोशिश करें।',
          );
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> setInApp(bool value) async {
    setState(() {
      inApp = value;
      dirty = true;
    });
    if (!value || !s.pushSupported) return;
    final allowed = await s.push!.enable();
    if (!allowed && mounted) {
      setState(() {
        _feedbackOk = false;
        feedback = s.t(
          'Notifications are off for Bid2Scale. Allow them in your phone settings to get alerts on this phone.',
          'Bid2Scale की सूचनाएँ बंद हैं। इस फ़ोन पर अलर्ट पाने के लिए फ़ोन की सेटिंग में अनुमति दें।',
        );
      });
    }
  }

  @override
  void dispose() {
    keywords.dispose();
    states.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: s,
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.t(
            'Find GeM opportunities that match your business.',
            'अपने व्यवसाय से मेल खाते GeM अवसर खोजें।',
          ),
          style: AppText.h2,
        ),
        const SizedBox(height: AppSpace.sm),
        Text(
          s.t(
            'Add your products or services and delivery locations. We\'ll notify you when matching bids become available.',
            'अपने उत्पाद या सेवाएँ और वितरण स्थान डालें। मेल खाती बोलियाँ मिलने पर हम आपको सूचित करेंगे।',
          ),
          style: AppText.body.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpace.xxl),
        if (!s.signedIn) ...[
          Text(
            s.t(
              'Sign in to save your alerts and see your private inbox.',
              'अलर्ट सहेजने और निजी सूचनाएँ देखने के लिए साइन इन करें।',
            ),
            style: AppText.body,
          ),
          const SizedBox(height: AppSpace.lg),
          AppButton(
            label: s.t('Sign in to set alerts', 'अलर्ट के लिए साइन इन करें'),
            onPressed: () => Navigator.pushNamed(context, '/auth'),
          ),
        ] else ...[
          // --- Setup card ---
          AppCard(
            tone: AppCardTone.outlined,
            child: Form(
              key: form,
              onChanged: () => dirty = true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(s.t('Alert settings', 'अलर्ट सेटिंग')),
                  const SizedBox(height: AppSpace.lg),
                  TextFormField(
                    controller: keywords,
                    enabled: !busy,
                    validator: filterError,
                    decoration: InputDecoration(
                      labelText: s.t('Products or services', 'उत्पाद या सेवाएँ'),
                      hintText: s.t(
                        'e.g. stationery, laptops, cleaning',
                        'उदा. stationery, laptops, cleaning',
                      ),
                      helperText: s.t(
                        'Enter keywords separated by commas. We\'ll match bids that contain your keywords.',
                        'अल्पविराम से अलग करें। आपके कीवर्ड वाली बोलियाँ मेल खाएंगी।',
                      ),
                      helperMaxLines: 3,
                    ),
                  ),
                  const SizedBox(height: AppSpace.xl),
                  TextFormField(
                    controller: states,
                    enabled: !busy,
                    validator: filterError,
                    decoration: InputDecoration(
                      labelText: s.t('Delivery states', 'वितरण राज्य'),
                      hintText: 'Maharashtra, Gujarat',
                      helperText: s.t(
                        'Enter delivery states separated by commas. Leave blank to include all of India.',
                        'राज्यों के नाम अल्पविराम से अलग करें। खाली छोड़ने पर पूरा भारत।',
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpace.xl),
                  if (feedback != null)
                    Semantics(
                      liveRegion: true,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: AppSpace.md),
                        child: Text(
                          feedback!,
                          style: AppText.bodySmall.copyWith(
                            color: _feedbackOk == true
                                ? AppColors.accentSuccess
                                : AppColors.accentDanger,
                          ),
                        ),
                      ),
                    ),
                  AppButton(
                    label: s.t('Save preferences', 'पसंद सहेजें'),
                    onPressed: busy ? null : save,
                    loading: busy,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          // --- Notification preferences card ---
          AppCard(
            tone: AppCardTone.outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(
                  s.t('How you\'ll be notified', 'आपको कैसे सूचित किया जाएगा'),
                ),
                const SizedBox(height: AppSpace.lg),
                _NotifTile(
                  icon: Icons.notifications_outlined,
                  title: s.t('App Notifications', 'ऐप सूचनाएँ'),
                  subtitle: s.t(
                    'Alerts on this device when matching GeM bids are found.',
                    'मेल खाती GeM बोलियाँ मिलने पर इस डिवाइस पर अलर्ट।',
                  ),
                  value: inApp,
                  onChanged: busy ? null : setInApp,
                ),
                Divider(
                  color: AppColors.border,
                  height: AppSpace.xl * 2,
                ),
                _NotifTile(
                  icon: Icons.email_outlined,
                  title: s.t('Email Notifications', 'ईमेल सूचनाएँ'),
                  subtitle: s.t(
                    'Matching bid summaries sent to {email}.',
                    'मेल खाती बोलियों का सारांश {email} पर भेजा जाएगा।',
                    vars: {'email': s.currentUser?.email ?? ''},
                  ),
                  value: s.emailAlerts,
                  onChanged: busy
                      ? null
                      : (v) async {
                          try {
                            await s.setEmailAlerts(v);
                          } catch (_) {
                            if (mounted) {
                              setState(() {
                                _feedbackOk = false;
                                feedback = s.t(
                                  'Could not save. Check your connection and retry.',
                                  'सहेजा नहीं गया। इंटरनेट जाँचकर फिर कोशिश करें।',
                                );
                              });
                            }
                          }
                        },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.huge),
          // --- Inbox section ---
          Row(
            children: [
              Expanded(
                child: Text(
                  s.t('Your inbox', 'आपकी सूचनाएँ'),
                  style: AppText.h2,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_outlined),
                tooltip: s.t('Refresh', 'ताज़ा करें'),
                onPressed: busy ? null : refresh,
              ),
            ],
          ),
          const SizedBox(height: AppSpace.lg),
          if (s.alertsError != null)
            _InboxState(
              icon: Icons.error_outline,
              iconColor: AppColors.accentDanger,
              message: s.t(
                'Could not load alerts. Check your connection and retry.',
                'अलर्ट लोड नहीं हुए। इंटरनेट जाँचकर फिर कोशिश करें।',
              ),
              actionLabel: s.t('Retry', 'फिर कोशिश करें'),
              onAction: refresh,
            )
          else if (s.bidNotifications.isEmpty)
            _InboxState(
              icon: Icons.inbox_outlined,
              message: s.t(
                'No bid alerts yet. Add keywords above to start getting matched opportunities.',
                'अभी कोई बोली अलर्ट नहीं। ऊपर कीवर्ड जोड़कर मेल खाते अवसर पाएं।',
              ),
            )
          else
            for (final n in s.bidNotifications)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.md),
                child: _BidCard(
                  notification: n,
                  store: s,
                  onError: (msg) {
                    if (mounted) {
                      setState(() {
                        _feedbackOk = false;
                        feedback = msg;
                      });
                    }
                  },
                ),
              ),
          const SizedBox(height: AppSpace.xxl),
        ],
        AppButton(
          label: s.t('GeM registration guide', 'GeM पंजीकरण गाइड'),
          variant: AppButtonVariant.secondary,
          onPressed: () => Navigator.pushNamed(context, '/gem-guide'),
        ),
        const SizedBox(height: AppSpace.gutter),
      ],
    ),
  );
}

// ── Notification toggle row ───────────────────────────────────────────────────

class _NotifTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _NotifTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Icon(icon, size: AppIconSize.md, color: AppColors.textSecondary),
      const SizedBox(width: AppSpace.md),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppText.bodyStrong),
            const SizedBox(height: AppSpace.xs),
            Text(subtitle, style: AppText.caption),
          ],
        ),
      ),
      const SizedBox(width: AppSpace.sm),
      Switch.adaptive(value: value, onChanged: onChanged),
    ],
  );
}

// ── Inbox empty / error state ─────────────────────────────────────────────────

class _InboxState extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _InboxState({
    required this.icon,
    this.iconColor,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.huge),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: AppIconSize.lg,
            color: iconColor ?? AppColors.textHint,
          ),
          const SizedBox(height: AppSpace.md),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppText.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpace.lg),
            AppButton(
              label: actionLabel!,
              variant: AppButtonVariant.secondary,
              size: AppButtonSize.sm,
              expand: false,
              onPressed: onAction,
            ),
          ],
        ],
      ),
    ),
  );
}

// ── Bid card with expandable body ─────────────────────────────────────────────

class _BidCard extends StatefulWidget {
  final Map<String, dynamic> notification;
  final AppStore store;
  final void Function(String) onError;

  const _BidCard({
    required this.notification,
    required this.store,
    required this.onError,
  });

  @override
  State<_BidCard> createState() => _BidCardState();
}

class _BidCardState extends State<_BidCard> {
  bool _expanded = false;

  Map<String, dynamic> get n => widget.notification;
  AppStore get s => widget.store;
  bool get _unread => n['read_at'] == null;

  @override
  Widget build(BuildContext context) {
    final body = n['body'] as String? ?? '';
    final canExpand = body.length > 120;

    return AppCard(
      tone: AppCardTone.outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: unread badge + date
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (_unread)
                Container(
                  margin: const EdgeInsets.only(right: AppSpace.sm),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accentInfoTint,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    s.t('New', 'नया'),
                    style: AppText.label.copyWith(color: AppColors.accentInfo),
                  ),
                ),
              const Spacer(),
              if (n['created_at'] != null)
                Text(
                  _formatDate(n['created_at'] as String),
                  style: AppText.caption,
                ),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          // Title
          Text(
            n['title'] as String? ?? '',
            style: _unread ? AppText.title : AppText.bodyStrong,
          ),
          if (body.isNotEmpty) ...[
            const SizedBox(height: AppSpace.sm),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              alignment: Alignment.topLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    body,
                    maxLines: _expanded ? null : 3,
                    overflow:
                        _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                    style: AppText.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (canExpand)
                    GestureDetector(
                      onTap: () => setState(() => _expanded = !_expanded),
                      child: Padding(
                        padding: const EdgeInsets.only(top: AppSpace.xs),
                        child: Text(
                          _expanded
                              ? s.t('Show less', 'कम देखें')
                              : s.t('Show more', 'और देखें'),
                          style: AppText.bodySmall.copyWith(
                            color: AppColors.accentInfo,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpace.md),
          // Actions
          Wrap(
            alignment: WrapAlignment.end,
            spacing: AppSpace.sm,
            runSpacing: AppSpace.sm,
            children: [
              if (_unread)
                AppButton(
                  label: s.t('Mark read', 'पढ़ा हुआ बताएँ'),
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.sm,
                  expand: false,
                  onPressed: () async {
                    try {
                      await s.markAlertRead(n['id'] as String);
                    } catch (_) {
                      widget.onError(
                        s.t(
                          'Could not update this alert. Try again.',
                          'अलर्ट अपडेट नहीं हुआ। फिर कोशिश करें।',
                        ),
                      );
                    }
                  },
                ),
              AppButton(
                label: s.t('View on GeM', 'GeM पर देखें'),
                icon: Icons.open_in_new,
                size: AppButtonSize.sm,
                expand: false,
                onPressed: () => openLink(context, s, n['source_url'] as String),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inDays == 0) {
        final h = diff.inHours;
        return h == 0 ? s.t('Just now', 'अभी') : '${h}h ago';
      }
      if (diff.inDays == 1) return s.t('Yesterday', 'कल');
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}';
    } catch (_) {
      return '';
    }
  }
}
