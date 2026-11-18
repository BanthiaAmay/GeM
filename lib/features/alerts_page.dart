import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../data/app_store.dart';
import 'components.dart';

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
  bool inApp = true, busy = false;
  String? feedback;
  AppStore get s => widget.store;

  @override
  void initState() {
    super.initState();
    final p = s.alertPreferences;
    inApp = p['in_app_enabled'] != false;
  }

  /// Saves the switch (the server stops or resumes pushes), and turning it
  /// on is the moment to ask the phone for notification permission.
  Future<void> setInApp(bool value) async {
    final previous = inApp;
    setState(() {
      inApp = value;
      busy = true;
      feedback = null;
    });
    try {
      await s.setInAppAlerts(value);
    } catch (_) {
      if (mounted) {
        setState(() {
          inApp = previous;
          busy = false;
          feedback = s.t(
            'Could not save. Check your connection and retry.',
            'सहेजा नहीं जा सका। कनेक्शन जाँचें और फिर कोशिश करें।',
          );
        });
      }
      return;
    }
    if (!mounted) return;
    setState(() => busy = false);
    if (!value || !s.pushSupported) return;
    final allowed = await s.push!.enable();
    if (!allowed && mounted) {
      setState(
        () => feedback = s.t(
          'Notifications are off for Bid2Scale. Allow them in your phone settings to get alerts on this phone.',
          'Bid2Scale के लिए सूचनाएँ बंद हैं। इस फ़ोन पर अलर्ट पाने के लिए फ़ोन सेटिंग में इन्हें चालू करें।',
        ),
      );
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: s,
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                if (feedback != null) ...[
                  const SizedBox(height: AppSpace.sm),
                  Text(
                    feedback!,
                    style: AppText.bodySmall.copyWith(color: AppColors.danger),
                  ),
                ],
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
                          } catch (_) {}
                        },
                ),
              ],
            ),
          ),
        ],
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
