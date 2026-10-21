/// MRP Declaration Letter generator.
/// Registered in tools_hub/tool_registry.dart, route `/tool-mrp-declaration`.
///
/// Declares the Maximum Retail Price printed on product labels for GeM bids.
/// Supports multiple products with optional product images.
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:printing/printing.dart';

import '../../core/tokens.dart';
import '../../data/app_store.dart';
import '../components.dart';
import '../tools_hub/tool_page_scaffold.dart';
import 'letter_model.dart';
import 'letter_pdf.dart';
import 'letter_preview.dart';
import 'mrp_declaration_text.dart';

enum _Step { details, preview }

// ─── per-product state ────────────────────────────────────────────────────────

class _ProductCard {
  static int _counter = 0;
  final int id = _counter++;

  final productName = TextEditingController();
  final brandName = TextEditingController();
  final modelNo = TextEditingController();
  final mrp = TextEditingController();
  Uint8List? imageBytes;

  void dispose() {
    productName.dispose();
    brandName.dispose();
    modelNo.dispose();
    mrp.dispose();
  }

  bool get isFilled =>
      productName.text.trim().isNotEmpty &&
      brandName.text.trim().isNotEmpty &&
      modelNo.text.trim().isNotEmpty &&
      mrp.text.trim().isNotEmpty;

  MrpProductEntry toEntry() => MrpProductEntry(
        productName: productName.text.trim(),
        brandName: brandName.text.trim(),
        modelNo: modelNo.text.trim(),
        mrp: mrp.text.trim(),
        imageBytes: imageBytes,
      );
}

// ─── page ─────────────────────────────────────────────────────────────────────

class MrpDeclarationPage extends StatefulWidget {
  final AppStore store;

  const MrpDeclarationPage({super.key, required this.store});

  @override
  State<MrpDeclarationPage> createState() => _MrpDeclarationPageState();
}

class _MrpDeclarationPageState extends State<MrpDeclarationPage> {
  final _form = GlobalKey<FormState>();
  final _scroll = ScrollController();
  final _cards = <_ProductCard>[];

  _Step _step = _Step.details;
  MrpDeclarationInput? _input;
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
    s.event('page_view', page: 'tool-mrp-declaration');
    _cards.add(_ProductCard());
  }

  @override
  void dispose() {
    _scroll.dispose();
    for (final c in _cards) {
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

  // ─── validation ─────────────────────────────────────────────────────────────

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty)
          ? t('This is required', 'यह आवश्यक है')
          : null;

  // ─── image handling ──────────────────────────────────────────────────────────

  Future<void> _pickImage(_ProductCard card) async {
    try {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(source: ImageSource.gallery);
      if (xfile == null || !mounted) return;
      final bytes = await xfile.readAsBytes();
      setState(() => card.imageBytes = bytes);
      _invalidateLetter();
    } catch (_) {}
  }

  Future<void> _pasteImage(_ProductCard card) async {
    try {
      final bytes = await Pasteboard.image;
      if (bytes == null || bytes.isEmpty || !mounted) return;
      setState(() => card.imageBytes = bytes);
      _invalidateLetter();
    } catch (_) {}
  }

  // ─── actions ─────────────────────────────────────────────────────────────────

  void _addProduct() {
    setState(() => _cards.add(_ProductCard()));
    _invalidateLetter();
  }

  void _removeProduct(int index) {
    _cards[index].dispose();
    setState(() => _cards.removeAt(index));
    _invalidateLetter();
  }

  void _generate() {
    if (!_form.currentState!.validate()) return;
    _disposeEditors();
    final input = MrpDeclarationInput(
      products: _cards.map((c) => c.toEntry()).toList(),
      date: DateTime.now(),
    );
    setState(() {
      _input = input;
      _blocks = buildMrpDeclarationLetter(input);
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
    for (final c in _cards) {
      c.dispose();
    }
    _cards.clear();
    _cards.add(_ProductCard());
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
            if (!b.isSpacer &&
                b.kind != LetterBlockKind.productTable &&
                b.kind != LetterBlockKind.productImage)
              TextEditingController(text: b.plainText),
        ];
      });

  void _finishEditing() {
    var i = 0;
    final edited = [
      for (final b in _blocks!)
        (b.isSpacer ||
                b.kind == LetterBlockKind.productTable ||
                b.kind == LetterBlockKind.productImage)
            ? b
            : LetterBlock.plain(b.kind, _editors![i++].text),
    ];
    _disposeEditors();
    setState(() {
      _blocks = edited;
      _confirmed = false;
    });
  }

  String get _fileStem => 'MRP Declaration';

  Future<void> _print() async {
    setState(() => _busy = true);
    try {
      s.event('document_generated', page: 'tool-mrp-declaration', props: {'action': 'print'});
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
      s.event('document_generated', page: 'tool-mrp-declaration', props: {'action': 'share'});
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

  // ─── build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final previewing = _step == _Step.preview && _blocks != null;
    final editing = _editors != null;
    return ToolPageScaffold(
      store: s,
      scrollController: _scroll,
      title: t('MRP Declaration', 'MRP घोषणा'),
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
            'Declare the Maximum Retail Price (MRP) of your products for a GeM bid. Add one or more products with their MRP details.',
            'GeM बिड के लिए उत्पादों की अधिकतम खुदरा कीमत (MRP) घोषित करें। एक या अधिक उत्पाद उनकी MRP जानकारी के साथ जोड़ें।',
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

  // ─── form ─────────────────────────────────────────────────────────────────────

  Widget _detailsForm() {
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < _cards.length; i++) _buildProductCard(i),
          const SizedBox(height: AppSpace.sm),
          AppButton(
            label: t('+ Add Product', '+ उत्पाद जोड़ें'),
            variant: AppButtonVariant.tertiary,
            onPressed: _addProduct,
          ),
          const SizedBox(height: AppSpace.lg),
          ReassuranceNote(
            t(
              'The letter is generated on your device. We do not upload or store it.',
              'पत्र आपके डिवाइस पर ही बनता है। हम इसे अपलोड या सेव नहीं करते।',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(int index) {
    final card = _cards[index];
    return Padding(
      key: ValueKey(card.id),
      padding: const EdgeInsets.only(bottom: AppSpace.lg),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    t('Product ${index + 1}', 'उत्पाद ${index + 1}'),
                    style: AppText.bodyStrong,
                  ),
                ),
                if (_cards.length > 1)
                  AppIconButton(
                    icon: Icons.close,
                    tooltip: t('Remove product', 'उत्पाद हटाएँ'),
                    onPressed: () => _removeProduct(index),
                  ),
              ],
            ),
            const SizedBox(height: AppSpace.md),
            _imageArea(card),
            const SizedBox(height: AppSpace.md),
            _cardField(card.productName, 'Product name', 'उत्पाद का नाम', index),
            _cardField(card.brandName, 'Brand name', 'ब्रांड का नाम', index),
            _cardField(card.modelNo, 'Model / Item No.', 'मॉडल / आइटम नं.', index),
            _cardField(
              card.mrp,
              'MRP (₹)',
              'MRP (₹)',
              index,
              caps: TextCapitalization.none,
              helper: t('As printed on label, e.g. 1500.00', 'लेबल पर जैसा छपा हो, जैसे 1500.00'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imageArea(_ProductCard card) {
    final bytes = card.imageBytes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t('Product image (optional)', 'उत्पाद की तस्वीर (वैकल्पिक)'),
          style: AppText.label,
        ),
        const SizedBox(height: AppSpace.sm),
        if (bytes != null) ...[
          Stack(
            children: [
              ClipRRect(
                borderRadius: AppRadius.card,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 140),
                  child: Image.memory(bytes, fit: BoxFit.contain),
                ),
              ),
              Positioned(
                top: AppSpace.xs,
                right: AppSpace.xs,
                child: AppIconButton(
                  icon: Icons.close,
                  tooltip: t('Remove image', 'तस्वीर हटाएँ'),
                  onPressed: () {
                    setState(() => card.imageBytes = null);
                    _invalidateLetter();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
        ],
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: t('Choose from gallery', 'गैलरी से चुनें'),
                icon: Icons.image_outlined,
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.sm,
                onPressed: () => _pickImage(card),
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: AppButton(
                label: t('Paste image', 'तस्वीर पेस्ट करें'),
                icon: Icons.content_paste_outlined,
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.sm,
                onPressed: () => _pasteImage(card),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _cardField(
    TextEditingController c,
    String en,
    String hi,
    int cardIndex, {
    String? helper,
    TextCapitalization caps = TextCapitalization.words,
  }) =>
      Padding(
        key: ValueKey('${cardIndex}_$en'),
        padding: const EdgeInsets.only(bottom: AppSpace.lg),
        child: TextFormField(
          controller: c,
          textCapitalization: caps,
          decoration: InputDecoration(
            labelText: t(en, hi),
            helperText: helper,
            helperMaxLines: 2,
          ),
          validator: _required,
          onChanged: (_) {
            setState(() {});
            _invalidateLetter();
          },
        ),
      );

  // ─── preview ──────────────────────────────────────────────────────────────────

  List<Widget> _previewSection() {
    final i = _input!;
    final editing = _editors != null;
    return [
      DividedList(
        children: [
          KeyValueRow(
            t('Products', 'उत्पाद'),
            '${i.products.length} ${i.products.length == 1 ? t('product', 'उत्पाद') : t('products', 'उत्पाद')}',
          ),
          KeyValueRow(t('First product', 'पहला उत्पाद'), i.products.first.productName),
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
          onChanged: editing ? null : (v) => setState(() => _confirmed = v ?? false),
          title: Text(
            t(
              'I confirm the MRP details above are accurate as printed on the product label.',
              'मैं पुष्टि करता/करती हूँ कि ऊपर दी गई MRP विवरण उत्पाद लेबल पर छपी जानकारी के अनुसार सही हैं।',
            ),
            style: AppText.bodySmall,
          ),
        ),
      ),
    ];
  }

  // ─── help ─────────────────────────────────────────────────────────────────────

  Widget _helpSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t('How to generate MRP Declaration', 'MRP घोषणा कैसे बनाएँ'),
          style: AppText.h3,
        ),
        const SizedBox(height: AppSpace.sm),
        Text(
          t(
            'Follow these steps to generate your MRP Declaration:',
            'MRP घोषणा बनाने के लिए इन चरणों का पालन करें:',
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
              'The MRP must match exactly what is printed on the product label or packaging. Submit only after verifying.',
              'MRP वही होनी चाहिए जो उत्पाद के लेबल या पैकेजिंग पर छपी हो। सत्यापन के बाद ही जमा करें।',
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
          t('Add product details', 'उत्पाद का विवरण दें'),
          t(
            'Enter the product name, brand, model number, and MRP as printed on the label.',
            'उत्पाद का नाम, ब्रांड, मॉडल नंबर और लेबल पर छपी MRP दर्ज करें।',
          ),
        ),
        (
          2,
          t('Add product image (optional)', 'उत्पाद की तस्वीर जोड़ें (वैकल्पिक)'),
          t(
            'Attach a photo of the product label showing the MRP from your gallery or clipboard.',
            'गैलरी या क्लिपबोर्ड से MRP दिखाने वाले उत्पाद लेबल की तस्वीर संलग्न करें।',
          ),
        ),
        (
          3,
          t('Add more products if needed', 'ज़रूरत हो तो और उत्पाद जोड़ें'),
          t(
            'Use "+ Add Product" to include multiple products in a single declaration.',
            'एक ही घोषणा में कई उत्पाद शामिल करने के लिए "+ उत्पाद जोड़ें" का उपयोग करें।',
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

// ─── help step widget ──────────────────────────────────────────────────────────

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
