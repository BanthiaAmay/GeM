import 'dart:async';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../data/app_store.dart';
import 'components.dart';
import 'contact_fields.dart';
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
  final phone = TextEditingController();
  final keywords = TextEditingController();
  final states = TextEditingController();
  bool whatsapp = false, inApp = true, busy = false, dirty = false;
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
    phone.text = p['whatsapp_number'] as String? ?? '';
    keywords.text = s.bidKeywords.join(', ');
    states.text = List<String>.from(p['states'] ?? []).join(', ');
    whatsapp = p['whatsapp_opt_in'] == true;
    inApp = p['in_app_enabled'] != false;
  }

  Future<void> refresh() async {
    await s.loadAlerts();
    if (mounted && !dirty) setState(hydrate);
  }

  List<String> split(String value) => value
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
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
    });
    try {
      await s.saveAlertPreferences(
        phone: phone.text,
        whatsapp: whatsapp,
        inApp: inApp,
        keywords: split(keywords.text),
        states: split(states.text),
      );
      if (mounted) {
        setState(() {
          dirty = false;
          feedback = s.t('Preferences saved.', 'पसंद सहेजी गई।');
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => feedback = s.t(
            'Could not save. Check your connection and retry.',
            'सहेजा नहीं गया। इंटरनेट जाँचकर फिर कोशिश करें।',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  /// Turning app notifications on is the moment to ask the phone for
  /// permission; the choice itself is saved with the form.
  Future<void> setInApp(bool value) async {
    setState(() {
      inApp = value;
      dirty = true;
    });
    if (!value || !s.pushSupported) return;
    final allowed = await s.push!.enable();
    if (!allowed && mounted) {
      setState(
        () => feedback = s.t(
          'Notifications are off for Bid2Scale. Allow them in your phone settings to get alerts on this phone.',
          'Bid2Scale की सूचनाएँ बंद हैं। इस फ़ोन पर अलर्ट पाने के लिए फ़ोन की सेटिंग में अनुमति दें।',
        ),
      );
    }
  }

  @override
  void dispose() {
    phone.dispose();
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
          s.t('Opportunities, on your terms.', 'अवसर, आपकी पसंद से।'),
          style: AppText.h1,
        ),
        const SizedBox(height: AppSpace.md),
        Text(
          s.t(
            'Choose what you sell and where you deliver. New matching GeM bids appear here and on your phone.',
            'अपनी पेशकश और वितरण स्थान चुनें। नई मेल खाती GeM बोलियाँ यहाँ और आपके फ़ोन पर दिखेंगी।',
          ),
          style: AppText.body,
        ),
        const SizedBox(height: AppSpace.xl),
        AppCard(
          tone: AppCardTone.muted,
          child: Text(
            s.t(
              'We check GeM for new bids through the day and notify you when one matches what you sell. WhatsApp alerts are coming soon.',
              'हम दिन भर GeM पर नई बोलियाँ देखते हैं और आपकी पेशकश से मेल खाने पर आपको बताते हैं। WhatsApp अलर्ट जल्द आ रहे हैं।',
            ),
            style: AppText.bodySmall,
          ),
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
          Form(
            key: form,
            onChanged: () => dirty = true,
            child: Column(
              children: [
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
                      'Separate keywords with commas. A bid matches when it contains every word of a keyword. Add at least one to get alerts.',
                      'अल्पविराम से अलग करें। किसी शब्द-समूह के सभी शब्द बोली में हों तो वह मेल खाती है। अलर्ट के लिए कम से कम एक जोड़ें।',
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
                      'Full English state names, separated by commas. Blank means all India.',
                      'राज्यों के पूरे अंग्रेज़ी नाम, अल्पविराम से अलग। खाली का अर्थ पूरा भारत।',
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.xl),
                ContactFields(
                  store: s,
                  phone: phone,
                  optedIn: whatsapp,
                  enabled: !busy,
                  onOptIn: (v) => setState(() {
                    whatsapp = v;
                    dirty = true;
                  }),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    s.t(
                      'App notifications for matching bids',
                      'मेल खाती बोलियों की ऐप सूचनाएँ',
                    ),
                    style: AppText.body,
                  ),
                  subtitle: Text(
                    s.t(
                      'In your inbox, and on this phone if you allow notifications.',
                      'आपकी सूचना सूची में, और अनुमति देने पर इस फ़ोन पर भी।',
                    ),
                    style: AppText.caption,
                  ),
                  value: inApp,
                  onChanged: busy ? null : setInApp,
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    s.t('Email me matching bids', 'मेल खाती बोलियाँ ईमेल करें'),
                    style: AppText.body,
                  ),
                  subtitle: Text(
                    s.t(
                      'One summary email at most every 12 hours, to {email}.',
                      'हर 12 घंटे में अधिकतम एक सारांश ईमेल, {email} पर।',
                      vars: {'email': s.currentUser?.email ?? ''},
                    ),
                    style: AppText.caption,
                  ),
                  value: s.emailAlerts,
                  onChanged: busy
                      ? null
                      : (v) async {
                          try {
                            await s.setEmailAlerts(v);
                          } catch (_) {
                            if (mounted) {
                              setState(
                                () => feedback = s.t(
                                  'Could not save. Check your connection and retry.',
                                  'सहेजा नहीं गया। इंटरनेट जाँचकर फिर कोशिश करें।',
                                ),
                              );
                            }
                          }
                        },
                ),
              ],
            ),
          ),
          if (feedback != null)
            Semantics(
              liveRegion: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
                child: Text(feedback!, style: AppText.body),
              ),
            ),
          AppButton(
            label: s.t('Save alert preferences', 'अलर्ट पसंद सहेजें'),
            onPressed: busy ? null : save,
            loading: busy,
          ),
          const SizedBox(height: AppSpace.huge),
          Text(s.t('Your inbox', 'आपकी सूचनाएँ'), style: AppText.h2),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: busy ? null : refresh,
              icon: const Icon(Icons.refresh),
              label: Text(s.t('Refresh', 'ताज़ा करें')),
            ),
          ),
          if (s.alertsError != null)
            Text(
              s.t(
                'Could not load alerts. Check your connection and retry.',
                'अलर्ट लोड नहीं हुए। इंटरनेट जाँचकर फिर कोशिश करें।',
              ),
              style: AppText.body,
            )
          else if (s.bidNotifications.isEmpty)
            Text(
              s.t(
                'No bid alerts yet. Your matching opportunities will appear here.',
                'अभी कोई बोली अलर्ट नहीं है। मेल खाते अवसर यहाँ दिखेंगे।',
              ),
              style: AppText.body,
            ),
          for (final n in s.bidNotifications)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.md),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(n['title'] as String, style: AppText.title),
                    const SizedBox(height: AppSpace.sm),
                    Text(n['body'] as String, style: AppText.bodySmall),
                    if (n['read_at'] == null)
                      TextButton(
                        onPressed: () async {
                          try {
                            await s.markAlertRead(n['id'] as String);
                          } catch (_) {
                            if (mounted) {
                              setState(
                                () => feedback = s.t(
                                  'Could not update this alert. Try again.',
                                  'अलर्ट अपडेट नहीं हुआ। फिर कोशिश करें।',
                                ),
                              );
                            }
                          }
                        },
                        child: Text(s.t('Mark as read', 'पढ़ा हुआ बताएँ')),
                      ),
                    TextButton.icon(
                      onPressed: () =>
                          openLink(context, s, n['source_url'] as String),
                      icon: const Icon(Icons.open_in_new),
                      label: Text(s.t('View on GeM', 'GeM पर देखें')),
                    ),
                  ],
                ),
              ),
            ),
        ],
        const SizedBox(height: AppSpace.xxl),
        AppButton(
          label: s.t('GeM registration guide', 'GeM पंजीकरण गाइड'),
          variant: AppButtonVariant.secondary,
          onPressed: () => Navigator.pushNamed(context, '/gem-guide'),
        ),
      ],
    ),
  );
}
