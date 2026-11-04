/// ATC Certificate (Acceptance of Terms and Conditions) generator.
/// Registered in tools_hub/tool_registry.dart, route `/tool-atc-certificate`.
///
/// 8-field form identical layout to financial_standing_page.dart.
/// No Udyam field; saves company/address/signatory/designation to profile.
library;

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../core/tokens.dart';
import '../../data/app_store.dart';
import '../components.dart';
import '../tools_hub/tool_page_scaffold.dart';
import 'atc_certificate_text.dart';
import 'letter_model.dart';
import 'letter_pdf.dart';
import 'letter_preview.dart';
import 'mii_certificate_page.dart' show BidDocProfileKeys;
import 'mii_certificate_text.dart' show looksLikeGemTenderNo;

enum _Step { details, preview }

class AtcCertificatePage extends StatefulWidget {
  final AppStore store;
  final String? tenderNo;

  const AtcCertificatePage({super.key, required this.store, this.tenderNo});

  @override
  State<AtcCertificatePage> createState() => _AtcCertificatePageState();
}

class _AtcCertificatePageState extends State<AtcCertificatePage> {
  final _form = GlobalKey<FormState>();
  final _scroll = ScrollController();

  late final TextEditingController _tenderNo;
  late final TextEditingController _recipientTitle;
  late final TextEditingController _organization;
  late final TextEditingController _organizationAddress;
  late final TextEditingController _company;
  late final TextEditingController _companyAddress;
  late final TextEditingController _signatory;
  late final TextEditingController _designation;

  _Step _step = _Step.details;
  AtcCertificateInput? _input;
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
    s.event('page_view', page: 'tool-atc-certificate');
    final p = s.profile;
    String pv(String k) => (p[k] as String?)?.trim() ?? '';
    _tenderNo = TextEditingController(text: widget.tenderNo ?? '');
    _recipientTitle = TextEditingController();
    _organization = TextEditingController();
    _organizationAddress = TextEditingController();
    _company = TextEditingController(text: pv(BidDocProfileKeys.companyName));
    _companyAddress = TextEditingController(
      text: pv(BidDocProfileKeys.companyAddress),
    );
    final signatory = pv(BidDocProfileKeys.signatoryName);
    _signatory = TextEditingController(
      text: signatory.isNotEmpty
          ? signatory
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

  String? _required(String? v) => (v == null || v.trim().isEmpty)
      ? t('This is required', 'यह आवश्यक है')
      : null;

  // ----------------------------------------------------------------- actions

  void _generate() {
    if (!_form.currentState!.validate()) return;
    _disposeEditors();
    final input = AtcCertificateInput(
      tenderNo: _tenderNo.text.trim().toUpperCase(),
      recipientTitle: _recipientTitle.text.trim(),
      organization: _organization.text.trim(),
      organizationAddress: _organizationAddress.text.trim(),
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
      _blocks = buildAtcCertificate(input);
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
      _companyAddress,
      _designation,
    ]) {
      c.clear();
    }
    _disposeEditors();
    setState(() {
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
      'ATC Certificate - ${(_input?.tenderNo ?? '').replaceAll('/', '-')}';

  Future<void> _print() async {
    setState(() => _busy = true);
    try {
      s.event(
        'document_generated',
        page: 'tool-atc-certificate',
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
        page: 'tool-atc-certificate',
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
      title: t('ATC Certificate', 'नियम एवं शर्त स्वीकृति प्रमाण'),
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
            'Fill in the required details to generate your ATC Certificate — formally accept all additional terms and conditions associated with a GeM bid.',
            'ATC प्रमाणपत्र बनाने के लिए आवश्यक जानकारी भरें — GeM बिड से जुड़ी सभी अतिरिक्त नियम व शर्तें औपचारिक रूप से स्वीकार करें।',
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
          _field(
            _tenderNo,
            'Tender / bid number',
            'निविदा / बोली संख्या',
            caps: TextCapitalization.characters,
            helper: t('e.g. GEM/2026/B/7845020', 'जैसे GEM/2026/B/7845020'),
            validator: (v) {
              final base = _required(v);
              if (base != null) return base;
              if (!looksLikeGemTenderNo(v!)) {
                return t(
                  'This doesn\'t look like a GeM bid number (e.g. GEM/2026/B/7845020). Double-check before generating.',
                  'यह GeM बोली संख्या जैसी नहीं लगती। बनाने से पहले जाँचें।',
                );
              }
              return null;
            },
          ),
          _field(
            _recipientTitle,
            'Recipient title',
            'प्राप्तकर्ता का शीर्षक',
            helper: t(
              'e.g. The Commandant, The Director General',
              'जैसे The Commandant, The Director General',
            ),
            caps: TextCapitalization.words,
          ),
          _field(
            _organization,
            'Organization',
            'संगठन',
            helper: t(
              'e.g. Indian Army, Punjab National Bank',
              'जैसे Indian Army, Punjab National Bank',
            ),
            caps: TextCapitalization.words,
          ),
          _field(
            _organizationAddress,
            'Organization address',
            'संगठन का पता',
            caps: TextCapitalization.words,
          ),
          _field(_company, 'Company name', 'कंपनी का नाम'),
          _field(
            _companyAddress,
            'Company address',
            'कंपनी का पता',
            caps: TextCapitalization.words,
          ),
          _field(_signatory, 'Signatory name', 'हस्ताक्षरकर्ता का नाम'),
          _field(
            _designation,
            'Designation',
            'पदनाम',
            helper: t(
              'e.g. Proprietor, Director, Authorised Signatory',
              'जैसे प्रोप्राइटर, निदेशक, अधिकृत हस्ताक्षरकर्ता',
            ),
          ),
          ReassuranceNote(
            t(
              'The letter is generated on your device. We do not upload or keep it — only your company details are remembered so you do not retype them.',
              'पत्र आपके डिवाइस पर ही बनता है। हम इसे अपलोड या सेव नहीं करते — केवल कंपनी का विवरण याद रखा जाता है।',
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
          KeyValueRow(t('Tender no.', 'निविदा संख्या'), i.tenderNo),
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
          t('How to generate ATC Certificate', 'ATC प्रमाणपत्र कैसे बनाएँ'),
          style: AppText.h3,
        ),
        const SizedBox(height: AppSpace.sm),
        Text(
          t(
            'Follow these steps to generate your certificate:',
            'प्रमाणपत्र बनाने के लिए इन चरणों का पालन करें:',
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
              'Please review all additional terms and conditions in the tender documents before submitting this certificate.',
              'यह प्रमाणपत्र जमा करने से पहले निविदा दस्तावेज़ों में सभी अतिरिक्त नियम व शर्तें ध्यान से पढ़ें।',
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
      t('Enter the tender number', 'निविदा संख्या दर्ज करें'),
      t(
        'Enter the official GeM Bid Number exactly as it appears in the tender documents.',
        'आधिकारिक GeM बोली संख्या वैसे ही दर्ज करें जैसे निविदा दस्तावेज़ों में है।',
      ),
    ),
    (
      2,
      t('Enter recipient information', 'प्राप्तकर्ता की जानकारी दें'),
      t(
        'Enter the Recipient Title, Organization name, and address from the tender documents.',
        'निविदा दस्तावेज़ों से प्राप्तकर्ता का शीर्षक, संगठन का नाम और पता दर्ज करें।',
      ),
    ),
    (
      3,
      t('Enter your company information', 'कंपनी की जानकारी दें'),
      t(
        'Enter your Company Name as registered, company address, signatory name and designation.',
        'अपना पंजीकृत कंपनी नाम, कंपनी का पता, हस्ताक्षरकर्ता का नाम और पदनाम दर्ज करें।',
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
