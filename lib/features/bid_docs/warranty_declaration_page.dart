/// Warranty Declaration generator.
/// Registered in tools_hub/tool_registry.dart, route `/tool-warranty-declaration`.
///
/// No tender number — this tool is product/service-level only.
/// Follows the same StatefulWidget pattern as all other bid doc tools.
library;

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../core/tokens.dart';
import '../../data/app_store.dart';
import '../components.dart';
import '../tools_hub/tool_page_scaffold.dart';
import 'escalation_matrix_text.dart' show validateEmail, validatePhone;
import 'letter_model.dart';
import 'letter_pdf.dart';
import 'letter_preview.dart';
import 'mii_certificate_page.dart' show BidDocProfileKeys;
import 'warranty_declaration_text.dart';

enum _Step { details, preview }

class WarrantyDeclarationPage extends StatefulWidget {
  final AppStore store;

  const WarrantyDeclarationPage({super.key, required this.store});

  @override
  State<WarrantyDeclarationPage> createState() =>
      _WarrantyDeclarationPageState();
}

class _WarrantyDeclarationPageState extends State<WarrantyDeclarationPage> {
  final _form = GlobalKey<FormState>();
  final _scroll = ScrollController();

  late final TextEditingController _signatory;
  late final TextEditingController _designation;
  late final TextEditingController _warrantyPeriod;
  late final TextEditingController _contactName;
  late final TextEditingController _contactPosition;
  late final TextEditingController _contactEmail;
  late final TextEditingController _contactPhone;

  _Step _step = _Step.details;
  WarrantyDeclarationInput? _input;
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
    s.event('page_view', page: 'tool-warranty-declaration');
    final p = s.profile;
    String pv(String k) => (p[k] as String?)?.trim() ?? '';
    final signatoryName = pv(BidDocProfileKeys.signatoryName);
    _signatory = TextEditingController(
      text: signatoryName.isNotEmpty
          ? signatoryName
          : pv(BidDocProfileKeys.fallbackSignatory),
    );
    _designation = TextEditingController(
      text: pv(BidDocProfileKeys.signatoryDesignation),
    );
    _warrantyPeriod = TextEditingController();
    _contactName = TextEditingController();
    _contactPosition = TextEditingController();
    _contactEmail = TextEditingController();
    _contactPhone = TextEditingController();
  }

  @override
  void dispose() {
    _scroll.dispose();
    for (final c in [
      _signatory,
      _designation,
      _warrantyPeriod,
      _contactName,
      _contactPosition,
      _contactEmail,
      _contactPhone,
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

  String? _emailValidator(String? v) {
    final err = validateEmail(v);
    if (err == null) return null;
    return err == 'Required'
        ? t('This is required', 'यह आवश्यक है')
        : t('Enter a valid email address', 'एक वैध ईमेल पता दर्ज करें');
  }

  String? _phoneValidator(String? v) {
    final err = validatePhone(v);
    if (err == null) return null;
    return err == 'Required'
        ? t('This is required', 'यह आवश्यक है')
        : t('Enter a valid phone number', 'एक वैध फ़ोन नंबर दर्ज करें');
  }

  // ----------------------------------------------------------------- actions

  void _generate() {
    if (!_form.currentState!.validate()) return;
    _disposeEditors();
    final input = WarrantyDeclarationInput(
      signatoryName: _signatory.text.trim(),
      designation: _designation.text.trim(),
      warrantyPeriod: _warrantyPeriod.text.trim(),
      contactName: _contactName.text.trim(),
      contactPosition: _contactPosition.text.trim(),
      contactEmail: _contactEmail.text.trim(),
      contactPhone: _contactPhone.text.trim(),
      date: DateTime.now(),
    );
    s.setProfile(BidDocProfileKeys.signatoryName, input.signatoryName);
    s.setProfile(BidDocProfileKeys.signatoryDesignation, input.designation);

    setState(() {
      _input = input;
      _blocks = buildWarrantyDeclaration(input);
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
      _signatory,
      _designation,
      _warrantyPeriod,
      _contactName,
      _contactPosition,
      _contactEmail,
      _contactPhone,
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
      'Warranty Declaration - ${(_input?.signatoryName ?? '').replaceAll(' ', '_')}';

  Future<void> _print() async {
    setState(() => _busy = true);
    try {
      s.event(
        'document_generated',
        page: 'tool-warranty-declaration',
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
        page: 'tool-warranty-declaration',
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
      title: t('Warranty Declaration', 'वारंटी घोषणा'),
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
            'Fill in the required details to generate your Warranty Declaration — certify your warranty terms for products or services being tendered.',
            'वारंटी घोषणा बनाने के लिए आवश्यक जानकारी भरें — निविदित उत्पादों या सेवाओं की वारंटी शर्तें प्रमाणित करें।',
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
          _field(
            _warrantyPeriod,
            'Warranty period',
            'वारंटी अवधि',
            helper: t('e.g. 6 months', 'जैसे 6 months'),
          ),
          _field(_contactName, 'Contact person name', 'संपर्क व्यक्ति का नाम'),
          _field(
            _contactPosition,
            'Contact position',
            'संपर्क पद',
            helper: t('e.g. Director', 'जैसे Director'),
          ),
          _field(
            _contactEmail,
            'Contact email',
            'संपर्क ईमेल',
            keyboard: TextInputType.emailAddress,
            validator: _emailValidator,
          ),
          _field(
            _contactPhone,
            'Contact phone',
            'संपर्क फ़ोन',
            keyboard: TextInputType.phone,
            validator: _phoneValidator,
          ),
          ReassuranceNote(
            t(
              'The letter is generated on your device. We do not upload or keep it — only your signatory details are remembered so you do not retype them.',
              'पत्र आपके डिवाइस पर ही बनता है। हम इसे अपलोड या सेव नहीं करते — केवल हस्ताक्षरकर्ता का विवरण याद रखा जाता है।',
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
          KeyValueRow(
            t('Signatory', 'हस्ताक्षरकर्ता'),
            '${i.signatoryName} (${i.designation})',
          ),
          KeyValueRow(t('Warranty period', 'वारंटी अवधि'), i.warrantyPeriod),
          KeyValueRow(t('Contact', 'संपर्क'), i.contactName),
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
            'How to generate Warranty Declaration',
            'वारंटी घोषणा कैसे बनाएँ',
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
              'Please verify the tender\'s specific warranty requirements before submission.',
              'जमा करने से पहले निविदा की विशिष्ट वारंटी आवश्यकताओं की जाँच करें।',
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
      t('Enter signatory details', 'हस्ताक्षरकर्ता का विवरण दें'),
      t(
        'Enter the name and designation of the person authorised to sign this warranty declaration.',
        'वारंटी घोषणा पर हस्ताक्षर करने के लिए अधिकृत व्यक्ति का नाम और पदनाम दर्ज करें।',
      ),
    ),
    (
      2,
      t('Enter warranty period', 'वारंटी अवधि दर्ज करें'),
      t(
        'Specify the warranty period you are committing to, e.g. "6 months" or "1 year".',
        'जैसे "6 months" या "1 year" — वह वारंटी अवधि दर्ज करें जिसका आप वादा कर रहे हैं।',
      ),
    ),
    (
      3,
      t('Enter contact information', 'संपर्क जानकारी दर्ज करें'),
      t(
        'Enter the name, position, email and phone of the warranty contact person.',
        'वारंटी संपर्क व्यक्ति का नाम, पद, ईमेल और फ़ोन नंबर दर्ज करें।',
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
