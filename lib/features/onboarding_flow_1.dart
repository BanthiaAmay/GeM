import 'package:flutter/material.dart';
import '../data/app_store.dart';
import 'onboarding_widgets.dart';

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
      progress: 1 / 6,
      sectionLabel: s.t('Your business', 'आपका व्यवसाय'),
      stepLabel: s.t('YOUR BUSINESS · 1 OF 6', 'आपका व्यवसाय · 1 में से 6'),
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
              Navigator.of(context).pushNamed('/flow-phone');
            },
      children: [
        OnboardingTextField(
          label: s.t('Full name', 'पूरा नाम'),
          controller: controller,
          hint: s.t('e.g. Vijay Kumar', 'उदा. विजय कुमार'),
          onChanged: (_) => setState(() {}),
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

  bool get _valid => controller.text.replaceAll(RegExp(r'\D'), '').length == 10;

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    return OnboardingStepScaffold(
      store: s,
      onBack: () => Navigator.of(context).pop(),
      progress: 1 / 3,
      sectionLabel: s.t('Getting started', 'शुरुआत'),
      stepLabel: s.t('GETTING STARTED · 1 OF 3', 'शुरुआत · 1 में से 3'),
      headline: s.t('Your mobile number', 'आपका मोबाइल नंबर'),
      subtitle: s.t(
        'This is a demonstration sign-in. No SMS will be sent.',
        'यह एक डेमो साइन-इन है। कोई SMS नहीं भेजा जाएगा।',
      ),
      continueLabel: s.t('Send demo code', 'डेमो कोड भेजें'),
      onContinue: _valid
          ? () {
              s.setProfile('mobile', controller.text.trim());
              Navigator.of(context).pushNamed('/flow-otp');
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
            'Use any 10 digits in this prototype. We won’t contact this number.',
            'इस प्रोटोटाइप में कोई भी 10 अंक दें। हम इस नंबर पर संपर्क नहीं करेंगे।',
          ),
          style: const TextStyle(fontSize: 14, color: Color(0xFF9A9A9A)),
        ),
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

class _FlowOtpPageState extends State<FlowOtpPage> {
  final controllers = List.generate(6, (_) => TextEditingController());
  final focusNodes = List.generate(6, (_) => FocusNode());

  @override
  void dispose() {
    for (final c in controllers) {
      c.dispose();
    }
    for (final f in focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _fillDemoCode() {
    const code = '123456';
    for (var i = 0; i < 6; i++) {
      controllers[i].text = code[i];
    }
    setState(() {});
  }

  bool get _complete => controllers.every((c) => c.text.trim().length == 1);

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    return OnboardingStepScaffold(
      store: s,
      onBack: () => Navigator.of(context).pop(),
      progress: 2 / 3,
      sectionLabel: s.t('Getting started', 'शुरुआत'),
      stepLabel: s.t('GETTING STARTED · 2 OF 3', 'शुरुआत · 2 में से 3'),
      headline: s.t('Enter your code', 'अपना कोड डालें'),
      subtitle: s.t(
        'For this prototype, use 123456. No real code was sent.',
        'इस प्रोटोटाइप के लिए 123456 इस्तेमाल करें। कोई असली कोड नहीं भेजा गया।',
      ),
      continueLabel: s.t('Continue', 'जारी रखें'),
      onContinue: _complete
          ? () => Navigator.of(context).pushNamed('/flow-location')
          : null,
      children: [
        Text(
          s.t('Demo verification code', 'डेमो सत्यापन कोड'),
          style: const TextStyle(fontSize: 15, color: Color(0xFF737B84)),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < 6; i++)
              SizedBox(
                width: 46,
                height: 56,
                child: TextField(
                  controller: controllers[i],
                  focusNode: focusNodes[i],
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength: 1,
                  style: const TextStyle(fontSize: 22, color: Colors.black),
                  decoration: InputDecoration(
                    counterText: '',
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Colors.black,
                        width: 1.4,
                      ),
                    ),
                  ),
                  onChanged: (v) {
                    setState(() {});
                    if (v.isNotEmpty && i < 5) {
                      focusNodes[i + 1].requestFocus();
                    }
                  },
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: _fillDemoCode,
            child: Text(
              s.t('Use demo code', 'डेमो कोड इस्तेमाल करें'),
              style: const TextStyle(
                fontSize: 16,
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
      progress: 2 / 6,
      sectionLabel: s.t('Your business', 'आपका व्यवसाय'),
      stepLabel: s.t('YOUR BUSINESS · 2 OF 6', 'आपका व्यवसाय · 2 में से 6'),
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
          : () {
              s.setProfile('state', state);
              s.setProfile('district', districtController.text.trim());
              Navigator.of(context).pushNamed('/flow-bizname');
            },
      children: [
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
          style: const TextStyle(fontSize: 13, color: Color(0xFF9A9A9A)),
        ),
      ],
    );
  }
}
