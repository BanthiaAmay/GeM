/// Escalation Matrix generator — route `/tool-escalation`.
///
/// Registered in tools_hub/tool_registry.dart.
/// Follows the same Details ↔ Preview pattern as MiiCertificatePage:
/// Offstage form, LetterPaper preview, print/PDF via the printing package,
/// profile pre-fill, scroll-to-top on generate.
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
import 'escalation_matrix_text.dart';

enum _Step { details, preview }

class EscalationMatrixPage extends StatefulWidget {
  final AppStore store;
  final String? tenderNo;

  const EscalationMatrixPage({
    super.key,
    required this.store,
    this.tenderNo,
  });

  @override
  State<EscalationMatrixPage> createState() => _EscalationMatrixPageState();
}

class _EscalationMatrixPageState extends State<EscalationMatrixPage> {
  final _form = GlobalKey<FormState>();
  final _scroll = ScrollController();

  // ── Header fields ──────────────────────────────────────────────────────────
  late final TextEditingController _tenderNo;
  late final TextEditingController _signatory;
  late final TextEditingController _designation;
  late final TextEditingController _company;

  // ── Primary contact (required) ─────────────────────────────────────────────
  late final TextEditingController _primName;
  late final TextEditingController _primPosition;
  late final TextEditingController _primEmail;
  late final TextEditingController _primPhone;

  // ── Secondary contact (optional, all-or-nothing) ───────────────────────────
  late final TextEditingController _secName;
  late final TextEditingController _secPosition;
  late final TextEditingController _secEmail;
  late final TextEditingController _secPhone;

  // ── Additional contact (optional, all-or-nothing) ──────────────────────────
  late final TextEditingController _addName;
  late final TextEditingController _addPosition;
  late final TextEditingController _addEmail;
  late final TextEditingController _addPhone;

  _Step _step = _Step.details;
  EscalationMatrixInput? _input;
  List<LetterBlock>? _blocks;
  List<TextEditingController>? _editors;
  double _extraTop = 0;
  bool _confirmed = false;
  bool _busy = false;

  AppStore get s => widget.store;
  String t(String en, String hi) => s.t(en, hi);

  List<TextEditingController> get _secGroup =>
      [_secName, _secPosition, _secEmail, _secPhone];
  List<TextEditingController> get _addGroup =>
      [_addName, _addPosition, _addEmail, _addPhone];

  bool _groupAnyFilled(List<TextEditingController> g) =>
      g.any((c) => c.text.trim().isNotEmpty);

  @override
  void initState() {
    super.initState();
    s.event('page_view', page: 'tool-escalation');
    final p = s.profile;
    String pv(String k) => (p[k] as String?)?.trim() ?? '';
    _tenderNo = TextEditingController(text: widget.tenderNo ?? '');
    final sig = pv(BidDocProfileKeys.signatoryName);
    _signatory = TextEditingController(
      text: sig.isNotEmpty ? sig : pv(BidDocProfileKeys.fallbackSignatory),
    );
    _designation = TextEditingController(
      text: pv(BidDocProfileKeys.signatoryDesignation),
    );
    _company = TextEditingController(text: pv(BidDocProfileKeys.companyName));
    _primName = TextEditingController();
    _primPosition = TextEditingController();
    _primEmail = TextEditingController();
    _primPhone = TextEditingController();
    _secName = TextEditingController();
    _secPosition = TextEditingController();
    _secEmail = TextEditingController();
    _secPhone = TextEditingController();
    _addName = TextEditingController();
    _addPosition = TextEditingController();
    _addEmail = TextEditingController();
    _addPhone = TextEditingController();
  }

  @override
  void dispose() {
    _scroll.dispose();
    for (final c in [
      _tenderNo, _signatory, _designation, _company,
      _primName, _primPosition, _primEmail, _primPhone,
      _secName, _secPosition, _secEmail, _secPhone,
      _addName, _addPosition, _addEmail, _addPhone,
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

  // ──────────────────────────────────────────────── validation

  String? _required(String? v) => (v == null || v.trim().isEmpty)
      ? t('This is required', 'यह आवश्यक है')
      : null;

  String? _emailError(String? v) {
    final err = validateEmail(v);
    if (err == null) return null;
    return err == 'Required'
        ? t('This is required', 'यह आवश्यक है')
        : t('Enter a valid email address', 'मान्य ईमेल पता दर्ज करें');
  }

  String? _phoneError(String? v) {
    final err = validatePhone(v);
    if (err == null) return null;
    return err == 'Required'
        ? t('This is required', 'यह आवश्यक है')
        : t('Enter a valid phone number', 'मान्य फ़ोन नंबर दर्ज करें');
  }

  String? _optionalRequired(List<TextEditingController> group, String? v) {
    if (!_groupAnyFilled(group)) return null;
    return _required(v);
  }

  String? _optionalEmail(List<TextEditingController> group, String? v) {
    if (!_groupAnyFilled(group)) return null;
    return _emailError(v);
  }

  String? _optionalPhone(List<TextEditingController> group, String? v) {
    if (!_groupAnyFilled(group)) return null;
    return _phoneError(v);
  }

  // ──────────────────────────────────────────────── actions

  void _generate() {
    if (!_form.currentState!.validate()) return;
    _disposeEditors();

    EscalationContact? buildContact(List<TextEditingController> cs) {
      if (!_groupAnyFilled(cs)) return null;
      return EscalationContact(
        name: cs[0].text.trim(),
        position: cs[1].text.trim(),
        email: cs[2].text.trim(),
        phone: cs[3].text.trim(),
      );
    }

    final input = EscalationMatrixInput(
      tenderNo: _tenderNo.text.trim().toUpperCase(),
      signatory: _signatory.text.trim(),
      designation: _designation.text.trim(),
      company: _company.text.trim(),
      primary: EscalationContact(
        name: _primName.text.trim(),
        position: _primPosition.text.trim(),
        email: _primEmail.text.trim(),
        phone: _primPhone.text.trim(),
      ),
      secondary: buildContact(_secGroup),
      tertiary: buildContact(_addGroup),
      date: DateTime.now(),
    );

    s.setProfile(BidDocProfileKeys.companyName, input.company);
    s.setProfile(BidDocProfileKeys.signatoryName, input.signatory);
    s.setProfile(BidDocProfileKeys.signatoryDesignation, input.designation);

    setState(() {
      _input = input;
      _blocks = buildEscalationMatrix(input);
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
      _tenderNo, _designation,
      _primName, _primPosition, _primEmail, _primPhone,
      _secName, _secPosition, _secEmail, _secPhone,
      _addName, _addPosition, _addEmail, _addPhone,
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
      'Escalation Matrix - ${(_input?.tenderNo ?? '').replaceAll('/', '-')}';

  Future<void> _print() async {
    setState(() => _busy = true);
    try {
      s.event('document_generated', page: 'tool-escalation', props: {'action': 'print'});
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
      s.event('document_generated', page: 'tool-escalation', props: {'action': 'share'});
      final bytes = await buildLetterPdf(_blocks!, extraTopMarginPt: _extraTop);
      await Printing.sharePdf(bytes: bytes, filename: '$_fileStem.pdf');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _explainConfirm() {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(t('Tick the confirmation first.', 'पहले पुष्टि वाले बॉक्स पर टिक करें।')),
    ));
  }

  // ──────────────────────────────────────────────── build

  @override
  Widget build(BuildContext context) {
    final previewing = _step == _Step.preview && _blocks != null;
    final editing = _editors != null;
    return ToolPageScaffold(
      store: s,
      scrollController: _scroll,
      title: t('Escalation Matrix', 'एस्केलेशन मैट्रिक्स'),
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
            'List the people to contact in case of issues during the tender process. Fill in the Primary contact (required) and up to two additional contacts.',
            'निविदा प्रक्रिया में समस्या होने पर संपर्क करने वाले लोगों की सूची बनाएँ। प्राथमिक संपर्क (आवश्यक) और दो और संपर्क भरें।',
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
      ],
    );
  }

  // ──────────────────────────────────────────────── form

  Widget _field(
    TextEditingController c,
    String en,
    String hi, {
    String? keyPrefix,
    String? Function(String?)? validator,
    String? helper,
    TextInputType? keyboard,
    TextCapitalization caps = TextCapitalization.none,
  }) => Padding(
    key: ValueKey(keyPrefix != null ? '$keyPrefix-$en' : en),
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

  Widget _sectionHeader(String en, String hi, {bool optional = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.md),
        child: Row(
          children: [
            Expanded(child: Text(t(en, hi), style: AppText.h3)),
            if (optional)
              Text(
                t('Optional', 'वैकल्पिक'),
                style: AppText.secondary(AppText.caption),
              ),
          ],
        ),
      );

  Widget _detailsForm() {
    final tenderOdd = _tenderNo.text.trim().isNotEmpty &&
        !looksLikeGemTenderNo(_tenderNo.text);
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header fields ────────────────────────────────
          _field(
            _tenderNo,
            'Tender / bid number',
            'निविदा / बोली संख्या',
            caps: TextCapitalization.characters,
            helper: tenderOdd
                ? t(
                    'This does not look like a usual GeM number (e.g. GEM/2026/B/7845020). Check it against the bid.',
                    'यह सामान्य GeM संख्या जैसी नहीं दिखती (जैसे GEM/2026/B/7845020)। बोली से मिलान करें।',
                  )
                : t('e.g. GEM/2026/B/7845020', 'जैसे GEM/2026/B/7845020'),
          ),
          _field(_signatory, 'Signatory name', 'हस्ताक्षरकर्ता का नाम',
              caps: TextCapitalization.words),
          _field(
            _designation,
            'Designation',
            'पदनाम',
            helper: t(
              'e.g. Proprietor, Director, Authorised Signatory',
              'जैसे प्रोप्राइटर, निदेशक, अधिकृत हस्ताक्षरकर्ता',
            ),
          ),
          _field(_company, 'Company name', 'कंपनी का नाम'),
          const SizedBox(height: AppSpace.md),

          // ── Primary contact ──────────────────────────────
          _sectionHeader('Primary Contact', 'प्राथमिक संपर्क'),
          _field(_primName, 'Name', 'नाम',
              keyPrefix: 'prim', caps: TextCapitalization.words),
          _field(_primPosition, 'Position', 'पद',
              keyPrefix: 'prim', caps: TextCapitalization.words),
          _field(_primEmail, 'Email', 'ईमेल',
              keyPrefix: 'prim',
              keyboard: TextInputType.emailAddress,
              validator: _emailError),
          _field(_primPhone, 'Phone', 'फ़ोन',
              keyPrefix: 'prim',
              keyboard: TextInputType.phone,
              validator: _phoneError),
          const SizedBox(height: AppSpace.md),

          // ── Secondary contact ────────────────────────────
          _sectionHeader('Secondary Contact', 'माध्यमिक संपर्क', optional: true),
          _field(_secName, 'Name', 'नाम',
              keyPrefix: 'sec',
              caps: TextCapitalization.words,
              validator: (v) => _optionalRequired(_secGroup, v)),
          _field(_secPosition, 'Position', 'पद',
              keyPrefix: 'sec',
              caps: TextCapitalization.words,
              validator: (v) => _optionalRequired(_secGroup, v)),
          _field(_secEmail, 'Email', 'ईमेल',
              keyPrefix: 'sec',
              keyboard: TextInputType.emailAddress,
              validator: (v) => _optionalEmail(_secGroup, v)),
          _field(_secPhone, 'Phone', 'फ़ोन',
              keyPrefix: 'sec',
              keyboard: TextInputType.phone,
              validator: (v) => _optionalPhone(_secGroup, v)),
          const SizedBox(height: AppSpace.md),

          // ── Additional contact ───────────────────────────
          _sectionHeader('Additional Contact', 'अतिरिक्त संपर्क', optional: true),
          _field(_addName, 'Name', 'नाम',
              keyPrefix: 'add',
              caps: TextCapitalization.words,
              validator: (v) => _optionalRequired(_addGroup, v)),
          _field(_addPosition, 'Position', 'पद',
              keyPrefix: 'add',
              caps: TextCapitalization.words,
              validator: (v) => _optionalRequired(_addGroup, v)),
          _field(_addEmail, 'Email', 'ईमेल',
              keyPrefix: 'add',
              keyboard: TextInputType.emailAddress,
              validator: (v) => _optionalEmail(_addGroup, v)),
          _field(_addPhone, 'Phone', 'फ़ोन',
              keyPrefix: 'add',
              keyboard: TextInputType.phone,
              validator: (v) => _optionalPhone(_addGroup, v)),
          const SizedBox(height: AppSpace.sm),
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

  // ──────────────────────────────────────────────── preview

  String _contactsSummary(EscalationMatrixInput i) {
    final hasSec = i.secondary != null && i.secondary!.isComplete;
    final hasAdd = i.tertiary != null && i.tertiary!.isComplete;
    if (hasSec && hasAdd) return t('All three', 'तीनों');
    if (hasSec) return t('Primary + Secondary', 'प्राथमिक + माध्यमिक');
    return t('Primary only', 'केवल प्राथमिक');
  }

  List<Widget> _previewSection() {
    final i = _input!;
    final editing = _editors != null;
    return [
      DividedList(
        children: [
          KeyValueRow(t('Tender no.', 'निविदा संख्या'), i.tenderNo),
          KeyValueRow(t('Company', 'कंपनी'), i.company),
          KeyValueRow(t('Contacts', 'संपर्क'), _contactsSummary(i)),
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
}
