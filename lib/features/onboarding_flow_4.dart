import 'package:flutter/material.dart';
import '../core/models.dart';
import '../data/app_store.dart';
import 'onboarding_widgets.dart';
import 'widgets.dart';

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
    final icons = {
      'register': Icons.person_outline,
      'email': Icons.email_outlined,
      'phone': Icons.phone_iphone_outlined,
      'authorised': Icons.badge_outlined,
      'pan': Icons.folder_outlined,
      'bizType': Icons.storefront_outlined,
      'sellType': Icons.inventory_2_outlined,
      'category': Icons.grid_view_outlined,
      'bank': Icons.account_balance_outlined,
    };
    return OnboardingStepScaffold(
      store: s,
      onBack: () => Navigator.of(context).pop(),
      progress: 0.85,
      sectionLabel: s.t('Next step', 'अगला कदम'),
      stepLabel: s.t('YOUR TAILORED GUIDE', 'आपकी तैयार गाइड'),
      headline: s.t('Your GeM-ready checklist', 'आपकी GeM-तैयार चेकलिस्ट'),
      subtitle: s.t(
        'Tick off each item yourself as you get it ready.',
        'जैसे-जैसे तैयार होते जाएँ, हर आइटम खुद टिक करें।',
      ),
      continueLabel: s.t('Continue', 'जारी रखें'),
      onContinue: () => Navigator.of(context).pushNamed('/flow-video'),
      children: [
        for (final key in _keys)
          OnboardingCheckOption(
            icon: icons[key]!,
            label: labels[key]!,
            checked: checked.contains(key),
            onTap: () => toggle(key),
          ),
        Text(
          '${checked.length} ${s.t('of', 'में से')} ${_keys.length} ${s.t('checked', 'टिक किए')}',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          s.t(
            'This is preparation, not an eligibility decision.',
            'यह तैयारी है, पात्रता का निर्णय नहीं।',
          ),
          style: const TextStyle(fontSize: 13, color: Color(0xFF9A9A9A)),
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
      progress: 0.9,
      sectionLabel: s.t('Next step', 'अगला कदम'),
      stepLabel: s.t('REGISTRATION GUIDE', 'पंजीकरण गाइड'),
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
        Container(
          padding: const EdgeInsets.symmetric(vertical: 32),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFDDDDDD)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.fromBorderSide(
                    BorderSide(color: Colors.black),
                  ),
                ),
                child: const Icon(
                  Icons.play_arrow,
                  size: 28,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                s.t('VIDEO GUIDE', 'वीडियो गाइड'),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: Color(0xFF9A9A9A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                s.t('Video coming soon', 'वीडियो शीघ्र आ रहा है'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                s.t(
                  'We’re preparing a clear, step-by-step walkthrough.',
                  'हम एक स्पष्ट, चरण-दर-चरण गाइड तैयार कर रहे हैं।',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Color(0xFF9A9A9A)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Text(
          s.t('What the guide will cover', 'गाइड में क्या शामिल होगा'),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 16),
        _CoverRow(
          icon: Icons.storefront_outlined,
          text: s.t(
            'Choose the right seller type',
            'सही विक्रेता प्रकार चुनें',
          ),
        ),
        _CoverRow(
          icon: Icons.folder_outlined,
          text: s.t(
            'Keep your business details ready',
            'अपने व्यवसाय का विवरण तैयार रखें',
          ),
        ),
        _CoverRow(
          icon: Icons.upload_outlined,
          text: s.t(
            'Complete registration on the official GeM portal',
            'आधिकारिक GeM पोर्टल पर पंजीकरण पूरा करें',
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => openLink(context, s, gemSource),
          child: Text(
            s.t('View registration overview', 'पंजीकरण अवलोकन देखें'),
            style: const TextStyle(
              fontSize: 15,
              color: Colors.black,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }
}

class _CoverRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _CoverRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      children: [
        Icon(icon, size: 22, color: Colors.black),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 16, color: Colors.black),
          ),
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
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final s = store;
    return OnboardingStepScaffold(
      store: s,
      onBack: () => Navigator.of(context).pop(),
      progress: 1,
      sectionLabel: s.t('Next step', 'अगला कदम'),
      stepLabel: s.t('OFFICIAL REGISTRATION', 'आधिकारिक पंजीकरण'),
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
        Text(
          s.t('Your next step', 'आपका अगला कदम'),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 16),
        _CoverRow(
          icon: Icons.open_in_new,
          text: s.t(
            'Open the official GeM registration page',
            'आधिकारिक GeM पंजीकरण पेज खोलें',
          ),
        ),
        _CoverRow(
          icon: Icons.folder_outlined,
          text: s.t(
            'Enter identity and business details only there',
            'पहचान और व्यवसाय विवरण केवल वहीं दें',
          ),
        ),
        _CoverRow(
          icon: Icons.replay_outlined,
          text: s.t(
            'Return to GeM BizReady whenever you need video guidance.',
            'जब भी वीडियो मार्गदर्शन चाहिए, GeM BizReady पर लौटें।',
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFDDDDDD)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Text(
                s.t('OFFICIAL DESTINATION', 'आधिकारिक गंतव्य'),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: Color(0xFF9A9A9A),
                ),
              ),
              const SizedBox(height: 10),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock, size: 18, color: Colors.black),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'mkp.gem.gov.in',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
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
                style: const TextStyle(fontSize: 13, color: Color(0xFF9A9A9A)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: () => _finish(context),
            child: Text(
              s.t('Not now', 'अभी नहीं'),
              style: const TextStyle(
                fontSize: 15,
                color: Colors.black,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

const gemRegistrationUrl =
    'https://mkp.gem.gov.in/registration/signup#!/seller';
