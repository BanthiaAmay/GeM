import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../data/app_store.dart';

/// Onboarding step shown right after language selection: a quick check
/// on whether the seller's business is already listed on GeM. Purely
/// informational today — it just records [AppStore.alreadyOnGem] — but
/// nothing else in the flow branches on the answer yet.
class GemCheckPage extends StatefulWidget {
  final AppStore store;
  const GemCheckPage({super.key, required this.store});

  @override
  State<GemCheckPage> createState() => _GemCheckPageState();
}

class _GemCheckPageState extends State<GemCheckPage> {
  late bool selected = widget.store.alreadyOnGem;

  void back() => Navigator.of(context).canPop()
      ? Navigator.of(context).pop()
      : Navigator.of(context).pushReplacementNamed('/language');

  void continueToApp() {
    widget.store.setAlreadyOnGem(selected);
    // Both answers share the first 11 steps (name through business
    // documentation). Already-on-GeM users stop there; not-yet users
    // continue on into PAN check, the readiness checklist, the video
    // guide, and the redirect — see FlowRecordsPage's onContinue.
    Navigator.of(context).pushNamed('/flow-name');
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    final size = MediaQuery.sizeOf(context);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: size.height - 44),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: back,
                      icon: const Icon(Icons.arrow_back_ios_new, size: 24),
                      color: Colors.black,
                    ),
                    Expanded(
                      child: Image.asset(
                        'assets/brand_logo_notag.png',
                        width: 150,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 55,
                        child: Container(height: 5, color: Colors.black),
                      ),
                      Expanded(
                        flex: 45,
                        child: Container(
                          height: 5,
                          color: const Color(0xFFE4E4E4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  s.t('Your business', 'आपका व्यवसाय'),
                  style: const TextStyle(fontSize: 15, color: Color(0xFF737B84)),
                ),
                const SizedBox(height: 20),
                Text(
                  s.t('ONE QUICK CHECK', 'एक जल्दी जाँच'),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: Color(0xFF737B84),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  s.t(
                    'Is your business already on GeM?',
                    'क्या आपका व्यवसाय पहले से GeM पर है?',
                  ),
                  style: const TextStyle(
                    fontFamily: sfProDisplay,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  s.t(
                    'We’ll guide you to the right next step.',
                    'हम आपको सही अगले कदम तक मार्गदर्शन देंगे।',
                  ),
                  style: const TextStyle(fontSize: 16, color: Color(0xFF737B84)),
                ),
                const SizedBox(height: 32),
                _CheckOption(
                  icon: Icons.storefront_outlined,
                  trailingIcon: Icons.circle_outlined,
                  label: s.t('No', 'नहीं'),
                  selected: !selected,
                  onTap: () => setState(() => selected = false),
                ),
                const SizedBox(height: 14),
                _CheckOption(
                  icon: Icons.storefront_outlined,
                  trailingIcon: Icons.check_circle_outline,
                  label: s.t('Yes', 'हाँ'),
                  selected: selected,
                  onTap: () => setState(() => selected = true),
                ),
                const SizedBox(height: 40),
                const Center(child: _JourneyIllustration()),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 66,
                  child: FilledButton(
                    onPressed: continueToApp,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF151515),
                      foregroundColor: Colors.white,
                      shape: const StadiumBorder(),
                    ),
                    child: Text(
                      s.t('Continue', 'जारी रखें'),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckOption extends StatelessWidget {
  final IconData icon;
  final IconData trailingIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CheckOption({
    required this.icon,
    required this.trailingIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        border: Border.all(
          color: selected ? Colors.black : const Color(0xFFDDDDDD),
          width: selected ? 1.4 : 1,
        ),
        borderRadius: BorderRadius.circular(14),
        color: selected ? const Color(0xFFFAFAFA) : Colors.white,
      ),
      child: Row(
        children: [
          Icon(icon, size: 26, color: Colors.black),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 20, color: Colors.black),
            ),
          ),
          Icon(
            trailingIcon,
            size: 24,
            color: selected ? Colors.black : const Color(0xFFBBBBBB),
          ),
        ],
      ),
    ),
  );
}

/// Small store → location → verified-listing motif echoing the option
/// icons above, tying "not listed yet" and "already listed" together.
class _JourneyIllustration extends StatelessWidget {
  const _JourneyIllustration();

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 90,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _JourneyStop(icon: Icons.storefront_outlined),
        const _DashedConnector(),
        const _JourneyStop(icon: Icons.location_on_outlined),
        const _DashedConnector(),
        const _JourneyStop(icon: Icons.verified_outlined),
      ],
    ),
  );
}

class _JourneyStop extends StatelessWidget {
  final IconData icon;
  const _JourneyStop({required this.icon});

  @override
  Widget build(BuildContext context) => Container(
    width: 64,
    height: 64,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: const Color(0xFFDDDDDD)),
    ),
    child: Icon(icon, size: 28, color: Colors.black),
  );
}

class _DashedConnector extends StatelessWidget {
  const _DashedConnector();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 36,
    height: 20,
    child: CustomPaint(painter: _DashedLinePainter()),
  );
}

class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFBBBBBB)
      ..strokeWidth = 2;
    const dash = 4.0, gap = 3.0;
    var x = 0.0;
    final y = size.height / 2;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset(x + dash, y), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) => false;
}
