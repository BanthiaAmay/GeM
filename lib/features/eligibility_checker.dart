import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/models.dart' show Enterprise, classify;
import '../core/tokens.dart';
import '../data/app_store.dart';
import 'components.dart';
import 'eligibility_engine.dart';
import 'tools_hub/tool_page_scaffold.dart';
import 'widgets.dart' show openLink;

class EligibilityChecker extends StatefulWidget {
  final AppStore store;
  final String? bidId;
  const EligibilityChecker({super.key, required this.store, this.bidId});
  @override
  State<EligibilityChecker> createState() => _EligibilityCheckerState();
}

class _EligibilityCheckerState extends State<EligibilityChecker> {
  int _step = 0;
  bool _loading = false;
  String? _error;
  final _bidIdController = TextEditingController();
  final _scrollController = ScrollController();

  Map<String, dynamic> _bid = {};
  Map<String, dynamic> _details = {};
  List<EligibilityCondition> _conditions = [];
  List<ConditionResult> _results = [];

  // User responses collected in step 1.
  String? _turnoverBand;
  double? _oemTurnover;
  double? _experienceYears;
  final Map<String, String> _docStatus = {};
  final Map<String, String> _certStatus = {};
  bool _emdCanArrange = false;
  bool _atcAccepted = false;

  @override
  void initState() {
    super.initState();
    if (widget.bidId != null && widget.bidId!.isNotEmpty) {
      _bidIdController.text = widget.bidId!;
      WidgetsBinding.instance.addPostFrameCallback((_) => _fetchBid());
    }
  }

  @override
  void dispose() {
    _bidIdController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  AppStore get s => widget.store;

  bool get _isMse {
    final elig = s.section('eligibility');
    final udyam = elig['udyam'] == true;
    if (!udyam) return false;
    final p = s.profile;
    final inv = (p['investment'] as num?)?.toDouble() ?? 0;
    final turn = (p['turnover'] as num?)?.toDouble() ?? 0;
    final c = classify(inv, turn);
    return c == Enterprise.micro ||
        c == Enterprise.small ||
        c == Enterprise.medium;
  }

  bool get _isStartup {
    final elig = s.section('eligibility');
    return elig['startup'] == true;
  }

  void _prefill() {
    final p = s.profile;
    _turnoverBand = p['turnoverLatest'] as String?;
    final exp = p['pastOrderExperience'] as String?;
    _experienceYears = switch (exp) {
      'none' => 0,
      'some' => 1,
      'regular' => 3,
      _ => null,
    };
  }

  Future<void> _fetchBid() async {
    final bidId = _bidIdController.text.trim();
    if (bidId.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await s.client!
          .from('gem_bids')
          .select()
          .eq('source_id', bidId)
          .maybeSingle();
      if (result == null) {
        setState(() {
          _loading = false;
          _error = s.t(
            'Bid not found. Check the bid number and try again.',
            'बोली नहीं मिली। बोली नंबर जाँचें और पुनः प्रयास करें।',
          );
        });
        return;
      }
      _bid = Map<String, dynamic>.from(result);
      _details = Map<String, dynamic>.from(_bid['details'] as Map? ?? {});
      _conditions = extractConditions(_details);
      _prefill();
      setState(() {
        _loading = false;
        _step = 1;
      });
      _scrollController.jumpTo(0);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = s.t(
          'Something went wrong. Try again.',
          'कुछ गड़बड़ हुई। पुनः प्रयास करें।',
        );
      });
    }
  }

  void _evaluate() {
    final responses = <String, dynamic>{
      'turnover_band': _turnoverBand,
      'oem_turnover': _oemTurnover,
      'experience_years': _experienceYears,
      'documents': _docStatus,
      'emd_can_arrange': _emdCanArrange,
      'atc_accepted': _atcAccepted,
    };
    for (final entry in _certStatus.entries) {
      responses['cert_${entry.key}'] = entry.value;
    }

    _results = evaluateEligibility(
      conditions: _conditions,
      responses: responses,
      mseEligible: _isMse,
      startupEligible: _isStartup,
      mseRelaxation: _details['mse_relaxation'] as String?,
      startupRelaxation: _details['startup_relaxation'] as String?,
    );
    setState(() {
      _step = 2;
    });
    _scrollController.jumpTo(0);
  }

  void _reset() {
    setState(() {
      _step = 0;
      _bid = {};
      _details = {};
      _conditions = [];
      _results = [];
      _docStatus.clear();
      _certStatus.clear();
      _emdCanArrange = false;
      _atcAccepted = false;
      _bidIdController.clear();
      _error = null;
    });
    _scrollController.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (_step) {
      0 => s.t('Eligibility Checker', 'पात्रता जाँच'),
      1 => s.t('Your Details', 'आपका विवरण'),
      _ => s.t('Eligibility Report', 'पात्रता रिपोर्ट'),
    };

    return ToolPageScaffold(
      store: s,
      title: title,
      scrollController: _scrollController,
      bottomBar: _bottomBar(),
      children: switch (_step) {
        0 => _buildStep0(),
        1 => _buildStep1(),
        _ => _buildStep2(),
      },
    );
  }

  Widget? _bottomBar() => switch (_step) {
    0 => AppButton(
      label: s.t('Check eligibility', 'पात्रता जाँचें'),
      icon: Icons.checklist_outlined,
      loading: _loading,
      onPressed: _bidIdController.text.trim().isEmpty ? null : _fetchBid,
    ),
    1 => AppButton(
      label: s.t('Check my eligibility', 'मेरी पात्रता जाँचें'),
      icon: Icons.verified_outlined,
      onPressed: _evaluate,
    ),
    _ => null,
  };

  // ── Step 0: Enter Bid Number ─────────────────────────────────────────────

  List<Widget> _buildStep0() => [
    Text(
      s.t(
        'Enter a GeM Bid ID to check if you meet its eligibility requirements.',
        'GeM बोली ID दर्ज करें और जाँचें कि आप पात्रता शर्तें पूरी करते हैं।',
      ),
      style: AppText.body,
    ),
    const SizedBox(height: AppSpace.xxl),
    TextField(
      controller: _bidIdController,
      decoration: InputDecoration(
        labelText: s.t('Bid Number', 'बोली नंबर'),
        hintText: 'GEM/2026/B/0000000',
        hintStyle: AppText.body.copyWith(color: AppColors.textHint),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.borderStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.borderStrong),
        ),
        prefixIcon: const Icon(Icons.search, color: AppColors.textHint),
      ),
      style: AppText.body,
      textInputAction: TextInputAction.search,
      onChanged: (_) => setState(() {}),
      onSubmitted: (_) => _fetchBid(),
    ),
    if (_error != null) ...[
      const SizedBox(height: AppSpace.lg),
      AppCard(
        tone: AppCardTone.muted,
        child: Row(
          children: [
            const Icon(Icons.info_outline, size: 20, color: AppColors.danger),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Text(
                _error!,
                style: AppText.bodySmall.copyWith(color: AppColors.danger),
              ),
            ),
          ],
        ),
      ),
    ],
    const SizedBox(height: AppSpace.xxl),
    ReassuranceNote(
      s.t(
        'Enter the full bid ID as shown on the GeM portal (e.g. GEM/2026/B/0000000). The bid must already be in our database from the Find Bids section.',
        'GeM पोर्टल पर दिखाई गई पूरी बोली ID दर्ज करें (जैसे GEM/2026/B/0000000)। बोली हमारे डेटाबेस में "बोली खोजें" अनुभाग से पहले से होनी चाहिए।',
      ),
    ),
  ];

  // ── Step 1: Collect Details ──────────────────────────────────────────────

  List<Widget> _buildStep1() {
    final widgets = <Widget>[];

    // Bid summary header
    widgets.add(_bidHeader());
    widgets.add(const SizedBox(height: AppSpace.lg));
    widgets.add(_profileAssumptionsNote());
    widgets.add(const SizedBox(height: AppSpace.xxl));

    if (_conditions.isEmpty) {
      widgets.add(
        AppCard(
          tone: AppCardTone.muted,
          child: Text(
            s.t(
              'No specific eligibility conditions were found in this bid\'s extracted data. Review the bid PDF on the GeM portal for requirements.',
              'इस बोली के निकाले गए डेटा में कोई विशेष पात्रता शर्तें नहीं मिलीं। आवश्यकताओं के लिए GeM पोर्टल पर बोली PDF देखें।',
            ),
            style: AppText.body,
          ),
        ),
      );
      return widgets;
    }

    // Group by type
    final financial = _conditions
        .where(
          (c) =>
              c.type == ConditionType.turnover ||
              c.type == ConditionType.oem ||
              c.type == ConditionType.emd,
        )
        .toList();
    final experience = _conditions
        .where((c) => c.type == ConditionType.experience)
        .toList();
    final documents = _conditions
        .where((c) => c.type == ConditionType.documents)
        .toList();
    final certs = _conditions
        .where((c) => c.type == ConditionType.certification)
        .toList();
    final atc = _conditions.where((c) => c.type == ConditionType.atc).toList();

    if (financial.isNotEmpty) {
      widgets.add(SectionHeader(s.t('Financial', 'वित्तीय')));
      for (final c in financial) {
        widgets.add(_buildFinancialField(c));
        widgets.add(const SizedBox(height: AppSpace.md));
      }
      widgets.add(const SizedBox(height: AppSpace.lg));
    }

    if (experience.isNotEmpty) {
      widgets.add(SectionHeader(s.t('Experience', 'अनुभव')));
      for (final c in experience) {
        widgets.add(_buildExperienceField(c));
        widgets.add(const SizedBox(height: AppSpace.md));
      }
      widgets.add(const SizedBox(height: AppSpace.lg));
    }

    if (documents.isNotEmpty) {
      widgets.add(SectionHeader(s.t('Documents', 'दस्तावेज़')));
      for (final c in documents) {
        widgets.add(_buildDocumentsField(c));
      }
      widgets.add(const SizedBox(height: AppSpace.lg));
    }

    if (certs.isNotEmpty) {
      widgets.add(SectionHeader(s.t('Certifications', 'प्रमाणपत्र')));
      for (final c in certs) {
        widgets.add(_buildCertField(c));
        widgets.add(const SizedBox(height: AppSpace.sm));
      }
      widgets.add(const SizedBox(height: AppSpace.lg));
    }

    if (atc.isNotEmpty) {
      widgets.add(
        SectionHeader(
          s.t('Additional Terms & Conditions', 'अतिरिक्त नियम एवं शर्तें'),
        ),
      );
      for (final c in atc) {
        widgets.add(_buildAtcField(c));
      }
    }

    return widgets;
  }

  /// What this check assumes from the user's own profile — self-reported
  /// during onboarding, never independently verified — so the user can
  /// see exactly why a relaxation might apply and correct it if it's
  /// out of date, instead of it silently driving the result.
  Widget _profileAssumptionsNote() {
    return AppCard(
      tone: AppCardTone.outlined,
      padding: const EdgeInsets.all(AppSpace.md),
      child: Row(
        children: [
          const Icon(Icons.badge_outlined, size: 18, color: AppColors.textHint),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Text(
              s.t(
                'From your profile (self-reported): MSME ${_isMse ? "Yes" : "No"}, Startup ${_isStartup ? "Yes" : "No"}.',
                'आपकी प्रोफ़ाइल से (स्वयं-रिपोर्ट किया गया): MSME ${_isMse ? "हाँ" : "नहीं"}, स्टार्टअप ${_isStartup ? "हाँ" : "नहीं"}।',
              ),
              style: AppText.caption.copyWith(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/account'),
            child: Text(
              s.t('Update', 'अपडेट करें'),
              style: AppText.label.copyWith(color: AppColors.brand),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bidHeader() {
    final closesAt = DateTime.tryParse(_bid['closes_at'] as String? ?? '');
    final closesDisplay = closesAt != null
        ? DateFormat('d MMM yyyy, h:mm a').format(closesAt.toLocal())
        : '—';
    return AppCard(
      tone: AppCardTone.outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_bid['source_id'] as String? ?? '', style: AppText.overline),
          const SizedBox(height: AppSpace.xs),
          Text(
            _bid['title'] as String? ?? '',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: AppText.title,
          ),
          const SizedBox(height: AppSpace.sm),
          if (_bid['organisation'] != null)
            Text(_bid['organisation'] as String, style: AppText.caption),
          const SizedBox(height: AppSpace.xs),
          Text(
            '${s.t("Closes", "अंतिम समय")}: $closesDisplay',
            style: AppText.caption.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialField(EligibilityCondition c) {
    if (c.type == ConditionType.turnover) {
      return _turnoverSelector(c);
    }
    if (c.type == ConditionType.oem) {
      return _oemInput(c);
    }
    // EMD
    return _emdField(c);
  }

  Widget _turnoverSelector(EligibilityCondition c) {
    const bands = [
      ('under10L', 'Under ₹10 lakh'),
      ('10to40L', '₹10 lakh – ₹40 lakh'),
      ('40Lto1_5Cr', '₹40 lakh – ₹1.5 crore'),
      ('1_5to5Cr', '₹1.5 crore – ₹5 crore'),
      ('5CrPlus', '₹5 crore and above'),
    ];
    return AppCard(
      tone: AppCardTone.muted,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.t(c.label, 'न्यूनतम वार्षिक टर्नओवर'),
            style: AppText.bodyStrong,
          ),
          const SizedBox(height: AppSpace.xs),
          StatusChip(
            s.t('Requirement: ${c.requirement}', 'आवश्यकता: ${c.requirement}'),
            tone: StatusTone.info,
          ),
          const SizedBox(height: AppSpace.lg),
          Text(
            s.t('Your annual turnover', 'आपका वार्षिक टर्नओवर'),
            style: AppText.caption,
          ),
          Text(
            s.t(
              'From your profile — self-reported, update if outdated',
              'आपकी प्रोफ़ाइल से — स्वयं-रिपोर्ट किया गया, पुराना हो तो अपडेट करें',
            ),
            style: AppText.caption.copyWith(color: AppColors.textHint),
          ),
          const SizedBox(height: AppSpace.sm),
          RadioGroup<String>(
            groupValue: _turnoverBand,
            onChanged: (v) => setState(() => _turnoverBand = v),
            child: Column(
              children: [
                for (final b in bands)
                  RadioListTile<String>(
                    title: Text(b.$2, style: AppText.bodySmall),
                    value: b.$1,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _oemInput(EligibilityCondition c) {
    return AppCard(
      tone: AppCardTone.muted,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.t(c.label, 'OEM वार्षिक टर्नओवर'), style: AppText.bodyStrong),
          const SizedBox(height: AppSpace.xs),
          StatusChip(
            s.t('Requirement: ${c.requirement}', 'आवश्यकता: ${c.requirement}'),
            tone: StatusTone.info,
          ),
          const SizedBox(height: AppSpace.lg),
          TextField(
            decoration: InputDecoration(
              labelText: s.t('OEM turnover in ₹', 'OEM टर्नओवर ₹ में'),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              prefixText: '₹ ',
            ),
            keyboardType: TextInputType.number,
            style: AppText.body,
            onChanged: (v) {
              _oemTurnover = double.tryParse(v.replaceAll(',', ''));
            },
          ),
        ],
      ),
    );
  }

  Widget _emdField(EligibilityCondition c) {
    if (_isMse) {
      return AppCard(
        tone: AppCardTone.muted,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.t(c.label, 'बयाना राशि'), style: AppText.bodyStrong),
            const SizedBox(height: AppSpace.xs),
            StatusChip(
              s.t(
                'Requirement: ${c.requirement}',
                'आवश्यकता: ${c.requirement}',
              ),
              tone: StatusTone.info,
            ),
            const SizedBox(height: AppSpace.sm),
            StatusChip(
              s.t(
                'You may qualify for an MSE EMD exemption — verify with the buyer',
                'आप MSE EMD छूट के पात्र हो सकते हैं — खरीदार से पुष्टि करें',
              ),
              tone: StatusTone.warning,
              icon: Icons.info_outline,
            ),
          ],
        ),
      );
    }
    return AppCard(
      tone: AppCardTone.muted,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.t(c.label, 'बयाना राशि'), style: AppText.bodyStrong),
          const SizedBox(height: AppSpace.xs),
          StatusChip(
            s.t('Requirement: ${c.requirement}', 'आवश्यकता: ${c.requirement}'),
            tone: StatusTone.info,
          ),
          const SizedBox(height: AppSpace.lg),
          Text(
            s.t(
              'Can you arrange the EMD amount?',
              'क्या आप बयाना राशि की व्यवस्था कर सकते हैं?',
            ),
            style: AppText.caption,
          ),
          const SizedBox(height: AppSpace.sm),
          Row(
            children: [
              _choiceChip(
                label: s.t('Yes', 'हाँ'),
                selected: _emdCanArrange,
                onTap: () => setState(() => _emdCanArrange = true),
              ),
              const SizedBox(width: AppSpace.md),
              _choiceChip(
                label: s.t('No', 'नहीं'),
                selected: !_emdCanArrange,
                onTap: () => setState(() => _emdCanArrange = false),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExperienceField(EligibilityCondition c) {
    return AppCard(
      tone: AppCardTone.muted,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.t(c.label, 'पिछला अनुभव'), style: AppText.bodyStrong),
          const SizedBox(height: AppSpace.xs),
          StatusChip(
            s.t('Requirement: ${c.requirement}', 'आवश्यकता: ${c.requirement}'),
            tone: StatusTone.info,
          ),
          const SizedBox(height: AppSpace.lg),
          TextField(
            decoration: InputDecoration(
              labelText: s.t('Years of experience', 'अनुभव के वर्ष'),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            keyboardType: TextInputType.number,
            style: AppText.body,
            controller: TextEditingController(
              text: _experienceYears?.toStringAsFixed(0) ?? '',
            ),
            onChanged: (v) {
              _experienceYears = double.tryParse(v);
            },
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            s.t(
              'From your profile — self-reported, update if outdated',
              'आपकी प्रोफ़ाइल से — स्वयं-रिपोर्ट किया गया, पुराना हो तो अपडेट करें',
            ),
            style: AppText.caption.copyWith(color: AppColors.textHint),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsField(EligibilityCondition c) {
    if (c.items == null || c.items!.isEmpty) return const SizedBox.shrink();
    return AppCard(
      tone: AppCardTone.muted,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.t(
              'Do you have these documents?',
              'क्या आपके पास ये दस्तावेज़ हैं?',
            ),
            style: AppText.bodyStrong,
          ),
          const SizedBox(height: AppSpace.md),
          for (final doc in c.items!) ...[
            _docRow(doc),
            if (doc != c.items!.last)
              const Divider(height: 1, color: AppColors.border),
          ],
        ],
      ),
    );
  }

  Widget _docRow(String doc) {
    final status = _docStatus[doc] ?? 'unsure';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(doc, style: AppText.bodySmall)),
          const SizedBox(width: AppSpace.sm),
          _miniChip(
            label: s.t('Yes', 'हाँ'),
            selected: status == 'yes',
            color: AppColors.brand,
            onTap: () => setState(() => _docStatus[doc] = 'yes'),
          ),
          const SizedBox(width: AppSpace.xs),
          _miniChip(
            label: s.t('No', 'नहीं'),
            selected: status == 'no',
            color: AppColors.danger,
            onTap: () => setState(() => _docStatus[doc] = 'no'),
          ),
          const SizedBox(width: AppSpace.xs),
          _miniChip(
            label: '?',
            selected: status == 'unsure',
            color: AppColors.warning,
            onTap: () => setState(() => _docStatus[doc] = 'unsure'),
          ),
        ],
      ),
    );
  }

  Widget _buildCertField(EligibilityCondition c) {
    final status = _certStatus[c.label] ?? '';
    return AppCard(
      tone: AppCardTone.muted,
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.label, style: AppText.bodyStrong),
                const SizedBox(height: AppSpace.xs),
                Text(
                  s.t(
                    'Do you have this certificate?',
                    'क्या आपके पास यह प्रमाणपत्र है?',
                  ),
                  style: AppText.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          _miniChip(
            label: s.t('Yes', 'हाँ'),
            selected: status == 'yes',
            color: AppColors.brand,
            onTap: () => setState(() => _certStatus[c.label] = 'yes'),
          ),
          const SizedBox(width: AppSpace.xs),
          _miniChip(
            label: s.t('No', 'नहीं'),
            selected: status == 'no',
            color: AppColors.danger,
            onTap: () => setState(() => _certStatus[c.label] = 'no'),
          ),
          const SizedBox(width: AppSpace.xs),
          _miniChip(
            label: s.t('Applied', 'आवेदित'),
            selected: status == 'applied',
            color: AppColors.warning,
            onTap: () => setState(() => _certStatus[c.label] = 'applied'),
          ),
        ],
      ),
    );
  }

  Widget _buildAtcField(EligibilityCondition c) {
    return AppCard(
      tone: AppCardTone.muted,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.t(
              'Review the additional terms and conditions:',
              'अतिरिक्त नियम एवं शर्तें देखें:',
            ),
            style: AppText.bodyStrong,
          ),
          const SizedBox(height: AppSpace.md),
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            padding: const EdgeInsets.all(AppSpace.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.border),
            ),
            child: SingleChildScrollView(
              child: Text(c.requirement, style: AppText.bodySmall),
            ),
          ),
          const SizedBox(height: AppSpace.md),
          SwitchListTile(
            title: Text(
              s.t(
                'I have reviewed and accept these terms',
                'मैंने इन शर्तों की समीक्षा की है और स्वीकार करता/करती हूँ',
              ),
              style: AppText.bodySmall,
            ),
            value: _atcAccepted,
            contentPadding: EdgeInsets.zero,
            dense: true,
            onChanged: (v) => setState(() => _atcAccepted = v),
          ),
        ],
      ),
    );
  }

  // ── Step 2: Report ───────────────────────────────────────────────────────

  List<Widget> _buildStep2() {
    final widgets = <Widget>[];

    widgets.add(_bidHeader());
    widgets.add(const SizedBox(height: AppSpace.lg));

    if (_results.isEmpty) {
      widgets.add(
        AppCard(
          tone: AppCardTone.muted,
          child: Text(
            s.t(
              'No eligibility conditions to evaluate for this bid.',
              'इस बोली के लिए मूल्यांकन हेतु कोई पात्रता शर्तें नहीं हैं।',
            ),
            style: AppText.body,
          ),
        ),
      );
    } else {
      final overall = overallVerdict(_results);
      widgets.add(_overallBadge(overall));
      widgets.add(const SizedBox(height: AppSpace.sm));
      widgets.add(
        Text(
          s.t(
            'Preliminary check only — not an official GeM decision.',
            'केवल प्रारंभिक जाँच — आधिकारिक GeM निर्णय नहीं।',
          ),
          textAlign: TextAlign.center,
          style: AppText.caption.copyWith(color: AppColors.textHint),
        ),
      );
      widgets.add(const SizedBox(height: AppSpace.xxl));

      widgets.add(
        SectionHeader(s.t('Condition-wise Results', 'शर्त-वार परिणाम')),
      );

      for (final r in _results) {
        widgets.add(_resultCard(r));
        widgets.add(const SizedBox(height: AppSpace.md));
      }
    }

    widgets.add(const SizedBox(height: AppSpace.lg));
    widgets.add(
      ReassuranceNote(
        s.t(
          'This is a preliminary check based on the information you provided and the data extracted from the bid PDF. It is not an official GeM eligibility decision. Verify all requirements on the GeM portal before bidding.',
          'यह आपके द्वारा दी गई जानकारी और बोली PDF से निकाले गए डेटा पर आधारित प्रारंभिक जाँच है। यह आधिकारिक GeM पात्रता निर्णय नहीं है। बोली लगाने से पहले GeM पोर्टल पर सभी आवश्यकताओं की पुष्टि करें।',
        ),
      ),
    );
    widgets.add(const SizedBox(height: AppSpace.xxl));

    widgets.add(
      Row(
        children: [
          Expanded(
            child: AppButton(
              label: s.t('Check another bid', 'अन्य बोली जाँचें'),
              variant: AppButtonVariant.secondary,
              icon: Icons.refresh,
              onPressed: _reset,
            ),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: AppButton(
              label: s.t('View on GeM', 'GeM पर देखें'),
              variant: AppButtonVariant.primary,
              trailingIcon: Icons.open_in_new,
              onPressed: () {
                final url = _bid['source_url'] as String?;
                if (url != null) openLink(context, s, url);
              },
            ),
          ),
        ],
      ),
    );

    return widgets;
  }

  Widget _overallBadge(Verdict v) {
    final (label, tone, icon) = switch (v) {
      Verdict.eligible => (
        s.t('Likely eligible', 'संभवतः पात्र'),
        StatusTone.success,
        Icons.check_circle_outline,
      ),
      Verdict.notEligible => (
        s.t('Potentially ineligible', 'संभवतः अपात्र'),
        StatusTone.danger,
        Icons.cancel_outlined,
      ),
      Verdict.needsVerification => (
        s.t('Needs verification', 'सत्यापन आवश्यक'),
        StatusTone.warning,
        Icons.help_outline,
      ),
      Verdict.insufficientInformation => (
        s.t('Insufficient information', 'अपर्याप्त जानकारी'),
        StatusTone.neutral,
        Icons.info_outline,
      ),
    };
    final (fg, bg) = switch (tone) {
      StatusTone.success => (AppColors.brand, AppColors.brandTint),
      StatusTone.danger => (AppColors.danger, AppColors.dangerTint),
      StatusTone.warning => (AppColors.warning, AppColors.warningTint),
      _ => (AppColors.textSecondary, AppColors.surfaceMuted),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.xl),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: fg, size: 28),
          const SizedBox(width: AppSpace.md),
          Flexible(
            child: Text(label, style: AppText.h3.copyWith(color: fg)),
          ),
        ],
      ),
    );
  }

  Widget _resultCard(ConditionResult r) {
    final (itemState, trailing) = switch (r.verdict) {
      Verdict.eligible => (ItemState.done, s.t('Eligible', 'पात्र')),
      Verdict.notEligible => (
        ItemState.attention,
        s.t('Potentially ineligible', 'संभवतः अपात्र'),
      ),
      Verdict.needsVerification => (
        ItemState.pending,
        s.t('Verify', 'सत्यापित करें'),
      ),
      Verdict.insufficientInformation => (
        ItemState.pending,
        s.t('Insufficient information', 'अपर्याप्त जानकारी'),
      ),
    };
    return AppCard(
      tone: AppCardTone.muted,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatusItem(
            label: s.t(r.condition.label, r.condition.label),
            state: itemState,
            trailing: trailing,
          ),
          KeyValueRow(
            s.t('Bid requirement', 'बोली आवश्यकता'),
            r.condition.requirement,
          ),
          if (r.userValue != null)
            KeyValueRow(s.t('Your detail', 'आपका विवरण'), r.userValue!),
          const SizedBox(height: AppSpace.xs),
          Text(
            r.explanation,
            style: AppText.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
          if (r.relaxationApplied) ...[
            const SizedBox(height: AppSpace.sm),
            StatusChip(
              s.t('Relaxation applied', 'छूट लागू'),
              tone: StatusTone.info,
              icon: Icons.info_outline,
            ),
          ],
        ],
      ),
    );
  }

  // ── Shared helpers ───────────────────────────────────────────────────────

  Widget _choiceChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.lg,
          vertical: AppSpace.sm,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected ? AppColors.ink : AppColors.borderStrong,
          ),
        ),
        child: Text(
          label,
          style: AppText.label.copyWith(
            color: selected ? AppColors.surface : AppColors.ink,
          ),
        ),
      ),
    );
  }

  Widget _miniChip({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.sm,
          vertical: 3,
        ),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: selected ? color : AppColors.border),
        ),
        child: Text(
          label,
          style: AppText.label.copyWith(
            color: selected ? color : AppColors.textHint,
          ),
        ),
      ),
    );
  }
}
