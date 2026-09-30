import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme.dart';
import '../data/app_store.dart';

void go(BuildContext context, AppStore store, String page) {
  store.event(
    'cta_clicked',
    page: ModalRoute.of(context)?.settings.name,
    props: {'destination': page},
  );
  Navigator.of(context).pushNamed('/$page');
}

Future<void> openLink(BuildContext context, AppStore store, String url) async {
  store.event('external_link_clicked', props: {'host': Uri.parse(url).host});
  try {
    if (!await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    )) {
      throw Exception();
    }
  } catch (_) {
    if (context.mounted) {
      message(
        context,
        store.t(
          'Could not open the link. Please try again.',
          'लिंक नहीं खुला। दोबारा कोशिश करें।',
        ),
      );
    }
  }
}

void message(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

class Panel extends StatelessWidget {
  final Widget child;
  final Color? color;
  final EdgeInsets padding;
  const Panel({
    super.key,
    required this.child,
    this.color,
    this.padding = const EdgeInsets.all(24),
  });
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: Material(
      color: color ?? Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: line),
      ),
      child: Padding(padding: padding, child: child),
    ),
  );
}

class Heading extends StatelessWidget {
  final String eyebrow, title, subtitle;
  const Heading(this.eyebrow, this.title, this.subtitle, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
            color: green,
          ),
        ),
        const SizedBox(height: 12),
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 10),
        Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
      ],
    ),
  );
}

class Tag extends StatelessWidget {
  final String label;
  final Color? color;
  const Tag(this.label, {super.key, this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color ?? lime,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: green,
      ),
    ),
  );
}

class Stat extends StatelessWidget {
  final String label, value, detail;
  const Stat(this.label, this.value, this.detail, {super.key});
  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 12),
        Text(value, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(detail),
      ],
    ),
  );
}

class ResponsiveRow extends StatelessWidget {
  final List<Widget> children;
  final double breakpoint;
  const ResponsiveRow({
    super.key,
    required this.children,
    this.breakpoint = 700,
  });
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => c.maxWidth < breakpoint
        ? Column(
            children: [
              for (final w in children)
                Padding(padding: const EdgeInsets.only(bottom: 16), child: w),
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(width: 20),
                Expanded(child: children[i]),
              ],
            ],
          ),
  );
}

class NextActions extends StatelessWidget {
  final AppStore store;
  final String next;
  const NextActions(this.store, this.next, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24),
    child: Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        FilledButton.icon(
          onPressed: () => go(context, store, next),
          icon: const Icon(Icons.arrow_forward, size: 18),
          label: Text(
            '${store.t('Continue', 'आगे बढ़ें')}: ${store.toolName(next)}',
          ),
        ),
        OutlinedButton(
          onPressed: () => go(context, store, 'report'),
          child: Text(store.t('See my full report', 'मेरी पूरी रिपोर्ट देखें')),
        ),
      ],
    ),
  );
}

class SourceNote extends StatelessWidget {
  final AppStore store;
  final String label, url;
  const SourceNote(this.store, this.label, this.url, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: InkWell(
      onTap: () => openLink(context, store, url),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.open_in_new, size: 14, color: muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: muted,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
