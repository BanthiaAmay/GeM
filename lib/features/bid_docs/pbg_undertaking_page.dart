/// Performance Bank Guarantee Undertaking generator.
/// Route: `/tool-pbg-undertaking`
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
import 'pbg_undertaking_text.dart';

enum _Step { details, preview }

class PbgUndertakingPage extends StatefulWidget {
  final AppStore store;
  final String? tenderNo;
  const PbgUndertakingPage({super.key, required this.store, this.tenderNo});

  @override
  State<PbgUndertakingPage> createState() => _PbgUndertakingPageState();
}

class _PbgUndertakingPageState extends State<PbgUndertakingPage> {
  final _form = GlobalKey<FormState>();
  final _scroll = ScrollController();

  late final TextEditingController _tenderNo;
  late final TextEditingController _buyerDesignation;
  late final TextEditingController _buyerOrg;
  late final TextEditingController _company;
  late final TextEditingController _pbgPercent;
  late final TextEditingController _pbgDays;
  late final TextEditingController _signatory;
  late final TextEditingController _designation;

  _Step _step = _Step.details;
  PbgUndertakingInput? _input;
  List<LetterBlock>? _blocks;
  List<TextEditingController>? _editors;
  bool _confirmed = false;
  bool _busy = false;

  AppStore get s => widget.store;
  String t(String en, String hi) => s.t(en, hi);

  @override
  void initState() {
    super.initState();
    s.event('page_view', page: 'tool-pbg-undertaking');
    final p = s.profile;
    String pv(String k) => (p[k] as String?)?.trim() ?? '';
    _tenderNo = TextEditingController(text: widget.tenderNo ?? '');
    _buyerDesignation = TextEditingController();
    _buyerOrg = TextEditingController();
    _company = TextEditingController(text: pv(BidDocProfileKeys.companyName));
    _pbgPercent = TextEditingController();
    _pbgDays = TextEditingController();
    final signatory = pv(BidDocProfileKeys.signatoryName);
    _signatory = TextEditingController(
      text: signatory.isNotEmpty ? signatory : pv(BidDocProfileKeys.fallbackSignatory),
    );
    _designation = TextEditingController(text: pv(BidDocProfileKeys.signatoryDesignation));
  }

  @override
  void dispose() {
    _scroll.dispose();
    for (final c in [_tenderNo, _buyerDesignation, _buyerOrg, _company, _pbgPercent, _pbgDays, _signatory, _designation]) {
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

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? t('This is required', 'यह आवश्यक है') : null;

  String? _validateTender(String? v) {
    if (v == null || v.trim().isEmpty) return t('This is required', 'यह आवश्यक है');
    if (!looksLikeGemTenderNo(v.trim())) {
      return t('Enter a valid GeM Bid / Tender number', 'सही GeM बिड / टेंडर नंबर दर्ज करें');
    }
    return null;
  }

  void _generate() {
    if (!_form.currentState!.validate()) return;
    _disposeEditors();
    final input = PbgUndertakingInput(
      tenderNo: _tenderNo.text.trim(),
      buyerDesignation: _buyerDesignation.text.trim(),
      buyerOrg: _buyerOrg.text.trim(),
      company: _company.text.trim(),
      pbgPercent: _pbgPercent.text.trim(),
      pbgDays: _pbgDays.text.trim(),
      signatory: _signatory.text.trim(),
      designation: _designation.text.trim(),
      date: DateTime.now(),
    );
    s.setProfile(BidDocProfileKeys.companyName, input.company);
    s.setProfile(BidDocProfileKeys.signatoryName, input.signatory);
    s.setProfile(BidDocProfileKeys.signatoryDesignation, input.designation);
    setState(() {
      _input = input;
      _blocks = buildPbgUndertaking(input);
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
    for (final c in [_tenderNo, _buyerDesignation, _buyerOrg, _company, _pbgPercent, _pbgDays, _signatory, _designation]) {
      c.clear();
    }
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
      'PBG-Undertaking - ${(_input?.company ?? '').replaceAll(' ', '_')}';

  Future<void> _print() async {
    setState(() => _busy = true);
    try {
      s.event('document_generated', page: 'tool-pbg-undertaking', props: {'action': 'print'});
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
      s.event('document_generated', page: 'tool-pbg-undertaking', props: {'action': 'share'});
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
      title: t('Performance Bank Guarantee Undertaking', 'परफॉर्मेंस बैंक गारंटी उपक्रम'),
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
            'Undertake to furnish a Performance Bank Guarantee if awarded the contract.',
            'यदि अनुबंध मिलता है तो परफॉर्मेंस बैंक गारंटी देने का उपक्रम करें।',
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
    TextInputType? keyboard,
    TextCapitalization caps = TextCapitalization.none,
  }) => Padding(
    key: ValueKey(en),
    padding: const EdgeInsets.only(bottom: AppSpace.lg),
    child: TextFormField(
      controller: c,
      keyboardType: keyboard,
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
          _field(_pbgPercent, 'PBG percentage', 'PBG प्रतिशत',
              helper: t('e.g. 3% or 5% (as specified in the bid)', 'जैसे 3% या 5% (बिड में उल्लिखित)')),
          _field(_pbgDays, 'Days to furnish PBG', 'PBG देने के लिए दिन',
              helper: t('Working days after award, e.g. 15', 'पुरस्कार के बाद कार्य-दिवस, जैसे 15'),
              keyboard: TextInputType.number),
          _field(_signatory, 'Signatory name', 'हस्ताक्षरकर्ता का नाम'),
          _field(_designation, 'Designation', 'पदनाम',
              helper: t('e.g. Proprietor, Director, Authorised Signatory',
                  'जैसे प्रोप्राइटर, निदेशक, अधिकृत हस्ताक्षरकर्ता')),
          ReassuranceNote(
            t(
              'The letter is generated on your device. We do not upload or keep it.',
              'पत्र आपके डिवाइस पर ही बनता है। हम इसे अपलोड या सेव नहीं करते।',
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _previewSection() {
    final i = _input!;
    final editing = _editors != null;
    return [
      DividedList(
        children: [
          KeyValueRow(t('Tender No.', 'टेंडर नं.'), i.tenderNo),
          KeyValueRow(t('Buyer', 'क्रेता'), '${i.buyerDesignation}, ${i.buyerOrg}'),
          KeyValueRow(t('Company', 'कंपनी'), i.company),
          KeyValueRow(t('PBG %', 'PBG %'), i.pbgPercent),
          KeyValueRow(t('Days to furnish', 'देने के लिए दिन'), i.pbgDays),
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
        t(
          'You can edit the letter before printing. Edited paragraphs lose their bold styling.',
          'प्रिंट से पहले आप पत्र में बदलाव कर सकते हैं।',
        ),
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
            t(
              'I confirm these details are true. I understand a false declaration can lead to debarment.',
              'मैं पुष्टि करता/करती हूँ कि ये विवरण सही हैं।',
            ),
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
        Text(t('How to generate PBG Undertaking', 'PBG उपक्रम कैसे बनाएँ'), style: AppText.h3),
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
            t(
              'Verify the tender\'s PBG percentage and submission timeline before generating.',
              'बनाने से पहले टेंडर का PBG प्रतिशत और जमा की समय-सीमा की जाँच करें।',
            ),
            style: AppText.caption,
          ),
        ),
      ],
    );
  }

  List<(int, String, String)> _helpSteps() => [
    (1, t('Enter tender and buyer details', 'टेंडर और क्रेता विवरण दें'),
        t('Enter the GeM Bid number, buyer designation and buyer organisation.', 'GeM बिड नंबर, क्रेता का पदनाम और संस्था दर्ज करें।')),
    (2, t('Enter PBG details', 'PBG विवरण दें'),
        t('Enter the PBG percentage and working days to furnish it after award.', 'PBG प्रतिशत और पुरस्कार के बाद इसे देने के कार्य-दिवस दर्ज करें।')),
    (3, t('Enter company and signatory', 'कंपनी और हस्ताक्षरकर्ता दें'),
        t('Enter company name and the authorised signatory\'s details.', 'कंपनी का नाम और अधिकृत हस्ताक्षरकर्ता का विवरण दर्ज करें।')),
    (4, t('Generate and submit', 'बनाएँ और जमा करें'),
        t('Click "Generate letter", review in Preview, tick the confirmation, then print or share.', '"पत्र बनाएँ" पर क्लिक करें, Preview में देखें, पुष्टि टिक करें, फिर प्रिंट या साझा करें।')),
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
