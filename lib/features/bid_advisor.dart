import 'package:flutter/material.dart';
import '../core/models.dart' show money;
import '../core/theme.dart';
import '../data/app_store.dart';
import 'components.dart';
import 'widgets.dart' show openLink;

// ── Scoring types ─────────────────────────────────────────────────────────────

enum _Verdict { go, caution, skip }

class _Check {
  final String label;
  final bool pass;
  final String detail;
  const _Check({required this.label, required this.pass, required this.detail});
}

// ── Scoring logic (pure function, no IO) ─────────────────────────────────────

class _AdvisorResult {
  final _Verdict verdict;
  final List<_Check> checks;
  const _AdvisorResult(this.verdict, this.checks);
}

_AdvisorResult _score(
  AppStore store,
  Map<String, dynamic> bid,
) {
  final s = store;
  final details = Map<String, dynamic>.from(bid['details'] as Map? ?? {});
  final profile = store.profile;

  final records = List<String>.from(profile['records'] as List? ?? []);
  final panReady = profile['panReady'] as String? ?? '';
  final turnoverRange = profile['pastOrderValueRange'] as String? ?? '';
  final pastOrderCount =
      int.tryParse((profile['pastOrderCount'] as String? ?? '0').trim()) ?? 0;

  final emdAmountStr = (details['emd_amount'] as String? ?? '').trim();
  final emdRequired = details['emd_required'] as String? ?? '';
  final emdAmount = num.tryParse(emdAmountStr);
  final docs = List<String>.from(details['documents_required'] ?? []);
  final experience = (details['experience'] as String? ?? '').trim();

  final checks = <_Check>[];

  // ── 1. PAN readiness ─────────────────────────────────────────────────────
  final hasPan = records.contains('pan') || panReady == 'yes';
  checks.add(
    _Check(
      label: s.t('PAN & basic identity', 'PAN और बुनियादी पहचान'),
      pass: hasPan,
      detail: hasPan
          ? s.t(
              'PAN is ready — you can register on GeM.',
              'PAN तैयार है — आप GeM पर पंजीकरण कर सकते हैं।',
            )
          : s.t(
              'PAN not confirmed. Complete PAN setup before bidding.',
              'PAN की पुष्टि नहीं हुई। बोली देने से पहले PAN तैयार करें।',
            ),
    ),
  );

  // ── 2. Required documents ────────────────────────────────────────────────
  if (docs.isEmpty) {
    checks.add(
      _Check(
        label: s.t('Required documents', 'आवश्यक दस्तावेज़'),
        pass: true,
        detail: s.t(
          'No specific documents listed for this bid.',
          'इस बोली के लिए कोई विशेष दस्तावेज़ नहीं हैं।',
        ),
      ),
    );
  } else {
    // Map doc keywords to profile record keys
    final docMap = {
      'PAN': 'pan',
      'GST': 'gstin',
      'GSTIN': 'gstin',
      'Udyam': 'udyam',
      'MSME': 'udyam',
      'Bank Account': 'bank',
      'Bank Details': 'bank',
      'ITR': 'itr',
      'Income Tax': 'itr',
      'Registration': 'registration',
    };
    final missing = <String>[];
    for (final doc in docs) {
      final upper = doc.toUpperCase();
      for (final entry in docMap.entries) {
        if (upper.contains(entry.key.toUpperCase())) {
          if (!records.contains(entry.value)) {
            missing.add(doc);
          }
          break;
        }
      }
    }
    final missingText = missing
        .take(2)
        .map((d) => d.length > 30 ? '${d.substring(0, 28)}…' : d)
        .join(', ');
    checks.add(
      _Check(
        label: s.t('Required documents', 'आवश्यक दस्तावेज़'),
        pass: missing.isEmpty,
        detail: missing.isEmpty
            ? s.t(
                'You have the key documents for this bid.',
                'आपके पास इस बोली के मुख्य दस्तावेज़ हैं।',
              )
            : s.t(
                'May need: $missingText',
                'ज़रूरी हो सकते हैं: $missingText',
              ),
      ),
    );
  }

  // ── 3. EMD affordability ─────────────────────────────────────────────────
  final emdExempt = emdRequired == 'No' || emdAmount == 0;
  if (emdExempt) {
    checks.add(
      _Check(
        label: s.t('EMD (security deposit)', 'EMD (सुरक्षा जमा)'),
        pass: true,
        detail: records.contains('udyam')
            ? s.t(
                'EMD not required, and your Udyam registration may further protect you.',
                'EMD आवश्यक नहीं है, और Udyam पंजीकरण आपको अतिरिक्त सुरक्षा दे सकता है।',
              )
            : s.t(
                'EMD is not required for this bid.',
                'इस बोली के लिए EMD आवश्यक नहीं है।',
              ),
      ),
    );
  } else {
    // Estimate max affordable EMD as 5% of turnover upper bound
    final turnoverMax = {
      'under10L': 1000000,
      '10to25L': 2500000,
      '25to50L': 5000000,
      '50Lto1Cr': 10000000,
      'above1Cr': 50000000,
    };
    final maxTurnover = (turnoverMax[turnoverRange] ?? 0).toDouble();
    final affordableEmd = maxTurnover * 0.05; // 5% of max turnover
    final emdStr = emdAmount != null ? money(emdAmount) : emdAmountStr;
    final canAfford =
        maxTurnover == 0 ||
        emdAmount == null ||
        emdAmount <= affordableEmd;
    checks.add(
      _Check(
        label: s.t('EMD (security deposit)', 'EMD (सुरक्षा जमा)'),
        pass: canAfford,
        detail: canAfford
            ? s.t(
                'EMD of $emdStr looks manageable for your turnover range.',
                '$emdStr EMD आपकी टर्नओवर सीमा में उचित लगती है।',
              )
            : s.t(
                'EMD of $emdStr may be high for your turnover range. Check if Udyam exemption applies.',
                '$emdStr EMD आपकी टर्नओवर सीमा के लिए अधिक हो सकती है। जाँचें कि Udyam छूट लागू होती है या नहीं।',
              ),
      ),
    );
  }

  // ── 4. Experience requirement ────────────────────────────────────────────
  if (experience.isEmpty) {
    checks.add(
      _Check(
        label: s.t('Prior experience', 'पूर्व अनुभव'),
        pass: true,
        detail: s.t(
          'No experience requirement listed for this bid.',
          'इस बोली के लिए कोई अनुभव की आवश्यकता नहीं दी गई है।',
        ),
      ),
    );
  } else {
    final hasExp = pastOrderCount > 0;
    checks.add(
      _Check(
        label: s.t('Prior experience', 'पूर्व अनुभव'),
        pass: hasExp,
        detail: hasExp
            ? s.t(
                'You have past orders on record — this helps meet the experience requirement.',
                'आपके पास पिछले ऑर्डर हैं — यह इस बोली की अनुभव शर्त पूरी करने में मदद करता है।',
              )
            : s.t(
                'This bid requires: $experience. You have no prior orders on record — consider first submitting small bids to build history.',
                'इस बोली में अनुभव आवश्यक है: $experience। आपके पास पिछले ऑर्डर नहीं हैं — पहले छोटी बोलियाँ दें।',
              ),
      ),
    );
  }

  // ── Verdict ───────────────────────────────────────────────────────────────
  final failing = checks.where((c) => !c.pass).length;
  final verdict = failing == 0
      ? _Verdict.go
      : failing == 1
      ? _Verdict.caution
      : _Verdict.skip;

  return _AdvisorResult(verdict, checks);
}

// ── Bottom sheet ──────────────────────────────────────────────────────────────

Future<void> showBidAdvisorSheet({
  required BuildContext context,
  required AppStore store,
  required Map<String, dynamic> bid,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    builder: (ctx) => BidAdvisorSheet(store: store, bid: bid),
  );
}

class BidAdvisorSheet extends StatelessWidget {
  final AppStore store;
  final Map<String, dynamic> bid;
  const BidAdvisorSheet({super.key, required this.store, required this.bid});

  @override
  Widget build(BuildContext context) {
    final s = store;
    final result = _score(s, bid);
    final title = bid['title'] as String? ?? '';

    final verdictColor = switch (result.verdict) {
      _Verdict.go => AppColors.brand,
      _Verdict.caution => AppColors.warning,
      _Verdict.skip => AppColors.danger,
    };
    final verdictBg = switch (result.verdict) {
      _Verdict.go => AppColors.brandTint,
      _Verdict.caution => AppColors.warningTint,
      _Verdict.skip => AppColors.dangerTint,
    };
    final verdictLabel = switch (result.verdict) {
      _Verdict.go => s.t('Go ahead', 'आगे बढ़ें'),
      _Verdict.caution => s.t('Proceed with caution', 'सावधानी से आगे बढ़ें'),
      _Verdict.skip => s.t('Not recommended', 'अनुशंसित नहीं'),
    };
    final verdictIcon = switch (result.verdict) {
      _Verdict.go => Icons.check_circle_outline,
      _Verdict.caution => Icons.warning_amber_outlined,
      _Verdict.skip => Icons.cancel_outlined,
    };

    final saathiQuestion = s.t(
      'Should I bid on "${title.length > 60 ? '${title.substring(0, 58)}…' : title}"? What do I need to prepare?',
      '"${title.length > 60 ? '${title.substring(0, 58)}…' : title}" पर बोली देनी चाहिए? मुझे क्या तैयार करना होगा?',
    );

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, controller) => SingleChildScrollView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(
          AppSpace.gutter,
          AppSpace.md,
          AppSpace.gutter,
          AppSpace.xxl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpace.lg),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              s.t('Bid Advisor', 'बोली सलाहकार'),
              style: AppText.overline.copyWith(color: AppColors.textHint),
            ),
            const SizedBox(height: AppSpace.xs),
            Text(
              title,
              style: AppText.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpace.lg),

            // Verdict banner
            Container(
              padding: const EdgeInsets.all(AppSpace.lg),
              decoration: BoxDecoration(
                color: verdictBg,
                borderRadius: AppRadius.card,
              ),
              child: Row(
                children: [
                  Icon(verdictIcon, color: verdictColor, size: 28),
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          verdictLabel,
                          style: AppText.bodyStrong.copyWith(
                            color: verdictColor,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _verdictSubtitle(s, result.verdict),
                          style: AppText.caption.copyWith(color: verdictColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.xl),

            Text(
              s.t('Your readiness check', 'आपकी तैयारी जाँच'),
              style: AppText.h2,
            ),
            const SizedBox(height: AppSpace.md),

            for (final check in result.checks)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.md),
                child: _CheckRow(check: check, store: s),
              ),

            const SizedBox(height: AppSpace.xl),

            // CTA: Ask Saathi
            AppButton(
              label: s.t('Ask Saathi about this bid', 'इस बोली के बारे में साथी से पूछें'),
              icon: Icons.auto_awesome_outlined,
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamed(
                  context,
                  '/saathi',
                  arguments: saathiQuestion,
                );
              },
            ),
            const SizedBox(height: AppSpace.md),
            AppButton(
              label: s.t('View on GeM', 'GeM पर देखें'),
              variant: AppButtonVariant.secondary,
              trailingIcon: Icons.open_in_new,
              onPressed: () => openLink(context, s, bid['source_url'] as String? ?? ''),
            ),

            const SizedBox(height: AppSpace.lg),
            Text(
              s.t(
                'Advisor is based on your profile — confirm all requirements on GeM before bidding.',
                'सलाह आपकी प्रोफ़ाइल पर आधारित है — बोली देने से पहले GeM पर सभी ज़रूरतें जाँचें।',
              ),
              style: AppText.caption.copyWith(color: AppColors.textHint),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _verdictSubtitle(AppStore s, _Verdict verdict) => switch (verdict) {
    _Verdict.go => s.t(
      'Your profile matches well for this bid.',
      'आपकी प्रोफ़ाइल इस बोली के लिए अच्छी तरह मेल खाती है।',
    ),
    _Verdict.caution => s.t(
      'Some preparation may be needed before bidding.',
      'बोली देने से पहले कुछ तैयारी की ज़रूरत हो सकती है।',
    ),
    _Verdict.skip => s.t(
      'Multiple gaps detected — consider building your profile first.',
      'कई कमियाँ मिलीं — पहले प्रोफ़ाइल मजबूत करने पर विचार करें।',
    ),
  };
}

class _CheckRow extends StatelessWidget {
  final _Check check;
  final AppStore store;
  const _CheckRow({required this.check, required this.store});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border(
          left: BorderSide(
            color: check.pass ? AppColors.brand : AppColors.warning,
            width: 3,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              check.pass
                  ? Icons.check_circle_outline
                  : Icons.error_outline,
              size: 16,
              color: check.pass ? AppColors.brand : AppColors.warning,
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  check.label,
                  style: AppText.label.copyWith(
                    color:
                        check.pass ? AppColors.brand : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(check.detail, style: AppText.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── /advisor route entry page ─────────────────────────────────────────────────

class AdvisorPage extends StatelessWidget {
  final AppStore store;
  const AdvisorPage({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final s = store;
    final bids = s.compareSelection.isNotEmpty
        ? s.compareSelection
        : <Map<String, dynamic>>[];

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: Text(s.t('Bid Advisor', 'बोली सलाहकार'))),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.gutter),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const DepthIcon(
                    Icons.auto_awesome_outlined,
                    size: AppIconSize.lg + 8,
                    color: AppColors.brand,
                    lifted: true,
                  ),
                  const SizedBox(height: AppSpace.lg),
                  Text(
                    s.t(
                      'Bid Advisor',
                      'बोली सलाहकार',
                    ),
                    style: AppText.h1,
                  ),
                  const SizedBox(height: AppSpace.sm),
                  Text(
                    s.t(
                      'The Advisor checks each bid against your profile — documents, EMD, experience — and gives you a readiness verdict.',
                      'सलाहकार आपकी प्रोफ़ाइल के आधार पर हर बोली जाँचता है — दस्तावेज़, EMD, अनुभव — और तैयारी का परिणाम देता है।',
                    ),
                    style: AppText.body,
                  ),
                  const SizedBox(height: AppSpace.xl),
                  if (bids.isEmpty) ...[
                    StateView(
                      kind: StateKind.empty,
                      title: s.t('No bids selected', 'कोई बोली नहीं चुनी'),
                      message: s.t(
                        'Open the Bids page, tap "+ Compare" on any bid, then come back here to get advice on each one.',
                        'बोलियाँ पेज खोलें, किसी भी बोली पर "+ तुलना" दबाएँ, फिर यहाँ वापस आएँ।',
                      ),
                      actionLabel: s.t('Go to live bids', 'लाइव बोलियाँ देखें'),
                      onAction: () => Navigator.pushReplacementNamed(context, '/bids'),
                    ),
                  ] else ...[
                    Text(
                      s.t(
                        'Tap a bid to see your readiness:',
                        'तैयारी जाँचने के लिए कोई बोली चुनें:',
                      ),
                      style: AppText.bodyStrong,
                    ),
                    const SizedBox(height: AppSpace.md),
                    for (final bid in bids)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpace.md),
                        child: _AdvisorBidTile(
                          bid: bid,
                          store: s,
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdvisorBidTile extends StatelessWidget {
  final Map<String, dynamic> bid;
  final AppStore store;
  const _AdvisorBidTile({required this.bid, required this.store});

  @override
  Widget build(BuildContext context) {
    final s = store;
    final result = _score(s, bid);
    final verdictColor = switch (result.verdict) {
      _Verdict.go => AppColors.brand,
      _Verdict.caution => AppColors.warning,
      _Verdict.skip => AppColors.danger,
    };
    final verdictLabel = switch (result.verdict) {
      _Verdict.go => s.t('Go', 'आगे बढ़ें'),
      _Verdict.caution => s.t('Caution', 'सावधानी'),
      _Verdict.skip => s.t('Skip', 'छोड़ें'),
    };
    return AppCard(
      onTap: () => showBidAdvisorSheet(context: context, store: s, bid: bid),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bid['title'] as String? ?? '—',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodyStrong,
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  bid['source_id'] as String? ?? '',
                  style: AppText.caption.copyWith(color: AppColors.textHint),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.md),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.sm,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: verdictColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              verdictLabel,
              style: AppText.label.copyWith(
                color: verdictColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          Icon(
            Icons.chevron_right,
            color: AppColors.textHint,
            size: AppIconSize.sm,
          ),
        ],
      ),
    );
  }
}
