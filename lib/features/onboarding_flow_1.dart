import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/motion.dart';
import '../core/phone.dart';
import '../data/app_store.dart';
import 'components.dart';
import 'onboarding_widgets.dart';
import '../core/tokens.dart';

const _indianStates = [
  'Andhra Pradesh',
  'Arunachal Pradesh',
  'Assam',
  'Bihar',
  'Chhattisgarh',
  'Goa',
  'Gujarat',
  'Haryana',
  'Himachal Pradesh',
  'Jharkhand',
  'Karnataka',
  'Kerala',
  'Madhya Pradesh',
  'Maharashtra',
  'Manipur',
  'Meghalaya',
  'Mizoram',
  'Nagaland',
  'Odisha',
  'Punjab',
  'Rajasthan',
  'Sikkim',
  'Tamil Nadu',
  'Telangana',
  'Tripura',
  'Uttar Pradesh',
  'Uttarakhand',
  'West Bengal',
  'Andaman and Nicobar Islands',
  'Chandigarh',
  'Dadra and Nagar Haveli and Daman and Diu',
  'Delhi',
  'Jammu and Kashmir',
  'Ladakh',
  'Lakshadweep',
  'Puducherry',
];

/// Step 1 of 15: full name.
class FlowFullNamePage extends StatefulWidget {
  final AppStore store;
  const FlowFullNamePage({super.key, required this.store});
  @override
  State<FlowFullNamePage> createState() => _FlowFullNamePageState();
}

class _FlowFullNamePageState extends State<FlowFullNamePage> {
  late final controller = TextEditingController(
    text: widget.store.profile['fullName'] as String? ?? '',
  );

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    return OnboardingStepScaffold(
      store: s,
      onBack: () => Navigator.of(context).pop(),
      headline: s.t('What is your full name?', 'आपका पूरा नाम क्या है?'),
      subtitle: s.t(
        'Use the full name you want us to use in your guide.',
        'वह पूरा नाम दें जो आप अपनी गाइड में चाहते हैं।',
      ),
      continueLabel: s.t('Continue', 'जारी रखें'),
      onContinue: controller.text.trim().isEmpty
          ? null
          : () {
              s.setProfile('fullName', controller.text.trim());
              Navigator.of(context).pushNamed(
                normalizeWhatsapp(
                          s.profile['whatsappNumber'] as String? ?? '',
                        ) !=
                        null
                    ? '/flow-location'
                    : '/flow-phone',
              );
            },
      children: [
        OnboardingTextField(
          label: s.t('Full name', 'पूरा नाम'),
          controller: controller,
          hint: s.t('e.g. Vijay Kumar', 'उदा. विजय कुमार'),
          onChanged: (_) => setState(() {}),
        ),
        OnboardingTextArt(
          name: 'name_card',
          pixelSize: const Size(585, 245),
          textBox: const Rect.fromLTRB(0.359, 0.261, 0.752, 0.645),
          angle: -0.11,
          text: controller.text,
          placeholder: s.t('Vijay Kumar', 'विजय कुमार'),
          style: const TextStyle(
            fontFamily: 'Snell Roundhand',
            fontFamilyFallback: ['cursive'],
            fontSize: 38,
            color: AppColors.ink,
          ),
        ),
      ],
    );
  }
}

/// Step 2 of 15: mobile number.
class FlowPhonePage extends StatefulWidget {
  final AppStore store;
  const FlowPhonePage({super.key, required this.store});
  @override
  State<FlowPhonePage> createState() => _FlowPhonePageState();
}

class _FlowPhonePageState extends State<FlowPhonePage> {
  late final controller = TextEditingController(
    text: widget.store.profile['mobile'] as String? ?? '',
  );

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  bool get _valid => normalizeWhatsapp(controller.text) != null;

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    return OnboardingStepScaffold(
      store: s,
      onBack: () => Navigator.of(context).pop(),
      headline: s.t('Your mobile number', 'आपका मोबाइल नंबर'),
      subtitle: s.t(
        'Save your contact number. WhatsApp verification is not connected yet.',
        'अपना संपर्क नंबर सहेजें। WhatsApp सत्यापन अभी जुड़ा नहीं है।',
      ),
      continueLabel: s.t('Continue', 'जारी रखें'),
      onContinue: _valid
          ? () {
              s.setProfile(
                'mobile',
                normalizeWhatsapp(controller.text)!.substring(3),
              );
              Navigator.of(context).pushNamed('/flow-location');
            }
          : null,
      children: [
        OnboardingTextField(
          label: s.t('Mobile number', 'मोबाइल नंबर'),
          controller: controller,
          prefixText: '+91  ',
          hint: '12345 67890',
          keyboardType: TextInputType.phone,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        Text(
          s.t(
            'Your email verifies your app account. Saving this number does not verify WhatsApp ownership.',
            'आपका ईमेल ऐप खाते को सत्यापित करता है। नंबर सहेजने से WhatsApp स्वामित्व सत्यापित नहीं होता।',
          ),
          style: AppText.secondary(AppText.bodySmall),
        ),
        const OnboardingArt('phone_shop', topGap: 28),
      ],
    );
  }
}

/// Step 3 of 15: demo OTP entry.
class FlowOtpPage extends StatefulWidget {
  final AppStore store;
  const FlowOtpPage({super.key, required this.store});
  @override
  State<FlowOtpPage> createState() => _FlowOtpPageState();
}

class _FlowOtpPageState extends State<FlowOtpPage>
    with SingleTickerProviderStateMixin {
  final _codeController = TextEditingController();
  final _focusNode = FocusNode();
  late final AnimationController _autoContinueTimer;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _autoContinueTimer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _codeController.dispose();
    _focusNode.dispose();
    _autoContinueTimer.dispose();
    super.dispose();
  }

  void _fillDemoCode() {
    _codeController.text = '123456';
    _onChanged('123456');
  }

  bool get _complete => _codeController.text.length == 6;

  void _proceed() {
    if (_navigated) return;
    _navigated = true;
    Navigator.of(context).pushNamed('/flow-location');
  }

  void _onChanged(String value) {
    setState(() {});
    if (value.length == 6) {
      unawaited(_autoContinueAfterPause());
    }
  }

  Future<void> _autoContinueAfterPause() async {
    if (Motion.reduced(context)) {
      _autoContinueTimer.value = 1;
    } else {
      await _autoContinueTimer.forward(from: 0);
    }
    if (!mounted) return;
    _proceed();
  }

  Widget _otpBox(int i) {
    final text = _codeController.text;
    final char = i < text.length ? text[i] : '';
    final active = _focusNode.hasFocus && text.length == i;
    return AnimatedContainer(
      duration: Motion.of(context, Motion.fast),
      curve: Motion.standard,
      width: 46,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: AppRadius.input,
        border: Border.all(
          color: active ? AppColors.ink : AppColors.borderStrong,
          width: active ? 1.4 : 1,
        ),
      ),
      child: AnimatedSwitcher(
        duration: Motion.of(context, Motion.fast),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.8, end: 1).animate(animation),
            child: child,
          ),
        ),
        child: Text(char, key: ValueKey(char), style: AppText.digit),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    return OnboardingStepScaffold(
      store: s,
      onBack: () => Navigator.of(context).pop(),
      headline: s.t('Enter your code', 'अपना कोड डालें'),
      subtitle: s.t(
        'For this prototype, use 123456. No real code was sent.',
        'इस प्रोटोटाइप के लिए 123456 इस्तेमाल करें। कोई असली कोड नहीं भेजा गया।',
      ),
      continueLabel: s.t('Continue', 'जारी रखें'),
      onContinue: _complete ? _proceed : null,
      children: [
        Text(
          s.t('Demo verification code', 'डेमो सत्यापन कोड'),
          style: AppText.secondary(AppText.bodySmall),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 56,
          child: Stack(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [for (var i = 0; i < 6; i++) _otpBox(i)],
              ),
              // A fully unpainted (Opacity 0) input laid over the boxes:
              // it still takes taps, focus, paste and autofill, but can
              // never draw over them — the app theme fills and outlines
              // every TextField, which otherwise hid all but the boxes'
              // bottom edges.
              Positioned.fill(
                child: Opacity(
                  opacity: 0,
                  alwaysIncludeSemantics: true,
                  child: TextField(
                    controller: _codeController,
                    focusNode: _focusNode,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    showCursor: false,
                    enableInteractiveSelection: false,
                    decoration: const InputDecoration(
                      counterText: '',
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: _onChanged,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: AppButton(
            label: s.t('Use demo code', 'डेमो कोड इस्तेमाल करें'),
            onPressed: _fillDemoCode,
            variant: AppButtonVariant.tertiary,
            expand: false,
            haptic: false,
          ),
        ),
        const OnboardingArt('otp_shop', topGap: 12),
      ],
    );
  }
}

/// Step 4 of 15: business location (state + district).
class FlowLocationPage extends StatefulWidget {
  final AppStore store;
  const FlowLocationPage({super.key, required this.store});
  @override
  State<FlowLocationPage> createState() => _FlowLocationPageState();
}

class _FlowLocationPageState extends State<FlowLocationPage> {
  late String state = widget.store.profile['state'] as String? ?? '';
  late final districtController = TextEditingController(
    text: widget.store.profile['district'] as String? ?? '',
  );

  @override
  void dispose() {
    districtController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    return OnboardingStepScaffold(
      store: s,
      onBack: () => Navigator.of(context).pop(),
      headline: s.t(
        'Where is your business based?',
        'आपका व्यवसाय कहाँ स्थित है?',
      ),
      subtitle: s.t(
        'Choose a state, then a district.',
        'एक राज्य चुनें, फिर जिला।',
      ),
      continueLabel: s.t('Continue', 'जारी रखें'),
      onContinue: state.isEmpty || districtController.text.trim().isEmpty
          ? null
          : () async {
              s.setProfile('state', state);
              s.setProfile('district', districtController.text.trim());
              // Last step of "Getting started" — a small checkpoint
              // before moving into the next section.
              await showSectionComplete(
                context,
                s.t('Getting started complete', 'शुरुआत पूर्ण'),
              );
              if (!context.mounted) return;
              Navigator.of(context).pushNamed('/flow-bizname');
            },
      children: [
        const OnboardingArt('location_map', topGap: 0),
        const SizedBox(height: 20),
        OnboardingPickerField(
          icon: Icons.location_on_outlined,
          value: state,
          hint: s.t('Choose state', 'राज्य चुनें'),
          options: _indianStates,
          s: s,
          onSelected: (v) => setState(() => state = v),
        ),
        const SizedBox(height: 14),
        OnboardingTextField(
          label: s.t('District', 'जिला'),
          controller: districtController,
          hint: s.t('e.g. Pune', 'उदा. पुणे'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        Text(
          s.t(
            'Explore opportunities across India. Availability depends on each bid.',
            'भारत भर के अवसर देखें। उपलब्धता हर बोली पर निर्भर करती है।',
          ),
          textAlign: TextAlign.center,
          style: AppText.caption,
        ),
      ],
    );
  }
}
