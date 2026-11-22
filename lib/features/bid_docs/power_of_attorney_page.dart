/// Power of Attorney generator.
/// Route: `/tool-power-of-attorney`
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
import 'power_of_attorney_text.dart';

enum _Step { details, preview }

class PowerOfAttorneyPage extends StatefulWidget {
  final AppStore store;
  final String? tenderNo;
  const PowerOfAttorneyPage({super.key, required this.store, this.tenderNo});

  @override
  State<PowerOfAttorneyPage> createState() => _PowerOfAttorneyPageState();
}

class _PowerOfAttorneyPageState extends State<PowerOfAttorneyPage> {
  final _form = GlobalKey<FormState>();
  final _scroll = ScrollController();

  late final TextEditingController _tenderNo;
  late final TextEditingController _company;
  late final TextEditingController _legalBasis;
  late final TextEditingController _cinRegNo;
  late final TextEditingController _registeredAddress;
  late final TextEditingController _buyerOrg;
  late final TextEditingController _attorneyName;
  late final TextEditingController _attorneyDesignation;
  late final TextEditingController _attorneyAddress;
  late final TextEditingController _attorneyPan;
  late final TextEditingController _executorName;
  late final TextEditingController _executorDesignation;

  _Step _step = _Step.details;
  PowerOfAttorneyInput? _input;
  List<LetterBlock>? _blocks;
  List<TextEditingController>? _editors;
  bool _confirmed = false;
  bool _busy = false;

  AppStore get s => widget.store;
  String t(String en, String hi) => s.t(en, hi);

  @override
  void initState() {
    super.initState();
    s.event('page_view', page: 'tool-power-of-attorney');
    final p = s.profile;
    String pv(String k) => (p[k] as String?)?.trim() ?? '';
    _tenderNo = TextEditingController(text: widget.tenderNo ?? '');
    _company = TextEditingController(text: pv(BidDocProfileKeys.companyName));
    _legalBasis = TextEditingController();
    _cinRegNo = TextEditingController();
    _registeredAddress = TextEditingController();
    _buyerOrg = TextEditingController();
    _attorneyName = TextEditingController();
    _attorneyDesignation = TextEditingController();
    _attorneyAddress = TextEditingController();
    _attorneyPan = TextEditingController();
    _executorName = TextEditingController();
    _executorDesignation = TextEditingController();
  }

  @override
  void dispose() {
    _scroll.dispose();
    for (final c in [
      _tenderNo, _company, _legalBasis, _cinRegNo, _registeredAddress, _buyerOrg,
      _attorneyName, _attorneyDesignation, _attorneyAddress, _attorneyPan,
      _executorName, _executorDesignation,
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

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? t('This is required', 'यह आवश्यक है') : null;

  String? _validateTender(String? v) {
    if (v == null || v.trim().isEmpty) return t('This is required', 'यह आवश्यक है');
    if (!looksLikeGemTenderNo(v.trim())) {
      return t('Enter a valid GeM Bid / Tender number', 'सही GeM बिड / टेंडर नंबर दर्ज करें');
    }
    return null;
  }

  String? _validatePan(String? v) {
    if (v == null || v.trim().isEmpty) return t('This is required', 'यह आवश्यक है');
    final val = v.trim().toUpperCase();
    if (val.length != 10) return t('PAN must be 10 characters', 'PAN 10 अक्षरों का होना चाहिए');
    return null;
  }

  void _generate() {
    if (!_form.currentState!.validate()) return;
    _disposeEditors();
    final input = PowerOfAttorneyInput(
      tenderNo: _tenderNo.text.trim(),
      company: _company.text.trim(),
      legalBasis: _legalBasis.text.trim(),
      cinRegNo: _cinRegNo.text.trim(),
      registeredAddress: _registeredAddress.text.trim(),
      buyerOrg: _buyerOrg.text.trim(),
      attorneyName: _attorneyName.text.trim(),
      attorneyDesignation: _attorneyDesignation.text.trim(),
      attorneyAddress: _attorneyAddress.text.trim(),
      attorneyPan: _attorneyPan.text.trim().toUpperCase(),
      executorName: _executorName.text.trim(),
      executorDesignation: _executorDesignation.text.trim(),
      date: DateTime.now(),
    );
    s.setProfile(BidDocProfileKeys.companyName, input.company);
    setState(() {
      _input = input;
      _blocks = buildPowerOfAttorney(input);
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
      _tenderNo, _company, _legalBasis, _cinRegNo, _registeredAddress, _buyerOrg,
      _attorneyName, _attorneyDesignation, _attorneyAddress, _attorneyPan,
      _executorName, _executorDesignation,
    ]) {
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
      'Power-of-Attorney - ${(_input?.company ?? '').replaceAll(' ', '_')}';

  Future<void> _print() async {
    setState(() => _busy = true);
    try {
      s.event('document_generated', page: 'tool-power-of-attorney', props: {'action': 'print'});
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
      s.event('document_generated', page: 'tool-power-of-attorney', props: {'action': 'share'});
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
      title: t('Power of Attorney', 'मुख्तारनामा'),
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
            'Authorise a representative to sign and submit bid documents on behalf of your company.',
            'अपनी कंपनी की ओर से बिड दस्तावेज़ साइन और जमा करने के लिए एक प्रतिनिधि को अधिकृत करें।',
          ),
          style: AppText.secondary(AppText.body),
        ),
        const SizedBox(height: AppSpace.sm),
        AppCard(
          tone: AppCardTone.muted,
          padding: const EdgeInsets.all(AppSpace.md),
          child: Text(
            t(
              'This document must be executed on stamp paper of appropriate value and notarized before submission.',
              'यह दस्तावेज़ उचित मूल्य के स्टाम्प पेपर पर निष्पादित और नोटराइज़ किया जाना चाहिए।',
            ),
            style: AppText.caption,
          ),
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
          Text(t('Tender & Company', 'टेंडर और कंपनी'), style: AppText.bodyStrong),
          const SizedBox(height: AppSpace.md),
          _field(_tenderNo, 'GeM Bid / Tender number', 'GeM बिड / टेंडर नंबर',
              validator: _validateTender),
          _field(_company, 'Company name', 'कंपनी का नाम'),
          _field(_legalBasis, 'Legal basis of incorporation', 'निगमन का कानूनी आधार',
              helper: t('e.g. the Companies Act, 2013 / the Indian Partnership Act, 1932',
                  'जैसे the Companies Act, 2013')),
          _field(_cinRegNo, 'CIN / Registration number', 'CIN / पंजीकरण संख्या',
              helper: t('Company Identification Number or Registration No.', 'CIN या पंजीकरण नंबर')),
          _field(_registeredAddress, 'Registered office address', 'पंजीकृत कार्यालय का पता',
              caps: TextCapitalization.words),
          _field(_buyerOrg, 'Buyer organisation', 'क्रेता संस्था',
              caps: TextCapitalization.words),
          const SizedBox(height: AppSpace.md),
          Text(t('Attorney (Authorised Person)', 'अटॉर्नी (अधिकृत व्यक्ति)'), style: AppText.bodyStrong),
          const SizedBox(height: AppSpace.md),
          _field(_attorneyName, 'Attorney name', 'अटॉर्नी का नाम'),
          _field(_attorneyDesignation, 'Attorney designation', 'अटॉर्नी का पदनाम'),
          _field(_attorneyAddress, 'Attorney address', 'अटॉर्नी का पता',
              caps: TextCapitalization.words),
          _field(_attorneyPan, 'Attorney PAN', 'अटॉर्नी का PAN',
              validator: _validatePan,
              helper: t('10-character PAN, e.g. ABCDE1234F', '10 अक्षरों का PAN, जैसे ABCDE1234F'),
              caps: TextCapitalization.characters),
          const SizedBox(height: AppSpace.md),
          Text(t('Executor (Signing Authority)', 'निष्पादक (हस्ताक्षर प्राधिकरण)'), style: AppText.bodyStrong),
          const SizedBox(height: AppSpace.md),
          _field(_executorName, 'Executor name', 'निष्पादक का नाम',
              helper: t('Director / Partner / Proprietor executing this PoA',
                  'इस PoA पर हस्ताक्षर करने वाले निदेशक/साझेदार/स्वामी')),
          _field(_executorDesignation, 'Executor designation', 'निष्पादक का पदनाम'),
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
          KeyValueRow(t('Company', 'कंपनी'), i.company),
          KeyValueRow(t('Buyer Org', 'क्रेता संस्था'), i.buyerOrg),
          KeyValueRow(t('Attorney', 'अटॉर्नी'), '${i.attorneyName} (${i.attorneyDesignation})'),
          KeyValueRow('PAN', i.attorneyPan),
          KeyValueRow(t('Executor', 'निष्पादक'), '${i.executorName} (${i.executorDesignation})'),
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
        Text(t('How to generate Power of Attorney', 'मुख्तारनामा कैसे बनाएँ'), style: AppText.h3),
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
              'This document must be executed on stamp paper of appropriate value and notarized. Consult a legal advisor for the correct stamp duty value in your state.',
              'यह दस्तावेज़ उचित मूल्य के स्टाम्प पेपर पर निष्पादित और नोटराइज़ किया जाना चाहिए। सही स्टाम्प शुल्क के लिए कानूनी सलाहकार से परामर्श लें।',
            ),
            style: AppText.caption,
          ),
        ),
      ],
    );
  }

  List<(int, String, String)> _helpSteps() => [
    (1, t('Enter tender and company details', 'टेंडर और कंपनी विवरण दें'),
        t('Enter the GeM Bid number, company name, legal basis, CIN/registration number, registered address, and buyer organisation.', 'GeM बिड नंबर, कंपनी का नाम, कानूनी आधार, CIN, पंजीकृत पता और क्रेता संस्था दर्ज करें।')),
    (2, t('Enter attorney details', 'अटॉर्नी का विवरण दें'),
        t('Enter the name, designation, address and PAN of the person being authorised.', 'अधिकृत किए जाने वाले व्यक्ति का नाम, पदनाम, पता और PAN दर्ज करें।')),
    (3, t('Enter executor details', 'निष्पादक का विवरण दें'),
        t('Enter the name and designation of the director/partner/proprietor executing this PoA.', 'इस PoA पर हस्ताक्षर करने वाले निदेशक/साझेदार/स्वामी का नाम और पदनाम दर्ज करें।')),
    (4, t('Generate, notarize and submit', 'बनाएँ, नोटराइज़ करें और जमा करें'),
        t('Generate the draft, review it, then execute on stamp paper and get it notarized before attaching to your bid.', 'ड्राफ्ट बनाएँ, समीक्षा करें, फिर स्टाम्प पेपर पर निष्पादित करें और बिड से जोड़ने से पहले नोटराइज़ करें।')),
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
