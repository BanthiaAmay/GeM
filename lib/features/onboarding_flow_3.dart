import 'package:flutter/material.dart';
import '../core/transitions.dart';
import '../data/app_store.dart';
import 'onboarding_widgets.dart';
import '../core/tokens.dart';

/// Step 9 of 15: is the authorised person ready.
class FlowAuthorisedPage extends StatefulWidget {
  final AppStore store;
  const FlowAuthorisedPage({super.key, required this.store});
  @override
  State<FlowAuthorisedPage> createState() => _FlowAuthorisedPageState();
}

class _FlowAuthorisedPageState extends State<FlowAuthorisedPage> {
  late String selected =
      widget.store.profile['authorisedReady'] as String? ?? '';

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    return OnboardingStepScaffold(
      store: s,
      onBack: () => Navigator.of(context).pop(),
      headline: s.t(
        'Is the authorised person ready?',
        'क्या अधिकृत व्यक्ति तैयार है?',
      ),
      subtitle: s.t(
        'GeM may ask that person to verify identity with Aadhaar or personal PAN details. Don’t enter those details here.',
        'GeM उस व्यक्ति से आधार या PAN से पहचान सत्यापित करने को कह सकता है। यहाँ वे विवरण न दें।',
      ),
      continueLabel: s.t('Continue', 'जारी रखें'),
      onContinue: selected.isEmpty
          ? null
          : () async {
              s.setProfile('authorisedReady', selected);
              // Last step of "Your business" — a small checkpoint
              // before moving into the next section.
              await showSectionComplete(
                context,
                s.t('Your business complete', 'आपका व्यवसाय पूर्ण'),
              );
              if (!context.mounted) return;
              Navigator.of(context).pushNamed('/flow-turnover');
            },
      children: [
        const OnboardingArt('authorised', topGap: 0),
        const SizedBox(height: 20),
        OnboardingRadioOption(
          iconAsset: 'auth_yes',
          label: s.t('Yes', 'हाँ'),
          selected: selected == 'yes',
          onTap: () => setState(() => selected = 'yes'),
        ),
        OnboardingRadioOption(
          iconAsset: 'auth_notyet',
          label: s.t('Not yet', 'अभी नहीं'),
          selected: selected == 'not_yet',
          onTap: () => setState(() => selected = 'not_yet'),
        ),
        OnboardingRadioOption(
          iconAsset: 'auth_unsure',
          label: s.t('I’m not sure', 'मुझे यकीन नहीं'),
          selected: selected == 'unsure',
          onTap: () => setState(() => selected = 'unsure'),
        ),
      ],
    );
  }
}

/// Step 10 of 15: privacy notice + consent checkbox.
class FlowPrivacyPage extends StatefulWidget {
  final AppStore store;
  const FlowPrivacyPage({super.key, required this.store});
  @override
  State<FlowPrivacyPage> createState() => _FlowPrivacyPageState();
}

class _FlowPrivacyPageState extends State<FlowPrivacyPage> {
  bool understood = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    return OnboardingStepScaffold(
      store: s,
      onBack: () => Navigator.of(context).pop(),
      headline: s.t(
        'Your information stays yours',
        'आपकी जानकारी आपकी ही रहती है',
      ),
      subtitle: s.t(
        'We’ll use your answers to tailor a readiness guide.',
        'हम आपके उत्तरों से एक तैयारी गाइड बनाएँगे।',
      ),
      continueLabel: s.t('Continue', 'जारी रखें'),
      onContinue: understood
          ? () => Navigator.of(context).pushNamed('/flow-records')
          : null,
      children: [
        const OnboardingArt('privacy', topGap: 0),
        const SizedBox(height: 24),
        Text(
          s.t(
            'No PAN, Aadhaar, ITR files, or GeM passwords are collected here.',
            'यहाँ PAN, आधार, ITR फाइलें या GeM पासवर्ड नहीं लिए जाते।',
          ),
          style: AppText.secondary(AppText.body),
        ),
        const SizedBox(height: 16),
        Text(
          s.t(
            'This prototype keeps your answers only while this page is open. No real OTP is sent.',
            'यह प्रोटोटाइप आपके उत्तर केवल इस पेज के खुले रहने तक रखता है। कोई असली OTP नहीं भेजा जाता।',
          ),
          style: AppText.secondary(AppText.body),
        ),
        const SizedBox(height: 16),
        Text(
          s.t(
            'You’ll enter registration details yourself on the official GeM portal.',
            'आप पंजीकरण विवरण स्वयं आधिकारिक GeM पोर्टल पर देंगे।',
          ),
          style: AppText.secondary(AppText.body),
        ),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: () => setState(() => understood = !understood),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                understood ? Icons.check_box : Icons.check_box_outline_blank,
                color: AppColors.ink,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  s.t(
                    'I understand this is a preparation guide.',
                    'मैं समझता/समझती हूँ कि यह एक तैयारी गाइड है।',
                  ),
                  style: AppText.body,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Step 11 of 15: business records readiness (multi-select).
class FlowRecordsPage extends StatefulWidget {
  final AppStore store;
  const FlowRecordsPage({super.key, required this.store});
  @override
  State<FlowRecordsPage> createState() => _FlowRecordsPageState();
}

class _FlowRecordsPageState extends State<FlowRecordsPage> {
  late Set<String> selected = {
    ...List<String>.from(widget.store.profile['records'] as List? ?? []),
  };

  void toggle(String key) => setState(
    () => selected.contains(key) ? selected.remove(key) : selected.add(key),
  );

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    return OnboardingStepScaffold(
      store: s,
      onBack: () => Navigator.of(context).pop(),
      headline: s.t(
        'Which business records do you have ready?',
        'आपके पास कौन से व्यवसाय दस्तावेज़ तैयार हैं?',
      ),
      subtitle: s.t(
        'Select all that apply. Requirements can vary by business type and activity.\n\nWe’ll only save your readiness answer—not document numbers or files.',
        'जो लागू हो चुनें। आवश्यकताएँ व्यवसाय के प्रकार और काम पर निर्भर हो सकती हैं।\n\nहम केवल आपकी तैयारी का उत्तर सहेजेंगे—दस्तावेज़ संख्या या फाइलें नहीं।',
      ),
      continueLabel: s.t('Continue', 'जारी रखें'),
      onContinue: () {
        s.setProfile('records', selected.toList());
        if (s.alreadyOnGem) {
          // Already on GeM: these 11 steps are all we ask for — no
          // PAN check, readiness checklist, video, or redirect.
          s.completeOnboarding();
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/home',
            (route) => false,
            arguments: fadeOnlyTransition,
          );
          return;
        }
        Navigator.of(context).pushNamed('/flow-pan');
      },
      children: [
        const OnboardingArt('records', topGap: 0),
        const SizedBox(height: 16),
        OnboardingCheckOption(
          iconAsset: 'rec_pan',
          label: s.t('Business PAN details', 'व्यवसाय PAN विवरण'),
          checked: selected.contains('pan'),
          onTap: () => toggle('pan'),
        ),
        OnboardingCheckOption(
          iconAsset: 'rec_gstin',
          label: s.t('GSTIN', 'GSTIN'),
          checked: selected.contains('gstin'),
          onTap: () => toggle('gstin'),
        ),
        OnboardingCheckOption(
          iconAsset: 'rec_udyam',
          label: s.t(
            'Udyam Registration Certificate',
            'उद्यम पंजीकरण प्रमाणपत्र',
          ),
          sublabel: s.t('MSME registration', 'MSME पंजीकरण'),
          checked: selected.contains('udyam'),
          onTap: () => toggle('udyam'),
        ),
        OnboardingCheckOption(
          iconAsset: 'rec_registration',
          label: s.t('Business registration details', 'व्यवसाय पंजीकरण विवरण'),
          sublabel: s.t(
            'CIN, LLPIN, deed or equivalent',
            'CIN, LLPIN, डीड या समान',
          ),
          checked: selected.contains('registration'),
          onTap: () => toggle('registration'),
        ),
        OnboardingCheckOption(
          iconAsset: 'rec_itr',
          label: s.t('ITR details', 'ITR विवरण'),
          sublabel: s.t('If applicable', 'यदि लागू हो'),
          checked: selected.contains('itr'),
          onTap: () => toggle('itr'),
        ),
        OnboardingCheckOption(
          iconAsset: 'rec_bank',
          label: s.t('Bank account details', 'बैंक खाता विवरण'),
          sublabel: s.t(
            'For profile and payments',
            'प्रोफ़ाइल और भुगतान के लिए',
          ),
          checked: selected.contains('bank'),
          onTap: () => toggle('bank'),
        ),
        OnboardingCheckOption(
          iconAsset: 'rec_none',
          label: s.t('None yet', 'अभी कुछ नहीं'),
          checked: selected.contains('none'),
          onTap: () => toggle('none'),
        ),
        const SizedBox(height: 4),
        Text(
          s.t(
            'You’ll enter any required details yourself on the official GeM portal.',
            'आप आवश्यक विवरण स्वयं आधिकारिक GeM पोर्टल पर देंगे।',
          ),
          style: AppText.caption,
        ),
      ],
    );
  }
}

/// Step 12 of 15: PAN readiness.
class FlowPanPage extends StatefulWidget {
  final AppStore store;
  const FlowPanPage({super.key, required this.store});
  @override
  State<FlowPanPage> createState() => _FlowPanPageState();
}

class _FlowPanPageState extends State<FlowPanPage> {
  late String selected = widget.store.profile['panReady'] as String? ?? '';

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    return OnboardingStepScaffold(
      store: s,
      onBack: () => Navigator.of(context).pop(),
      headline: s.t(
        'Do you have business PAN details?',
        'क्या आपके पास व्यवसाय PAN विवरण है?',
      ),
      subtitle: s.t(
        'We only need a readiness answer—not the PAN number.',
        'हमें केवल तैयारी का उत्तर चाहिए—PAN नंबर नहीं।',
      ),
      continueLabel: s.t('Continue', 'जारी रखें'),
      onContinue: selected.isEmpty
          ? null
          : () {
              s.setProfile('panReady', selected);
              Navigator.of(context).pushNamed('/flow-checklist');
            },
      children: [
        const OnboardingArt('pan', topGap: 0),
        const SizedBox(height: 16),
        OnboardingRadioOption(
          iconAsset: 'pan_yes',
          label: s.t('Yes', 'हाँ'),
          selected: selected == 'yes',
          onTap: () => setState(() => selected = 'yes'),
        ),
        OnboardingRadioOption(
          iconAsset: 'pan_notyet',
          label: s.t('Not yet', 'अभी नहीं'),
          selected: selected == 'not_yet',
          onTap: () => setState(() => selected = 'not_yet'),
        ),
        OnboardingRadioOption(
          iconAsset: 'pan_unsure',
          label: s.t('I’m not sure', 'मुझे यकीन नहीं'),
          selected: selected == 'unsure',
          onTap: () => setState(() => selected = 'unsure'),
        ),
      ],
    );
  }
}
