/// Lowest Price Declaration Certificate generator.
/// Registered in tools_hub/tool_registry.dart, route `/tool-lowest-price-declaration`.
///
/// Declares prices quoted in a GeM bid are the lowest offered to any buyer.
/// Follows the same StatefulWidget pattern as all other bid doc tools.
library;

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../core/tokens.dart';
import '../../data/app_store.dart';
import '../components.dart';
import '../tools_hub/tool_page_scaffold.dart';
import 'letter_model.dart';
import 'letter_pdf.dart';
import 'letter_preview.dart';
import 'lowest_price_declaration_text.dart';
import 'mii_certificate_page.dart' show BidDocProfileKeys;
import 'mii_certificate_text.dart' show looksLikeGemTenderNo;

enum _Step { details, preview }

class LowestPriceDeclarationPage extends StatefulWidget {
  final AppStore store;
  final String? tenderNo;

  const LowestPriceDeclarationPage({
    super.key,
    required this.store,
    this.tenderNo,
  });

  @override
  State<LowestPriceDeclarationPage> createState() =>
      _LowestPriceDeclarationPageState();
}

class _LowestPriceDeclarationPageState
    extends State<LowestPriceDeclarationPage> {
  final _form = GlobalKey<FormState>();
  final _scroll = ScrollController();

  LowestPriceTemplate _template = LowestPriceTemplate.template1;
  late final TextEditingController _tenderNo;
  late final TextEditingController _recipientTitle;
  late final TextEditingController _organization;
  late final TextEditingController _organizationAddress;
  late final TextEditingController _company;
  late final TextEditingController _companyAddress;
  late final TextEditingController _signatory;
  late final TextEditingController _designation;

  _Step _step = _Step.details;
  LowestPriceDeclarationInput? _input;
  List<LetterBlock>? _blocks;
  List<TextEditingController>? _editors;
  double _extraTop = 0;
  bool _confirmed = false;
  bool _busy = false;

  AppStore get s => widget.store;
  String t(String en, String hi) => s.t(en, hi);

  @override
  void initState() {
    super.initState();
    s.event('page_view', page: 'tool-lowest-price-declaration');
    final p = s.profile;
    String pv(String k) => (p[k] as String?)?.trim() ?? '';
    final signatoryName = pv(BidDocProfileKeys.signatoryName);
    _tenderNo = TextEditingController(text: widget.tenderNo ?? '');
    _recipientTitle = TextEditingController();
    _organization = TextEditingController();
    _organizationAddress = TextEditingController();
    _company = TextEditingController(text: pv(BidDocProfileKeys.companyName));
    _companyAddress = TextEditingController(
      text: pv(BidDocProfileKeys.companyAddress),
    );
    _signatory = TextEditingController(
      text: signatoryName.isNotEmpty
          ? signatoryName
          : pv(BidDocProfileKeys.fallbackSignatory),
    );
    _designation = TextEditingController(
      text: pv(BidDocProfileKeys.signatoryDesignation),
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    for (final c in [
      _tenderNo,
      _recipientTitle,
      _organization,
      _organizationAddress,
      _company,
      _companyAddress,
      _signatory,
      _designation,
    ]) {
      c.dispose();
    }
    _disposeEditors();
    super.dispose();
  }

  void _disposeEditors() {
    for (final c in _editors ?? const <TextEditingController>[]) {
      c.dispose();
    }
    _editors = null;
  }

  // ---------------------------------------------------------------- validation

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty)
          ? t('This is required', 'यह आवश्यक है')
          : null;

  String? _tenderValidator(String? v) {
    if (v == null || v.trim().isEmpty) {
      return t('This is required', 'यह आवश्यक है');
    }
    if (!looksLikeGemTenderNo(v.trim())) {
      return t(
        'Check the tender number format',
        'निविदा नंबर का प्रारूप जाँचें',
      );
    }
    return null;
  }

  // ----------------------------------------------------------------- actions

  void _generate() {
    if (!_form.currentState!.validate()) return;
    _disposeEditors();
    final input = LowestPriceDeclarationInput(
      template: _template,
      recipientTitle: _recipientTitle.text.trim(),
      organization: _organization.text.trim(),
      organizationAddress: _organizationAddress.text.trim(),
      tenderNo: _tenderNo.text.trim(),
      company: _company.text.trim(),
      companyAddress: _companyAddress.text.trim(),
      signatory: _signatory.text.trim(),
      designation: _designation.text.trim(),
      date: DateTime.now(),
    );
    s.setProfile(BidDocProfileKeys.companyName, input.company);
    s.setProfile(BidDocProfileKeys.companyAddress, input.companyAddress);
    s.setProfile(BidDocProfileKeys.signatoryName, input.signatory);
    s.setProfile(BidDocProfileKeys.signatoryDesignation, input.designation);

    setState(() {
      _input = input;
      _blocks = buildLowestPriceDeclaration(input);
      _confirmed = false;
      _step = _Step.preview;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(0);
    });
  }

  void _onStepChanged(_Step next) {
    if (next == _Step.details) {
      if (_editors != null) _finishEditing();
      setState(() => _step = _Step.details);
    } else if (_blocks == null) {
      _generate();
    } else {
      setState(() => _step = _Step.preview);
    }
  }

  void _resetAll() {
    for (final c in [
      _tenderNo,
      _recipientTitle,
      _organization,
      _organizationAddress,
      _company,
      _companyAddress,
      _signatory,
      _designation,
    ]) {
      c.clear();
    }
    _disposeEditors();
    setState(() {
      _template = LowestPriceTemplate.template1;
      _blocks = null;
      _input = null;
      _confirmed = false;
      _extraTop = 0;
      _step = _Step.details;
    });
  }

  void _invalidateLetter() {
    if (_blocks == null) return;
    setState(() {
      _blocks = null;
      _input = null;
      _confirmed = false;
      _disposeEditors();
    });
  }

  void _startEditing() => setState(() {
    _editors = [
      for (final b in _blocks!)
        if (!b.isSpacer) TextEditingController(text: b.plainText),
    ];
  });

  void _finishEditing() {
    var i = 0;
    final edited = [
      for (final b in _blocks!)
        b.isSpacer ? b : LetterBlock.plain(b.kind, _editors![i++].text),
    ];
    _disposeEditors();
    setState(() {
      _blocks = edited;
      _confirmed = false;
    });
  }

  String get _fileStem =>
      'Lowest Price Declaration - ${(_input?.tenderNo ?? '').replaceAll('/', '-')}';

  Future<void> _print() async {
    setState(() => _busy = true);
    try {
      s.event(
        'document_generated',
        page: 'tool-lowest-price-declaration',
        props: {'action': 'print'},
      );
      await Printing.layoutPdf(
        name: _fileStem,
        onLayout: (_) => buildLetterPdf(_blocks!, extraTopMarginPt: _extraTop),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      s.event(
        'document_generated',
        page: 'tool-lowest-price-declaration',
        props: {'action': 'share'},
      );
      final bytes = await buildLetterPdf(_blocks!, extraTopMarginPt: _extraTop);
      await Printing.sharePdf(bytes: bytes, filename: '$_fileStem.pdf');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _explainConfirm() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          t(
            'Tick the confirmation first.',
            'पहले पुष्टि वाले बॉक्स पर टिक करें।',
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final previewing = _step == _Step.preview && _blocks != null;
    final editing = _editors != null;
    return ToolPageScaffold(
      store: s,
      scrollController: _scroll,
      title: t('Lowest Price Declaration', 'न्यूनतम मूल्य घोषणा'),
      action: AppIconButton(
        icon: Icons.refresh,
        tooltip: t('Clear form', 'फ़ॉर्म साफ़ करें'),
        onPressed: _resetAll,
      ),
      bottomBar: previewing
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppButton(
                  label: t('Print / Save as PDF', 'प्रिंट / PDF सेव करें'),
                  icon: Icons.print_outlined,
                  loading: _busy,
                  onPressed: (_confirmed && !editing) ? _print : null,
                  onDisabledTap: _explainConfirm,
                ),
                const SizedBox(height: AppSpace.sm),
                AppButton(
                  label: t('Share PDF', 'PDF साझा करें'),
                  icon: Icons.ios_share,
                  variant: AppButtonVariant.secondary,
                  onPressed: (_confirmed && !editing) ? _share : null,
                  onDisabledTap: _explainConfirm,
                ),
              ],
            )
          : AppButton(
              label: _blocks == null
                  ? t('Generate letter', 'पत्र बनाएँ')
                  : t('Update letter', 'पत्र अपडेट करें'),
              onPressed: _generate,
            ),
      children: [
        Text(
          t(
            'Fill in the required details to generate your Lowest Price Declaration — declare that your quoted price is the lowest offered to any buyer.',
            'न्यूनतम मूल्य घोषणा बनाने के लिए आवश्यक जानकारी भरें — घोषित करें कि आपका उद्धृत मूल्य किसी भी खरीदार को दिया गया सबसे कम मूल्य है।',
          ),
          style: AppText.secondary(AppText.body),
        ),
        const SizedBox(height: AppSpace.xl),
        AppSegmentedControl<_Step>(
          semanticLabel: t('Letter step', 'पत्र का चरण'),
          value: previewing ? _Step.preview : _Step.details,
          onChanged: _onStepChanged,
          options: [
            (_Step.details, t('Details', 'विवरण'), null),
            (_Step.preview, t('Preview', 'पूर्वावलोकन'), null),
          ],
        ),
        const SizedBox(height: AppSpace.xl),
        Offstage(offstage: previewing, child: _detailsForm()),
        if (previewing) ..._previewSection(),
        if (!previewing) ...[
          const SizedBox(height: AppSpace.xxxl),
          _helpSection(),
        ],
      ],
    );
  }

  // ------------------------------------------------------------------ form

  Widget _field(
    TextEditingController c,
    String en,
    String hi, {
    String? Function(String?)? validator,
    String? helper,
    TextCapitalization caps = TextCapitalization.words,
  }) => Padding(
    key: ValueKey(en),
    padding: const EdgeInsets.only(bottom: AppSpace.lg),
    child: TextFormField(
      controller: c,
      textCapitalization: caps,
      decoration: InputDecoration(
        labelText: t(en, hi),
        helperText: helper,
        helperMaxLines: 3,
      ),
      validator: validator ?? _required,
      onChanged: (_) {
        setState(() {});
        _invalidateLetter();
      },
    ),
  );

  Widget _detailsForm() {
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Template dropdown
          Padding(
            key: const ValueKey('template-dropdown'),
            padding: const EdgeInsets.only(bottom: AppSpace.lg),
            child: DropdownButtonFormField<LowestPriceTemplate>(
              initialValue: _template,
              decoration: InputDecoration(
                labelText: t('Template', 'टेम्पलेट'),
              ),
              items: [
                DropdownMenuItem(
                  value: LowestPriceTemplate.template1,
                  child: Text(t('Template 1', 'टेम्पलेट 1')),
                ),
              ],
              onChanged: (v) {
                if (v == null || v == _template) return;
                setState(() => _template = v);
                _invalidateLetter();
              },
            ),
          ),
          _field(_recipientTitle, 'Recipient title', 'प्राप्तकर्ता का शीर्षक'),
          _field(_organization, 'Organization', 'संगठन'),
          _field(_organizationAddress, 'Organization address', 'संगठन का पता'),
          _field(
            _tenderNo,
            'Tender / bid number',
            'निविदा / बिड नंबर',
            caps: TextCapitalization.characters,
            validator: _tenderValidator,
            helper: t('e.g. GEM/2026/B/1234567', 'जैसे GEM/2026/B/1234567'),
          ),
          _field(_company, 'Company name', 'कंपनी का नाम'),
          _field(_companyAddress, 'Company address', 'कंपनी का पता'),
          _field(_signatory, 'Signatory name', 'हस्ताक्षरकर्ता का नाम'),
          _field(
            _designation,
            'Designation',
            'पदनाम',
            helper: t(
              'e.g. Director, Proprietor, Authorised Signatory',
              'जैसे Director, Proprietor, Authorised Signatory',
            ),
          ),
          ReassuranceNote(
            t(
              'The letter is generated on your device. We do not upload or keep it — only your company and signatory details are remembered so you do not retype them.',
              'पत्र आपके डिवाइस पर ही बनता है। हम इसे अपलोड या सेव नहीं करते — केवल कंपनी और हस्ताक्षरकर्ता का विवरण याद रखा जाता है।',
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- preview

  List<Widget> _previewSection() {
    final i = _input!;
    final editing = _editors != null;
    return [
      DividedList(
        children: [
          KeyValueRow(t('Tender no.', 'निविदा नं.'), i.tenderNo),
          KeyValueRow(t('Recipient', 'प्राप्तकर्ता'), i.recipientTitle),
          KeyValueRow(t('Organization', 'संगठन'), i.organization),
          KeyValueRow(t('Company', 'कंपनी'), i.company),
        ],
      ),
      const SizedBox(height: AppSpace.xl),
      Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(t('Your letter', 'आपका पत्र'), style: AppText.h3),
            ),
          ),
          AppButton(
            label: editing
                ? t('Done editing', 'संपादन पूरा')
                : t('Edit text', 'टेक्स्ट बदलें'),
            variant: AppButtonVariant.tertiary,
            size: AppButtonSize.sm,
            expand: false,
            onPressed: editing ? _finishEditing : _startEditing,
          ),
        ],
      ),
      const SizedBox(height: AppSpace.xs),
      Text(
        t(
          'You can edit the letter before printing. Edited paragraphs lose their bold styling.',
          'प्रिंट से पहले आप पत्र में बदलाव कर सकते हैं। बदले गए अनुच्छेदों की बोल्ड शैली हट जाती है।',
        ),
        style: AppText.caption,
      ),
      const SizedBox(height: AppSpace.lg),
      Text(
        t('Top margin (for letterhead)', 'ऊपरी मार्जिन (लेटरहेड के लिए)'),
        style: AppText.label,
      ),
      Slider(
        value: _extraTop,
        min: 0,
        max: kLetterMaxExtraTopMarginPt,
        onChanged: (v) => setState(() => _extraTop = v),
      ),
      LetterPaper(
        blocks: _blocks!,
        extraTopMargin: _extraTop / 2,
        editors: _editors,
      ),
      const SizedBox(height: AppSpace.lg),
      AppCard(
        tone: AppCardTone.muted,
        padding: const EdgeInsets.all(AppSpace.md),
        child: CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _confirmed,
          onChanged: editing
              ? null
              : (v) => setState(() => _confirmed = v ?? false),
          title: Text(
            t(
              'I confirm these details are true. I understand a false declaration can lead to debarment.',
              'मैं पुष्टि करता/करती हूँ कि ये विवरण सही हैं। मैं समझता/समझती हूँ कि गलत घोषणा पर प्रतिबंध लग सकता है।',
            ),
            style: AppText.bodySmall,
          ),
        ),
      ),
    ];
  }

  // ---------------------------------------------------------------- help

  Widget _helpSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t(
            'How to generate Lowest Price Declaration',
            'न्यूनतम मूल्य घोषणा कैसे बनाएँ',
          ),
          style: AppText.h3,
        ),
        const SizedBox(height: AppSpace.sm),
        Text(
          t(
            'Follow these steps to generate your declaration:',
            'घोषणा बनाने के लिए इन चरणों का पालन करें:',
          ),
          style: AppText.secondary(AppText.body),
        ),
        const SizedBox(height: AppSpace.lg),
        for (final step in _helpSteps()) ...[
          _HelpStep(number: step.$1, title: step.$2, body: step.$3),
          const SizedBox(height: AppSpace.md),
        ],
        const SizedBox(height: AppSpace.lg),
        AppCard(
          tone: AppCardTone.muted,
          padding: const EdgeInsets.all(AppSpace.md),
          child: Text(
            t(
              'This declaration is a legal commitment. Ensure the price quoted in your bid is truly the lowest you have offered to any buyer before submitting.',
              'यह घोषणा एक कानूनी प्रतिबद्धता है। जमा करने से पहले सुनिश्चित करें कि आपकी बिड में उद्धृत मूल्य वास्तव में किसी भी खरीदार को दिया गया सबसे कम मूल्य है।',
            ),
            style: AppText.caption,
          ),
        ),
      ],
    );
  }

  List<(int, String, String)> _helpSteps() => [
    (
      1,
      t('Enter recipient details', 'प्राप्तकर्ता का विवरण दें'),
      t(
        'Enter the procurement officer\'s title and organization details.',
        'खरीद अधिकारी का शीर्षक और संगठन का विवरण दर्ज करें।',
      ),
    ),
    (
      2,
      t('Enter tender number', 'निविदा नंबर दर्ज करें'),
      t(
        'Enter the GeM bid number this declaration applies to.',
        'वह GeM बिड नंबर दर्ज करें जिस पर यह घोषणा लागू होती है।',
      ),
    ),
    (
      3,
      t('Enter company details', 'कंपनी का विवरण दें'),
      t(
        'Enter your company name, registered address, and authorized signatory.',
        'कंपनी का नाम, पंजीकृत पता और अधिकृत हस्ताक्षरकर्ता का विवरण दर्ज करें।',
      ),
    ),
    (
      4,
      t('Generate, review and submit', 'बनाएँ, देखें और जमा करें'),
      t(
        'Click "Generate letter", review in Preview, tick the confirmation, then print or save as PDF.',
        '"पत्र बनाएँ" पर क्लिक करें, Preview में देखें, पुष्टि टिक करें, फिर प्रिंट करें या PDF सेव करें।',
      ),
    ),
  ];
}

// ----------------------------------------------------------- help step widget

class _HelpStep extends StatelessWidget {
  final int number;
  final String title;
  final String body;
  const _HelpStep({
    required this.number,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 28,
        height: 28,
        decoration: const ShapeDecoration(
          color: AppColors.ink,
          shape: CircleBorder(),
        ),
        alignment: Alignment.center,
        child: Text(
          '$number',
          style: AppText.caption.copyWith(
            color: AppColors.surface,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      const SizedBox(width: AppSpace.md),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppText.bodyStrong),
            const SizedBox(height: AppSpace.xs),
            Text(body, style: AppText.secondary(AppText.body)),
          ],
        ),
      ),
    ],
  );
}
