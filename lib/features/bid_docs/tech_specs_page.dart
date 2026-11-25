/// Technical Specifications Compliance Certificate generator.
/// Route: `/tool-tech-specs`
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
import 'mii_certificate_page.dart' show BidDocProfileKeys;
import 'mii_certificate_text.dart' show looksLikeGemTenderNo;
import 'tech_specs_text.dart';

enum _Step { details, preview }

// ─── per-row state ────────────────────────────────────────────────────────────

class _SpecRowCard {
  static int _counter = 0;
  final int id = _counter++;

  final specParameter = TextEditingController();
  final requiredValue = TextEditingController();
  final offeredValue = TextEditingController();
  String compliant = 'Yes';

  void dispose() {
    specParameter.dispose();
    requiredValue.dispose();
    offeredValue.dispose();
  }

  bool get isFilled =>
      specParameter.text.trim().isNotEmpty &&
      requiredValue.text.trim().isNotEmpty &&
      offeredValue.text.trim().isNotEmpty;

  SpecRow toRow() => SpecRow(
    specParameter: specParameter.text.trim(),
    requiredValue: requiredValue.text.trim(),
    offeredValue: offeredValue.text.trim(),
    compliant: compliant,
  );
}

// ─── page ─────────────────────────────────────────────────────────────────────

class TechSpecsPage extends StatefulWidget {
  final AppStore store;
  final String? tenderNo;
  const TechSpecsPage({super.key, required this.store, this.tenderNo});

  @override
  State<TechSpecsPage> createState() => _TechSpecsPageState();
}

class _TechSpecsPageState extends State<TechSpecsPage> {
  final _form = GlobalKey<FormState>();
  final _scroll = ScrollController();
  final _rows = <_SpecRowCard>[];

  late final TextEditingController _tenderNo;
  late final TextEditingController _buyerDesignation;
  late final TextEditingController _buyerOrg;
  late final TextEditingController _company;
  late final TextEditingController _signatory;
  late final TextEditingController _designation;

  _Step _step = _Step.details;
  TechSpecsInput? _input;
  List<LetterBlock>? _blocks;
  List<TextEditingController>? _editors;
  bool _confirmed = false;
  bool _busy = false;

  AppStore get s => widget.store;
  String t(String en, String hi) => s.t(en, hi);

  @override
  void initState() {
    super.initState();
    s.event('page_view', page: 'tool-tech-specs');
    final p = s.profile;
    String pv(String k) => (p[k] as String?)?.trim() ?? '';
    _tenderNo = TextEditingController(text: widget.tenderNo ?? '');
    _buyerDesignation = TextEditingController();
    _buyerOrg = TextEditingController();
    _company = TextEditingController(text: pv(BidDocProfileKeys.companyName));
    final signatory = pv(BidDocProfileKeys.signatoryName);
    _signatory = TextEditingController(
      text: signatory.isNotEmpty ? signatory : pv(BidDocProfileKeys.fallbackSignatory),
    );
    _designation = TextEditingController(text: pv(BidDocProfileKeys.signatoryDesignation));
    _rows.add(_SpecRowCard());
  }

  @override
  void dispose() {
    _scroll.dispose();
    for (final c in [_tenderNo, _buyerDesignation, _buyerOrg, _company, _signatory, _designation]) {
      c.dispose();
    }
    for (final r in _rows) {
      r.dispose();
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

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? t('This is required', 'यह आवश्यक है') : null;

  String? _validateTender(String? v) {
    if (v == null || v.trim().isEmpty) return t('This is required', 'यह आवश्यक है');
    if (!looksLikeGemTenderNo(v.trim())) {
      return t('Enter a valid GeM Bid / Tender number', 'सही GeM बिड / टेंडर नंबर दर्ज करें');
    }
    return null;
  }

  void _addRow() {
    setState(() => _rows.add(_SpecRowCard()));
    _invalidateLetter();
  }

  void _removeRow(int index) {
    _rows[index].dispose();
    setState(() => _rows.removeAt(index));
    _invalidateLetter();
  }

  void _generate() {
    if (!_form.currentState!.validate()) return;
    _disposeEditors();
    final input = TechSpecsInput(
      tenderNo: _tenderNo.text.trim(),
      buyerDesignation: _buyerDesignation.text.trim(),
      buyerOrg: _buyerOrg.text.trim(),
      company: _company.text.trim(),
      specRows: _rows.map((r) => r.toRow()).toList(),
      signatory: _signatory.text.trim(),
      designation: _designation.text.trim(),
      date: DateTime.now(),
    );
    s.setProfile(BidDocProfileKeys.companyName, input.company);
    s.setProfile(BidDocProfileKeys.signatoryName, input.signatory);
    s.setProfile(BidDocProfileKeys.signatoryDesignation, input.designation);
    setState(() {
      _input = input;
      _blocks = buildTechSpecsCertificate(input);
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
    for (final c in [_tenderNo, _buyerDesignation, _buyerOrg, _company, _signatory, _designation]) {
      c.clear();
    }
    for (final r in _rows) {
      r.dispose();
    }
    _rows.clear();
    _rows.add(_SpecRowCard());
    _disposeEditors();
    setState(() {
      _blocks = null;
      _input = null;
      _confirmed = false;
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
      'Tech-Specs - ${(_input?.company ?? '').replaceAll(' ', '_')}';

  Future<void> _print() async {
    setState(() => _busy = true);
    try {
      s.event('document_generated', page: 'tool-tech-specs', props: {'action': 'print'});
      await Printing.layoutPdf(
        name: _fileStem,
        onLayout: (_) => buildLetterPdf(_blocks!, extraTopMarginPt: 0),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      s.event('document_generated', page: 'tool-tech-specs', props: {'action': 'share'});
      final bytes = await buildLetterPdf(_blocks!, extraTopMarginPt: 0);
      await Printing.sharePdf(bytes: bytes, filename: '$_fileStem.pdf');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _explainConfirm() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t('Tick the confirmation first.', 'पहले पुष्टि वाले बॉक्स पर टिक करें।'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final previewing = _step == _Step.preview && _blocks != null;
    final editing = _editors != null;
    return ToolPageScaffold(
      store: s,
      scrollController: _scroll,
      title: t('Technical Specifications Compliance Certificate',
          'तकनीकी विशिष्टताओं का अनुपालन प्रमाणपत्र'),
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
            'Certify that your offered product meets each technical specification in the tender.',
            'प्रमाणित करें कि आपका उत्पाद टेंडर की प्रत्येक तकनीकी विशिष्टता पूरी करता है।',
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

  Widget _field(
    TextEditingController c,
    String en,
    String hi, {
    String? Function(String?)? validator,
    String? helper,
    TextCapitalization caps = TextCapitalization.none,
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
          _field(_tenderNo, 'GeM Bid / Tender number', 'GeM बिड / टेंडर नंबर',
              validator: _validateTender),
          _field(_buyerDesignation, 'Buyer designation', 'क्रेता का पदनाम',
              helper: t('e.g. Commandant, Principal, Director', 'जैसे कमांडेंट, प्रिंसिपल, निदेशक'),
              caps: TextCapitalization.words),
          _field(_buyerOrg, 'Buyer organisation', 'क्रेता संस्था',
              caps: TextCapitalization.words),
          _field(_company, 'Company name', 'कंपनी का नाम'),
          const SizedBox(height: AppSpace.sm),
          Text(t('Specification rows', 'विशिष्टता पंक्तियाँ'), style: AppText.bodyStrong),
          const SizedBox(height: AppSpace.sm),
          Text(
            t('Add one row per specification parameter.', 'प्रत्येक विशिष्टता पैरामीटर के लिए एक पंक्ति जोड़ें।'),
            style: AppText.secondary(AppText.body),
          ),
          const SizedBox(height: AppSpace.md),
          for (var i = 0; i < _rows.length; i++) _rowCard(i),
          OutlinedButton.icon(
            onPressed: _addRow,
            icon: const Icon(Icons.add),
            label: Text(t('Add specification', 'विशिष्टता जोड़ें')),
          ),
          const SizedBox(height: AppSpace.lg),
          _field(_signatory, 'Signatory name', 'हस्ताक्षरकर्ता का नाम'),
          _field(_designation, 'Designation', 'पदनाम',
              helper: t('e.g. Proprietor, Director, Authorised Signatory',
                  'जैसे प्रोप्राइटर, निदेशक, अधिकृत हस्ताक्षरकर्ता')),
          ReassuranceNote(
            t('The letter is generated on your device. We do not upload or keep it.',
                'पत्र आपके डिवाइस पर ही बनता है।'),
          ),
        ],
      ),
    );
  }

  Widget _rowCard(int index) {
    final row = _rows[index];
    return AppCard(
      padding: const EdgeInsets.all(AppSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t('Spec ${index + 1}', 'विशिष्टता ${index + 1}'),
                  style: AppText.bodyStrong,
                ),
              ),
              if (_rows.length > 1)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _removeRow(index),
                  tooltip: t('Remove', 'हटाएँ'),
                ),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          _rowField(row.specParameter, 'Specification parameter', 'विशिष्टता पैरामीटर', index),
          _rowField(row.requiredValue, 'Required value / standard', 'आवश्यक मान / मानक', index),
          _rowField(row.offeredValue, 'Offered value / standard', 'प्रस्तावित मान / मानक', index),
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.md),
            child: DropdownButtonFormField<String>(
              initialValue: row.compliant,
              decoration: InputDecoration(
                labelText: t('Compliant', 'अनुपालक'),
              ),
              items: ['Yes', 'No']
                  .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() => row.compliant = v);
                _invalidateLetter();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _rowField(TextEditingController c, String en, String hi, int rowIndex) =>
      Padding(
        key: ValueKey('row-$rowIndex-$en'),
        padding: const EdgeInsets.only(bottom: AppSpace.md),
        child: TextFormField(
          controller: c,
          decoration: InputDecoration(labelText: t(en, hi)),
          validator: _required,
          onChanged: (_) {
            setState(() {});
            _invalidateLetter();
          },
        ),
      );

  List<Widget> _previewSection() {
    final i = _input!;
    final editing = _editors != null;
    return [
      DividedList(
        children: [
          KeyValueRow(t('Tender No.', 'टेंडर नं.'), i.tenderNo),
          KeyValueRow(t('Buyer', 'क्रेता'), '${i.buyerDesignation}, ${i.buyerOrg}'),
          KeyValueRow(t('Company', 'कंपनी'), i.company),
          KeyValueRow(t('Spec rows', 'विशिष्टता पंक्तियाँ'), '${i.specRows.length}'),
          KeyValueRow(t('Signatory', 'हस्ताक्षरकर्ता'), '${i.signatory} (${i.designation})'),
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
            label: editing ? t('Done editing', 'संपादन पूरा') : t('Edit text', 'टेक्स्ट बदलें'),
            variant: AppButtonVariant.tertiary,
            size: AppButtonSize.sm,
            expand: false,
            onPressed: editing ? _finishEditing : _startEditing,
          ),
        ],
      ),
      const SizedBox(height: AppSpace.xs),
      Text(
        t('You can edit the letter before printing. Edited paragraphs lose their bold styling.',
            'प्रिंट से पहले आप पत्र में बदलाव कर सकते हैं।'),
        style: AppText.caption,
      ),
      const SizedBox(height: AppSpace.lg),
      LetterPaper(blocks: _blocks!, editors: _editors),
      const SizedBox(height: AppSpace.lg),
      AppCard(
        tone: AppCardTone.muted,
        padding: const EdgeInsets.all(AppSpace.md),
        child: CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _confirmed,
          onChanged: editing ? null : (v) => setState(() => _confirmed = v ?? false),
          title: Text(
            t('I confirm these details are true. I understand a false declaration can lead to debarment.',
                'मैं पुष्टि करता/करती हूँ कि ये विवरण सही हैं।'),
            style: AppText.bodySmall,
          ),
        ),
      ),
    ];
  }

  Widget _helpSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t('How to generate Tech Specs Certificate', 'तकनीकी विशिष्टता प्रमाणपत्र कैसे बनाएँ'),
            style: AppText.h3),
        const SizedBox(height: AppSpace.sm),
        Text(t('Follow these steps:', 'इन चरणों का पालन करें:'), style: AppText.secondary(AppText.body)),
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
            t('Cross-check each specification against the tender document before submission.',
                'जमा करने से पहले टेंडर दस्तावेज़ की प्रत्येक विशिष्टता की जाँच करें।'),
            style: AppText.caption,
          ),
        ),
      ],
    );
  }

  List<(int, String, String)> _helpSteps() => [
    (1, t('Enter tender and buyer details', 'टेंडर और क्रेता विवरण दें'),
        t('Enter the GeM Bid number, buyer designation and buyer organisation.', 'GeM बिड नंबर, क्रेता का पदनाम और संस्था दर्ज करें।')),
    (2, t('Add specification rows', 'विशिष्टता पंक्तियाँ जोड़ें'),
        t('Add one row per parameter — the spec name, required value, your offered value, and whether it is compliant.', 'प्रत्येक पैरामीटर के लिए एक पंक्ति — विशिष्टता का नाम, आवश्यक मान, आपका प्रस्तावित मान और अनुपालन।')),
    (3, t('Enter signatory details', 'हस्ताक्षरकर्ता का विवरण दें'),
        t('Enter the authorised signatory\'s name and designation.', 'अधिकृत हस्ताक्षरकर्ता का नाम और पदनाम दर्ज करें।')),
    (4, t('Generate and submit', 'बनाएँ और जमा करें'),
        t('Click "Generate letter", review in Preview, tick the confirmation, then print or share.', '"पत्र बनाएँ" पर क्लिक करें, समीक्षा करें, पुष्टि टिक करें, फिर प्रिंट या साझा करें।')),
  ];
}

class _HelpStep extends StatelessWidget {
  final int number;
  final String title;
  final String body;
  const _HelpStep({required this.number, required this.title, required this.body});

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 28,
        height: 28,
        decoration: const ShapeDecoration(color: AppColors.ink, shape: CircleBorder()),
        alignment: Alignment.center,
        child: Text('$number',
            style: AppText.caption.copyWith(color: AppColors.surface, fontWeight: FontWeight.w700)),
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
