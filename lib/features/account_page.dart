import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme.dart';
import '../data/app_store.dart';
import 'brand_logo.dart';
import 'components.dart';
import 'contact_fields.dart';
import '../core/phone.dart';

class AccountPage extends StatefulWidget {
  final AppStore store;
  final bool entry;
  final String? continueTo;
  const AccountPage({
    super.key,
    required this.store,
    this.entry = false,
    this.continueTo,
  });

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final email = TextEditingController();
  final code = TextEditingController();
  final phone = TextEditingController();
  final form = GlobalKey<FormState>();
  late bool signUp = widget.entry;
  bool whatsapp = false;
  bool codeSent = false;
  bool navigating = false;
  bool busy = false;
  String? error;
  String? notice;

  AppStore get s => widget.store;

  @override
  void initState() {
    super.initState();
    phone.text = s.alertPreferences['whatsapp_number'] as String? ?? '';
    whatsapp = s.alertPreferences['whatsapp_opt_in'] == true;
    s.addListener(onStoreChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => onStoreChanged());
  }

  void onStoreChanged() {
    if (!mounted) return;
    setState(() {});
    if (s.signedIn && !busy && !navigating && widget.continueTo != null) {
      navigating = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
          Navigator.pushReplacementNamed(context, widget.continueTo!);
        } else {
          navigating = false;
        }
      });
    }
  }

  @override
  void dispose() {
    email.dispose();
    code.dispose();
    phone.dispose();
    s.removeListener(onStoreChanged);
    super.dispose();
  }

  String friendlyError(Object value) {
    if (s.signedIn) {
      return s.t(
        'You are signed in, but your details could not be saved. Check your connection and try again.',
        'साइन इन हो गया, लेकिन विवरण सहेजे नहीं गए। इंटरनेट जाँचकर फिर कोशिश करें।',
      );
    }
    if (value is AuthException) {
      if (value.statusCode == '429') {
        return s.t(
          'Too many attempts. Wait a few minutes and try again.',
          'बहुत अधिक प्रयास हुए। कुछ मिनट रुककर फिर कोशिश करें।',
        );
      }
      if (value.message.toLowerCase().contains('expired')) {
        return s.t(
          'That code has expired. Request a new one.',
          'यह कोड समाप्त हो गया है। नया कोड माँगें।',
        );
      }
      if (value.message.toLowerCase().contains('invalid')) {
        return s.t(
          'The code or sign-in response was not valid. Please try again.',
          'कोड या साइन-इन उत्तर सही नहीं था। फिर कोशिश करें।',
        );
      }
      if (value.message.toLowerCase().contains('signup')) {
        return s.t(
          'This email may need an account. Choose Sign up to continue.',
          'इस ईमेल के लिए खाता बनाना पड़ सकता है। जारी रखने के लिए साइन अप चुनें।',
        );
      }
    }
    return s.t(
      'We could not sign you in. Check your connection and try again.',
      'साइन इन नहीं हो पाया। इंटरनेट जाँचकर फिर कोशिश करें।',
    );
  }

  Future<void> run(Future<void> Function() action) async {
    setState(() {
      busy = true;
      error = null;
      notice = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
      if (mounted) onStoreChanged();
    }
  }

  Future<void> sendCode() async {
    if (!form.currentState!.validate()) return;
    await run(() async {
      await s.sendOtp(email.text, shouldCreateUser: signUp);
      if (mounted) {
        setState(() {
          codeSent = true;
          notice = s.t(
            'Check ${email.text.trim()} for your sign-in code. If it does not arrive, check spam or choose Sign up.',
            '${email.text.trim()} पर साइन-इन कोड देखें। न मिले तो स्पैम जाँचें या साइन अप चुनें।',
          );
        });
      }
    });
  }

  Future<void> verifyCode() async {
    if (!RegExp(r'^\d{6,10}$').hasMatch(code.text.trim())) {
      setState(() {
        error = s.t(
          'Enter the full code from your email (6–10 digits).',
          'ईमेल से मिला पूरा कोड डालें (6–10 अंक)।',
        );
      });
      return;
    }
    await run(() async {
      await s.verifyOtp(email.text, code.text);
      var contactSaved = true;
      if (signUp && normalizeWhatsapp(phone.text) != null) {
        final number = normalizeWhatsapp(phone.text)!;
        s.setProfile('mobile', number.substring(3));
        s.setProfile('whatsappNumber', number);
        s.setProfile('whatsappOptIn', whatsapp);
        try {
          await saveContact();
        } catch (_) {
          // Email authentication is complete even if alert setup is unavailable.
          contactSaved = false;
        }
      }
      if (mounted) {
        setState(() {
          notice = contactSaved
              ? s.t(
                  'Signed in. Your saved work is now connected to this account.',
                  'साइन इन हो गया। आपका सहेजा काम अब इस खाते से जुड़ा है।',
                )
              : s.t(
                  'Signed in. You can finish WhatsApp alert setup in Updates.',
                  'साइन इन हो गया। WhatsApp अलर्ट सेटअप सूचनाओं में पूरा कर सकते हैं।',
                );
        });
      }
    });
  }

  Future<void> saveContact() => s.saveAlertPreferences(
    phone: phone.text,
    whatsapp: whatsapp,
    inApp: s.alertPreferences['in_app_enabled'] != false,
    keywords: List<String>.from(s.alertPreferences['keywords'] ?? []),
    states: List<String>.from(s.alertPreferences['states'] ?? []),
  );

  Future<bool> confirm(String title, String body, String action) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(body),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(s.t('Cancel', 'रद्द करें')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.danger,
                ),
                child: Text(action),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 56,
        centerTitle: true,
        title: const BrandLogo(variant: BrandLogoVariant.lockup, width: 62),
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => Navigator.of(context).canPop()
              ? Navigator.pop(context)
              : Navigator.pushReplacementNamed(context, '/welcome'),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        child: SelectionArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpace.gutter),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: s.signedIn ? signedInView() : signedOutView(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget heading(String title, String body) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: AppText.h1),
      const SizedBox(height: AppSpace.md),
      Text(body, style: AppText.secondary(AppText.body)),
      const SizedBox(height: AppSpace.xxxl),
    ],
  );

  Widget feedback() => Column(
    children: [
      if (error != null)
        Semantics(
          liveRegion: true,
          child: AppCard(
            tone: AppCardTone.muted,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline, color: AppColors.danger),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: Text(
                    error!,
                    style: AppText.bodySmall.copyWith(color: AppColors.danger),
                  ),
                ),
              ],
            ),
          ),
        ),
      if (notice != null) ...[
        if (error != null) const SizedBox(height: AppSpace.md),
        Semantics(
          liveRegion: true,
          child: AppCard(
            tone: AppCardTone.brand,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle_outline, color: AppColors.brand),
                const SizedBox(width: AppSpace.sm),
                Expanded(child: Text(notice!, style: AppText.bodySmall)),
              ],
            ),
          ),
        ),
      ],
      if (error != null || notice != null) const SizedBox(height: AppSpace.xl),
    ],
  );

  Widget signedOutView() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      heading(
        widget.entry
            ? (signUp
                  ? s.t(
                      'Your next chapter\nstarts on GeM.',
                      'आपकी नई शुरुआत\nGeM पर।',
                    )
                  : s.t('Welcome back.', 'फिर से स्वागत है।'))
            : s.t('Save your progress', 'अपनी प्रगति सहेजें'),
        s.t(
          'Get GeM-ready. Find bids that fit your business.',
          'GeM की तैयारी करें। अपने व्यवसाय के लिए सही बोलियाँ खोजें।',
        ),
      ),
      if (!codeSent) ...[
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<bool>(
            direction: MediaQuery.textScalerOf(context).scale(14) > 22
                ? Axis.vertical
                : Axis.horizontal,
            segments: [
              ButtonSegment(
                value: true,
                label: Text(s.t('Sign up', 'साइन अप')),
              ),
              ButtonSegment(value: false, label: Text(s.t('Log in', 'लॉग इन'))),
            ],
            selected: {signUp},
            showSelectedIcon: false,
            onSelectionChanged: busy
                ? null
                : (value) => setState(() {
                    signUp = value.first;
                    error = null;
                    notice = null;
                  }),
          ),
        ),
        const SizedBox(height: AppSpace.xxl),
      ],
      if (!s.configured)
        StateView(
          kind: StateKind.error,
          title: s.t('Sign-in is not configured', 'साइन-इन कॉन्फ़िगर नहीं है'),
          message: s.t(
            'Build the app with your Supabase URL and publishable key. Local tools remain available.',
            'ऐप को Supabase URL और publishable key के साथ बनाएँ। स्थानीय टूल उपलब्ध रहेंगे।',
          ),
        )
      else ...[
        feedback(),
        if (s.authError != null) Text(s.authError!, style: AppText.body),
        Form(
          key: form,
          child: AutofillGroup(
            child: Column(
              children: [
                TextFormField(
                  controller: email,
                  enabled: !busy && !codeSent,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: signUp
                      ? TextInputAction.next
                      : TextInputAction.done,
                  autofillHints: const [AutofillHints.email],
                  decoration: InputDecoration(
                    labelText: s.t('Email address', 'ईमेल पता'),
                    hintText: 'name@business.com',
                  ),
                  validator: (value) {
                    final v = value?.trim() ?? '';
                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) {
                      return s.t(
                        'Enter a valid email address',
                        'सही ईमेल पता डालें',
                      );
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) {
                    if (!codeSent) sendCode();
                  },
                ),
                if (signUp && !codeSent) ...[
                  const SizedBox(height: AppSpace.lg),
                  ContactFields(
                    store: s,
                    phone: phone,
                    optedIn: whatsapp,
                    enabled: !busy,
                    onOptIn: (v) => setState(() => whatsapp = v),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (codeSent) ...[
          const SizedBox(height: AppSpace.lg),
          TextField(
            controller: code,
            enabled: !busy,
            autofocus: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            decoration: InputDecoration(
              labelText: s.t('Email verification code', 'ईमेल सत्यापन कोड'),
              hintText: '123456',
            ),
            onSubmitted: (_) => verifyCode(),
          ),
          const SizedBox(height: AppSpace.lg),
          AppButton(
            label: s.t('Resend code', 'कोड फिर भेजें'),
            onPressed: busy ? null : sendCode,
            variant: AppButtonVariant.tertiary,
          ),
          AppButton(
            label: s.t('Verify and sign in', 'पुष्टि करके साइन इन करें'),
            onPressed: busy ? null : verifyCode,
            loading: busy,
          ),
          AppButton(
            label: s.t('Use a different email', 'दूसरा ईमेल इस्तेमाल करें'),
            onPressed: busy
                ? null
                : () => setState(() {
                    codeSent = false;
                    code.clear();
                    error = null;
                    notice = null;
                  }),
            variant: AppButtonVariant.tertiary,
          ),
        ] else ...[
          const SizedBox(height: AppSpace.lg),
          AppButton(
            label: s.t('Email me a code', 'मुझे ईमेल कोड भेजें'),
            onPressed: busy || s.emailAvailable == false ? null : sendCode,
            loading: busy,
          ),
        ],
        const SizedBox(height: AppSpace.xxl),
        Text(
          s.t(
            'Sign in with a code sent to your email. Research tracking stays off unless you separately opt in.',
            'ईमेल पर भेजे गए कोड से साइन इन करें। शोध ट्रैकिंग आपकी अलग सहमति के बिना बंद रहती है।',
          ),
          style: AppText.caption,
        ),
      ],
      const SizedBox(height: AppSpace.xxl),
      Text(
        s.t(
          'Your Bid2Scale account is separate from your official GeM seller account.',
          'आपका Bid2Scale खाता आधिकारिक GeM विक्रेता खाते से अलग है।',
        ),
        style: AppText.caption,
      ),
    ],
  );

  Widget signedInView() {
    final user = s.currentUser!;
    final meta = user.userMetadata ?? const <String, dynamic>{};
    final name = '${meta['full_name'] ?? meta['name'] ?? ''}'.trim();
    final emailAddress = user.email ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        heading(
          s.t(
            name.isEmpty ? 'Your account' : 'Hello, $name',
            name.isEmpty ? 'आपका खाता' : 'नमस्ते, $name',
          ),
          s.t(
            'Your progress can sync privately across signed-in devices.',
            'आपकी प्रगति साइन-इन किए गए डिवाइसों पर निजी रूप से सिंक हो सकती है।',
          ),
        ),
        feedback(),
        AppCard(
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: AppColors.brandTint,
                foregroundColor: AppColors.brand,
                child: Icon(Icons.person_outline),
              ),
              const SizedBox(width: AppSpace.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? s.t('Signed in', 'साइन इन') : name,
                      style: AppText.title,
                    ),
                    if (emailAddress.isNotEmpty)
                      Text(
                        emailAddress,
                        style: AppText.secondary(AppText.bodySmall),
                      ),
                  ],
                ),
              ),
              StatusChip(
                s.status == 'offline'
                    ? s.t('Saved locally', 'स्थानीय रूप से सहेजा')
                    : s.t('Private sync', 'निजी सिंक'),
                tone: s.status == 'offline'
                    ? StatusTone.warning
                    : StatusTone.success,
                icon: s.status == 'offline'
                    ? Icons.cloud_off_outlined
                    : Icons.cloud_done_outlined,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.xxl),
        AppButton(
          label: s.t('GeM registration guide', 'GeM पंजीकरण गाइड'),
          icon: Icons.assignment_outlined,
          onPressed: () => Navigator.pushNamed(context, '/gem-guide'),
          variant: AppButtonVariant.secondary,
        ),
        const SizedBox(height: AppSpace.md),
        AppButton(
          label: s.t('Bid alerts & WhatsApp', 'बोली अलर्ट और WhatsApp'),
          icon: Icons.notifications_outlined,
          onPressed: () => Navigator.pushNamed(context, '/alerts'),
          variant: AppButtonVariant.secondary,
        ),
        const SizedBox(height: AppSpace.xxl),
        AppButton(
          label: s.t('Sync now', 'अभी सिंक करें'),
          onPressed: busy ? null : () => run(s.sync),
          icon: Icons.sync,
          loading: busy,
        ),
        const SizedBox(height: AppSpace.md),
        AppButton(
          label: s.t('Sign out', 'साइन आउट करें'),
          onPressed: busy
              ? null
              : () => run(() async {
                  await s.signOut();
                  if (mounted) setState(() => codeSent = false);
                }),
          variant: AppButtonVariant.secondary,
        ),
        const SizedBox(height: AppSpace.huge),
        const Divider(),
        const SizedBox(height: AppSpace.xl),
        SectionHeader(s.t('Privacy controls', 'गोपनीयता नियंत्रण')),
        Text(
          s.t(
            'Deleting app data keeps your sign-in identity. Deleting your account permanently removes the Supabase identity and associated project data.',
            'ऐप डेटा मिटाने पर साइन-इन पहचान रहती है। खाता मिटाने पर Supabase पहचान और उससे जुड़ा परियोजना डेटा स्थायी रूप से मिट जाता है।',
          ),
          style: AppText.secondary(AppText.bodySmall),
        ),
        const SizedBox(height: AppSpace.xl),
        AppButton(
          label: s.t('Delete saved app data', 'सहेजा ऐप डेटा मिटाएँ'),
          onPressed: busy
              ? null
              : () async {
                  final ok = await confirm(
                    s.t('Delete saved app data?', 'सहेजा ऐप डेटा मिटाएँ?'),
                    s.t(
                      'This removes your plans, research events and support requests. Your sign-in account remains.',
                      'इससे आपकी योजनाएँ, शोध इवेंट और सहायता अनुरोध मिटेंगे। साइन-इन खाता रहेगा।',
                    ),
                    s.t('Delete data', 'डेटा मिटाएँ'),
                  );
                  if (ok) await run(s.deleteData);
                },
          variant: AppButtonVariant.secondary,
          danger: true,
        ),
        const SizedBox(height: AppSpace.md),
        AppButton(
          label: s.t('Delete account permanently', 'खाता स्थायी रूप से मिटाएँ'),
          onPressed: busy
              ? null
              : () async {
                  final ok = await confirm(
                    s.t('Delete your account?', 'अपना खाता मिटाएँ?'),
                    s.t(
                      'This permanently deletes this account and its Bid2Scale data. This cannot be undone.',
                      'यह खाता और इसका Bid2Scale डेटा स्थायी रूप से मिट जाएगा। इसे वापस नहीं किया जा सकता।',
                    ),
                    s.t('Delete account', 'खाता मिटाएँ'),
                  );
                  if (ok) await run(s.deleteAccount);
                },
          variant: AppButtonVariant.secondary,
          danger: true,
        ),
      ],
    );
  }
}
