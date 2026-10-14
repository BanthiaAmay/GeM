/// Non-Blacklisting / Non-Blacklist Certificate (undertaking) generator.
/// Registered in tools_hub/tool_registry.dart, route `/tool-nbc`.
///
/// Follows the same pattern as [MiiCertificatePage]: Details ↔ Preview segmented
/// control, Offstage form, LetterPaper preview, print/PDF via the printing
/// package, profile pre-fill, scroll-to-top on generate.
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
import 'non_blacklist_certificate_text.dart';

/// NBC-specific profile keys (company/signatory keys re-used from
/// [BidDocProfileKeys] so data entered for MII pre-fills here too).
abstract final class NbcProfileKeys {
  /// Preferred recipient title (tender-specific; not saved to profile).
  // Intentionally empty — recipient info varies per tender.
}

enum _Step { details, preview }

class NonBlacklistCertificatePage extends StatefulWidget {
  final AppStore store;
  final String? tenderNo;

  const NonBlacklistCertificatePage({
    super.key,
    required this.store,
    this.tenderNo,
  });

  @override
  State<NonBlacklistCertificatePage> createState() =>
      _NonBlacklistCertificatePageState();
}

class _NonBlacklistCertificatePageState
    extends State<NonBlacklistCertificatePage> {
  final _form = GlobalKey<FormState>();
  final _scroll = ScrollController();

  // Form controllers — tender-specific fields start empty; profile fields
  // are pre-filled from the shared bid-doc profile bag.
  late final TextEditingController _recipient;
  late final TextEditingController _organization;
  late final TextEditingController _address;
  late final TextEditingController _tenderNo;
  late final TextEditingController _company;
  late final TextEditingController _companyAddress;
  late final TextEditingController _signatory;
  late final TextEditingController _designation;

  _Step _step = _Step.details;
  NbcInput? _input;
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
    s.event('page_view', page: 'tool-nbc');
    final p = s.profile;
    String pv(String k) => (p[k] as String?)?.trim() ?? '';
    _recipient = TextEditingController();
    _organization = TextEditingController();
    _address = TextEditingController();
    _tenderNo = TextEditingController(text: widget.tenderNo ?? '');
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
      _recipient,
      _organization,
      _address,
      _tenderNo,
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

  // ----------------------------------------------------------- validation

  String? _required(String? v) => (v == null || v.trim().isEmpty)
      ? t('This is required', 'यह आवश्यक है')
      : null;

  // ------------------------------------------------------------ actions

  void _generate() {
    if (!_form.currentState!.validate()) return;
    _disposeEditors();
    final input = NbcInput(
      recipient: _recipient.text.trim(),
      organization: _organization.text.trim(),
      address: _address.text.trim(),
      tenderNo: _tenderNo.text.trim().toUpperCase(),
      company: _company.text.trim(),
      companyAddress: _companyAddress.text.trim(),
      signatory: _signatory.text.trim(),
      designation: _designation.text.trim(),
      date: DateTime.now(),
    );
    // Save reusable company details; tender-specific fields are not saved.
    s.setProfile(BidDocProfileKeys.companyName, input.company);
    s.setProfile(BidDocProfileKeys.companyAddress, input.companyAddress);
    s.setProfile(BidDocProfileKeys.signatoryName, input.signatory);
    s.setProfile(BidDocProfileKeys.signatoryDesignation, input.designation);

    setState(() {
      _input = input;
      _blocks = buildNbcCertificate(input);
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
      _recipient,
      _organization,
      _address,
      _tenderNo,
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
        b.isSpacer
            ? b
            : LetterBlock.plain(b.kind, _editors![i++].text),
    ];
    _disposeEditors();
    setState(() {
      _blocks = edited;
      _confirmed = false;
    });
  }

  String get _fileStem =>
      'Non Blacklist Certificate - ${(_input?.tenderNo ?? '').replaceAll('/', '-')}';

  Future<void> _print() async {
    setState(() => _busy = true);
    try {
      s.event('document_generated', page: 'tool-nbc', props: {'action': 'print'});
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
      s.event('document_generated', page: 'tool-nbc', props: {'action': 'share'});
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
          t('Tick the confirmation first.', 'पहले पुष्टि वाले बॉक्स पर टिक करें।'),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final previewing = _step == _Step.preview && _blocks != null;
    final editing = _editors != null;
    return ToolPageScaffold(
      store: s,
      scrollController: _scroll,
      title: t('Non Blacklist Certificate', 'गैर-ब्लैकलिस्ट प्रमाणपत्र'),
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
                  ? t('Generate certificate', 'प्रमाणपत्र बनाएँ')
                  : t('Update certificate', 'प्रमाणपत्र अपडेट करें'),
              onPressed: _generate,
            ),
      children: [
        Text(
          t(
            'Fill in the required details to generate your Non-Blacklisting Certificate — a declaration that your company has not been debarred or blacklisted by any government entity.',
            'गैर-ब्लैकलिस्टिंग प्रमाणपत्र बनाने के लिए आवश्यक जानकारी भरें — यह घोषणा कि आपकी कंपनी को किसी सरकारी संस्था ने प्रतिबंधित या ब्लैकलिस्ट नहीं किया है।',
          ),
          style: AppText.secondary(AppText.body),
        ),
        const SizedBox(height: AppSpace.xl),
        AppSegmentedControl<_Step>(
          semanticLabel: t('Certificate step', 'प्रमाणपत्र का चरण'),
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

  // ---------------------------------------------------------------- form

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
            _recipient,
            'Recipient (To)',
            'प्राप्तकर्ता (को)',
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
            _address,
            'Address',
            'पता',
            caps: TextCapitalization.words,
          ),
          _field(
            _tenderNo,
            'Tender / bid number',
            'निविदा / बोली संख्या',
            caps: TextCapitalization.characters,
            helper: t('e.g. GEM/2026/B/7845020', 'जैसे GEM/2026/B/7845020'),
          ),
          _field(
            _company,
            'Company name',
            'कंपनी का नाम',
          ),
          _field(
            _companyAddress,
            'Company address',
            'कंपनी का पता',
            helper: t(
              'Stored for future certificates; not shown in Template 1.',
              'भविष्य के प्रमाणपत्रों के लिए सहेजा जाएगा; टेम्प्लेट 1 में नहीं दिखेगा।',
            ),
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
              'The certificate is generated on your device. We do not upload or keep it — only your company details are remembered so you do not retype them.',
              'प्रमाणपत्र आपके डिवाइस पर ही बनता है। हम इसे अपलोड या सेव नहीं करते — केवल कंपनी का विवरण याद रखा जाता है।',
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- preview

  List<Widget> _previewSection() {
    final i = _input!;
    final editing = _editors != null;
    return [
      DividedList(
        children: [
          KeyValueRow(t('Tender no.', 'निविदा संख्या'), i.tenderNo),
          KeyValueRow(t('Company', 'कंपनी'), i.company),
          KeyValueRow(t('Recipient', 'प्राप्तकर्ता'), i.recipient),
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

  // --------------------------------------------------------------- help

  Widget _helpSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t(
            'How to generate Non Blacklist Certificate',
            'गैर-ब्लैकलिस्ट प्रमाणपत्र कैसे बनाएँ',
          ),
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
              'Please verify the tender\'s specific document requirements and declaration wording before submission.',
              'जमा करने से पहले निविदा की विशिष्ट दस्तावेज़ आवश्यकताओं और घोषणा शब्दों की जाँच करें।',
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
      t('Enter recipient information', 'प्राप्तकर्ता की जानकारी दें'),
      t(
        'Fill in the Recipient (To) field with the designation of the person you are addressing, such as "The Commandant". Add the Organization name and their full address.',
        '"प्राप्तकर्ता (को)" में संबोधित व्यक्ति का पदनाम जैसे "The Commandant" भरें। संगठन का नाम और पूरा पता भरें।',
      ),
    ),
    (
      2,
      t('Provide tender details', 'निविदा विवरण दें'),
      t(
        'Enter the official Tender / Bid Number exactly as it appears in the tender documents. For example: GEM/2026/B/7845020.',
        'आधिकारिक निविदा / बोली संख्या वैसे ही दर्ज करें जैसे निविदा दस्तावेज़ों में है। उदाहरण: GEM/2026/B/7845020।',
      ),
    ),
    (
      3,
      t('Enter your company information', 'कंपनी की जानकारी दें'),
      t(
        'Enter your Company Name as registered. Add the Signatory Name (the person signing the document) and their Designation, such as Director or Authorised Signatory.',
        'अपना पंजीकृत कंपनी नाम दर्ज करें। हस्ताक्षरकर्ता का नाम और पदनाम जैसे Director या Authorised Signatory जोड़ें।',
      ),
    ),
    (
      4,
      t('Generate your certificate', 'प्रमाणपत्र बनाएँ'),
      t(
        'Click "Generate certificate". Review the document in the Preview tab and use "Edit text" to make any corrections before printing.',
        '"प्रमाणपत्र बनाएँ" पर क्लिक करें। Preview टैब में दस्तावेज़ देखें और प्रिंट से पहले "टेक्स्ट बदलें" से सुधार करें।',
      ),
    ),
    (
      5,
      t('Download, sign and submit', 'डाउनलोड करें, हस्ताक्षर करें और जमा करें'),
      t(
        'Tick the confirmation checkbox, then print or save as PDF. Have it signed by the authorised signatory and attach it to your tender submission.',
        'पुष्टि चेकबॉक्स टिक करें, फिर प्रिंट करें या PDF सेव करें। अधिकृत हस्ताक्षरकर्ता से हस्ताक्षर करवाकर निविदा के साथ संलग्न करें।',
      ),
    ),
  ];
}

// ---------------------------------------------------------------- help step widget

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
