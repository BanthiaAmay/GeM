/// Make in India (PPP-MII) self-certification generator — one tool "box" on
/// the Tools tab (registered in tools_hub/tool_registry.dart, route
/// `/tool-mii`).
///
/// Screen follows the app concept: back chevron + centered title + reset icon,
/// a pill "Details | Preview" switch (like Matched / Saved / All), plain
/// labelled fields, key-value summary + status chip, and the one primary
/// action pinned in the bottom bar (black pill).
///
/// Everything is generated on-device; the document is never uploaded or kept.
/// Only company details are remembered (profile bag) so they are never retyped.
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
import 'mii_certificate_text.dart';

/// Profile-bag keys shared by every future bid document. `fullName` already
/// exists (onboarding); the rest are new. Keep these names stable.
abstract final class BidDocProfileKeys {
  static const companyName = 'companyName';
  static const companyAddress = 'companyAddress';
  static const signatoryName = 'signatoryName';
  static const signatoryDesignation = 'signatoryDesignation';
  static const fallbackSignatory = 'fullName';
  static const udyamRegistrationNo = 'udyamRegistrationNo';
}

enum _Step { details, preview }

class MiiCertificatePage extends StatefulWidget {
  final AppStore store;

  /// Pass the bid's number when opened from a bid card (as the route
  /// argument) so the user types nothing for it.
  final String? tenderNo;

  const MiiCertificatePage({super.key, required this.store, this.tenderNo});

  @override
  State<MiiCertificatePage> createState() => _MiiCertificatePageState();
}

class _MiiCertificatePageState extends State<MiiCertificatePage> {
  final _form = GlobalKey<FormState>();
  final _scroll = ScrollController();
  late final TextEditingController _tender;
  late final TextEditingController _localContent;
  late final TextEditingController _company;
  late final TextEditingController _location;
  late final TextEditingController _signatory;
  late final TextEditingController _designation;

  _Step _step = _Step.details;
  MiiCertificateInput? _input; // what the current letter was built from
  List<LetterBlock>? _blocks;
  List<TextEditingController>? _editors; // non-null while editing the letter
  double _extraTop = 0;
  bool _confirmed = false;
  bool _busy = false;

  AppStore get s => widget.store;
  String t(String en, String hi) => s.t(en, hi);

  @override
  void initState() {
    super.initState();
    s.event('page_view', page: 'tool-mii');
    final p = s.profile;
    String pv(String k) => (p[k] as String?)?.trim() ?? '';
    _tender = TextEditingController(text: widget.tenderNo ?? '');
    _localContent = TextEditingController();
    _company = TextEditingController(text: pv(BidDocProfileKeys.companyName));
    _location = TextEditingController(
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
      _tender,
      _localContent,
      _company,
      _location,
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

  // ------------------------------------------------------------ validation

  String? _required(String? v) => (v == null || v.trim().isEmpty)
      ? t('This is required', 'यह आवश्यक है')
      : null;

  String? _localContentError(String? v) {
    final key = validateLocalContent(v);
    if (key == null) return null;
    return key.startsWith('Below')
        ? t(key, '20% से कम पर आप स्थानीय आपूर्तिकर्ता नहीं माने जाते')
        : t(key, '0 से 100 के बीच संख्या दें');
  }

  LocalSupplierClass? get _liveClass {
    final v = double.tryParse(_localContent.text.trim());
    return (v == null || v < 0 || v > 100) ? null : classifyLocalContent(v);
  }

  // -------------------------------------------------------------- actions

  /// Validates, builds the letter and switches to the preview.
  void _generate() {
    if (!_form.currentState!.validate()) return;
    _disposeEditors();
    final input = MiiCertificateInput(
      tenderNo: _tender.text.trim().toUpperCase(),
      localContentPercent: double.parse(_localContent.text.trim()),
      company: _company.text.trim(),
      valueAdditionLocation: _location.text.trim(),
      signatory: _signatory.text.trim(),
      designation: _designation.text.trim(),
      date: DateTime.now(),
    );
    // Remember reusable company details (not tender-specific ones).
    s.setProfile(BidDocProfileKeys.companyName, input.company);
    s.setProfile(BidDocProfileKeys.companyAddress, input.valueAdditionLocation);
    s.setProfile(BidDocProfileKeys.signatoryName, input.signatory);
    s.setProfile(BidDocProfileKeys.signatoryDesignation, input.designation);

    setState(() {
      _input = input;
      _blocks = buildMiiCertificate(input);
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
      _generate(); // tapping "Preview" first generates (and validates)
    } else {
      setState(() => _step = _Step.preview);
    }
  }

  void _resetAll() {
    for (final c in [_tender, _localContent, _location, _designation]) {
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
            : LetterBlock.plain(b.kind, _editors![i++].text), // hand edits = plain text
    ];
    _disposeEditors();
    setState(() {
      _blocks = edited;
      _confirmed = false; // edited text must be re-confirmed
    });
  }

  String get _fileStem =>
      'MII Certificate - ${(_input?.tenderNo ?? '').replaceAll('/', '-')}';

  Future<void> _print() async {
    setState(() => _busy = true);
    try {
      s.event(
        'document_generated',
        page: 'tool-mii',
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
        page: 'tool-mii',
        props: {'action': 'share'},
      );
      final bytes = await buildLetterPdf(
        _blocks!,
        extraTopMarginPt: _extraTop,
      );
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

  // ----------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final previewing = _step == _Step.preview && _blocks != null;
    final editing = _editors != null;
    return ToolPageScaffold(
      store: s,
      scrollController: _scroll,
      title: t('Make in India certificate', 'मेक इन इंडिया प्रमाणपत्र'),
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
            'Many GeM bids ask for a self-declaration that you are a local supplier. Fill the details once and print a letter that is ready to sign.',
            'कई GeM बोलियों में स्थानीय आपूर्तिकर्ता होने की स्व-घोषणा माँगी जाती है। जानकारी एक बार भरें और हस्ताक्षर के लिए तैयार पत्र प्रिंट करें।',
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
        // Both stay in the tree so typed text and validation state survive
        // switching steps; only visibility changes.
        Offstage(offstage: previewing, child: _detailsForm()),
        if (previewing) ..._previewSection(),
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
        setState(() {}); // refresh live class chip / tender hint
        _invalidateLetter(); // any input change invalidates the letter
      },
    ),
  );

  Widget _detailsForm() {
    final cls = _liveClass;
    final tenderOdd =
        _tender.text.trim().isNotEmpty && !looksLikeGemTenderNo(_tender.text);
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _field(
            _tender,
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
          _field(
            _localContent,
            'Local content (%)',
            'स्थानीय सामग्री (%)',
            keyboard: const TextInputType.numberWithOptions(decimal: true),
            validator: _localContentError,
            helper: t(
              '50% or more = Class-I local supplier. 20% to under 50% = Class-II.',
              '50% या अधिक = क्लास-I स्थानीय आपूर्तिकर्ता। 20% से 50% से कम = क्लास-II।',
            ),
          ),
          if (cls == LocalSupplierClass.classI ||
              cls == LocalSupplierClass.classII)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.lg),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: _classChip(cls!),
              ),
            ),
          _field(_company, 'Company name', 'कंपनी का नाम'),
          _field(
            _location,
            'Where the local value addition is done',
            'जहाँ स्थानीय मूल्य संवर्धन होता है',
            helper: t(
              'Usually your factory or office address.',
              'आमतौर पर आपकी फैक्ट्री या कार्यालय का पता।',
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
              'The letter is made on your phone. We do not upload or keep it — only your company details are remembered so you do not retype them.',
              'पत्र आपके फ़ोन पर ही बनता है। हम इसे अपलोड या सेव नहीं करते — केवल कंपनी का विवरण याद रखा जाता है।',
            ),
          ),
        ],
      ),
    );
  }

  Widget _classChip(LocalSupplierClass c) => StatusChip(
    c == LocalSupplierClass.classI
        ? t('Class-I local supplier', 'क्लास-I स्थानीय आपूर्तिकर्ता')
        : t('Class-II local supplier', 'क्लास-II स्थानीय आपूर्तिकर्ता'),
    tone: StatusTone.success,
    icon: Icons.check_circle_outline,
  );

  List<Widget> _previewSection() {
    final i = _input!;
    final editing = _editors != null;
    return [
      // Summary, in the same key-value style as the concept's Bid details.
      Wrap(
        spacing: AppSpace.sm,
        runSpacing: AppSpace.sm,
        children: [_classChip(classifyLocalContent(i.localContentPercent))],
      ),
      const SizedBox(height: AppSpace.md),
      DividedList(
        children: [
          KeyValueRow(t('Tender no.', 'निविदा संख्या'), i.tenderNo),
          KeyValueRow(
            t('Local content', 'स्थानीय सामग्री'),
            '${formatPercent(i.localContentPercent)}%',
          ),
          KeyValueRow(t('Company', 'कंपनी'), i.company),
          KeyValueRow(
            t('Value addition at', 'मूल्य संवर्धन स्थान'),
            i.valueAdditionLocation,
          ),
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
        extraTopMargin: _extraTop / 2, // preview is roughly half PDF scale
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
