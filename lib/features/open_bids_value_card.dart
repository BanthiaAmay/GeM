import 'package:flutter/material.dart';
import '../core/models.dart' show money;
import '../core/tokens.dart';
import '../data/app_store.dart';
import 'components.dart';

/// ₹ in lakh / crore, the way buyers and sellers quote bid values:
/// "₹1.25 Cr", "₹18.5 L", "₹45,000".
String inrShort(double value) {
  if (value >= 10000000) return '₹${(value / 10000000).toStringAsFixed(2)} Cr';
  if (value >= 100000) return '₹${(value / 100000).toStringAsFixed(1)} L';
  return money(value);
}

/// Why bids are not completely valued, e.g. "2 awaiting valuation · 1
/// failed, will retry". Parts that are zero are left out; null if none.
String? _breakdown(
  AppStore s,
  ({
    int open,
    int complete,
    int incomplete,
    int pending,
    int failed,
    int noPrice,
    double completeValue,
    double partialValue,
  })
  v,
) {
  final parts = [
    if (v.pending > 0)
      s.t(
        '{n} awaiting valuation',
        '{n} मूल्यांकन की प्रतीक्षा में',
        vars: {'n': '${v.pending}'},
      ),
    if (v.failed > 0)
      s.t(
        '{n} failed, will retry',
        '{n} विफल, फिर कोशिश होगी',
        vars: {'n': '${v.failed}'},
      ),
    if (v.noPrice > 0)
      s.t(
        '{n} no market price found',
        '{n} का बाज़ार मूल्य नहीं मिला',
        vars: {'n': '${v.noPrice}'},
      ),
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

/// The home hero's single tile: estimated contract value of the user's
/// open matched bids closing in the next 10 days. The main figure counts
/// only completely valued bids; partial estimates are shown apart and never
/// added to it. Never shown as profit or earnings.
class OpenBidsValueCard extends StatelessWidget {
  final AppStore store;
  final VoidCallback? onTap;
  const OpenBidsValueCard({super.key, required this.store, this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = store;
    final v = s.openBidsValue;
    final strong = AppColors.surface;
    final soft = AppColors.surface.withValues(alpha: 0.72);
    final faint = AppColors.surface.withValues(alpha: 0.6);
    final r = AppRadius.card;

    Widget stat(String value, String label) => ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 88),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: AppText.h3.copyWith(color: strong)),
          Text(label, style: AppText.caption.copyWith(color: soft)),
        ],
      ),
    );

    return Semantics(
      container: true,
      button: onTap != null,
      child: Ink(
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.14),
          borderRadius: r,
          border: Border.all(color: AppColors.surface.withValues(alpha: 0.2)),
        ),
        child: InkWell(
          borderRadius: r,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.t('Open bids value', 'खुली बोलियों का मूल्य'),
                  style: AppText.overline.copyWith(color: soft),
                ),
                const SizedBox(height: AppSpace.xs),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  // With no bid fully valued there is no total to show:
                  // "—", never a misleading ₹0.
                  child: Text(
                    v == null || v.complete == 0
                        ? '—'
                        : inrShort(v.completeValue),
                    style: AppText.h1.copyWith(color: strong),
                  ),
                ),
                Text(
                  v == null
                      ? s.t(
                          'Estimates not available yet',
                          'अनुमान अभी उपलब्ध नहीं',
                        )
                      : v.complete == 0
                      ? s.t(
                          'No bid fully valued yet',
                          'अभी कोई बोली पूरी तरह मूल्यांकित नहीं',
                        )
                      : s.t('Complete contract value', 'पूर्ण अनुबंध मूल्य'),
                  style: AppText.caption.copyWith(color: soft),
                ),
                if (v != null) ...[
                  const SizedBox(height: AppSpace.lg),
                  Wrap(
                    spacing: AppSpace.lg,
                    runSpacing: AppSpace.md,
                    children: [
                      stat('${v.open}', s.t('Open bids', 'खुली बोलियाँ')),
                      stat(
                        '${v.complete}',
                        s.t('Completely valued', 'पूरी तरह मूल्यांकित'),
                      ),
                      stat(
                        '${v.incomplete}',
                        s.t(
                          'Not completely valued',
                          'पूरी तरह मूल्यांकित नहीं',
                        ),
                      ),
                    ],
                  ),
                  if (_breakdown(s, v) case final why?) ...[
                    const SizedBox(height: AppSpace.sm),
                    Text(why, style: AppText.caption.copyWith(color: soft)),
                  ],
                  const SizedBox(height: AppSpace.md),
                  AppProgressBar(
                    value: v.open == 0 ? 0 : v.complete / v.open,
                    color: AppColors.surface,
                    semanticLabel: s.t(
                      '{complete} of {open} bids completely valued',
                      '{open} में से {complete} बोलियाँ पूरी तरह मूल्यांकित',
                      vars: {'complete': '${v.complete}', 'open': '${v.open}'},
                    ),
                  ),
                  const SizedBox(height: AppSpace.md),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.t('Partial estimates', 'आंशिक अनुमान'),
                              style: AppText.label.copyWith(color: strong),
                            ),
                            Text(
                              s.t('Incomplete estimates', 'अधूरे अनुमान'),
                              style: AppText.caption.copyWith(color: faint),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        inrShort(v.partialValue),
                        style: AppText.bodyStrong.copyWith(color: strong),
                      ),
                    ],
                  ),
                  if (v.open == 0) ...[
                    const SizedBox(height: AppSpace.sm),
                    Text(
                      s.t(
                        'No matched bids close in the next 10 days.',
                        'अगले 10 दिनों में कोई मेल खाती बोली बंद नहीं हो रही।',
                      ),
                      style: AppText.caption.copyWith(color: soft),
                    ),
                  ],
                ],
                const SizedBox(height: AppSpace.md),
                Text(
                  s.t(
                    'Estimated total value based on prevailing market prices. Partial estimates are excluded from the main total.',
                    'मौजूदा बाज़ार कीमतों पर आधारित अनुमानित कुल मूल्य। आंशिक अनुमान मुख्य कुल में शामिल नहीं हैं।',
                  ),
                  style: AppText.caption.copyWith(color: faint),
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  s.t(
                    'This is an estimate based on available market prices. It is not an official GeM valuation or a guaranteed contract price.',
                    'यह उपलब्ध बाज़ार कीमतों पर आधारित अनुमान है। यह GeM का आधिकारिक मूल्यांकन या गारंटीशुदा अनुबंध मूल्य नहीं है।',
                  ),
                  style: AppText.caption.copyWith(color: faint),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
