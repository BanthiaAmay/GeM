import 'dart:async';
import 'package:flutter/material.dart';
import '../core/gem_categories.dart';
import '../data/app_store.dart';
import 'onboarding_widgets.dart';
import '../core/tokens.dart';

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
      store: s,
      onBack: () => Navigator.of(context).pop(),
      headline: s.t(
        'What is your business called?',
        'आपके व्यवसाय का नाम क्या है?',
      ),
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
      factIndex: 1,
      children: [
        OnboardingTextField(
          label: s.t('Business name', 'व्यवसाय का नाम'),
          controller: controller,
          hint: s.t('e.g. Asha Textiles', 'उदा. आशा टेक्सटाइल्स'),
          onChanged: (_) => setState(() {}),
        ),
        OnboardingTextArt(
          name: 'bizname_box',
          pixelSize: const Size(742, 335),
          textBox: const Rect.fromLTRB(0.317, 0.579, 0.527, 0.690),
          angle: -0.05,
          text: controller.text,
          placeholder: s.t('Asha Textiles', 'आशा टेक्सटाइल्स'),
          style: AppText.bodySmall,
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
      store: s,
      onBack: () => Navigator.of(context).pop(),
      headline: s.t(
        'How is your business formed?',
        'आपका व्यवसाय किस रूप में है?',
      ),
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
      factIndex: 2,
      children: [
        OnboardingRadioOption(
          iconAsset: 'form_proprietorship',
          iconSlot: 76,
          label: s.t('Proprietorship', 'एकल स्वामित्व'),
          selected: selected == 'proprietorship',
          onTap: () => setState(() => selected = 'proprietorship'),
        ),
        OnboardingRadioOption(
          iconAsset: 'form_partnership',
          iconSlot: 76,
          label: s.t('Partnership or LLP', 'साझेदारी या LLP'),
          selected: selected == 'partnership',
          onTap: () => setState(() => selected = 'partnership'),
        ),
        OnboardingRadioOption(
          iconAsset: 'form_company',
          iconSlot: 76,
          label: s.t('Company', 'कंपनी'),
          selected: selected == 'company',
          onTap: () => setState(() => selected = 'company'),
        ),
        OnboardingRadioOption(
          iconAsset: 'form_others',
          iconSlot: 76,
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
      store: s,
      onBack: () => Navigator.of(context).pop(),
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
              Navigator.of(context).pushNamed('/flow-products');
            },
      factIndex: 3,
      children: [
        OnboardingRadioOption(
          iconAsset: 'sector_manufacturing',
          label: s.t('Manufacturing', 'निर्माण'),
          selected: selected == 'manufacturing',
          onTap: () => setState(() => selected = 'manufacturing'),
        ),
        OnboardingRadioOption(
          iconAsset: 'sector_trading',
          label: s.t('Trading & Distribution', 'व्यापार और वितरण'),
          selected: selected == 'trading',
          onTap: () => setState(() => selected = 'trading'),
        ),
        OnboardingRadioOption(
          iconAsset: 'sector_services',
          label: s.t(
            'Professional & Business Services',
            'व्यावसायिक और व्यवसाय सेवाएँ',
          ),
          selected: selected == 'services',
          onTap: () => setState(() => selected = 'services'),
        ),
        OnboardingRadioOption(
          iconAsset: 'sector_agri',
          label: s.t(
            'Agriculture & Food Processing',
            'कृषि और खाद्य प्रसंस्करण',
          ),
          selected: selected == 'agriculture',
          onTap: () => setState(() => selected = 'agriculture'),
        ),
        OnboardingRadioOption(
          iconAsset: 'sector_construction',
          label: s.t(
            'Construction & Infrastructure',
            'निर्माण कार्य और अवसंरचना',
          ),
          selected: selected == 'construction',
          onTap: () => setState(() => selected = 'construction'),
        ),
        OnboardingRadioOption(
          iconAsset: 'sector_others',
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

/// Step 7 of 15: what the business supplies — 2-level GeM category picker.
class FlowProductsPage extends StatefulWidget {
  final AppStore store;
  const FlowProductsPage({super.key, required this.store});
  @override
  State<FlowProductsPage> createState() => _FlowProductsPageState();
}

class _FlowProductsPageState extends State<FlowProductsPage> {
  // Data
  GemCategoryData? _data;
  bool _loading = true;

  // Level tracking: 1 = pick industry, 2 = pick category
  int _level = 1;

  // Level 1
  final _industryController = TextEditingController();
  String _industryQuery = '';
  String? _selectedIndustry; // null means nothing chosen yet
  bool _industryOtherMode = false;
  final _industryOtherController = TextEditingController();

  // Level 2
  final _categoryController = TextEditingController();
  String _categoryQuery = '';
  GemCategory? _selectedCategory;
  bool _categoryOtherMode = false;
  final _categoryOtherController = TextEditingController();

  // Notification
  bool _notify = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _industryController.addListener(() =>
        setState(() => _industryQuery = _industryController.text));
    _categoryController.addListener(() =>
        setState(() => _categoryQuery = _categoryController.text));
    GemCategoryData.load().then((d) {
      if (mounted) setState(() { _data = d; _loading = false; });
    });
    // Pre-fill from profile if already answered.
    final s = widget.store;
    final savedIndustry = s.gemIndustry;
    final savedCat = s.gemCategoryName;
    if (savedIndustry != null && savedIndustry.isNotEmpty) {
      _selectedIndustry = savedIndustry;
      _level = 2;
      if (savedIndustry == kOtherIndustry) _industryOtherMode = true;
    }
    if (savedCat != null && savedCat.isNotEmpty) {
      _level = 2;
    }
  }

  @override
  void dispose() {
    _industryController.dispose();
    _industryOtherController.dispose();
    _categoryController.dispose();
    _categoryOtherController.dispose();
    super.dispose();
  }

  bool get _canContinue {
    if (_level == 1) {
      if (_industryOtherMode) return _industryOtherController.text.trim().isNotEmpty;
      return _selectedIndustry != null;
    }
    if (_categoryOtherMode) return _categoryOtherController.text.trim().isNotEmpty;
    return _selectedCategory != null;
  }

  void _selectIndustry(String industry) {
    setState(() {
      _selectedIndustry = industry;
      _industryOtherMode = industry == kOtherIndustry;
      _industryQuery = '';
      _industryController.clear();
      if (!_industryOtherMode) _level = 2;
    });
  }

  void _backToLevel1() {
    setState(() {
      _level = 1;
      _selectedCategory = null;
      _categoryOtherMode = false;
      _categoryController.clear();
      _categoryQuery = '';
    });
  }

  Future<void> _continue() async {
    if (_saving) return;
    if (_level == 1) {
      // "Others" in level 1 — advance to level 2 on continue press
      if (_industryOtherMode && _industryOtherController.text.trim().isNotEmpty) {
        setState(() { _level = 2; });
        return;
      }
      return;
    }

    final s = widget.store;
    final industry = _industryOtherMode
        ? _industryOtherController.text.trim()
        : _selectedIndustry ?? '';
    final catName = _categoryOtherMode
        ? _categoryOtherController.text.trim()
        : _selectedCategory?.name ?? '';
    final catLink = _categoryOtherMode ? '' : (_selectedCategory?.link ?? '');

    setState(() => _saving = true);
    try {
      await s.saveGemCategory(
        industry: industry,
        categoryName: catName,
        categoryLink: catLink,
      );
      // Also save as a keyword for the existing bid-matching pipeline.
      await s.saveBidInterests([catName]);
      if (_notify && s.pushSupported) await s.push!.enable();
    } catch (_) {}
    if (!mounted) return;
    setState(() => _saving = false);
    unawaited(Navigator.of(context).pushNamed('/flow-role'));
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store;

    if (_loading) {
      return OnboardingStepScaffold(
        store: s,
        onBack: () => Navigator.of(context).pop(),
        headline: s.t('What does your business supply?',
            'आपका व्यवसाय क्या सप्लाई करता है?'),
        subtitle: '',
        continueLabel: s.t('Continue', 'जारी रखें'),
        onContinue: null,
        factIndex: 4,
        children: const [
          SizedBox(height: 48),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    final data = _data!;

    if (_level == 1) return _buildLevel1(s, data);
    return _buildLevel2(s, data);
  }

  Widget _buildLevel1(AppStore s, GemCategoryData data) {
    final visibleIndustries = filterItems(
        [...data.industries, kOtherIndustry], _industryQuery);

    return OnboardingStepScaffold(
      store: s,
      onBack: () => Navigator.of(context).pop(),
      headline: s.t(
        'What industry does your business operate in?',
        'आपका व्यवसाय किस उद्योग में है?',
      ),
      subtitle: s.t(
        'Choose your industry. We\'ll show matching GeM categories next.',
        'अपना उद्योग चुनें। हम अगले चरण में मेल खाती GeM श्रेणियाँ दिखाएँगे।',
      ),
      continueLabel: _industryOtherMode
          ? s.t('Continue', 'जारी रखें')
          : s.t('Select an industry', 'उद्योग चुनें'),
      onContinue: _canContinue ? _continue : null,
      factIndex: 4,
      children: [
        // Search bar
        TextField(
          controller: _industryController,
          decoration: InputDecoration(
            hintText: s.t('Search industries…', 'उद्योग खोजें…'),
            prefixIcon: const Icon(Icons.search_rounded,
                color: AppColors.textHint),
            suffixIcon: _industryQuery.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      _industryController.clear();
                    },
                    child: const Icon(Icons.close_rounded,
                        color: AppColors.textHint))
                : null,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md)),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpace.md, vertical: AppSpace.sm),
          ),
          style: AppText.body,
        ),
        const SizedBox(height: AppSpace.md),
        // Industry tiles
        for (final industry in visibleIndustries) ...[
          if (industry == kOtherIndustry) ...[
            const SizedBox(height: AppSpace.sm),
            const Divider(),
            const SizedBox(height: AppSpace.sm),
          ],
          _CategoryTile(
            label: industry == kOtherIndustry
                ? s.t('Others', 'अन्य')
                : industry,
            selected: _selectedIndustry == industry,
            onTap: () => _selectIndustry(industry),
          ),
          if (industry == kOtherIndustry && _industryOtherMode) ...[
            const SizedBox(height: AppSpace.sm),
            TextField(
              controller: _industryOtherController,
              decoration: InputDecoration(
                hintText: s.t('Type your industry…', 'अपना उद्योग लिखें…'),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.md, vertical: AppSpace.sm),
              ),
              style: AppText.body,
              onChanged: (_) => setState(() {}),
            ),
          ],
          const SizedBox(height: AppSpace.sm),
        ],
      ],
    );
  }

  Widget _buildLevel2(AppStore s, GemCategoryData data) {
    final industry = _industryOtherMode
        ? _industryOtherController.text.trim()
        : _selectedIndustry ?? '';
    final pool = (_selectedIndustry == null || _industryOtherMode)
        ? <GemCategory>[]
        : data.categoriesFor(_selectedIndustry!);
    final visible = filterCategories(pool, _categoryQuery);

    return OnboardingStepScaffold(
      store: s,
      onBack: _backToLevel1,
      headline: s.t(
        'Which category best describes what you supply?',
        'आप क्या सप्लाई करते हैं — सही श्रेणी चुनें',
      ),
      subtitle: s.t(
        'Showing categories for: $industry',
        'श्रेणियाँ: $industry',
      ),
      continueLabel: s.t('Continue', 'जारी रखें'),
      onContinue: (_canContinue && !_saving) ? _continue : null,
      factIndex: 4,
      children: [
        // Search bar
        TextField(
          controller: _categoryController,
          decoration: InputDecoration(
            hintText: s.t('Search categories…', 'श्रेणी खोजें…'),
            prefixIcon: const Icon(Icons.search_rounded,
                color: AppColors.textHint),
            suffixIcon: _categoryQuery.isNotEmpty
                ? GestureDetector(
                    onTap: () { _categoryController.clear(); },
                    child: const Icon(Icons.close_rounded,
                        color: AppColors.textHint))
                : null,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md)),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpace.md, vertical: AppSpace.sm),
          ),
          style: AppText.body,
        ),
        const SizedBox(height: AppSpace.md),
        if (visible.isEmpty && _categoryQuery.isEmpty && !_categoryOtherMode)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.lg),
            child: Text(
              s.t(
                'No categories found for this industry. Use "Others" below.',
                'इस उद्योग के लिए कोई श्रेणी नहीं मिली। नीचे "अन्य" चुनें।',
              ),
              style: AppText.bodySmall.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ),
        // Category tiles
        for (final cat in visible) ...[
          _CategoryTile(
            label: cat.name,
            selected: _selectedCategory == cat,
            onTap: () => setState(() {
              _selectedCategory = cat;
              _categoryOtherMode = false;
            }),
          ),
          const SizedBox(height: AppSpace.sm),
        ],
        // Others option
        if (_categoryQuery.isEmpty) ...[
          if (visible.isNotEmpty) ...[
            const Divider(),
            const SizedBox(height: AppSpace.sm),
          ],
          _CategoryTile(
            label: s.t('Others', 'अन्य'),
            selected: _categoryOtherMode,
            onTap: () => setState(() {
              _categoryOtherMode = true;
              _selectedCategory = null;
            }),
          ),
          if (_categoryOtherMode) ...[
            const SizedBox(height: AppSpace.sm),
            TextField(
              controller: _categoryOtherController,
              decoration: InputDecoration(
                hintText: s.t(
                    'Type your category…', 'अपनी श्रेणी लिखें…'),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.md, vertical: AppSpace.sm),
              ),
              style: AppText.body,
              onChanged: (_) => setState(() {}),
            ),
          ],
          const SizedBox(height: AppSpace.sm),
        ],
        // Notification toggle — shown once a category is chosen
        if (_canContinue && s.pushSupported) ...[
          const SizedBox(height: AppSpace.md),
          OnboardingCheckOption(
            icon: Icons.notifications_outlined,
            label: s.t('Notify me on this phone', 'इस फ़ोन पर सूचना दें'),
            sublabel: s.t(
              'When a matching bid is published',
              'मेल खाती बोली प्रकाशित होने पर',
            ),
            checked: _notify,
            onTap: () => setState(() => _notify = !_notify),
          ),
        ],
      ],
    );
  }
}

/// A single tappable row used for both industry and category selection.
class _CategoryTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.md, vertical: AppSpace.sm + 2),
        decoration: BoxDecoration(
          color: selected ? AppColors.brandTint : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected ? AppColors.brand : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: AppText.body.copyWith(
                    color: selected
                        ? AppColors.brand
                        : AppColors.ink,
                    fontWeight: selected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  )),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded,
                  size: 18, color: AppColors.brand),
          ],
        ),
      ),
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
      store: s,
      onBack: () => Navigator.of(context).pop(),
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
      factIndex: 0,
      children: [
        OnboardingRadioOption(
          iconAsset: 'role_owner',
          label: s.t('Owner / Proprietor', 'मालिक / स्वामी'),
          selected: selected == 'owner',
          onTap: () => setState(() => selected = 'owner'),
        ),
        OnboardingRadioOption(
          iconAsset: 'role_partner',
          label: s.t('Partner / LLP partner', 'भागीदार / LLP भागीदार'),
          selected: selected == 'partner',
          onTap: () => setState(() => selected = 'partner'),
        ),
        OnboardingRadioOption(
          iconAsset: 'role_director',
          label: s.t('Company Director', 'कंपनी निदेशक'),
          selected: selected == 'director',
          onTap: () => setState(() => selected = 'director'),
        ),
        OnboardingRadioOption(
          iconAsset: 'role_employee',
          label: s.t('Employee / Team member', 'कर्मचारी / टीम सदस्य'),
          selected: selected == 'employee',
          onTap: () => setState(() => selected = 'employee'),
        ),
        OnboardingRadioOption(
          iconAsset: 'role_advisor',
          label: s.t('Advisor / Consultant', 'सलाहकार / परामर्शदाता'),
          selected: selected == 'advisor',
          onTap: () => setState(() => selected = 'advisor'),
        ),
        OnboardingRadioOption(
          iconAsset: 'role_others',
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
            "If you're assisting someone else, the authorised person must complete GeM registration.",
            'यदि आप किसी और की मदद कर रहे हैं, तो अधिकृत व्यक्ति को ही GeM पंजीकरण पूरा करना होगा।',
          ),
          style: AppText.caption,
        ),
      ],
    );
  }
}
