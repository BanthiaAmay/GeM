/// Bank Solvency Certificate generator.
/// Registered in tools_hub/tool_registry.dart, route `/tool-bank-solvency`.
///
/// Two output modes:
///   Mode 1 — Request Letter: formal application to the branch manager.
///   Mode 2 — Reference Format: bank-side template with a mandatory disclaimer.
///
/// Reuses BidDocProfileKeys from mii_certificate_page.dart and adds its own
/// bank-specific keys that persist in the profile bag.
library;

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../core/tokens.dart';
import '../../data/app_store.dart';
import '../components.dart';
import '../tools_hub/tool_page_scaffold.dart';
import 'bank_solvency_text.dart';
import 'letter_model.dart';
import 'letter_pdf.dart';
import 'letter_preview.dart';
import 'mii_certificate_page.dart' show BidDocProfileKeys;

// ── Profile keys specific to this document ───────────────────────────────────

abstract final class _Keys {
  static const panNumber = 'panNumber';
  static const constitutionType = 'constitutionType';
  static const bankName = 'bankName';
  static const branchName = 'branchName';
  static const accountHolderName = 'accountHolderName';
  static const ifscCode = 'ifscCode';
}

// ── Enums ─────────────────────────────────────────────────────────────────────

enum _Step { details, preview }

enum _DocMode {
  requestLetter,
  referenceFormat;

  String label(String Function(String, String) t) => switch (this) {
    _DocMode.requestLetter => t('Request Letter', 'अनुरोध पत्र'),
    _DocMode.referenceFormat => t('Reference Format', 'संदर्भ प्रारूप'),
  };
}

// ── Page ──────────────────────────────────────────────────────────────────────

class BankSolvencyPage extends StatefulWidget {
  final AppStore store;
  const BankSolvencyPage({super.key, required this.store});

  @override
  State<BankSolvencyPage> createState() => _BankSolvencyPageState();
}

class _BankSolvencyPageState extends State<BankSolvencyPage> {
  final _form = GlobalKey<FormState>();
  final _scroll = ScrollController();

  // form controllers
  late final TextEditingController _company;
  late final TextEditingController _constitutionType;
  late final TextEditingController _companyAddress;
  late final TextEditingController _pan;
  late final TextEditingController _accountHolder;
  late final TextEditingController _bankName;
  late final TextEditingController _branchName;
  late final TextEditingController _ifsc;
  late final TextEditingController _accountNo; // optional
  late final TextEditingController _amount;
  late final TextEditingController _bidRef; // optional
  late final TextEditingController _signatory;
  late final TextEditingController _designation;

  _Step _step = _Step.details;
  _DocMode _mode = _DocMode.requestLetter;
  BankSolvencyInput? _input;
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
    s.event('page_view', page: 'tool-bank-solvency');
    final p = s.profile;
    String pv(String k) => (p[k] as String?)?.trim() ?? '';
    _company = TextEditingController(text: pv(BidDocProfileKeys.companyName));
    _constitutionType = TextEditingController(text: pv(_Keys.constitutionType));
    _companyAddress = TextEditingController(
      text: pv(BidDocProfileKeys.companyAddress),
    );
    _pan = TextEditingController(text: pv(_Keys.panNumber));
    _accountHolder = TextEditingController(
      text: pv(_Keys.accountHolderName),
    );
    _bankName = TextEditingController(text: pv(_Keys.bankName));
    _branchName = TextEditingController(text: pv(_Keys.branchName));
    _ifsc = TextEditingController(text: pv(_Keys.ifscCode));
    _accountNo = TextEditingController();
    _amount = TextEditingController();
    _bidRef = TextEditingController();
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
      _company,
      _constitutionType,
      _companyAddress,
      _pan,
      _accountHolder,
      _bankName,
      _branchName,
      _ifsc,
      _accountNo,
      _amount,
      _bidRef,
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

  String? _validateAmount(String? v) {
    final base = _required(v);
    if (base != null) return base;
    final clean = v!.trim().replaceAll(RegExp(r'[,\s₹]'), '');
    final n = int.tryParse(clean);
    if (n == null || n <= 0) {
      return t(
        'Enter a valid amount (numbers only)',
        'वैध राशि दर्ज करें (केवल अंक)',
      );
    }
    return null;
  }

  String? _validatePan(String? v) {
    final base = _required(v);
    if (base != null) return base;
    final pan = v!.trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(pan)) {
      return t(
        'PAN should be 10 characters (e.g. ABCDE1234F)',
        'PAN 10 अक्षर का होना चाहिए (जैसे ABCDE1234F)',
      );
    }
    return null;
  }

  // ----------------------------------------------------------------- actions

  void _generate() {
    if (!_form.currentState!.validate()) return;
    _disposeEditors();
    final clean = _amount.text.trim().replaceAll(RegExp(r'[,\s₹]'), '');
    final input = BankSolvencyInput(
      company: _company.text.trim(),
      constitutionType: _constitutionType.text.trim(),
      companyAddress: _companyAddress.text.trim(),
      panNumber: _pan.text.trim().toUpperCase(),
      accountHolderName: _accountHolder.text.trim(),
      bankName: _bankName.text.trim(),
      branchName: _branchName.text.trim(),
      ifscCode: _ifsc.text.trim().toUpperCase(),
      accountNumber: _accountNo.text.trim(),
      solventAmount: int.parse(clean),
      bidReferenceNo: _bidRef.text.trim().toUpperCase(),
      signatory: _signatory.text.trim(),
      designation: _designation.text.trim(),
      date: DateTime.now(),
    );

    // Persist profile fields
    s.setProfile(BidDocProfileKeys.companyName, input.company);
    s.setProfile(BidDocProfileKeys.companyAddress, input.companyAddress);
    s.setProfile(BidDocProfileKeys.signatoryName, input.signatory);
    s.setProfile(BidDocProfileKeys.signatoryDesignation, input.designation);
    s.setProfile(_Keys.panNumber, input.panNumber);
    s.setProfile(_Keys.constitutionType, input.constitutionType);
    s.setProfile(_Keys.bankName, input.bankName);
    s.setProfile(_Keys.branchName, input.branchName);
    s.setProfile(_Keys.accountHolderName, input.accountHolderName);
    s.setProfile(_Keys.ifscCode, input.ifscCode);

    final blocks = _mode == _DocMode.requestLetter
        ? buildBankSolvencyRequestLetter(input)
        : buildBankSolvencyReferenceFormat(input);

    setState(() {
      _input = input;
      _blocks = blocks;
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

  void _onModeChanged(_DocMode next) {
    if (next == _mode) return;
    _invalidateLetter();
    setState(() => _mode = next);
  }

  void _resetAll() {
    for (final c in [
      _constitutionType,
      _companyAddress,
      _accountNo,
      _amount,
      _bidRef,
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

  String get _fileStem {
    final ref = _input?.bidReferenceNo ?? '';
    final suffix = ref.isNotEmpty ? ref.replaceAll('/', '-') : _input?.company ?? '';
    final modeTag = _mode == _DocMode.requestLetter
        ? 'Request Letter'
        : 'Reference Format';
    return 'Bank Solvency Certificate $modeTag - $suffix';
  }

  Future<void> _print() async {
    setState(() => _busy = true);
    try {
      s.event(
        'document_generated',
        page: 'tool-bank-solvency',
        props: {'action': 'print', 'mode': _mode.name},
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
        page: 'tool-bank-solvency',
        props: {'action': 'share', 'mode': _mode.name},
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
      title: t('Bank Solvency Certificate', 'बैंक सॉल्वेंसी प्रमाणपत्र'),
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
                  ? t('Generate document', 'दस्तावेज़ बनाएँ')
                  : t('Update document', 'दस्तावेज़ अपडेट करें'),
              onPressed: _generate,
            ),
      children: [
        Text(
          t(
            'Generate a Bank Solvency Certificate request letter or reference '
            'format for GeM / government tender participation.',
            'GeM / सरकारी निविदा भागीदारी के लिए बैंक सॉल्वेंसी प्रमाणपत्र '
            'अनुरोध पत्र या संदर्भ प्रारूप बनाएँ।',
          ),
          style: AppText.secondary(AppText.body),
        ),
        const SizedBox(height: AppSpace.xl),

        // Document mode selector
        AppSegmentedControl<_DocMode>(
          semanticLabel: t('Document type', 'दस्तावेज़ प्रकार'),
          value: _mode,
          onChanged: _onModeChanged,
          options: [
            (
              _DocMode.requestLetter,
              t('Request Letter', 'अनुरोध पत्र'),
              null,
            ),
            (
              _DocMode.referenceFormat,
              t('Reference Format', 'संदर्भ प्रारूप'),
              null,
            ),
          ],
        ),
        const SizedBox(height: AppSpace.sm),

        // Mode description
        AppCard(
          tone: _mode == _DocMode.referenceFormat
              ? AppCardTone.brand
              : AppCardTone.muted,
          padding: const EdgeInsets.all(AppSpace.md),
          child: Text(
            _mode == _DocMode.requestLetter
                ? t(
                    'Request Letter: A formal application to your Branch Manager '
                    'requesting issuance of a Bank Solvency Certificate on official '
                    'bank letterhead.',
                    'अनुरोध पत्र: शाखा प्रबंधक को आधिकारिक बैंक लेटरहेड पर बैंक '
                    'सॉल्वेंसी प्रमाणपत्र जारी करने का औपचारिक आवेदन।',
                  )
                : t(
                    'Reference Format: A structured template for the bank to '
                    'complete and issue. This is NOT a valid Bank Solvency Certificate '
                    '— it must be completed, verified and stamped by your bank.',
                    'संदर्भ प्रारूप: बैंक के लिए एक संरचित टेम्पलेट। यह एक '
                    'वैध बैंक सॉल्वेंसी प्रमाणपत्र नहीं है — इसे आपके बैंक द्वारा '
                    'पूरा, सत्यापित और मोहर लगाया जाना चाहिए।',
                  ),
            style: AppText.caption,
          ),
        ),
        const SizedBox(height: AppSpace.xl),

        // Details / Preview tabs
        AppSegmentedControl<_Step>(
          semanticLabel: t('Document step', 'दस्तावेज़ का चरण'),
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
    bool optional = false,
  }) => Padding(
    key: ValueKey(en),
    padding: const EdgeInsets.only(bottom: AppSpace.lg),
    child: TextFormField(
      controller: c,
      keyboardType: keyboard,
      textCapitalization: caps,
      decoration: InputDecoration(
        labelText: optional
            ? '${t(en, hi)} ${t('(optional)', '(वैकल्पिक)')}'
            : t(en, hi),
        helperText: helper,
        helperMaxLines: 3,
      ),
      validator: optional ? null : (validator ?? _required),
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
          // Business details
          Text(
            t('Business details', 'व्यवसाय विवरण'),
            style: AppText.label,
          ),
          const SizedBox(height: AppSpace.md),
          _field(
            _company,
            'Business / Company name',
            'व्यवसाय / कंपनी का नाम',
            caps: TextCapitalization.words,
          ),
          _field(
            _constitutionType,
            'Constitution type',
            'संस्था का प्रकार',
            helper: t(
              'e.g. Proprietorship, Partnership, LLP, Private Limited',
              'जैसे Proprietorship, Partnership, LLP, Private Limited',
            ),
            caps: TextCapitalization.words,
          ),
          _field(
            _companyAddress,
            'Registered business address',
            'पंजीकृत व्यवसाय पता',
            caps: TextCapitalization.words,
          ),
          _field(
            _pan,
            'PAN number',
            'PAN नंबर',
            caps: TextCapitalization.characters,
            helper: t('e.g. ABCDE1234F', 'जैसे ABCDE1234F'),
            validator: _validatePan,
          ),
          const SizedBox(height: AppSpace.sm),

          // Bank details
          Text(
            t('Bank account details', 'बैंक खाता विवरण'),
            style: AppText.label,
          ),
          const SizedBox(height: AppSpace.md),
          _field(
            _accountHolder,
            'Name of account holder',
            'खाताधारक का नाम',
            caps: TextCapitalization.words,
          ),
          _field(
            _bankName,
            'Bank name',
            'बैंक का नाम',
            helper: t(
              'e.g. State Bank of India, Punjab National Bank',
              'जैसे State Bank of India, Punjab National Bank',
            ),
            caps: TextCapitalization.words,
          ),
          _field(
            _branchName,
            'Branch name',
            'शाखा का नाम',
            caps: TextCapitalization.words,
          ),
          _field(
            _ifsc,
            'IFSC code',
            'IFSC कोड',
            caps: TextCapitalization.characters,
            helper: t('e.g. SBIN0001234', 'जैसे SBIN0001234'),
          ),
          _field(
            _accountNo,
            'Bank account number',
            'बैंक खाता संख्या',
            keyboard: TextInputType.number,
            optional: true,
            helper: t(
              'Optional — omit if you prefer not to include it',
              'वैकल्पिक — यदि आप शामिल नहीं करना चाहते तो छोड़ें',
            ),
          ),
          const SizedBox(height: AppSpace.sm),

          // Certificate details
          Text(
            t('Certificate details', 'प्रमाणपत्र विवरण'),
            style: AppText.label,
          ),
          const SizedBox(height: AppSpace.md),
          _field(
            _amount,
            'Requested solvency amount (₹)',
            'अनुरोधित सॉल्वेंसी राशि (₹)',
            keyboard: TextInputType.number,
            validator: _validateAmount,
            helper: t(
              'Enter the amount in numbers, e.g. 5000000 for ₹50 Lakh',
              'राशि अंकों में दर्ज करें, जैसे ₹50 लाख के लिए 5000000',
            ),
          ),
          _field(
            _bidRef,
            'Bid reference number',
            'बोली संदर्भ संख्या',
            caps: TextCapitalization.characters,
            optional: true,
            helper: t(
              'Optional — e.g. GEM/2026/B/7845020',
              'वैकल्पिक — जैसे GEM/2026/B/7845020',
            ),
          ),
          const SizedBox(height: AppSpace.sm),

          // Signatory
          Text(
            t('Authorised signatory', 'अधिकृत हस्ताक्षरकर्ता'),
            style: AppText.label,
          ),
          const SizedBox(height: AppSpace.md),
          _field(
            _signatory,
            'Name of authorised signatory',
            'अधिकृत हस्ताक्षरकर्ता का नाम',
          ),
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
              'The document is generated on your device. We do not upload or '
              'keep it — only your business and bank details are remembered so '
              'you do not retype them.',
              'दस्तावेज़ आपके डिवाइस पर ही बनता है। हम इसे अपलोड या सेव नहीं '
              'करते — केवल आपके व्यवसाय और बैंक विवरण याद रखे जाते हैं।',
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
    final isRef = _mode == _DocMode.referenceFormat;
    return [
      DividedList(
        children: [
          KeyValueRow(t('Document type', 'दस्तावेज़ प्रकार'), _mode.label(t)),
          KeyValueRow(t('Company', 'कंपनी'), i.company),
          KeyValueRow(t('Bank', 'बैंक'), '${i.bankName} – ${i.branchName}'),
          KeyValueRow(t('Solvency amount', 'सॉल्वेंसी राशि'), i.amountFmt),
          if (i.bidReferenceNo.isNotEmpty)
            KeyValueRow(t('Bid ref.', 'बोली संदर्भ'), i.bidReferenceNo),
        ],
      ),
      const SizedBox(height: AppSpace.xl),
      Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                t('Your document', 'आपका दस्तावेज़'),
                style: AppText.h3,
              ),
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
          'You can edit the document before printing. Edited paragraphs lose '
          'their bold styling.',
          'प्रिंट से पहले आप दस्तावेज़ में बदलाव कर सकते हैं। बदले गए '
          'अनुच्छेदों की बोल्ड शैली हट जाती है।',
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
            isRef
                ? t(
                    'I understand this is a reference format only. '
                    'This document cannot be used as a Bank Solvency '
                    'Certificate. The actual certificate must be obtained '
                    'from my bank on official letterhead with authorised '
                    'signature and seal.',
                    'मैं समझता/समझती हूँ कि यह केवल एक संदर्भ प्रारूप है। '
                    'इस दस्तावेज़ का उपयोग बैंक सॉल्वेंसी प्रमाणपत्र के '
                    'रूप में नहीं किया जा सकता। वास्तविक प्रमाणपत्र बैंक '
                    'के आधिकारिक लेटरहेड पर हस्ताक्षर और मोहर के साथ '
                    'प्राप्त किया जाना चाहिए।',
                  )
                : t(
                    'I confirm the details in this request letter are correct '
                    'to the best of my knowledge.',
                    'मैं पुष्टि करता/करती हूँ कि इस अनुरोध पत्र में दी गई '
                    'जानकारी मेरी जानकारी के अनुसार सही है।',
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
            'How to obtain your Bank Solvency Certificate',
            'बैंक सॉल्वेंसी प्रमाणपत्र कैसे प्राप्त करें',
          ),
          style: AppText.h3,
        ),
        const SizedBox(height: AppSpace.sm),
        Text(
          t(
            'Follow these steps to get your Bank Solvency Certificate from '
            'your bank:',
            'अपने बैंक से बैंक सॉल्वेंसी प्रमाणपत्र प्राप्त करने के लिए '
            'इन चरणों का पालन करें:',
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
              'Requirements, supporting documents, fees and validity period '
              'may vary between banks. Contact your branch for specific '
              'requirements.',
              'आवश्यकताएँ, सहायक दस्तावेज़, शुल्क और वैधता अवधि बैंकों '
              'के बीच भिन्न हो सकती है। विशिष्ट आवश्यकताओं के लिए अपनी '
              'शाखा से संपर्क करें।',
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
      t('Contact your bank branch', 'अपनी बैंक शाखा से संपर्क करें'),
      t(
        'Visit or call your bank branch where you maintain your business '
        'account.',
        'उस बैंक शाखा में जाएँ या कॉल करें जहाँ आपका व्यावसायिक खाता है।',
      ),
    ),
    (
      2,
      t(
        'Submit a formal application',
        'औपचारिक आवेदन जमा करें',
      ),
      t(
        'Use the Request Letter generated here, or write a letter requesting '
        'a Solvency Certificate specifying the required amount.',
        'यहाँ बनाए गए अनुरोध पत्र का उपयोग करें, या आवश्यक राशि निर्दिष्ट '
        'करते हुए सॉल्वेंसी प्रमाणपत्र के लिए पत्र लिखें।',
      ),
    ),
    (
      3,
      t(
        'Provide required business documents',
        'आवश्यक व्यवसाय दस्तावेज़ प्रदान करें',
      ),
      t(
        'Typically: PAN card, GST certificate, company registration documents, '
        'and recent bank statements.',
        'आमतौर पर: PAN कार्ड, GST प्रमाणपत्र, कंपनी पंजीकरण दस्तावेज़ और '
        'हालिया बैंक स्टेटमेंट।',
      ),
    ),
    (
      4,
      t(
        'Specify the solvency amount',
        'सॉल्वेंसी राशि निर्दिष्ट करें',
      ),
      t(
        'Mention the solvency amount as required by the GeM bid or government '
        'tender you are applying for.',
        'GeM बोली या सरकारी निविदा में आवश्यक सॉल्वेंसी राशि का उल्लेख करें।',
      ),
    ),
    (
      5,
      t('Pay applicable bank charges', 'लागू बैंक शुल्क का भुगतान करें'),
      t(
        'Pay the bank fees for issuing the certificate, if any. Charges vary '
        'by bank and branch.',
        'प्रमाणपत्र जारी करने के लिए बैंक शुल्क का भुगतान करें, यदि कोई हो। '
        'शुल्क बैंक और शाखा के अनुसार भिन्न होता है।',
      ),
    ),
    (
      6,
      t(
        'Collect the official certificate',
        'आधिकारिक प्रमाणपत्र प्राप्त करें',
      ),
      t(
        'Collect the Bank Solvency Certificate issued on the bank\'s official '
        'letterhead with authorised signature and bank seal.',
        'बैंक के आधिकारिक लेटरहेड पर अधिकृत हस्ताक्षर और बैंक सील के साथ '
        'जारी बैंक सॉल्वेंसी प्रमाणपत्र प्राप्त करें।',
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
