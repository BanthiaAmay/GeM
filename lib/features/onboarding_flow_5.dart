import 'package:flutter/material.dart';
import '../core/tokens.dart';
import '../data/app_store.dart';
import 'components.dart';
import 'onboarding_widgets.dart';

/// The "GeM bidding" section — inserted between "Your business" and
/// "Get ready" (see flow-authorised's onContinue and _kOnboardingSteps
/// in onboarding_widgets.dart). Turnover and past-order-experience help
/// explain criteria a real GeM bid may state; none of it is a GeM
/// registration form, none of it decides eligibility, and none of it
/// asks for proof or documents — every screen here says so.
///
/// Steps 10–12 (or 13, on the "Yes" branch): turnover, turnover history,
/// experience, and — only if the answer to experience is "Yes" — the
/// optional past-order detail screen.

/// Monetary bands shared by every picker in this section: the latest-FY
/// turnover choice, both prior-year pickers, and the optional past-order
/// value range. One list kept in one place so they always read the same
/// way wherever they appear.
const _kTurnoverBands = <(String key, String en, String hi)>[
  ('under10L', 'Under ₹10 lakh', '₹10 लाख से कम'),
  ('10to40L', '₹10 lakh–₹40 lakh', '₹10 लाख–₹40 लाख'),
  ('40Lto1_5Cr', '₹40 lakh–₹1.5 crore', '₹40 लाख–₹1.5 करोड़'),
  ('1_5to5Cr', '₹1.5 crore–₹5 crore', '₹1.5 करोड़–₹5 करोड़'),
  ('5CrPlus', '₹5 crore and above', '₹5 करोड़ और अधिक'),
];

List<String> _bandLabels(AppStore s) => [
  for (final b in _kTurnoverBands) s.t(b.$2, b.$3),
];

String _bandKeyForLabel(AppStore s, String label) => _kTurnoverBands
    .firstWhere((b) => s.t(b.$2, b.$3) == label, orElse: () => _kTurnoverBands.first)
    .$1;

String _labelForBandKey(AppStore s, String? key) {
  final band = _kTurnoverBands.firstWhere(
    (b) => b.$1 == key,
    orElse: () => _kTurnoverBands.first,
  );
  return s.t(band.$2, band.$3);
}

/// Step 10 (of up to 13): latest completed financial year's turnover.
class FlowTurnoverPage extends StatefulWidget {
  final AppStore store;
  const FlowTurnoverPage({super.key, required this.store});
  @override
  State<FlowTurnoverPage> createState() => _FlowTurnoverPageState();
}

class _FlowTurnoverPageState extends State<FlowTurnoverPage> {
  late String selected = widget.store.profile['turnoverLatest'] as String? ?? '';

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    return OnboardingStepScaffold(
      store: s,
      onBack: () => Navigator.of(context).pop(),
      headline: s.t(
        'What’s your business’s annual turnover (latest FY)?',
        'आपके व्यवसाय का नवीनतम वित्त वर्ष का वार्षिक कारोबार क्या है?',
      ),
      subtitle: s.t(
        'This helps explain turnover criteria you may see in GeM bids. Use FY 2025–26; a range is enough.',
        'इससे GeM बोलियों में दिखने वाली कारोबार शर्तें समझने में मदद मिलती है। वित्त वर्ष 2025–26 का उपयोग करें; एक श्रेणी काफी है।',
      ),
      continueLabel: s.t('Continue', 'जारी रखें'),
      onContinue: selected.isEmpty
          ? null
          : () {
              s.setProfile('turnoverLatest', selected);
              Navigator.of(context).pushNamed('/flow-turnover-history');
            },
      children: [
        for (final band in _kTurnoverBands)
          OnboardingRadioOption(
            icon: Icons.bar_chart_outlined,
            label: s.t(band.$2, band.$3),
            selected: selected == band.$1,
            onTap: () => setState(() => selected = band.$1),
          ),
        const SizedBox(height: 4),
        ReassuranceNote(
          s.t(
            'No exact figure or documents needed. This is preparation guidance—not an eligibility decision.',
            'सटीक आँकड़ा या दस्तावेज़ों की ज़रूरत नहीं है। यह तैयारी मार्गदर्शन है—पात्रता का निर्णय नहीं।',
          ),
        ),
      ],
    );
  }
}

/// Step 11: the two financial years before the latest one.
class FlowTurnoverHistoryPage extends StatefulWidget {
  final AppStore store;
  const FlowTurnoverHistoryPage({super.key, required this.store});
  @override
  State<FlowTurnoverHistoryPage> createState() =>
      _FlowTurnoverHistoryPageState();
}

class _FlowTurnoverHistoryPageState extends State<FlowTurnoverHistoryPage> {
  late String fy2425 = widget.store.profile['turnoverFY2024_25'] as String? ?? '';
  late bool same2425 = widget.store.profile['turnoverFY2024_25Same'] as bool? ?? false;
  late String fy2324 = widget.store.profile['turnoverFY2023_24'] as String? ?? '';
  late bool same2324 = widget.store.profile['turnoverFY2023_24Same'] as bool? ?? false;

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    final latestLabel = _labelForBandKey(
      s,
      s.profile['turnoverLatest'] as String?,
    );
    final ready = (same2425 || fy2425.isNotEmpty) && (same2324 || fy2324.isNotEmpty);
    return OnboardingStepScaffold(
      store: s,
      onBack: () => Navigator.of(context).pop(),
      headline: s.t(
        'And the two years before that, roughly?',
        'और उससे पहले के दो साल, लगभग?',
      ),
      subtitle: s.t(
        'Some GeM bids assess turnover across three financial years. Estimates help explain those requirements; choose “Same as latest FY” if unsure.',
        'कुछ GeM बोलियाँ तीन वित्त वर्षों के कारोबार का आकलन करती हैं। अनुमान इन शर्तों को समझने में मदद करते हैं; अनिश्चित हों तो “नवीनतम वित्त वर्ष के समान” चुनें।',
      ),
      continueLabel: s.t('Continue', 'जारी रखें'),
      onContinue: ready
          ? () {
              s.setProfile('turnoverFY2024_25Same', same2425);
              s.setProfile('turnoverFY2024_25', same2425 ? null : fy2425);
              s.setProfile('turnoverFY2023_24Same', same2324);
              s.setProfile('turnoverFY2023_24', same2324 ? null : fy2324);
              Navigator.of(context).pushNamed('/flow-experience');
            }
          : null,
      children: [
        Text('FY 2024–25', style: AppText.secondary(AppText.bodySmall)),
        const SizedBox(height: 8),
        if (same2425)
          _SameAsLatestField(label: latestLabel)
        else
          OnboardingPickerField(
            icon: Icons.calendar_today_outlined,
            value: fy2425.isEmpty ? '' : _labelForBandKey(s, fy2425),
            hint: s.t('Choose a range', 'श्रेणी चुनें'),
            options: _bandLabels(s),
            s: s,
            onSelected: (label) =>
                setState(() => fy2425 = _bandKeyForLabel(s, label)),
          ),
        const SizedBox(height: 10),
        _SameAsLatestToggle(
          store: s,
          checked: same2425,
          onTap: () => setState(() => same2425 = !same2425),
        ),
        const SizedBox(height: 20),
        Text('FY 2023–24', style: AppText.secondary(AppText.bodySmall)),
        const SizedBox(height: 8),
        if (same2324)
          _SameAsLatestField(label: latestLabel)
        else
          OnboardingPickerField(
            icon: Icons.calendar_today_outlined,
            value: fy2324.isEmpty ? '' : _labelForBandKey(s, fy2324),
            hint: s.t('Choose a range', 'श्रेणी चुनें'),
            options: _bandLabels(s),
            s: s,
            onSelected: (label) =>
                setState(() => fy2324 = _bandKeyForLabel(s, label)),
          ),
        const SizedBox(height: 10),
        _SameAsLatestToggle(
          store: s,
          checked: same2324,
          onTap: () => setState(() => same2324 = !same2324),
        ),
        const SizedBox(height: 4),
        ReassuranceNote(
          s.t(
            'Ranges are enough. This is preparation guidance, not an eligibility decision.',
            'श्रेणियाँ पर्याप्त हैं। यह तैयारी मार्गदर्शन है, पात्रता का निर्णय नहीं।',
          ),
        ),
      ],
    );
  }
}

/// A picker field frozen on the latest FY's own value, shown in place of
/// the real picker while "Same as latest FY" is checked.
class _SameAsLatestField extends StatelessWidget {
  final String label;
  const _SameAsLatestField({required this.label});

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: 0.55,
    child: IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.xl,
          vertical: AppSpace.lg,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.borderStrong),
          borderRadius: AppRadius.input,
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined, size: 22),
            const SizedBox(width: AppSpace.md),
            Expanded(child: Text(label, style: AppText.input)),
          ],
        ),
      ),
    ),
  );
}

/// The flat "Same as latest FY" toggle: no card, just a check state and
/// a label, matching the minimal treatment in the reference screens.
class _SameAsLatestToggle extends StatelessWidget {
  final AppStore store;
  final bool checked;
  final VoidCallback onTap;
  const _SameAsLatestToggle({
    required this.store,
    required this.checked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = store;
    return Semantics(
      button: true,
      checked: checked,
      label: s.t('Same as latest FY', 'नवीनतम वित्त वर्ष के समान'),
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSize.tap),
            child: Row(
              children: [
                Icon(
                  checked ? Icons.check_circle : Icons.circle_outlined,
                  size: AppIconSize.md,
                  color: checked ? AppColors.brand : AppColors.textHint,
                ),
                const SizedBox(width: AppSpace.md),
                Text(
                  s.t('Same as latest FY', 'नवीनतम वित्त वर्ष के समान'),
                  style: AppText.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Step 12: similar past-order experience — Yes/No, no wrong answer.
class FlowExperiencePage extends StatefulWidget {
  final AppStore store;
  const FlowExperiencePage({super.key, required this.store});
  @override
  State<FlowExperiencePage> createState() => _FlowExperiencePageState();
}

class _FlowExperiencePageState extends State<FlowExperiencePage> {
  late String selected = widget.store.profile['pastOrderExperience'] as String? ?? '';

  Future<void> _finishSection(BuildContext context) async {
    await showSectionComplete(
      context,
      widget.store.t('GeM bidding complete', 'GeM बोली पूर्ण'),
    );
    if (!context.mounted) return;
    Navigator.of(context).pushNamed('/flow-privacy');
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    return OnboardingStepScaffold(
      store: s,
      onBack: () => Navigator.of(context).pop(),
      headline: s.t(
        'Have you supplied similar orders before?',
        'क्या आपने पहले ऐसे ही ऑर्डर की आपूर्ति की है?',
      ),
      subtitle: s.t(
        'This helps explain typical GeM experience criteria. Answering “No” is completely fine.',
        'इससे सामान्य GeM अनुभव शर्तें समझने में मदद मिलती है। “नहीं” चुनना पूरी तरह ठीक है।',
      ),
      continueLabel: s.t('Continue', 'जारी रखें'),
      onContinue: selected.isEmpty
          ? null
          : () async {
              s.setProfile('pastOrderExperience', selected);
              if (selected == 'yes') {
                Navigator.of(context).pushNamed('/flow-experience-detail');
              } else {
                await _finishSection(context);
              }
            },
      children: [
        OnboardingRadioOption(
          icon: Icons.check_circle_outline,
          label: s.t('Yes', 'हाँ'),
          selected: selected == 'yes',
          onTap: () => setState(() => selected = 'yes'),
        ),
        OnboardingRadioOption(
          icon: Icons.remove_circle_outline,
          label: s.t('No', 'नहीं'),
          selected: selected == 'no',
          onTap: () => setState(() => selected = 'no'),
        ),
        const SizedBox(height: 4),
        ReassuranceNote(
          s.t(
            'This helps explain bidding criteria and prepare for relevant bids. It is not a GeM registration form and does not require proof or documents.',
            'यह बोली शर्तें समझने और उपयुक्त बोलियों की तैयारी में मदद करता है। यह GeM पंजीकरण फ़ॉर्म नहीं है और इसके लिए प्रमाण या दस्तावेज़ आवश्यक नहीं हैं।',
          ),
        ),
      ],
    );
  }
}

/// Step 13 (only on the "Yes" branch): optional order count and value.
/// No Skip control — the primary button itself is always enabled, since
/// both fields are optional.
class FlowExperienceDetailPage extends StatefulWidget {
  final AppStore store;
  const FlowExperienceDetailPage({super.key, required this.store});
  @override
  State<FlowExperienceDetailPage> createState() =>
      _FlowExperienceDetailPageState();
}

class _FlowExperienceDetailPageState extends State<FlowExperienceDetailPage> {
  late final controller = TextEditingController(
    text: widget.store.profile['pastOrderCount'] as String? ?? '',
  );
  late String valueRange = widget.store.profile['pastOrderValueRange'] as String? ?? '';

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
        'Roughly how many, and what total value?',
        'लगभग कितने, और कुल मूल्य क्या था?',
      ),
      subtitle: s.t(
        'Some GeM bids ask about similar past orders. A ballpark helps explain those criteria; both answers are optional.',
        'कुछ GeM बोलियाँ पिछले समान ऑर्डर के बारे में पूछती हैं। अनुमान इन शर्तों को समझने में मदद करता है; दोनों उत्तर वैकल्पिक हैं।',
      ),
      continueLabel: s.t('Save and finish', 'सहेजें और समाप्त करें'),
      // Always enabled: both fields are optional and there is no
      // separate Skip control, so the primary action must double as
      // "continue without answering".
      onContinue: () async {
        final count = controller.text.trim();
        s.setProfile('pastOrderCount', count.isEmpty ? null : count);
        s.setProfile(
          'pastOrderValueRange',
          valueRange.isEmpty ? null : valueRange,
        );
        await showSectionComplete(
          context,
          s.t('GeM bidding complete', 'GeM बोली पूर्ण'),
        );
        if (!context.mounted) return;
        Navigator.of(context).pushNamed('/flow-privacy');
      },
      children: [
        OnboardingTextField(
          label: s.t('Number of orders', 'ऑर्डर की संख्या'),
          controller: controller,
          hint: s.t('For example, 5', 'उदाहरण के लिए, 5'),
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 18),
        Text(
          s.t('Total order value', 'कुल ऑर्डर मूल्य'),
          style: AppText.secondary(AppText.bodySmall),
        ),
        const SizedBox(height: 8),
        OnboardingPickerField(
          icon: Icons.receipt_long_outlined,
          value: valueRange.isEmpty ? '' : _labelForBandKey(s, valueRange),
          hint: s.t('Choose a range', 'श्रेणी चुनें'),
          options: _bandLabels(s),
          s: s,
          onSelected: (label) =>
              setState(() => valueRange = _bandKeyForLabel(s, label)),
        ),
        const SizedBox(height: 4),
        ReassuranceNote(
          s.t(
            'Optional preparation only. No proof or documents are requested here.',
            'केवल वैकल्पिक तैयारी। यहाँ किसी प्रमाण या दस्तावेज़ की आवश्यकता नहीं है।',
          ),
        ),
      ],
    );
  }
}
