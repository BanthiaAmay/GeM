import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/tokens.dart';
import '../data/app_store.dart';

const _kQuadrantPdfUrl =
    'https://assets-bg.gem.gov.in/resources/pdf/quadrant-policy-of-gem.pdf';
const _kGemPortalUrl = 'https://gem.gov.in';

/// Shows a bottom sheet explaining the user's GeM quadrant once after they
/// first complete onboarding. The sheet is dismissed permanently once closed.
Future<void> showQuadrantPopupIfNeeded(
  BuildContext context,
  AppStore store,
) async {
  final quadrant = store.gemCategoryQuadrant;
  if (quadrant == null || quadrant.isEmpty) return;
  if (store.seenQuadrantPopup) return;

  await store.markQuadrantPopupSeen();

  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _QuadrantSheet(store: store, quadrant: quadrant),
  );
}

class _QuadrantSheet extends StatelessWidget {
  final AppStore store;
  final String quadrant;
  const _QuadrantSheet({required this.store, required this.quadrant});

  @override
  Widget build(BuildContext context) {
    final s = store;
    final quadrantLabel = _quadrantLabel(quadrant);
    final quadrantDesc = _quadrantDescription(quadrant);

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        child: Column(
          children: [
            // Drag handle
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.xxl, AppSpace.lg, AppSpace.xxl, AppSpace.xxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Text(
                      s.t('Your GeM Quadrant', 'आपका GeM क्वाड्रेंट'),
                      style: AppText.h2,
                    ),
                    const SizedBox(height: AppSpace.sm),
                    Text(
                      s.t(
                        'Based on your chosen category, you are classified under',
                        'आपकी चुनी हुई श्रेणी के आधार पर, आपको इसमें वर्गीकृत किया गया है',
                      ),
                      style: AppText.body
                          .copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: AppSpace.lg),

                    // Quadrant badge card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpace.xxl),
                      decoration: BoxDecoration(
                        color: AppColors.brandTint,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(color: AppColors.brand, width: 1.5),
                      ),
                      child: Column(
                        children: [
                          Text(
                            quadrant,
                            style: AppText.display.copyWith(
                              color: AppColors.brand,
                              fontSize: 56,
                            ),
                          ),
                          const SizedBox(height: AppSpace.sm),
                          Text(
                            quadrantLabel,
                            style: AppText.title.copyWith(
                                color: AppColors.brand),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpace.sm),
                          Text(
                            quadrantDesc,
                            style: AppText.bodySmall.copyWith(
                                color: AppColors.brand),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpace.lg),

                    // What this means section
                    Text(
                      s.t(
                        'What this means for you on GeM',
                        'GeM पर आपके लिए इसका क्या अर्थ है',
                      ),
                      style: AppText.h3,
                    ),
                    const SizedBox(height: AppSpace.sm),
                    Text(
                      s.t(
                        'Each quadrant on GeM represents a different category of products or services. Your quadrant determines bid eligibility rules, turnover requirements, and the type of government buyers you can supply to.',
                        'GeM पर प्रत्येक क्वाड्रेंट उत्पादों या सेवाओं की एक अलग श्रेणी को दर्शाता है। आपका क्वाड्रेंट बोली पात्रता नियम, टर्नओवर आवश्यकताएं और सरकारी खरीदारों के प्रकार निर्धारित करता है जिन्हें आप सप्लाई कर सकते हैं।',
                      ),
                      style: AppText.body,
                    ),

                    const SizedBox(height: AppSpace.lg),

                    // PDF link
                    GestureDetector(
                      onTap: () => _openUrl(_kQuadrantPdfUrl),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpace.md, vertical: AppSpace.sm + 4),
                        decoration: BoxDecoration(
                          color: AppColors.infoTint,
                          borderRadius:
                              BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.info),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.picture_as_pdf_rounded,
                                color: AppColors.info, size: 20),
                            const SizedBox(width: AppSpace.sm),
                            Expanded(
                              child: Text(
                                s.t(
                                  'Read the full GeM Quadrant Policy',
                                  'पूरी GeM क्वाड्रेंट नीति पढ़ें',
                                ),
                                style: AppText.bodySmall.copyWith(
                                  color: AppColors.info,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                  decorationColor: AppColors.info,
                                ),
                              ),
                            ),
                            const Icon(Icons.open_in_new_rounded,
                                color: AppColors.info, size: 16),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: AppSpace.lg),

                    // Disclaimer
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpace.md),
                      decoration: BoxDecoration(
                        color: AppColors.warningTint,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border:
                            Border.all(color: AppColors.warning.withAlpha(100)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.info_outline_rounded,
                                  color: AppColors.warning, size: 16),
                              const SizedBox(width: AppSpace.sm),
                              Text(
                                'Disclaimer',
                                style: AppText.bodySmall.copyWith(
                                  color: AppColors.warning,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpace.sm),
                          Text(
                            'Bid2Scale is an independent, free educational application developed to help sellers understand and navigate the Government e-Marketplace (GeM). It is not a government application and is neither affiliated with, authorised by, nor endorsed by GeM or the Government of India.\n\n'
                            'The information provided is for educational purposes only and should not be treated as official advice. Users are advised to verify all requirements against the latest official GeM policies, terms and conditions, and bid-specific documents.\n\n'
                            'Official references:',
                            style: AppText.caption
                                .copyWith(color: AppColors.warning),
                          ),
                          const SizedBox(height: AppSpace.sm),
                          _LinkLine(
                            label: 'GeM Portal: ',
                            url: _kGemPortalUrl,
                            urlText: _kGemPortalUrl,
                          ),
                          const SizedBox(height: 2),
                          _LinkLine(
                            label: 'GeM Quadrant Policy: ',
                            url: _kQuadrantPdfUrl,
                            urlText: 'quadrant-policy-of-gem.pdf',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpace.xxl),

                    // Got it button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.brand,
                          foregroundColor: AppColors.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.pill),
                          ),
                          padding: const EdgeInsets.symmetric(
                              vertical: AppSpace.md),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          s.t('Got it', 'समझ गया'),
                          style: AppText.button,
                        ),
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

  static String _quadrantLabel(String q) {
    switch (q) {
      case 'Q1':
        return 'Quadrant 1 — Products';
      case 'Q2':
        return 'Quadrant 2 — Services';
      case 'Q3':
        return 'Quadrant 3 — Works';
      case 'Q4':
        return 'Quadrant 4 — Consulting & Analytics';
      default:
        return q;
    }
  }

  static String _quadrantDescription(String q) {
    switch (q) {
      case 'Q1':
        return 'Physical goods and manufactured items sold on GeM.';
      case 'Q2':
        return 'Service-based contracts like manpower, cleaning, and IT.';
      case 'Q3':
        return 'Civil and construction works for government infrastructure.';
      case 'Q4':
        return 'Consulting, research, and analytics services.';
      default:
        return '';
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

/// A compact inline text link row used inside the disclaimer.
class _LinkLine extends StatelessWidget {
  final String label;
  final String url;
  final String urlText;
  const _LinkLine(
      {required this.label, required this.url, required this.urlText});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: AppText.caption.copyWith(color: AppColors.warning),
        children: [
          TextSpan(text: label),
          TextSpan(
            text: urlText,
            style: AppText.caption.copyWith(
              color: AppColors.info,
              decoration: TextDecoration.underline,
              decorationColor: AppColors.info,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () async {
                final uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri,
                      mode: LaunchMode.externalApplication);
                }
              },
          ),
        ],
      ),
    );
  }
}
