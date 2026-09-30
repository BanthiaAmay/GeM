import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../data/app_store.dart';
import '../gst/invoice.dart';
import 'widgets.dart';

String _periodNow() => DateTime.now().toIso8601String().substring(0, 7);
String _fmtDate(DateTime? d) => d == null
    ? '—'
    : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

class GstHeading extends StatelessWidget {
  final AppStore s;
  final String eyebrow, title, body;
  const GstHeading(this.s, this.eyebrow, this.title, this.body, {super.key});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        eyebrow.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          letterSpacing: 1.6,
          fontWeight: FontWeight.w700,
          color: muted,
        ),
      ),
      const SizedBox(height: 12),
      Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.headlineLarge?.copyWith(fontSize: 38),
      ),
      const SizedBox(height: 12),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Text(body, style: Theme.of(context).textTheme.bodyLarge),
      ),
      const SizedBox(height: 28),
    ],
  );
}

class GstMiniCard extends StatelessWidget {
  final IconData icon;
  final String title, body;
  final VoidCallback action;
  final String actionLabel;
  const GstMiniCard(
    this.icon,
    this.title,
    this.body,
    this.action,
    this.actionLabel, {
    super.key,
  });
  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: lime,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: ink),
        ),
        const SizedBox(height: 20),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(body),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: action,
          icon: const Icon(Icons.arrow_forward, size: 17),
          label: Text(actionLabel),
        ),
      ],
    ),
  );
}

class GstHubPage extends StatelessWidget {
  final AppStore s;
  const GstHubPage(this.s, {super.key});
  @override
  Widget build(BuildContext context) {
    final all = s.gstInvoices;
    final period = _periodNow();
    final sum = GstSummary.forPeriod(all, period);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GstHeading(
          s,
          s.t('GST WORKSPACE', 'GST कार्यक्षेत्र'),
          s.t(
            'Your paperwork, under control.',
            'आपके दस्तावेज़, आपकी पकड़ में।',
          ),
          s.t(
            'Import an invoice, correct what was found, and see what needs attention before preparing a return.',
            'इनवॉइस जोड़ें, निकाली गई जानकारी ठीक करें, और रिटर्न तैयारी से पहले ज़रूरी काम देखें।',
          ),
        ),
        Panel(
          color: ink,
          child: ResponsiveRow(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.t('START HERE', 'यहाँ से शुरू करें'),
                    style: const TextStyle(
                      fontSize: 12,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFC6C8CB),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    s.t(
                      'One invoice.\nOne clear next step.',
                      'एक इनवॉइस।\nएक स्पष्ट अगला कदम।',
                    ),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontSize: 34,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    s.t(
                      'Extracted fields stay drafts until you review them. PDFs are saved online only if you choose to.',
                      'समीक्षा तक निकाली गई जानकारी ड्राफ्ट रहती है। PDF ऑनलाइन तभी सहेजेंगे जब आप चुनें।',
                    ),
                    style: const TextStyle(
                      color: Color(0xFFE1E2E4),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: ink,
                  ),
                  onPressed: () => go(context, s, 'gst-upload'),
                  icon: const Icon(Icons.add),
                  label: Text(s.t('Add an invoice', 'इनवॉइस जोड़ें')),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Text(
          s.t('This month · $period', 'इस महीने · $period'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 14),
        ResponsiveRow(
          children: [
            Stat(
              s.t('Sales recorded', 'दर्ज बिक्री'),
              money(sum.sales),
              s.t(
                '${sum.invoiceCount} invoices in this period',
                'इस अवधि में ${sum.invoiceCount} इनवॉइस',
              ),
            ),
            Stat(
              s.t('Output GST', 'बिक्री पर GST'),
              money(sum.outputTax),
              s.t('From entered invoices', 'दर्ज इनवॉइस से'),
            ),
            Stat(
              s.t('Needs review', 'समीक्षा बाकी'),
              '${sum.reviewCount}',
              s.t(
                'Errors, gaps or unreviewed drafts',
                'त्रुटि, कमी या ड्राफ्ट',
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        LayoutBuilder(
          builder: (context, c) {
            final cols = c.maxWidth > 820
                ? 3
                : c.maxWidth > 560
                ? 2
                : 1;
            final items = [
              GstMiniCard(
                Icons.receipt_long_outlined,
                s.t('Invoices', 'इनवॉइस'),
                s.t(
                  'View sales and purchases, correct fields and catch duplicates.',
                  'बिक्री और खरीद देखें, जानकारी सुधारें और डुप्लीकेट पकड़ें।',
                ),
                () => go(context, s, 'gst-invoices'),
                s.t('View invoices', 'इनवॉइस देखें'),
              ),
              GstMiniCard(
                Icons.rule_folder_outlined,
                s.t('Reconcile purchases', 'खरीद का मिलान'),
                s.t(
                  'Compare purchases with a reviewed GSTR-2B CSV.',
                  'समीक्षित GSTR-2B CSV से खरीद का मिलान करें।',
                ),
                () => go(context, s, 'gst-reconcile'),
                s.t('Check matches', 'मिलान देखें'),
              ),
              GstMiniCard(
                Icons.fact_check_outlined,
                s.t('Prepare a return', 'रिटर्न तैयार करें'),
                s.t(
                  'See a draft period summary and issues before official filing.',
                  'आधिकारिक फाइलिंग से पहले ड्राफ्ट सारांश और समस्याएँ देखें।',
                ),
                () => go(context, s, 'gst-returns'),
                s.t('Review period', 'अवधि की समीक्षा'),
              ),
            ];
            return Wrap(
              spacing: 18,
              runSpacing: 18,
              children: [
                for (final item in items)
                  SizedBox(
                    width: (c.maxWidth - 18 * (cols - 1)) / cols,
                    child: item,
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 22),
        GstMiniCard(
          Icons.folder_outlined,
          s.t('Documents & trends', 'दस्तावेज़ और रुझान'),
          s.t(
            'Open privately saved PDFs and compare recorded months.',
            'निजी सहेजे PDF खोलें और दर्ज महीनों की तुलना करें।',
          ),
          () => go(context, s, 'gst-documents'),
          s.t('Open documents', 'दस्तावेज़ खोलें'),
        ),
        const SizedBox(height: 20),
        Panel(
          color: lime,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.t(
                  'A preparation workspace, with you in control',
                  'तैयारी का कार्यक्षेत्र, नियंत्रण आपके हाथ में',
                ),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                s.t(
                  'This is not a GST return, challan, payment instruction or active-GSTIN verification. Confirm figures on the GST portal or with your tax professional before filing.',
                  'यह GST रिटर्न, चालान, भुगतान निर्देश या सक्रिय GSTIN सत्यापन नहीं है। फाइल करने से पहले GST पोर्टल या कर विशेषज्ञ से आँकड़े पुष्टि करें।',
                ),
              ),
              SourceNote(
                s,
                s.t('Official GST portal guide', 'आधिकारिक GST पोर्टल गाइड'),
                'https://tutorial.gst.gov.in/userguide/returns/Creation_of_Outward_Supplies_Return_in_GSTR-1.htm',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class GstInvoicesPage extends StatelessWidget {
  final AppStore s;
  const GstInvoicesPage(this.s, {super.key});
  @override
  Widget build(BuildContext context) {
    final rows = s.gstInvoices.reversed.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GstHeading(
          s,
          s.t('INVOICE REGISTER', 'इनवॉइस रजिस्टर'),
          s.t('Every invoice, easy to inspect.', 'हर इनवॉइस, जाँचने में आसान।'),
          s.t(
            'Figures are extracted drafts or user entries. Open any item to review or correct it.',
            'आँकड़े निकाले गए ड्राफ्ट या आपके दिए इनपुट हैं। जाँच या सुधार के लिए इनवॉइस खोलें।',
          ),
        ),
        FilledButton.icon(
          onPressed: () => go(context, s, 'gst-upload'),
          icon: const Icon(Icons.add),
          label: Text(s.t('Add invoice', 'इनवॉइस जोड़ें')),
        ),
        const SizedBox(height: 22),
        if (rows.isEmpty)
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.receipt_long_outlined, size: 40, color: muted),
                const SizedBox(height: 12),
                Text(
                  s.t('No invoices yet', 'अभी कोई इनवॉइस नहीं'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  s.t(
                    'Import a text PDF or enter fields manually to start a private register.',
                    'शुरू करने के लिए PDF आयात करें या जानकारी खुद भरें।',
                  ),
                ),
              ],
            ),
          )
        else
          for (final i in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Panel(
                child: InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GstUploadPage(s, existing: i),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: lime,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          i.direction == 'sale'
                              ? Icons.north_east
                              : Icons.south_west,
                          color: ink,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              i.invoiceNumber.isEmpty
                                  ? s.t('Number missing', 'संख्या नहीं है')
                                  : i.invoiceNumber,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              '${i.direction == 'sale' ? s.t('Sale', 'बिक्री') : s.t('Purchase', 'खरीद')} · ${_fmtDate(i.invoiceDate)} · ${i.fileName}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            money(i.total),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            invoiceIssues(i, rows).isEmpty && i.reviewed
                                ? s.t('Reviewed', 'समीक्षित')
                                : s.t('Review', 'समीक्षा'),
                            style: TextStyle(
                              color:
                                  invoiceIssues(i, rows).isEmpty && i.reviewed
                                  ? success
                                  : warning,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

class GstUploadPage extends StatefulWidget {
  final AppStore s;
  final GstInvoice? existing;
  const GstUploadPage(this.s, {super.key, this.existing});
  @override
  State<GstUploadPage> createState() => _GstUploadPageState();
}

class _GstUploadPageState extends State<GstUploadPage> {
  final form = GlobalKey<FormState>();
  final ctr = <String, TextEditingController>{};
  String direction = 'sale', name = 'Manual entry', extraction = 'manual';
  Uint8List? pdf;
  bool busy = false, savePdf = false, reviewed = false;
  String? path;
  @override
  void initState() {
    super.initState();
    final i = widget.existing;
    direction = i?.direction ?? 'sale';
    name = i?.fileName ?? 'Manual entry';
    extraction = i?.extraction ?? 'manual';
    reviewed = i?.reviewed ?? false;
    path = i?.documentPath;
    final values = {
      'seller': i?.sellerGstin ?? '',
      'buyer': i?.buyerGstin ?? '',
      'number': i?.invoiceNumber ?? '',
      'date': i?.invoiceDate == null ? '' : _fmtDate(i!.invoiceDate),
      'place': i?.placeOfSupply ?? '',
      'taxable': i == null ? '' : i.taxableValue.toStringAsFixed(2),
      'rate': i == null ? '' : i.rate.toStringAsFixed(2),
      'cgst': i == null ? '' : i.cgst.toStringAsFixed(2),
      'sgst': i == null ? '' : i.sgst.toStringAsFixed(2),
      'igst': i == null ? '' : i.igst.toStringAsFixed(2),
    };
    for (final e in values.entries) {
      ctr[e.key] = TextEditingController(text: e.value);
    }
  }

  @override
  void dispose() {
    for (final c in ctr.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> pick() async {
    setState(() => busy = true);
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 10 * 1024 * 1024) {
        throw const FormatException('PDF must be under 10 MB');
      }
      final ref = PdfDocumentRefData(
        bytes,
        sourceName: file.name,
        useProgressiveLoading: false,
      );
      final doc = await ref.loadDocument((_, [_]) {});
      final b = StringBuffer();
      try {
        for (final p in doc.pages.take(10)) {
          final text = await p.loadStructuredText();
          b.writeln(text.fullText);
        }
      } finally {
        await doc.dispose();
      }
      final draft = GstInvoiceParser.draft(
        b.toString(),
        id: widget.existing?.id ?? const Uuid().v4(),
        name: file.name,
        direction: direction,
      );
      setState(() {
        name = file.name;
        pdf = bytes;
        extraction = draft.extraction;
        reviewed = false;
        ctr['seller']!.text = draft.sellerGstin;
        ctr['buyer']!.text = draft.buyerGstin;
        ctr['number']!.text = draft.invoiceNumber;
        ctr['date']!.text = _fmtDate(draft.invoiceDate).replaceAll('—', '');
        ctr['place']!.text = draft.placeOfSupply;
        ctr['taxable']!.text = draft.taxableValue == 0
            ? ''
            : draft.taxableValue.toString();
        ctr['rate']!.text = draft.rate == 0 ? '' : draft.rate.toString();
        for (final key in ['cgst', 'sgst', 'igst']) {
          final v = switch (key) {
            'cgst' => draft.cgst,
            'sgst' => draft.sgst,
            _ => draft.igst,
          };
          ctr[key]!.text = v == 0 ? '' : v.toString();
        }
      });
    } catch (e) {
      if (mounted) {
        message(
          context,
          widget.s.t(
            'Could not read this PDF. Try manual entry or a text PDF.',
            'यह PDF नहीं पढ़ पाए। खुद जानकारी भरें या टेक्स्ट PDF चुनें।',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget field(
    String key,
    String label, {
    bool numeric = false,
    String? hint,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      controller: ctr[key],
        onChanged: (_) => setState(() => reviewed = false),
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      textCapitalization: key == 'seller' || key == 'buyer'
          ? TextCapitalization.characters
          : TextCapitalization.none,
      decoration: InputDecoration(labelText: label, hintText: hint),
      validator: (v) {
        if (numeric && v!.isNotEmpty) {
          final n = double.tryParse(v);
          if (n == null || !n.isFinite || n < 0) {
            return widget.s.t(
              'Enter a non-negative amount',
              'शून्य या अधिक सही राशि दें',
            );
          }
        }
        return null;
      },
    ),
  );
  GstInvoice draft() {
    double n(String key) => double.tryParse(ctr[key]!.text.trim()) ?? 0;
    return GstInvoice(
      id: widget.existing?.id ?? const Uuid().v4(),
      direction: direction,
      fileName: name,
      sellerGstin: ctr['seller']!.text.trim().toUpperCase(),
      buyerGstin: ctr['buyer']!.text.trim().toUpperCase(),
      invoiceNumber: ctr['number']!.text.trim(),
      invoiceDate: GstInvoiceParser.parseDate(ctr['date']!.text.trim()),
      placeOfSupply: ctr['place']!.text.trim(),
      taxableValue: n('taxable'),
      rate: n('rate'),
      cgst: n('cgst'),
      sgst: n('sgst'),
      igst: n('igst'),
      reviewed: reviewed,
      extraction: extraction,
      documentPath: path,
    );
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    var d = draft();
    final issues = invoiceIssues(d, widget.s.gstInvoices);
    if (reviewed && issues.isNotEmpty) {
      message(
        context,
        widget.s.t(
          'Resolve flagged items before marking this invoice reviewed.',
          'समीक्षित चिह्न लगाने से पहले समस्याएँ सुधारें।',
        ),
      );
      return;
    }
    setState(() => busy = true);
    try {
      if (savePdf && pdf != null) {
        path = await widget.s.uploadInvoicePdf(d.id, pdf!);
        d = d.copyWith(documentPath: path);
      }
      widget.s.saveGstInvoice(d);
      if (mounted) {
        message(
          context,
          widget.s.t(
            'Invoice saved as ${reviewed ? 'reviewed' : 'draft'}.',
            'इनवॉइस ${reviewed ? 'समीक्षित' : 'ड्राफ्ट'} के रूप में सहेजा गया।',
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (_) {
      widget.s.saveGstInvoice(d);
      if (mounted) {
        message(
          context,
          widget.s.t(
            'Fields saved locally. PDF upload failed; retry online.',
            'जानकारी स्थानीय रूप से सहेजी गई। PDF अपलोड नहीं हुआ; ऑनलाइन फिर कोशिश करें।',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final d = draft();
    final issues = invoiceIssues(d, s.gstInvoices);
    return Scaffold(
      backgroundColor: canvas,
      appBar: AppBar(
        title: Text(
          s.t(
            widget.existing == null ? 'Add invoice' : 'Review invoice',
            widget.existing == null ? 'इनवॉइस जोड़ें' : 'इनवॉइस समीक्षा',
          ),
        ),
        backgroundColor: canvas,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GstHeading(
                    s,
                    s.t('DOCUMENT REVIEW', 'दस्तावेज़ समीक्षा'),
                    s.t('Check every field.', 'हर जानकारी जाँचें।'),
                    s.t(
                      'Text extraction is a starting point. For scanned PDFs, enter the fields yourself. No AI service receives this document.',
                      'टेक्स्ट निकालना केवल शुरुआत है। स्कैन PDF के लिए जानकारी खुद भरें। यह दस्तावेज़ किसी AI सेवा को नहीं जाता।',
                    ),
                  ),
                  ResponsiveRow(
                    children: [
                      Panel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.t('1 · Source', '1 · स्रोत'),
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 12),
                            Text(name),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: busy ? null : pick,
                              icon: const Icon(Icons.upload_file_outlined),
                              label: Text(
                                s.t(
                                  'Choose PDF · up to 10 MB',
                                  'PDF चुनें · 10 MB तक',
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              s.t(
                                extraction == 'scanned_or_empty'
                                    ? 'No selectable text found. Manual entry required.'
                                    : extraction == 'pdf_text'
                                    ? 'Fields extracted locally. Check against your original PDF.'
                                    : 'You can start with manual entry.',
                                extraction == 'scanned_or_empty'
                                    ? 'चुनने योग्य टेक्स्ट नहीं मिला। जानकारी खुद भरें।'
                                    : extraction == 'pdf_text'
                                    ? 'जानकारी डिवाइस पर निकाली गई। मूल PDF से जाँचें।'
                                    : 'आप खुद जानकारी भर सकते हैं।',
                              ),
                            ),
                            const SizedBox(height: 18),
                            SegmentedButton<String>(
                              segments: [
                                ButtonSegment(
                                  value: 'sale',
                                  label: Text(s.t('Sale', 'बिक्री')),
                                ),
                                ButtonSegment(
                                  value: 'purchase',
                                  label: Text(s.t('Purchase', 'खरीद')),
                                ),
                              ],
                              selected: {direction},
                              onSelectionChanged: widget.existing != null
                                  ? null
                                  : (v) => setState(() => direction = v.first),
                            ),
                            const SizedBox(height: 18),
                            if (s.signedIn)
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  s.t(
                                    'Save PDF privately online',
                                    'PDF निजी तौर पर ऑनलाइन सहेजें',
                                  ),
                                ),
                                subtitle: Text(
                                  s.t(
                                    'Only you can open it from this account.',
                                    'इस खाते से केवल आप इसे खोल सकते हैं।',
                                  ),
                                ),
                                value: savePdf,
                                onChanged: pdf == null
                                    ? null
                                    : (v) =>
                                          setState(() => savePdf = v ?? false),
                              )
                            else
                              Text(
                                s.t(
                                  'Sign in before importing if you want to keep the PDF across devices. Only corrected fields are kept locally.',
                                  'अलग डिवाइस पर PDF रखने के लिए आयात से पहले साइन इन करें। यहाँ केवल सुधारी जानकारी सहेजी जाती है।',
                                ),
                              ),
                          ],
                        ),
                      ),
                      Panel(
                        child: Form(
                          key: form,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.t(
                                  '2 · Invoice details',
                                  '2 · इनवॉइस जानकारी',
                                ),
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 20),
                              field(
                                'seller',
                                s.t('Supplier GSTIN', 'आपूर्तिकर्ता GSTIN'),
                              ),
                              field(
                                'buyer',
                                s.t(
                                  'Buyer GSTIN (if any)',
                                  'खरीदार GSTIN (यदि हो)',
                                ),
                              ),
                              field(
                                'number',
                                s.t('Invoice number', 'इनवॉइस संख्या'),
                              ),
                              field(
                                'date',
                                s.t('Invoice date', 'इनवॉइस तिथि'),
                                hint: 'DD/MM/YYYY',
                              ),
                              field(
                                'place',
                                s.t('Place of supply', 'आपूर्ति का स्थान'),
                              ),
                              field(
                                'taxable',
                                s.t('Taxable value · ₹', 'कर योग्य मूल्य · ₹'),
                                numeric: true,
                              ),
                              field(
                                'rate',
                                s.t('GST rate · %', 'GST दर · %'),
                                numeric: true,
                              ),
                              ResponsiveRow(
                                children: [
                                  field('cgst', 'CGST · ₹', numeric: true),
                                  field('sgst', 'SGST · ₹', numeric: true),
                                  field('igst', 'IGST · ₹', numeric: true),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Panel(
                    color: issues.isEmpty ? lime : const Color(0xFFFFF5E8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.t('3 · Review checks', '3 · जाँच'),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        if (issues.isEmpty)
                          Text(
                            s.t(
                              'No basic validation issues. Confirm the invoice against the original and tax rules.',
                              'बुनियादी जाँच में कोई समस्या नहीं। मूल इनवॉइस और कर नियमों से पुष्टि करें।',
                            ),
                          )
                        else
                          for (final issue in issues)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text('• $issue'),
                            ),
                        const SizedBox(height: 12),
                        Text(
                          s.t(
                            'GSTIN checks cover format and checksum only; they do not confirm active registration or correct tax treatment.',
                            'GSTIN जाँच केवल बनावट और चेकसम की है; सक्रिय पंजीकरण या सही कर उपचार की पुष्टि नहीं।',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      s.t(
                        'I compared this draft with the original invoice',
                        'मैंने इस ड्राफ्ट की मूल इनवॉइस से तुलना की है',
                      ),
                    ),
                    value: reviewed,
                    onChanged: (v) => setState(() => reviewed = v ?? false),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: busy ? null : save,
                        icon: const Icon(Icons.save_outlined),
                        label: Text(s.t('Save invoice', 'इनवॉइस सहेजें')),
                      ),
                      if (widget.existing != null)
                        OutlinedButton.icon(
                          onPressed: busy
                              ? null
                              : () async {
                                  final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (c) => AlertDialog(
                                      title: Text(
                                        s.t(
                                          'Delete this invoice?',
                                          'यह इनवॉइस मिटाएँ?',
                                        ),
                                      ),
                                      content: Text(
                                        s.t(
                                          'This removes its saved fields and private PDF, if present.',
                                          'इसकी सहेजी जानकारी और निजी PDF, यदि हो, मिट जाएगी।',
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(c, false),
                                          child: Text(
                                            s.t('Cancel', 'रद्द करें'),
                                          ),
                                        ),
                                        FilledButton(
                                          onPressed: () =>
                                              Navigator.pop(c, true),
                                          child: Text(s.t('Delete', 'मिटाएँ')),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (ok == true) {
                                    try {
                                      await s.removeGstInvoice(
                                        widget.existing!,
                                      );
                                      if (context.mounted) {
                                        Navigator.pop(context);
                                      }
                                    } catch (_) {
                                      if (context.mounted) {
                                        message(
                                          context,
                                          s.t(
                                            'Could not delete online. Try again.',
                                            'ऑनलाइन नहीं मिटा। फिर कोशिश करें।',
                                          ),
                                        );
                                      }
                                    }
                                  }
                                },
                          icon: const Icon(Icons.delete_outline),
                          label: Text(s.t('Delete', 'मिटाएँ')),
                        ),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GstReturnsPage extends StatefulWidget {
  final AppStore s;
  const GstReturnsPage(this.s, {super.key});
  @override
  State<GstReturnsPage> createState() => _GstReturnsPageState();
}

class _GstReturnsPageState extends State<GstReturnsPage> {
  String period = _periodNow();
  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final rows = s.gstInvoices.where((i) => i.period == period).toList();
    final sum = GstSummary.forPeriod(rows, period);
    final periods = {
      _periodNow(),
      ...s.gstInvoices.map((e) => e.period),
    }.where((e) => e != 'unknown').toList()..sort((a, b) => b.compareTo(a));
    final blockers = <String>[];
    if (rows.isEmpty) {
      blockers.add(
        s.t(
          'No invoices recorded for this period. This does not establish a Nil return.',
          'इस अवधि के इनवॉइस दर्ज नहीं हैं। इससे शून्य रिटर्न सिद्ध नहीं होता।',
        ),
      );
    }
    if (sum.reviewCount > 0) {
      blockers.add(
        s.t(
          '${sum.reviewCount} invoice(s) need review or correction.',
          '${sum.reviewCount} इनवॉइस की समीक्षा या सुधार बाकी है।',
        ),
      );
    }
    if (s.gst2b.isEmpty || s.gst2bPeriod != period) {
      blockers.add(
        s.t(
          'GSTR-2B data not compared; purchase tax is only a potential input figure.',
          'GSTR-2B से मिलान नहीं हुआ; खरीद कर केवल संभावित इनपुट आँकड़ा है।',
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GstHeading(
          s,
          s.t('RETURN PREPARATION', 'रिटर्न की तैयारी'),
          s.t('Review before you file.', 'फाइल करने से पहले समीक्षा करें।'),
          s.t(
            'A working paper from recorded invoices. Match it to the GST portal, your books and a qualified reviewer.',
            'दर्ज इनवॉइस से कार्यपत्र। GST पोर्टल, अपनी पुस्तकों और योग्य समीक्षक से मिलान करें।',
          ),
        ),
        DropdownButtonFormField<String>(
          initialValue: period,
          decoration: InputDecoration(labelText: s.t('Tax period', 'कर अवधि')),
          items: periods
              .map((p) => DropdownMenuItem(value: p, child: Text(p)))
              .toList(),
          onChanged: (v) => setState(() => period = v!),
        ),
        const SizedBox(height: 20),
        ResponsiveRow(
          children: [
            Stat(
              s.t('Taxable sales', 'कर योग्य बिक्री'),
              money(sum.sales),
              s.t('Recorded invoices only', 'केवल दर्ज इनवॉइस'),
            ),
            Stat(
              s.t('Output GST', 'बिक्री पर GST'),
              money(sum.outputTax),
              s.t('Entered CGST + SGST + IGST', 'दर्ज CGST + SGST + IGST'),
            ),
            Stat(
              s.t('Potential purchase tax', 'संभावित खरीद कर'),
              money(sum.potentialInputTax),
              s.t('Not confirmed eligible ITC', 'पात्र ITC की पुष्टि नहीं'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Panel(
          color: lime,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.t(
                  'Indicative difference · ${money(sum.roughDifference)}',
                  'संकेतात्मक अंतर · ${money(sum.roughDifference)}',
                ),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                s.t(
                  'Output GST minus all recorded purchase tax. This is not your GST liability, challan amount or claimable credit: eligibility, reverse charge, cash/credit ledgers, adjustments and scheme are not modelled.',
                  'बिक्री GST से दर्ज खरीद कर घटाया गया है। यह आपकी GST देनदारी, चालान राशि या दावा योग्य क्रेडिट नहीं है: पात्रता, रिवर्स चार्ज, लेजर, समायोजन और योजना का मॉडल नहीं बना है।',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.t(
                  'Before any official action',
                  'किसी भी आधिकारिक कार्रवाई से पहले',
                ),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              for (final b in blockers)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline, color: warning, size: 19),
                      const SizedBox(width: 8),
                      Expanded(child: Text(b)),
                    ],
                  ),
                ),
              if (blockers.isEmpty)
                Text(
                  s.t(
                    'Basic workspace checks are clear. A professional and official portal review are still needed.',
                    'बुनियादी जाँच ठीक है। विशेषज्ञ और आधिकारिक पोर्टल पर समीक्षा अभी भी ज़रूरी है।',
                  ),
                ),
              const Divider(),
              for (final step in [
                s.t(
                  'Confirm sales and credit/debit notes against your books.',
                  'बिक्री और क्रेडिट/डेबिट नोट पुस्तकों से मिलाएँ।',
                ),
                s.t(
                  'Reconcile purchases against official GSTR-2B and assess ITC eligibility.',
                  'आधिकारिक GSTR-2B से खरीद मिलाएँ और ITC पात्रता जाँचें।',
                ),
                s.t(
                  'Verify return type, period, due date and ledger balances on the GST portal.',
                  'GST पोर्टल पर रिटर्न प्रकार, अवधि, अंतिम तिथि और लेजर शेष जाँचें।',
                ),
                s.t(
                  'Review portal preview and authorise filing/payment yourself.',
                  'पोर्टल पूर्वावलोकन जाँचें और फाइलिंग/भुगतान स्वयं अधिकृत करें।',
                ),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.circle_outlined, size: 18, color: muted),
                      const SizedBox(width: 10),
                      Expanded(child: Text(step)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: () => go(context, s, 'gst-reconcile'),
              icon: const Icon(Icons.rule_outlined),
              label: Text(s.t('Reconcile first', 'पहले मिलान करें')),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                final text =
                    'GeM BizReady GST working paper · $period\nSales taxable: ${money(sum.sales)}\nOutput GST: ${money(sum.outputTax)}\nPurchase tax (unverified): ${money(sum.potentialInputTax)}\nIndicative difference: ${money(sum.roughDifference)}\nInvoice count: ${sum.invoiceCount}\nNeeds review: ${sum.reviewCount}\nNOT A RETURN OR CHALLAN. Confirm on official GST portal.';
                await SharePlus.instance.share(
                  ShareParams(
                    files: [
                      XFile.fromData(
                        Uint8List.fromList(utf8.encode(text)),
                        mimeType: 'text/plain',
                      ),
                    ],
                    fileNameOverrides: ['gst-working-paper-$period.txt'],
                  ),
                );
              },
              icon: const Icon(Icons.ios_share_outlined),
              label: Text(s.t('Share working paper', 'कार्यपत्र साझा करें')),
            ),
            OutlinedButton(
              onPressed: () => openLink(context, s, 'https://www.gst.gov.in/'),
              child: Text(
                s.t('Open official GST portal', 'आधिकारिक GST पोर्टल खोलें'),
              ),
            ),
          ],
        ),
        SourceNote(
          s,
          s.t(
            'Official GSTR-1 guide · review before filing',
            'आधिकारिक GSTR-1 गाइड · फाइलिंग से पहले समीक्षा',
          ),
          'https://tutorial.gst.gov.in/userguide/returns/Creation_of_Outward_Supplies_Return_in_GSTR-1.htm',
        ),
      ],
    );
  }
}

class GstReconcilePage extends StatefulWidget {
  final AppStore s;
  const GstReconcilePage(this.s, {super.key});
  @override
  State<GstReconcilePage> createState() => _GstReconcilePageState();
}

class _GstReconcilePageState extends State<GstReconcilePage> {
  bool loading = false;
  String period = _periodNow();
  Future<void> import() async {
    setState(() => loading = true);
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 2 * 1024 * 1024) {
        throw const FormatException('CSV too large');
      }
      final rows = parse2bCsv(utf8.decode(bytes));
      widget.s.saveGst2b(rows, period);
      if (mounted) {
        message(
          context,
          widget.s.t(
            '${rows.length} comparison rows imported.',
            '${rows.length} तुलना पंक्तियाँ आयात हुईं।',
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        message(
          context,
          widget.s.t(
            'CSV needs Supplier GSTIN, Invoice number, Taxable value and optional CGST/SGST/IGST columns.',
            'CSV में आपूर्तिकर्ता GSTIN, इनवॉइस संख्या, कर योग्य मूल्य और वैकल्पिक CGST/SGST/IGST स्तंभ चाहिए।',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final periods = {
      _periodNow(),
      ...s.gstInvoices.map((e) => e.period),
      if (s.gst2bPeriod.isNotEmpty) s.gst2bPeriod,
    }.where((e) => e != 'unknown').toList()..sort((a, b) => b.compareTo(a));
    final comparison = s.gst2bPeriod == period ? s.gst2b : <Gst2bEntry>[];
    final purchases = s.gstInvoices
        .where((i) => i.direction == 'purchase' && i.period == period)
        .toList();
    final bank = {for (final b in comparison) b.key: b};
    final matched = <String>{};
    final issues = <String>[];
    for (final p in comparison.isEmpty ? <GstInvoice>[] : purchases) {
      final key =
          '${p.sellerGstin.trim().toUpperCase()}|${p.invoiceNumber.trim().toUpperCase()}';
      final b = bank[key];
      if (b == null) {
        issues.add(
          '${p.invoiceNumber.isEmpty ? p.fileName : p.invoiceNumber}: ${s.t('not found in imported comparison', 'आयात तुलना में नहीं मिला')}',
        );
        continue;
      }
      matched.add(key);
      if ((p.taxableValue - b.taxableValue).abs() > 1 ||
          (p.tax - b.tax).abs() > 1) {
        issues.add(
          '${p.invoiceNumber}: ${s.t('amount differs', 'राशि अलग है')} (${money(p.taxableValue)} / ${money(b.taxableValue)})',
        );
      }
    }
    for (final b in comparison) {
      if (!matched.contains(b.key)) {
        issues.add(
          '${b.invoiceNumber}: ${s.t('in comparison file, not in purchases', 'तुलना फ़ाइल में है, खरीद में नहीं')}',
        );
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GstHeading(
          s,
          s.t('PURCHASE RECONCILIATION', 'खरीद का मिलान'),
          s.t('Spot the differences.', 'अंतर पहचानें।'),
          s.t(
            'Compare your purchase invoices with a reviewed GSTR-2B CSV. The comparison flags mismatches; it does not decide ITC eligibility.',
            'खरीद इनवॉइस की समीक्षित GSTR-2B CSV से तुलना करें। अंतर दिखेंगे; ITC पात्रता तय नहीं होगी।',
          ),
        ),
        DropdownButtonFormField<String>(
          initialValue: period,
          decoration: InputDecoration(labelText: s.t('Tax period', 'कर अवधि')),
          items: periods
              .map((p) => DropdownMenuItem(value: p, child: Text(p)))
              .toList(),
          onChanged: (v) => setState(() => period = v!),
        ),
        const SizedBox(height: 18),
        Panel(
          color: lime,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.t(
                  'Your comparison file stays in this private workspace.',
                  'आपकी तुलना फ़ाइल इसी निजी कार्यक्षेत्र में रहती है।',
                ),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                s.t(
                  'Use columns: Supplier GSTIN, Invoice number, Taxable value, CGST, SGST, IGST. Check that the file came from the correct GSTIN and period. Official export layouts can vary.',
                  'स्तंभ रखें: Supplier GSTIN, Invoice number, Taxable value, CGST, SGST, IGST। फ़ाइल का GSTIN और अवधि जाँचें। आधिकारिक निर्यात का रूप अलग हो सकता है।',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: loading ? null : import,
          icon: const Icon(Icons.upload_file_outlined),
          label: Text(s.t('Import comparison CSV', 'तुलना CSV आयात करें')),
        ),
        const SizedBox(height: 24),
        ResponsiveRow(
          children: [
            Stat(
              s.t('Purchases', 'खरीद'),
              '${purchases.length}',
              s.t('Recorded invoices', 'दर्ज इनवॉइस'),
            ),
            Stat(
              s.t('Comparison rows', 'तुलना पंक्तियाँ'),
              '${comparison.length}',
              s.t('Imported in this workspace', 'इस कार्यक्षेत्र में आयात'),
            ),
            Stat(
              s.t('Differences', 'अंतर'),
              '${issues.length}',
              s.t('Check every item', 'हर मद जाँचें'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.t('What needs attention', 'कहाँ ध्यान दें'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (comparison.isEmpty)
                Text(
                  s.t(
                    'Import a comparison CSV to see purchase matches.',
                    'खरीद का मिलान देखने के लिए CSV आयात करें।',
                  ),
                )
              else if (issues.isEmpty)
                Text(
                  s.t(
                    'No amount/key differences found in this import. This is not a full GSTR-2B or ITC eligibility audit.',
                    'इस आयात में कुंजी या राशि का अंतर नहीं मिला। यह पूरी GSTR-2B या ITC पात्रता जाँच नहीं है।',
                  ),
                )
              else
                for (final item in issues)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 18,
                          color: warning,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(item)),
                      ],
                    ),
                  ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        OutlinedButton(
          onPressed: () => go(context, s, 'gst-returns'),
          child: Text(
            s.t('Continue to return review', 'रिटर्न समीक्षा पर जाएँ'),
          ),
        ),
      ],
    );
  }
}

class GstDocumentsPage extends StatelessWidget {
  final AppStore s;
  const GstDocumentsPage(this.s, {super.key});
  @override
  Widget build(BuildContext context) {
    final rows = s.gstInvoices;
    final months = {
      ...rows.map((i) => i.period),
    }.where((p) => p != 'unknown').toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GstHeading(
          s,
          s.t('RECORDS & TRENDS', 'रिकॉर्ड और रुझान'),
          s.t(
            'Find the document. See the pattern.',
            'दस्तावेज़ ढूँढें। रुझान देखें।',
          ),
          s.t(
            'A simple view of the invoices you entered. Private PDF links expire after one minute.',
            'दर्ज इनवॉइस की सरल सूची। निजी PDF लिंक एक मिनट बाद समाप्त होते हैं।',
          ),
        ),
        Text(
          s.t('Recorded periods', 'दर्ज अवधियाँ'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        if (months.isEmpty)
          Panel(
            child: Text(
              s.t(
                'No periods yet. Add an invoice to build a monthly view.',
                'अभी कोई अवधि नहीं। मासिक दृश्य के लिए इनवॉइस जोड़ें।',
              ),
            ),
          )
        else
          for (final period in months.reversed)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      period,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    ResponsiveRow(
                      children: [
                        Text(
                          '${s.t('Sales', 'बिक्री')}: ${money(GstSummary.forPeriod(rows, period).sales)}',
                        ),
                        Text(
                          '${s.t('Purchases', 'खरीद')}: ${money(GstSummary.forPeriod(rows, period).purchases)}',
                        ),
                        Text(
                          '${s.t('Output GST', 'बिक्री GST')}: ${money(GstSummary.forPeriod(rows, period).outputTax)}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        const SizedBox(height: 22),
        Text(
          s.t('Documents', 'दस्तावेज़'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 14),
        if (rows.isEmpty)
          Panel(
            child: Text(
              s.t(
                'No documents recorded yet.',
                'अभी कोई दस्तावेज़ दर्ज नहीं है।',
              ),
            ),
          )
        else
          for (final i in rows.reversed)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Panel(
                child: Row(
                  children: [
                    const Icon(Icons.picture_as_pdf_outlined, color: ink),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            i.fileName,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            '${i.invoiceNumber} · ${_fmtDate(i.invoiceDate)}',
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: i.documentPath == null
                          ? () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => GstUploadPage(s, existing: i),
                              ),
                            )
                          : () async {
                              try {
                                final url = await s.signedInvoiceUrl(
                                  i.documentPath!,
                                );
                                if (context.mounted) openLink(context, s, url);
                              } catch (_) {
                                if (context.mounted) {
                                  message(
                                    context,
                                    s.t(
                                      'Could not open PDF. Sign in and retry.',
                                      'PDF नहीं खुला। साइन इन कर फिर कोशिश करें।',
                                    ),
                                  );
                                }
                              }
                            },
                      child: Text(
                        i.documentPath == null
                            ? s.t('Fields only', 'केवल जानकारी')
                            : s.t('Open PDF', 'PDF खोलें'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        const SizedBox(height: 14),
        Text(
          s.t(
            'These trends reflect only documents added here. They are not your complete books or GST portal ledger.',
            'ये रुझान केवल यहाँ जोड़े दस्तावेज़ दिखाते हैं। ये आपकी पूरी लेखा-पुस्तक या GST पोर्टल लेजर नहीं हैं।',
          ),
        ),
      ],
    );
  }
}

class AboutPage extends StatelessWidget {
 final AppStore s;const AboutPage(this.s,{super.key});
 @override Widget build(BuildContext context)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[GstHeading(s,s.t('ABOUT THE PROJECT','परियोजना के बारे में'),s.t('Small business, clearer decisions.','छोटे व्यवसाय, स्पष्ट निर्णय।'),s.t('GeM BizReady is an independent project for businesses exploring government sales and organising their GST paperwork.','GeM BizReady सरकारी बिक्री के अवसर और GST दस्तावेज़ व्यवस्थित करने वाले व्यवसायों के लिए स्वतंत्र परियोजना है।')),Panel(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(s.t('How it helps','यह कैसे मदद करता है'),style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:12),Text(s.t('The GeM tools show assumptions, eligibility gaps and next actions. The GST workspace extracts text from invoices locally, highlights basic inconsistencies and helps prepare a reviewable working paper. All official registrations, filings and payments happen through authorised channels after your approval.','GeM टूल धारणाएँ, पात्रता की कमियाँ और अगले कदम दिखाते हैं। GST कार्यक्षेत्र इनवॉइस का टेक्स्ट डिवाइस पर निकालता है, बुनियादी अंतर दिखाता है और समीक्षा योग्य कार्यपत्र तैयार करता है। आधिकारिक पंजीकरण, फाइलिंग और भुगतान आपकी मंजूरी के बाद अधिकृत माध्यम से होते हैं।')),const SizedBox(height:18),Text(s.t('Your information','आपकी जानकारी'),style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:12),Text(s.t('Guest answers are stored on this device. Signing in syncs your entries to a private Supabase account. Invoice PDFs are uploaded only when you select private PDF saving. Optional research analytics are controlled separately on the privacy page.','अतिथि उत्तर इस डिवाइस पर रहते हैं। साइन इन पर आपकी जानकारी निजी Supabase खाते में जुड़ती है। इनवॉइस PDF तभी अपलोड होती है जब आप निजी सहेजना चुनते हैं। वैकल्पिक शोध उपयोग का नियंत्रण गोपनीयता पृष्ठ पर अलग है।')),const SizedBox(height:18),Text(s.t('Independent guidance','स्वतंत्र मार्गदर्शन'),style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:12),Text(s.t('This project is not affiliated with GeM or GSTN and is not a tax filing, registration or payment service. Verify current rules and deadlines on the official portals.','यह परियोजना GeM या GSTN से संबद्ध नहीं है और कर फाइलिंग, पंजीकरण या भुगतान सेवा नहीं है। वर्तमान नियम और तिथियाँ आधिकारिक पोर्टल पर जाँचें।')),SourceNote(s,'GeM',gemSource),SourceNote(s,'GST','https://www.gst.gov.in/'),const SizedBox(height:16),OutlinedButton(onPressed:()=>go(context,s,'account'),child:Text(s.t('Privacy and saved data','गोपनीयता और सहेजा डेटा')))]))]);
}
