import 'package:flutter/material.dart';
import '../core/models.dart';
import '../core/transitions.dart';
import '../data/app_store.dart';
import 'components.dart';
import 'onboarding_widgets.dart';
import 'widgets.dart';
import '../core/tokens.dart';

/// Step 13 of 15: readiness checklist — the user ticks each item off
/// themselves rather than having it computed for them. Items the
/// earlier answers already suggest are ready start pre-checked, but
/// every box stays tappable and the final state is what gets saved.
class FlowChecklistPage extends StatefulWidget {
  final AppStore store;
  const FlowChecklistPage({super.key, required this.store});
  @override
  State<FlowChecklistPage> createState() => _FlowChecklistPageState();
}

class _FlowChecklistPageState extends State<FlowChecklistPage> {
  static const _keys = [
    'register',
    'email',
    'phone',
    'authorised',
    'pan',
    'bizType',
    'sellType',
    'category',
    'bank',
  ];

  late Set<String> checked = _initialChecked();

  Set<String> _initialChecked() {
    final saved = widget.store.profile['checklist'] as List?;
    if (saved != null) return saved.cast<String>().toSet();
    // First visit: pre-check what the earlier answers already imply.
    final p = widget.store.profile;
    return {
      'register',
      'email',
      'phone',
      if (p['authorisedReady'] == 'yes') 'authorised',
      if (p['panReady'] == 'yes') 'pan',
      'bizType',
      'sellType',
      'category',
    };
  }

  void toggle(String key) {
    setState(
      () => checked.contains(key) ? checked.remove(key) : checked.add(key),
    );
    widget.store.setProfile('checklist', checked.toList());
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    final labels = {
      'register': s.t(
        'I know who will register the business',
        'मुझे पता है व्यवसाय कौन पंजीकृत करेगा',
      ),
      'email': s.t('I can access my email', 'मैं अपना ईमेल देख सकता/सकती हूँ'),
      'phone': s.t(
        'I can access a phone for GeM identity verification',
        'GeM पहचान सत्यापन के लिए मेरे पास फोन है',
      ),
      'authorised': s.t(
        'I have the authorised person’s identity information',
        'मेरे पास अधिकृत व्यक्ति की पहचान जानकारी है',
      ),
      'pan': s.t(
        'I have my business PAN details',
        'मेरे पास व्यवसाय PAN विवरण है',
      ),
      'bizType': s.t(
        'I know my business type',
        'मुझे अपने व्यवसाय का प्रकार पता है',
      ),
      'sellType': s.t(
        'I know if I’ll sell products, services, or both',
        'मुझे पता है मैं उत्पाद, सेवाएँ या दोनों बेचूँगा/बेचूँगी',
      ),
      'category': s.t(
        'I know my main product or service category',
        'मुझे अपनी मुख्य उत्पाद या सेवा श्रेणी पता है',
      ),
      'bank': s.t(
        'I can provide bank details later',
        'मैं बैंक विवरण बाद में दे सकता/सकती हूँ',
      ),
    };
    const icons = {
      'register': 'cl_register',
      'email': 'cl_email',
      'phone': 'cl_phone',
      'authorised': 'cl_identity',
      'pan': 'cl_pan',
      'bizType': 'cl_type',
      'sellType': 'cl_offering',
      'category': 'cl_category',
      'bank': 'cl_bank',
    };
    return OnboardingStepScaffold(
      store: s,
      onBack: () => Navigator.of(context).pop(),
      headline: s.t('Your GeM-ready checklist', 'आपकी GeM-तैयार चेकलिस्ट'),
      subtitle: s.t(
        'Tick off each item yourself as you get it ready.',
        'जैसे-जैसे तैयार होते जाएँ, हर आइटम खुद टिक करें।',
      ),
      continueLabel: s.t('Continue', 'जारी रखें'),
      onContinue: () async {
        // Last step of "Get ready" — a small checkpoint before
        // moving into "Next step". Not shown for the already-on-GeM
        // early exit (that happens earlier, in FlowRecordsPage, and
        // never reaches this screen).
        await showSectionComplete(
          context,
          s.t('Get ready complete', 'तैयार हो जाएँ पूर्ण'),
        );
        if (!context.mounted) return;
        Navigator.of(context).pushNamed('/flow-video');
      },
      children: [
        const OnboardingArt('checklist', topGap: 0),
        const SizedBox(height: 16),
        for (final key in _keys)
          OnboardingCheckOption(
            iconAsset: icons[key]!,
            label: labels[key]!,
            checked: checked.contains(key),
            onTap: () => toggle(key),
          ),
        Text(
          '${checked.length} ${s.t('of', 'में से')} ${_keys.length} ${s.t('checked', 'टिक किए')}',
          style: AppText.bodyStrong,
        ),
        const SizedBox(height: 8),
        Text(
          s.t(
            'This is preparation, not an eligibility decision.',
            'यह तैयारी है, पात्रता का निर्णय नहीं।',
          ),
          style: AppText.caption,
        ),
      ],
    );
  }
}

/// Step 14 of 15: registration video guide (placeholder).
class FlowVideoPage extends StatelessWidget {
  final AppStore store;
  const FlowVideoPage({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final s = store;
    return OnboardingStepScaffold(
      store: s,
      onBack: () => Navigator.of(context).pop(),
      headline: s.t(
        'How to register your business on GeM',
        'GeM पर अपना व्यवसाय कैसे पंजीकृत करें',
      ),
      subtitle: s.t(
        'This short guide will walk you through seller registration on the official GeM portal.',
        'यह छोटी गाइड आपको आधिकारिक GeM पोर्टल पर विक्रेता पंजीकरण के बारे में बताएगी।',
      ),
      continueLabel: s.t('Continue without video', 'वीडियो के बिना जारी रखें'),
      onContinue: () => Navigator.of(context).pushNamed('/flow-redirect'),
      children: [
        AppCard(
          padding: const EdgeInsets.fromLTRB(12, 24, 12, 28),
          child: Column(
            children: [
              const OnboardingArt('video', topGap: 0),
              const SizedBox(height: 16),
              Text(
                s.t('VIDEO GUIDE', 'वीडियो गाइड'),
                style: AppText.overline,
              ),
              const SizedBox(height: 6),
              Text(
                s.t('Video coming soon', 'वीडियो शीघ्र आ रहा है'),
                style: AppText.title,
              ),
              const SizedBox(height: 6),
              Text(
                s.t(
                  'We’re preparing a clear, step-by-step walkthrough.',
                  'हम एक स्पष्ट, चरण-दर-चरण गाइड तैयार कर रहे हैं।',
                ),
                textAlign: TextAlign.center,
                style: AppText.secondary(AppText.bodySmall),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Text(
          s.t('What the guide will cover', 'गाइड में क्या शामिल होगा'),
          style: AppText.h3,
        ),
        const SizedBox(height: 16),
        _CoverRow(
          asset: 'video_seller',
          text: s.t('Choose the right seller type', 'सही विक्रेता प्रकार चुनें'),
        ),
        _CoverRow(
          asset: 'video_details',
          text: s.t(
            'Keep your business details ready',
            'अपने व्यवसाय का विवरण तैयार रखें',
          ),
        ),
        _CoverRow(
          asset: 'video_portal',
          text: s.t(
            'Complete registration on the official GeM portal',
            'आधिकारिक GeM पोर्टल पर पंजीकरण पूरा करें',
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: AppButton(
            label: s.t('View registration overview', 'पंजीकरण अवलोकन देखें'),
            onPressed: () => openLink(context, s, gemSource),
            variant: AppButtonVariant.tertiary,
            size: AppButtonSize.sm,
            expand: false,
            haptic: false,
          ),
        ),
      ],
    );
  }
}

class _CoverRow extends StatelessWidget {
  final String asset;
  final String text;
  const _CoverRow({required this.asset, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      children: [
        OnboardingIcon(icon: null, asset: asset, slot: 46),
        const SizedBox(width: 14),
        Expanded(
          child: Text(text, style: AppText.body),
        ),
      ],
    ),
  );
}

/// Step 15 of 15: hand-off to the official GeM registration portal.
class FlowRedirectPage extends StatelessWidget {
  final AppStore store;
  const FlowRedirectPage({super.key, required this.store});

  void _finish(BuildContext context) {
    store.completeOnboarding();
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/home',
      (route) => false,
      arguments: fadeOnlyTransition,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = store;
    return OnboardingStepScaffold(
      store: s,
      onBack: () => Navigator.of(context).pop(),
      headline: s.t(
        'You’re ready to register on GeM',
        'आप GeM पर पंजीकरण के लिए तैयार हैं',
      ),
      subtitle: s.t(
        'You’ll now leave GeM BizReady and complete seller registration yourself on the official Government e-Marketplace portal.',
        'अब आप GeM BizReady छोड़कर आधिकारिक सरकारी ई-मार्केटप्लेस पोर्टल पर स्वयं विक्रेता पंजीकरण पूरा करेंगे।',
      ),
      continueLabel: s.t(
        'Open official GeM registration',
        'आधिकारिक GeM पंजीकरण खोलें',
      ),
      onContinue: () async {
        await openLink(context, s, gemRegistrationUrl);
        if (context.mounted) _finish(context);
      },
      children: [
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          child: const OnboardingArt('redirect', topGap: 0),
        ),
        const SizedBox(height: 24),
        Text(
          s.t('Your next step', 'आपका अगला कदम'),
          style: AppText.h3,
        ),
        const SizedBox(height: 16),
        _CoverRow(
          asset: 'redir_open',
          text: s.t(
            'Open the official GeM registration page',
            'आधिकारिक GeM पंजीकरण पेज खोलें',
          ),
        ),
        _CoverRow(
          asset: 'redir_details',
          text: s.t(
            'Enter identity and business details only there',
            'पहचान और व्यवसाय विवरण केवल वहीं दें',
          ),
        ),
        _CoverRow(
          asset: 'redir_return',
          text: s.t(
            'Return to GeM BizReady whenever you need video guidance.',
            'जब भी वीडियो मार्गदर्शन चाहिए, GeM BizReady पर लौटें।',
          ),
        ),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            children: [
              Text(
                s.t('OFFICIAL DESTINATION', 'आधिकारिक गंतव्य'),
                style: AppText.overline,
              ),
              const SizedBox(height: 10),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock, size: 18, color: AppColors.ink),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'mkp.gem.gov.in',
                      overflow: TextOverflow.ellipsis,
                      style: AppText.h3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                s.t(
                  'Opens securely in your browser',
                  'यह आपके ब्राउज़र में सुरक्षित रूप से खुलता है',
                ),
                style: AppText.caption,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: AppButton(
            label: s.t('Not now', 'अभी नहीं'),
            onPressed: () => _finish(context),
            variant: AppButtonVariant.tertiary,
            expand: false,
            haptic: false,
          ),
        ),
      ],
    );
  }
}

const gemRegistrationUrl = 'https://mkp.gem.gov.in/registration/signup#!/seller';
