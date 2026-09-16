import 'package:flutter/material.dart';
import '../data/app_store.dart';
import 'onboarding_widgets.dart';

/// Step 5 of 15: business name.
class FlowBusinessNamePage extends StatefulWidget {
  final AppStore store;
  const FlowBusinessNamePage({super.key, required this.store});
  @override
  State<FlowBusinessNamePage> createState() => _FlowBusinessNamePageState();
}

class _FlowBusinessNamePageState extends State<FlowBusinessNamePage> {
  late final controller = TextEditingController(
    text: widget.store.profile['businessName'] as String? ?? '',
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
      onBack: () => Navigator.of(context).pop(),
      progress: 3 / 6,
      sectionLabel: s.t('Your business', 'आपका व्यवसाय'),
      stepLabel: s.t('YOUR BUSINESS · 3 OF 6', 'आपका व्यवसाय · 3 में से 6'),
      headline: s.t('What is your business called?', 'आपके व्यवसाय का नाम क्या है?'),
      subtitle: s.t(
        'Use the name you know it by. You can update this later.',
        'जिस नाम से आप इसे जानते हैं वह दें। बाद में बदल सकते हैं।',
      ),
      continueLabel: s.t('Continue', 'जारी रखें'),
      onContinue: controller.text.trim().isEmpty
          ? null
          : () {
              s.setProfile('businessName', controller.text.trim());
              Navigator.of(context).pushNamed('/flow-bizform');
            },
      children: [
        OnboardingTextField(
          label: s.t('Business name', 'व्यवसाय का नाम'),
          controller: controller,
          hint: s.t('e.g. Asha Textiles', 'उदा. आशा टेक्सटाइल्स'),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }
}

/// Step 6 of 15: business form.
class FlowBusinessFormPage extends StatefulWidget {
  final AppStore store;
  const FlowBusinessFormPage({super.key, required this.store});
  @override
  State<FlowBusinessFormPage> createState() => _FlowBusinessFormPageState();
}

class _FlowBusinessFormPageState extends State<FlowBusinessFormPage> {
  late String selected = widget.store.profile['businessForm'] as String? ?? '';
  late final otherController = TextEditingController(
    text: widget.store.profile['businessFormOther'] as String? ?? '',
  );

  @override
  void dispose() {
    otherController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    return OnboardingStepScaffold(
      onBack: () => Navigator.of(context).pop(),
      progress: 4 / 6,
      sectionLabel: s.t('Your business', 'आपका व्यवसाय'),
      stepLabel: s.t('YOUR BUSINESS · 4 OF 6', 'आपका व्यवसाय · 4 में से 6'),
      headline: s.t('How is your business formed?', 'आपका व्यवसाय किस रूप में है?'),
      subtitle: s.t(
        'Choose the closest fit. GeM will confirm the official classification.',
        'सबसे उपयुक्त विकल्प चुनें। आधिकारिक वर्गीकरण GeM पुष्टि करेगा।',
      ),
      continueLabel: s.t('Continue', 'जारी रखें'),
      onContinue: selected.isEmpty
          ? null
          : () {
              s.setProfile('businessForm', selected);
              if (selected == 'other') {
                s.setProfile('businessFormOther', otherController.text.trim());
              }
              Navigator.of(context).pushNamed('/flow-sector');
            },
      children: [
        OnboardingRadioOption(
          icon: Icons.storefront_outlined,
          label: s.t('Proprietorship', 'एकल स्वामित्व'),
          selected: selected == 'proprietorship',
          onTap: () => setState(() => selected = 'proprietorship'),
        ),
        OnboardingRadioOption(
          icon: Icons.groups_outlined,
          label: s.t('Partnership or LLP', 'साझेदारी या LLP'),
          selected: selected == 'partnership',
          onTap: () => setState(() => selected = 'partnership'),
        ),
        OnboardingRadioOption(
          icon: Icons.apartment_outlined,
          label: s.t('Company', 'कंपनी'),
          selected: selected == 'company',
          onTap: () => setState(() => selected = 'company'),
        ),
        OnboardingRadioOption(
          icon: Icons.edit_note_outlined,
          label: s.t('Others', 'अन्य'),
          selected: selected == 'other',
          onTap: () => setState(() => selected = 'other'),
          trailingField: OnboardingTextField(
            label: s.t('Specify your business form', 'अपना व्यवसाय रूप बताएँ'),
            controller: otherController,
          ),
        ),
      ],
    );
  }
}

/// Step 7 of 15: sector.
class FlowSectorPage extends StatefulWidget {
  final AppStore store;
  const FlowSectorPage({super.key, required this.store});
  @override
  State<FlowSectorPage> createState() => _FlowSectorPageState();
}

class _FlowSectorPageState extends State<FlowSectorPage> {
  late String selected = widget.store.profile['sector'] as String? ?? '';
  late final otherController = TextEditingController(
    text: widget.store.profile['sectorOther'] as String? ?? '',
  );

  @override
  void dispose() {
    otherController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    return OnboardingStepScaffold(
      onBack: () => Navigator.of(context).pop(),
      progress: 5 / 6,
      sectionLabel: s.t('Your business', 'आपका व्यवसाय'),
      stepLabel: s.t('YOUR BUSINESS · 5 OF 6', 'आपका व्यवसाय · 5 में से 6'),
      headline: s.t(
        'Which sector best fits your business?',
        'आपके व्यवसाय के लिए कौन सा क्षेत्र सबसे उपयुक्त है?',
      ),
      subtitle: s.t(
        'Choose the main sector where most of your work belongs.',
        'वह मुख्य क्षेत्र चुनें जिसमें आपका अधिकांश काम आता है।',
      ),
      continueLabel: s.t('Continue', 'जारी रखें'),
      onContinue: selected.isEmpty
          ? null
          : () {
              s.setProfile('sector', selected);
              if (selected == 'other') {
                s.setProfile('sectorOther', otherController.text.trim());
              }
              Navigator.of(context).pushNamed('/flow-role');
            },
      children: [
        OnboardingRadioOption(
          icon: Icons.precision_manufacturing_outlined,
          label: s.t('Manufacturing', 'निर्माण'),
          selected: selected == 'manufacturing',
          onTap: () => setState(() => selected = 'manufacturing'),
        ),
        OnboardingRadioOption(
          icon: Icons.storefront_outlined,
          label: s.t('Trading & Distribution', 'व्यापार और वितरण'),
          selected: selected == 'trading',
          onTap: () => setState(() => selected = 'trading'),
        ),
        OnboardingRadioOption(
          icon: Icons.business_center_outlined,
          label: s.t(
            'Professional & Business Services',
            'व्यावसायिक और व्यवसाय सेवाएँ',
          ),
          selected: selected == 'services',
          onTap: () => setState(() => selected = 'services'),
        ),
        OnboardingRadioOption(
          icon: Icons.eco_outlined,
          label: s.t(
            'Agriculture & Food Processing',
            'कृषि और खाद्य प्रसंस्करण',
          ),
          selected: selected == 'agriculture',
          onTap: () => setState(() => selected = 'agriculture'),
        ),
        OnboardingRadioOption(
          icon: Icons.engineering_outlined,
          label: s.t(
            'Construction & Infrastructure',
            'निर्माण कार्य और अवसंरचना',
          ),
          selected: selected == 'construction',
          onTap: () => setState(() => selected = 'construction'),
        ),
        OnboardingRadioOption(
          icon: Icons.sell_outlined,
          label: s.t('Others', 'अन्य'),
          selected: selected == 'other',
          onTap: () => setState(() => selected = 'other'),
          trailingField: OnboardingTextField(
            label: s.t('Describe your sector', 'अपना क्षेत्र बताएँ'),
            controller: otherController,
          ),
        ),
      ],
    );
  }
}

/// Step 8 of 15: role in the business.
class FlowRolePage extends StatefulWidget {
  final AppStore store;
  const FlowRolePage({super.key, required this.store});
  @override
  State<FlowRolePage> createState() => _FlowRolePageState();
}

class _FlowRolePageState extends State<FlowRolePage> {
  late String selected = widget.store.profile['role'] as String? ?? '';
  late final otherController = TextEditingController(
    text: widget.store.profile['roleOther'] as String? ?? '',
  );

  @override
  void dispose() {
    otherController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    return OnboardingStepScaffold(
      onBack: () => Navigator.of(context).pop(),
      progress: 6 / 6,
      sectionLabel: s.t('Your business', 'आपका व्यवसाय'),
      stepLabel: s.t('YOUR BUSINESS · 6 OF 6', 'आपका व्यवसाय · 6 में से 6'),
      headline: s.t(
        'What is your role in the business?',
        'व्यवसाय में आपकी भूमिका क्या है?',
      ),
      subtitle: s.t(
        'Choose the role that best describes you.',
        'वह भूमिका चुनें जो आपको सबसे अच्छी तरह बताती है।',
      ),
      continueLabel: s.t('Continue', 'जारी रखें'),
      onContinue: selected.isEmpty
          ? null
          : () {
              s.setProfile('role', selected);
              if (selected == 'other') {
                s.setProfile('roleOther', otherController.text.trim());
              }
              Navigator.of(context).pushNamed('/flow-authorised');
            },
      children: [
        OnboardingRadioOption(
          icon: Icons.storefront_outlined,
          label: s.t('Owner / Proprietor', 'मालिक / स्वामी'),
          selected: selected == 'owner',
          onTap: () => setState(() => selected = 'owner'),
        ),
        OnboardingRadioOption(
          icon: Icons.groups_outlined,
          label: s.t('Partner / LLP partner', 'भागीदार / LLP भागीदार'),
          selected: selected == 'partner',
          onTap: () => setState(() => selected = 'partner'),
        ),
        OnboardingRadioOption(
          icon: Icons.badge_outlined,
          label: s.t('Company Director', 'कंपनी निदेशक'),
          selected: selected == 'director',
          onTap: () => setState(() => selected = 'director'),
        ),
        OnboardingRadioOption(
          icon: Icons.person_outline,
          label: s.t('Employee / Team member', 'कर्मचारी / टीम सदस्य'),
          selected: selected == 'employee',
          onTap: () => setState(() => selected = 'employee'),
        ),
        OnboardingRadioOption(
          icon: Icons.support_agent_outlined,
          label: s.t('Advisor / Consultant', 'सलाहकार / परामर्शदाता'),
          selected: selected == 'advisor',
          onTap: () => setState(() => selected = 'advisor'),
        ),
        OnboardingRadioOption(
          icon: Icons.edit_note_outlined,
          label: s.t('Others', 'अन्य'),
          selected: selected == 'other',
          onTap: () => setState(() => selected = 'other'),
          trailingField: OnboardingTextField(
            label: s.t('Describe your role', 'अपनी भूमिका बताएँ'),
            controller: otherController,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          s.t(
            'If you’re assisting someone else, the authorised person must complete GeM registration.',
            'यदि आप किसी और की मदद कर रहे हैं, तो अधिकृत व्यक्ति को ही GeM पंजीकरण पूरा करना होगा।',
          ),
          style: const TextStyle(fontSize: 13, color: Color(0xFF9A9A9A)),
        ),
      ],
    );
  }
}
