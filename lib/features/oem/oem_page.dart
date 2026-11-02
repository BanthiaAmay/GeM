import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../data/app_store.dart';
import '../components.dart';
import '../glass.dart';
import '../scroll_hint.dart';
import '../widgets.dart' show openLink;
import 'oem_data.dart';

/// Searchable / filterable directory of OEM partners that Pune MSMEs can
/// contact to get GeM OEM Authorization.
class OemPage extends StatefulWidget {
  final AppStore store;
  const OemPage({super.key, required this.store});

  @override
  State<OemPage> createState() => _OemPageState();
}

class _OemPageState extends State<OemPage> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String? _activeTag; // null = All

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<OemEntry> get _filtered {
    final q = _query;
    final tag = _activeTag;
    return kOemDirectory.where((e) {
      final matchesTag = tag == null || e.filterTag == tag;
      final matchesQuery = q.isEmpty ||
          e.name.toLowerCase().contains(q) ||
          e.segment.toLowerCase().contains(q) ||
          e.gemCategories.toLowerCase().contains(q) ||
          e.hqCity.toLowerCase().contains(q);
      return matchesTag && matchesQuery;
    }).toList();
  }

  AppStore get s => widget.store;

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            GlassBar.top(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.sm,
                AppSpace.sm,
                AppSpace.sm,
                AppSpace.sm,
              ),
              child: Row(
                children: [
                  AppIconButton(
                    icon: Icons.arrow_back_ios_new,
                    tooltip: s.t('Back', 'वापस'),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        s.t('OEM Database', 'OEM डेटाबेस'),
                        textAlign: TextAlign.center,
                        style: AppText.title,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSize.tap),
                ],
              ),
            ),
            Expanded(
              child: ScrollMoreHint(
                builder: (context, controller) => CustomScrollView(
                  controller: controller,
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpace.gutter,
                          AppSpace.lg,
                          AppSpace.gutter,
                          0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.t(
                                '18 verified OEM partners across 8 categories. Tap any card to see contact details and how to get authorized on GeM.',
                                '18 सत्यापित OEM भागीदार, 8 श्रेणियों में। संपर्क विवरण और GeM पर प्राधिकरण प्रक्रिया देखने के लिए कोई भी कार्ड टैप करें।',
                              ),
                              style: AppText.secondary(AppText.body),
                            ),
                            const SizedBox(height: AppSpace.lg),
                            // Search field
                            TextField(
                              controller: _searchCtrl,
                              style: AppText.body,
                              decoration: InputDecoration(
                                hintText: s.t(
                                  'Search by name or category…',
                                  'नाम या श्रेणी से खोजें…',
                                ),
                                hintStyle: AppText.secondary(AppText.body),
                                prefixIcon: const Icon(
                                  Icons.search,
                                  color: AppColors.textHint,
                                  size: AppIconSize.md,
                                ),
                                suffixIcon: _query.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(
                                          Icons.clear,
                                          size: AppIconSize.sm,
                                        ),
                                        onPressed: () {
                                          _searchCtrl.clear();
                                        },
                                      )
                                    : null,
                                filled: true,
                                fillColor: AppColors.surfaceMuted,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: AppSpace.md,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.md,
                                  ),
                                  borderSide: const BorderSide(
                                    color: AppColors.border,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.md,
                                  ),
                                  borderSide: const BorderSide(
                                    color: AppColors.border,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.md,
                                  ),
                                  borderSide: const BorderSide(
                                    color: AppColors.brand,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpace.md),
                            // Filter chips
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _FilterChip(
                                    label: s.t('All', 'सभी'),
                                    selected: _activeTag == null,
                                    onTap: () =>
                                        setState(() => _activeTag = null),
                                  ),
                                  for (final tag in kOemFilterTags) ...[
                                    const SizedBox(width: AppSpace.xs),
                                    _FilterChip(
                                      label: tag,
                                      selected: _activeTag == tag,
                                      onTap: () => setState(
                                        () => _activeTag =
                                            _activeTag == tag ? null : tag,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpace.md),
                            Text(
                              s.t(
                                '${filtered.length} OEM${filtered.length == 1 ? '' : 's'} found',
                                '${filtered.length} OEM मिले',
                              ),
                              style: AppText.caption,
                            ),
                            const SizedBox(height: AppSpace.md),
                          ],
                        ),
                      ),
                    ),
                    if (filtered.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpace.huge),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.search_off_outlined,
                                size: AppIconSize.lg,
                                color: AppColors.textHint,
                              ),
                              const SizedBox(height: AppSpace.md),
                              Text(
                                s.t(
                                  'No OEMs match your search.',
                                  'कोई OEM नहीं मिला।',
                                ),
                                style: AppText.secondary(AppText.body),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) {
                            final oem = filtered[i];
                            final isLast = i == filtered.length - 1;
                            return Padding(
                              padding: EdgeInsets.fromLTRB(
                                AppSpace.gutter,
                                0,
                                AppSpace.gutter,
                                isLast ? 80 : AppSpace.md,
                              ),
                              child: _OemCard(store: s, oem: oem),
                            );
                          },
                          childCount: filtered.length,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.md,
        vertical: AppSpace.xs + 2,
      ),
      decoration: BoxDecoration(
        color: selected ? AppColors.brand : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: selected ? AppColors.brand : AppColors.border,
        ),
      ),
      child: Text(
        label,
        style: AppText.label.copyWith(
          color: selected ? AppColors.surface : AppColors.textSecondary,
        ),
      ),
    ),
  );
}

class _OemCard extends StatefulWidget {
  final AppStore store;
  final OemEntry oem;
  const _OemCard({required this.store, required this.oem});

  @override
  State<_OemCard> createState() => _OemCardState();
}

class _OemCardState extends State<_OemCard> {
  bool _expanded = false;

  AppStore get s => widget.store;
  OemEntry get oem => widget.oem;

  String get _starsLabel {
    if (oem.priorityStars == 5) return s.t('Highest priority', 'सर्वोच्च');
    if (oem.priorityStars == 4) return s.t('High priority', 'उच्च');
    return s.t('Medium priority', 'मध्यम');
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.all(AppSpace.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.brandTint,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Icon(
                    Icons.business_outlined,
                    color: AppColors.brand,
                    size: AppIconSize.md,
                  ),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(oem.name, style: AppText.title),
                      const SizedBox(height: AppSpace.xs),
                      Text(
                        '${oem.segment}  ·  ${oem.hqCity}',
                        style: AppText.caption,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                // Priority badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.sm,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: oem.priorityStars == 5
                        ? AppColors.brandTint
                        : oem.priorityStars == 4
                        ? AppColors.infoTint
                        : AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    _starsLabel,
                    style: AppText.label.copyWith(
                      color: oem.priorityStars == 5
                          ? AppColors.brand
                          : oem.priorityStars == 4
                          ? AppColors.info
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // GeM Categories + Quadrant
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.lg,
              0,
              AppSpace.lg,
              AppSpace.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.grid_view_outlined,
                      size: AppIconSize.sm,
                      color: AppColors.textHint,
                    ),
                    const SizedBox(width: AppSpace.xs),
                    Text(
                      s.t('GeM Quadrant', 'GeM क्वाड्रेंट'),
                      style: AppText.caption,
                    ),
                    const SizedBox(width: AppSpace.sm),
                    Text(
                      oem.quadrant,
                      style: AppText.bodyStrong.copyWith(
                        color: AppColors.brand,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.xs),
                Text(oem.gemCategories, style: AppText.secondary(AppText.bodySmall)),
              ],
            ),
          ),
          // Expand / collapse toggle
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.lg,
                AppSpace.sm,
                AppSpace.lg,
                AppSpace.sm,
              ),
              child: Row(
                children: [
                  Text(
                    s.t('Contact & Auth', 'संपर्क और प्राधिकरण'),
                    style: AppText.bodyStrong.copyWith(color: AppColors.brand),
                  ),
                  const Spacer(),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppColors.brand,
                    size: AppIconSize.md,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.all(AppSpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Phone
                  _ContactRow(
                    icon: Icons.phone_outlined,
                    label: s.t('Phone', 'फ़ोन'),
                    value: oem.phone,
                    onTap: () => openLink(context, s, 'tel:${oem.phone}'),
                  ),
                  const SizedBox(height: AppSpace.sm),
                  // Corp email
                  _ContactRow(
                    icon: Icons.email_outlined,
                    label: s.t('Corp. Email', 'कॉर्प. ईमेल'),
                    value: oem.corpEmail,
                    onTap: () =>
                        openLink(context, s, 'mailto:${oem.corpEmail}'),
                  ),
                  if (oem.govtEmail.isNotEmpty) ...[
                    const SizedBox(height: AppSpace.sm),
                    _ContactRow(
                      icon: Icons.alternate_email,
                      label: s.t('Govt. Sales Email', 'सरकारी बिक्री ईमेल'),
                      value: oem.govtEmail,
                      onTap: () =>
                          openLink(context, s, 'mailto:${oem.govtEmail}'),
                    ),
                  ],
                  const SizedBox(height: AppSpace.sm),
                  // Website
                  _ContactRow(
                    icon: Icons.language,
                    label: s.t('Website', 'वेबसाइट'),
                    value: oem.website
                        .replaceAll('https://', '')
                        .replaceAll('http://', ''),
                    onTap: () => openLink(context, s, oem.website),
                  ),
                  const Divider(height: AppSpace.xxl, color: AppColors.border),
                  // Auth Process
                  Text(
                    s.t('Auth Process', 'प्राधिकरण प्रक्रिया'),
                    style: AppText.bodyStrong,
                  ),
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    oem.authProcess,
                    style: AppText.secondary(AppText.bodySmall),
                  ),
                  const SizedBox(height: AppSpace.md),
                  // Key Docs
                  Text(
                    s.t('Key Documents', 'मुख्य दस्तावेज़'),
                    style: AppText.bodyStrong,
                  ),
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    oem.keyDocs,
                    style: AppText.secondary(AppText.bodySmall),
                  ),
                  const SizedBox(height: AppSpace.md),
                  // Processing time
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule_outlined,
                        size: AppIconSize.sm,
                        color: AppColors.textHint,
                      ),
                      const SizedBox(width: AppSpace.xs),
                      Text(
                        s.t('Processing Time', 'प्रसंस्करण समय'),
                        style: AppText.caption,
                      ),
                      const SizedBox(width: AppSpace.sm),
                      Text(oem.processingDays, style: AppText.bodyStrong),
                    ],
                  ),
                  if (oem.remarks.isNotEmpty) ...[
                    const Divider(
                      height: AppSpace.xxl,
                      color: AppColors.border,
                    ),
                    AppCard(
                      tone: AppCardTone.muted,
                      padding: const EdgeInsets.all(AppSpace.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: AppIconSize.sm,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: AppSpace.xs),
                              Text(
                                s.t(
                                  'Pune / Maharashtra Presence',
                                  'पुणे / महाराष्ट्र उपस्थिति',
                                ),
                                style: AppText.bodyStrong,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpace.xs),
                          Text(
                            oem.punePresence,
                            style: AppText.secondary(AppText.bodySmall),
                          ),
                          const SizedBox(height: AppSpace.sm),
                          Text(
                            oem.remarks,
                            style: AppText.secondary(AppText.bodySmall),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpace.lg),
                  // CTA buttons
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          label: s.t('Call', 'कॉल करें'),
                          trailingIcon: Icons.phone_outlined,
                          variant: AppButtonVariant.secondary,
                          onPressed: () =>
                              openLink(context, s, 'tel:${oem.phone}'),
                        ),
                      ),
                      const SizedBox(width: AppSpace.md),
                      Expanded(
                        child: AppButton(
                          label: s.t('Email', 'ईमेल करें'),
                          trailingIcon: Icons.email_outlined,
                          onPressed: () => openLink(
                            context,
                            s,
                            'mailto:${oem.govtEmail.isNotEmpty ? oem.govtEmail : oem.corpEmail}',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: AppIconSize.sm, color: AppColors.textHint),
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppText.caption),
              Text(
                value,
                style: AppText.bodySmall.copyWith(color: AppColors.brand),
              ),
            ],
          ),
        ),
        const Icon(
          Icons.open_in_new,
          size: AppIconSize.sm,
          color: AppColors.textHint,
        ),
      ],
    ),
  );
}
