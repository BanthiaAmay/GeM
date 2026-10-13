import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme.dart';
import '../data/app_store.dart';
import 'brand_logo.dart';
import 'components.dart';

class AccountPage extends StatefulWidget {
  final AppStore store;
  const AccountPage({super.key, required this.store});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final email = TextEditingController();
  final code = TextEditingController();
  final form = GlobalKey<FormState>();
  bool codeSent = false;
  bool busy = false;
  String? error;
  String? notice;

  AppStore get s => widget.store;

  @override
  void dispose() {
    email.dispose();
    code.dispose();
    super.dispose();
  }

  String friendlyError(Object value) {
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
    }
  }

  Future<void> sendCode() async {
    if (!form.currentState!.validate()) return;
    await run(() async {
      await s.sendOtp(email.text);
      if (mounted) {
        setState(() {
          codeSent = true;
          notice = s.t(
            'A six-digit code was sent to ${email.text.trim()}.',
            '${email.text.trim()} पर छह अंकों का कोड भेजा गया है।',
          );
        });
      }
    });
  }

  Future<void> verifyCode() async {
    if (code.text.trim().length != 6) {
      setState(() {
        error = s.t(
          'Enter the six-digit code from your email.',
          'ईमेल से मिला छह अंकों का कोड डालें।',
        );
      });
      return;
    }
    await run(() async {
      await s.verifyOtp(email.text, code.text);
      if (mounted) {
        setState(() {
          notice = s.t(
            'Signed in. Your saved work is now connected to this account.',
            'साइन इन हो गया। आपका सहेजा काम अब इस खाते से जुड़ा है।',
          );
        });
      }
    });
  }

  Future<void> google() async {
    await run(() async {
      final opened = await s.signInWithGoogle();
      if (mounted && opened) {
        setState(() {
          notice = s.t(
            'Finish signing in with Google, then return to GeM BizReady.',
            'Google से साइन इन पूरा करके GeM BizReady पर लौटें।',
          );
        });
      }
    });
  }

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
                style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
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
        title: const BrandLogo(variant: BrandLogoVariant.lockup, width: 130),
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => Navigator.maybePop(context),
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
      if (error != null || notice != null)
        const SizedBox(height: AppSpace.xl),
    ],
  );

  Widget signedOutView() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      heading(
        s.t('Save your progress', 'अपनी प्रगति सहेजें'),
        s.t(
          'Sign in to restore your tools and readiness plan on another device. You can keep using the app without an account.',
          'दूसरे डिवाइस पर अपने टूल और तैयारी योजना पाने के लिए साइन इन करें। आप बिना खाते के भी ऐप इस्तेमाल कर सकते हैं।',
        ),
      ),
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
        AppButton(
          label: s.t('Continue with Google', 'Google से जारी रखें'),
          onPressed: busy ? null : google,
          icon: Icons.account_circle_outlined,
          variant: AppButtonVariant.secondary,
          loading: busy && !codeSent,
        ),
        const SizedBox(height: AppSpace.xl),
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
              child: Text(s.t('or use email', 'या ईमेल इस्तेमाल करें'), style: AppText.caption),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: AppSpace.xl),
        Form(
          key: form,
          child: TextFormField(
            controller: email,
            enabled: !busy && !codeSent,
            keyboardType: TextInputType.emailAddress,
            textInputAction: codeSent ? TextInputAction.next : TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            decoration: InputDecoration(
              labelText: s.t('Email address', 'ईमेल पता'),
              hintText: 'name@business.com',
            ),
            validator: (value) {
              final v = value?.trim() ?? '';
              if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) {
                return s.t('Enter a valid email address', 'सही ईमेल पता डालें');
              }
              return null;
            },
            onFieldSubmitted: (_) {
              if (!codeSent) sendCode();
            },
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
              LengthLimitingTextInputFormatter(6),
            ],
            decoration: InputDecoration(
              labelText: s.t('Six-digit code', 'छह अंकों का कोड'),
              hintText: '123456',
            ),
            onSubmitted: (_) => verifyCode(),
          ),
          const SizedBox(height: AppSpace.lg),
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
            onPressed: busy ? null : sendCode,
            loading: busy,
          ),
        ],
        const SizedBox(height: AppSpace.xxl),
        Text(
          s.t(
            'Google or email identifies your private account. GeM BizReady never receives your Google password. Research tracking remains off unless you separately opt in.',
            'Google या ईमेल आपके निजी खाते की पहचान करता है। GeM BizReady को आपका Google पासवर्ड नहीं मिलता। शोध ट्रैकिंग आपकी अलग सहमति के बिना बंद रहती है।',
          ),
          style: AppText.caption,
        ),
      ],
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
                      Text(emailAddress, style: AppText.secondary(AppText.bodySmall)),
                  ],
                ),
              ),
              StatusChip(
                s.status == 'offline'
                    ? s.t('Saved locally', 'स्थानीय रूप से सहेजा')
                    : s.t('Private sync', 'निजी सिंक'),
                tone: s.status == 'offline' ? StatusTone.warning : StatusTone.success,
                icon: s.status == 'offline' ? Icons.cloud_off_outlined : Icons.cloud_done_outlined,
              ),
            ],
          ),
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
                      'This permanently deletes this account and its GeM BizReady data. This cannot be undone.',
                      'यह खाता और इसका GeM BizReady डेटा स्थायी रूप से मिट जाएगा। इसे वापस नहीं किया जा सकता।',
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
