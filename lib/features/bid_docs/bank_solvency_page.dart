/// Bank Solvency Certificate Cover Letter generator.
/// Route: `/tool-bank-solvency`
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
import 'bank_solvency_text.dart';

enum _Step { details, preview }

class BankSolvencyPage extends StatefulWidget {
  final AppStore store;
  const BankSolvencyPage({super.key, required this.store});

  @override
  State<BankSolvencyPage> createState() => _BankSolvencyPageState();
}

class _BankSolvencyPageState extends State<BankSolvencyPage> {
  final _form = GlobalKey<FormState>();
  final _scroll = ScrollController();

  late final TextEditingController _tenderNo;
  late final TextEditingController _buyerOrg;
  late final TextEditingController _bankName;
  late final TextEditingController _bankAddress;
  late final TextEditingController _company;
  late final TextEditingController _accountNo;
  late final TextEditingController _accountHolderSince;
  late final TextEditingController _contractAmount;
  String _validityMonths = '3';
  late final TextEditingController _signatory;
  late final TextEditingController _designation;

  _Step _step = _Step.details;
  BankSolvencyInput? _input;
  List<LetterBlock>? _blocks;
  List<TextEditingController>? _editors;
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
    _tenderNo = TextEditingController();
    _buyerOrg = TextEditingController();
    _bankName = TextEditingController();
    _bankAddress = TextEditingController();
    _company = TextEditingController(text: pv(BidDocProfileKeys.companyName));
    _accountNo = TextEditingController();
    _accountHolderSince = TextEditingController();
    _contractAmount = TextEditingController();
    final signatory = pv(BidDocProfileKeys.signatoryName);
    _signatory = TextEditingController(
      text: signatory.isNotEmpty ? signatory : pv(BidDocProfileKeys.fallbackSignatory),
    );
    _designation = TextEditingController(text: pv(BidDocProfileKeys.signatoryDesignation));
  }

  @override
  void dispose() {
    _scroll.dispose();
    for (final c in [
      _tenderNo, _buyerOrg, _bankName, _bankAddress, _company,
      _accountNo, _accountHolderSince, _contractAmount, _signatory, _designation,
    ]) {
      c.dispose();
    }
    _disposeEditors();
    super.dispose();
  }

  void _disposeEditors() {
    for (final c in _editors ?? const <TextEditingController>[]) c.dispose();
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
    final input = BankSolvencyInput(
      tenderNo: _tenderNo.text.trim(),
      bankName: _bankName.text.trim(),
      bankAddress: _bankAddress.text.trim(),
      company: _company.text.trim(),
      accountNo: _accountNo.text.trim(),
      buyerOrg: _buyerOrg.text.trim(),
      accountHolderSince: _accountHolderSince.text.trim(),
      contractAmount: _contractAmount.text.trim(),
      validityMonths: _validityMonths,
      signatory: _signatory.text.trim(),
      designation: _designation.text.trim(),
      date: DateTime.now(),
    );
    s.setProfile(BidDocProfileKeys.companyName, input.company);
    s.setProfile(BidDocProfileKeys.signatoryName, input.signatory);
    s.setProfile(BidDocProfileKeys.signatoryDesignation, input.designation);
    setState(() {
      _input = input;
      _blocks = buildBankSolvencyCoverLetter(input);
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
      _tenderNo, _buyerOrg, _bankName, _bankAddress, _company,
      _accountNo, _accountHolderSince, _contractAmount, _signatory, _designation,
    ]) {
      c.clear();
    }
    _validityMonths = '3';
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
      'Bank-Solvency-Cover-Letter - ${(_input?.company ?? '').replaceAll(' ', '_')}';

  Future<void> _print() async {
    setState(() => _busy = true);
    try {
      s.event('document_generated', page: 'tool-bank-solvency', props: {'action': 'print'});
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
      s.event('document_generated', page: 'tool-bank-solvency', props: {'action': 'share'});
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
      title: t('Bank Solvency Certificate Cover Letter', 'बैंक सॉल्वेंसी प्रमाणपत्र कवर लेटर'),
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
            'Generate a request letter to your bank for a Solvency Certificate for a GeM bid.',
            'GeM बिड के लिए बैंक सॉल्वेंसी प्रमाणपत्र के लिए अपने बैंक को अनुरोध पत्र बनाएँ।',
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
          _field(_buyerOrg, 'Buyer organisation', 'क्रेता संस्था',
              helper: t('Government department / organisation placing the order',
                  'ऑर्डर देने वाला सरकारी विभाग / संस्था'),
              caps: TextCapitalization.words),
          _field(_bankName, 'Bank name', 'बैंक का नाम',
              caps: TextCapitalization.words),
          _field(_bankAddress, 'Bank branch address', 'बैंक शाखा का पता',
              caps: TextCapitalization.words),
          _field(_company, 'Company name / account holder name', 'कंपनी / खाताधारक का नाम'),
          _field(_accountNo, 'Account number', 'खाता संख्या'),
          _field(_accountHolderSince, 'Account holder since (year)', 'खाताधारक कब से (वर्ष)',
              helper: t('Year the account was opened, e.g. 2019', 'खाता खुलने का वर्ष, जैसे 2019')),
          _field(_contractAmount, 'Estimated contract amount', 'अनुमानित अनुबंध राशि',
              helper: t('e.g. ₹50,00,000', 'जैसे ₹50,00,000')),
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.lg),
            child: DropdownButtonFormField<String>(
              value: _validityMonths,
              decoration: InputDecoration(
                labelText: t('Solvency certificate validity', 'सॉल्वेंसी प्रमाणपत्र वैधता'),
              ),
              items: ['3', '6']
                  .map((v) => DropdownMenuItem(value: v, child: Text(t('$v months', '$v महीने'))))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() => _validityMonths = v);
                _invalidateLetter();
              },
            ),
          ),
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

  List<Widget> _previewSection() {
    final i = _input!;
    final editing = _editors != null;
    return [
      DividedList(
        children: [
          KeyValueRow(t('Tender No.', 'टेंडर नं.'), i.tenderNo),
          KeyValueRow(t('Buyer Org', 'क्रेता संस्था'), i.buyerOrg),
          KeyValueRow(t('Bank', 'बैंक'), i.bankName),
          KeyValueRow(t('Company', 'कंपनी'), i.company),
          KeyValueRow(t('Account No.', 'खाता नं.'), i.accountNo),
          KeyValueRow(t('Contract Amount', 'अनुबंध राशि'), i.contractAmount),
          KeyValueRow(t('Validity', 'वैधता'), '${i.validityMonths} months'),
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
        Text(t('How to generate Bank Solvency Cover Letter', 'बैंक सॉल्वेंसी कवर लेटर कैसे बनाएँ'),
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
            t('Submit this letter to your bank well in advance of the tender deadline to allow time for the bank to issue the solvency certificate.',
                'बैंक को सॉल्वेंसी प्रमाणपत्र जारी करने का समय देने के लिए यह पत्र टेंडर की समय-सीमा से पहले जमा करें।'),
            style: AppText.caption,
          ),
        ),
      ],
    );
  }

  List<(int, String, String)> _helpSteps() => [
    (1, t('Enter tender and buyer details', 'टेंडर और क्रेता विवरण दें'),
        t('Enter the GeM Bid number and the buyer organisation.', 'GeM बिड नंबर और क्रेता संस्था दर्ज करें।')),
    (2, t('Enter bank and account details', 'बैंक और खाता विवरण दें'),
        t('Enter your bank name, branch address, company/account holder name, account number, and the year the account was opened.', 'बैंक का नाम, शाखा का पता, कंपनी/खाताधारक का नाम, खाता संख्या और खाता खुलने का वर्ष दर्ज करें।')),
    (3, t('Enter contract amount and validity', 'अनुबंध राशि और वैधता दें'),
        t('Enter the estimated contract amount and the required validity period for the solvency certificate.', 'अनुमानित अनुबंध राशि और सॉल्वेंसी प्रमाणपत्र के लिए आवश्यक वैधता अवधि दर्ज करें।')),
    (4, t('Generate and submit to bank', 'बनाएँ और बैंक में जमा करें'),
        t('Generate, review, then print and submit to your bank branch manager.', 'बनाएँ, समीक्षा करें, फिर प्रिंट करें और बैंक शाखा प्रबंधक को जमा करें।')),
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
