import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/motion.dart';
import '../core/theme.dart';
import '../data/app_store.dart';

/// One sourced GeM fact, styled with an accent colour pair.
class Fact {
  final IconData icon;
  final String figure;
  final String caption;
  final String source;
  final Color accent;
  final Color tint;
  const Fact(
    this.icon,
    this.figure,
    this.caption,
    this.source,
    this.accent,
    this.tint,
  );
}

List<Fact> gemFacts(AppStore s) => [
  Fact(
    Icons.trending_up_rounded,
    s.t('₹5.4 lakh crore', '₹5.4 लाख करोड़'),
    s.t(
      'of government orders placed on GeM in FY 2024-25',
      'के सरकारी ऑर्डर वित्त वर्ष 2024-25 में GeM पर दिए गए',
    ),
    s.t('Source: PIB, Aug 2025', 'स्रोत: PIB, अगस्त 2025'),
    AppColors.brand,
    AppColors.brandTint,
  ),
  Fact(
    Icons.storefront_outlined,
    '68%',
    s.t(
      'of GeM orders carried out by small businesses (FY 2025-26)',
      'GeM ऑर्डर छोटे व्यवसायों ने पूरे किए (वित्त वर्ष 2025-26)',
    ),
    s.t('Source: PIB, Apr 2026', 'स्रोत: PIB, अप्रैल 2026'),
    AppColors.chartCost,
    AppColors.warningTint,
  ),
  Fact(
    Icons.account_balance_outlined,
    s.t('1.6 lakh+', '1.6 लाख+'),
    s.t('government buyer organisations on GeM', 'सरकारी खरीदार संगठन GeM पर'),
    s.t('Source: DD News, Jan 2025', 'स्रोत: DD News, जनवरी 2025'),
    AppColors.info,
    AppColors.infoTint,
  ),
  Fact(
    Icons.handshake_outlined,
    '25%',
    s.t(
      'of central purchases targeted from micro & small enterprises',
      'केंद्र की खरीद का लक्ष्य सूक्ष्म व लघु उद्यमों से',
    ),
    s.t('Source: Ministry of MSME', 'स्रोत: MSME मंत्रालय'),
    AppColors.brand,
    AppColors.brandTint,
  ),
  Fact(
    Icons.event_available_outlined,
    s.t('10 days', '10 दिन'),
    s.t(
      'for buyers to pay you after accepting delivery',
      'में खरीदार को डिलीवरी स्वीकारने के बाद भुगतान करना होता है',
    ),
    s.t('Source: GeM Terms & Conditions', 'स्रोत: GeM नियम और शर्तें'),
    AppColors.chartCost,
    AppColors.warningTint,
  ),
];

/// Replaces the first number in [figure] with [t] of its value.
String countedFigure(String figure, double t) {
  final m = RegExp(r'\d+(\.\d+)?').firstMatch(figure);
  if (m == null || t >= 1) return figure;
  final target = double.parse(m.group(0)!);
  final decimals = m.group(1) == null ? 0 : m.group(1)!.length - 1;
  return figure.replaceRange(
    m.start,
    m.end,
    (target * t).toStringAsFixed(decimals),
  );
}

class _TicketClipper extends CustomClipper<Path> {
  final double footer;
  const _TicketClipper(this.footer);

  @override
  Path getClip(Size size) {
    final y = size.height - footer;
    const r = 10.0;
    return Path.combine(
      PathOperation.difference,
      Path()..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(AppRadius.xl),
        ),
      ),
      Path()
        ..addOval(Rect.fromCircle(center: Offset(0, y), radius: r))
        ..addOval(Rect.fromCircle(center: Offset(size.width, y), radius: r)),
    );
  }

  @override
  bool shouldReclip(_TicketClipper old) => old.footer != footer;
}

class _Perforation extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1.5;
    const dash = 6.0, gap = 5.0;
    for (var x = 18.0; x < size.width - 18; x += dash + gap) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(math.min(x + dash, size.width - 18), 0),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(_Perforation old) => false;
}

/// A ticket-shaped fact card: big accent number, caption, perforated
/// edge with notches, and the source as the stub.
class FactTicket extends StatelessWidget {
  final Fact fact;
  final AppStore store;
  final double count;
  final bool compact;
  const FactTicket({
    super.key,
    required this.fact,
    required this.store,
    this.count = 1,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final footer = compact ? 40.0 : 46.0;
    final pad = compact ? AppSpace.md : AppSpace.lg;
    final figureStyle = (compact ? AppText.h2 : AppText.display).copyWith(
      color: fact.accent,
      letterSpacing: -1,
    );
    return PhysicalShape(
      clipper: _TicketClipper(footer),
      color: AppColors.surface,
      elevation: 6,
      shadowColor: AppColors.ink.withValues(alpha: 0.35),
      child: Semantics(
        container: true,
        label: '${fact.figure} ${fact.caption}. ${fact.source}',
        excludeSemantics: true,
        child: LayoutBuilder(
          builder: (context, box) => Column(
            mainAxisSize: box.hasBoundedHeight
                ? MainAxisSize.max
                : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(pad, pad, pad, AppSpace.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: compact ? 28 : 36,
                          height: compact ? 28 : 36,
                          decoration: BoxDecoration(
                            color: fact.tint,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            fact.icon,
                            size: compact ? 16 : 20,
                            color: fact.accent,
                          ),
                        ),
                        const SizedBox(width: AppSpace.sm),
                        Flexible(
                          child: Text(
                            store.t('GeM FACT', 'GeM तथ्य'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.overline.copyWith(
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Flexible(
                          child: Transform.rotate(
                            angle: -0.12,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpace.sm,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(AppRadius.sm),
                                  border: Border.all(
                                    color: fact.accent,
                                    width: 1.5,
                                  ),
                                ),
                                child: Text(
                                  store.t('OFFICIAL DATA', 'आधिकारिक आँकड़े'),
                                  style: AppText.tick.copyWith(
                                    color: fact.accent,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: compact ? AppSpace.sm : AppSpace.md),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        countedFigure(fact.figure, count),
                        style: figureStyle,
                      ),
                    ),
                    const SizedBox(height: AppSpace.xs),
                    Text(
                      fact.caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: compact ? AppText.bodySmall : AppText.body,
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: footer,
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      child: CustomPaint(
                        size: const Size(double.infinity, 1),
                        painter: _Perforation(),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(pad, 10, pad, 0),
                      child: Row(
                        children: [
                          Icon(
                            Icons.verified_outlined,
                            size: 14,
                            color: fact.accent,
                          ),
                          const SizedBox(width: AppSpace.xs),
                          Expanded(
                            child: Text(
                              fact.source,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.tick.copyWith(
                                color: AppColors.textHint,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DotGrid extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dot = Paint()..color = AppColors.surface.withValues(alpha: 0.07);
    for (var y = 10.0; y < size.height; y += 18) {
      for (var x = 10.0; x < size.width; x += 18) {
        canvas.drawCircle(Offset(x, y), 1.4, dot);
      }
    }
    final glow = Paint()
      ..shader =
          RadialGradient(
            colors: [
              AppColors.surface.withValues(alpha: 0.16),
              AppColors.surface.withValues(alpha: 0),
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.85, 0),
              radius: size.width * 0.7,
            ),
          );
    canvas.drawRect(Offset.zero & size, glow);
  }

  @override
  bool shouldRepaint(_DotGrid old) => false;
}

/// Welcome hero: a deep-green stage with a self-shuffling, swipeable
/// stack of fact tickets.
class FactDeck extends StatefulWidget {
  final AppStore store;
  const FactDeck({super.key, required this.store});

  @override
  State<FactDeck> createState() => _FactDeckState();
}

class _FactDeckState extends State<FactDeck> with TickerProviderStateMixin {
  static const _cardHeight = 236.0;
  late final _dwell = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );
  late final _shuffle = AnimationController(
    vsync: this,
    duration: Motion.emphasis,
  );
  late final _count = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  int _index = 0;
  int _cycles = 0;
  double _drag = 0;
  bool _reduced = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _reduced = Motion.reduced(context);
    final factCount = gemFacts(widget.store).length;
    _dwell.addStatusListener((s) {
      if (s == AnimationStatus.completed) _shuffle.forward(from: 0);
    });
    _shuffle.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        setState(() {
          _index++;
          _drag = 0;
        });
        _shuffle.value = 0;
        _cycles++;
        if (!_reduced && _cycles < factCount) _dwell.forward(from: 0);
      }
    });
    if (_reduced) {
      _count.value = 1;
    } else {
      _count.forward();
      _dwell.forward();
    }
  }

  @override
  void dispose() {
    _dwell.dispose();
    _shuffle.dispose();
    _count.dispose();
    super.dispose();
  }

  void _next() {
    _dwell.stop();
    if (_reduced) {
      setState(() {
        _index++;
        _drag = 0;
      });
    } else {
      _shuffle.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    final facts = gemFacts(s);
    final n = facts.length;
    final stageTop = Color.lerp(AppColors.brand, AppColors.ink, 0.1)!;
    final stageBottom = Color.lerp(AppColors.brand, AppColors.ink, 0.5)!;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [stageTop, stageBottom],
          ),
        ),
        child: CustomPaint(
          painter: _DotGrid(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.lg,
              AppSpace.lg,
              AppSpace.lg,
              AppSpace.md,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    // Both labels may shorten so long translations never
                    // push the swipe hint past narrow screens.
                    Flexible(
                      child: Text(
                        s.t('WHY GeM?', 'GeM क्यों?'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.overline.copyWith(
                          color: AppColors.surface,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Flexible(
                      child: Text(
                        s.t('Swipe', 'स्वाइप करें'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.tick.copyWith(
                          color: AppColors.surface.withValues(alpha: 0.75),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpace.xs),
                    Icon(
                      Icons.swipe_left_outlined,
                      size: 16,
                      color: AppColors.surface.withValues(alpha: 0.75),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.lg),
                GestureDetector(
                  onHorizontalDragUpdate: (d) =>
                      setState(() => _drag += d.delta.dx),
                  onHorizontalDragEnd: (d) {
                    if (_drag.abs() > 60 ||
                        d.velocity.pixelsPerSecond.dx.abs() > 400) {
                      _next();
                    } else {
                      setState(() => _drag = 0);
                    }
                  },
                  child: SizedBox(
                    height: _cardHeight + 28,
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_shuffle, _count]),
                      builder: (context, _) {
                        final t = Curves.easeInOutCubic.transform(
                          _shuffle.value,
                        );
                        Widget card(int depth) {
                          final f = facts[(_index + depth) % n];
                          // depth 0 = front; behind cards move up as t grows.
                          final d = (depth - t).clamp(0.0, 2.0);
                          final scale = 1 - 0.06 * d;
                          final dy = 13.0 * d;
                          final rot = depth == 0
                              ? -0.28 * t + _drag / 900
                              : (depth.isOdd ? -0.035 : 0.035) * d;
                          final dx = depth == 0 ? _drag - 420 * t : 0.0;
                          return Positioned(
                            left: 0,
                            right: 0,
                            top: 0,
                            child: Opacity(
                              opacity: depth == 0
                                  ? (1 - t * 0.9)
                                  : (d > 1.6 ? 0.6 : 1),
                              child: Transform.translate(
                                offset: Offset(dx, dy),
                                child: Transform.rotate(
                                  angle: rot,
                                  child: Transform.scale(
                                    scale: scale,
                                    alignment: Alignment.bottomCenter,
                                    child: SizedBox(
                                      height: _cardHeight,
                                      child: FactTicket(
                                        fact: f,
                                        store: s,
                                        count: switch (depth) {
                                          0 => _index == 0 ? _count.value : 1,
                                          1 => t,
                                          _ => 0,
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }

                        return Stack(
                          clipBehavior: Clip.none,
                          children: [card(2), card(1), card(0)],
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var k = 0; k < n; k++)
                      AnimatedContainer(
                        duration: Motion.normal,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: k == _index % n ? 18 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: AppColors.surface.withValues(
                            alpha: k == _index % n ? 1 : 0.35,
                          ),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Sign-up: a compact, peeking carousel of fact tickets that advances on
/// its own and can be swiped.
class FactCarousel extends StatefulWidget {
  final AppStore store;
  const FactCarousel({super.key, required this.store});

  @override
  State<FactCarousel> createState() => _FactCarouselState();
}

class _FactCarouselState extends State<FactCarousel>
    with TickerProviderStateMixin {
  static const _loop = 50;
  late final _page = PageController(
    viewportFraction: 0.86,
    initialPage: _loop * 5,
  );
  late final _dwell = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );
  late final _count = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );
  int _current = _loop * 5;
  int _advances = 0;
  bool _started = false;
  bool _reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _reduced = Motion.reduced(context);
    _dwell.addStatusListener((st) {
      if (st == AnimationStatus.completed &&
          _page.hasClients &&
          _advances < 5) {
        _advances++;
        _page.nextPage(duration: Motion.slow, curve: Motion.enter);
      }
    });
    if (_reduced) {
      _count.value = 1;
    } else {
      _count.forward();
      _dwell.forward();
    }
  }

  @override
  void dispose() {
    _page.dispose();
    _dwell.dispose();
    _count.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    final facts = gemFacts(s);
    final n = facts.length;
    return Column(
      children: [
        SizedBox(
          // Grows with the user's text size so the ticket's text never
          // spills past its fixed-height page.
          height: MediaQuery.textScalerOf(context).scale(186),
          child: PageView.builder(
            controller: _page,
            padEnds: true,
            onPageChanged: (i) {
              setState(() => _current = i);
              if (!_reduced) _dwell.forward(from: 0);
            },
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.only(
                right: AppSpace.md,
                bottom: AppSpace.sm,
              ),
              child: AnimatedBuilder(
                animation: _count,
                builder: (context, _) => FactTicket(
                  fact: facts[i % n],
                  store: s,
                  compact: true,
                  count: i == _loop * 5 ? _count.value : 1,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpace.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var k = 0; k < n; k++)
              AnimatedContainer(
                duration: Motion.normal,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: k == _current % n ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: k == _current % n
                      ? AppColors.brand
                      : AppColors.brand.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Log-in / onboarding: one compact ticket that counts up once.
/// [factIndex] selects which fact to show (0–4); defaults to 4 (10-day
/// payment fact), keeping the existing log-in screen behaviour unchanged.
class FactMini extends StatefulWidget {
  final AppStore store;
  final int factIndex;
  const FactMini({super.key, required this.store, this.factIndex = 4});

  @override
  State<FactMini> createState() => _FactMiniState();
}

class _FactMiniState extends State<FactMini>
    with SingleTickerProviderStateMixin {
  late final _count = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (Motion.reduced(context)) {
      _count.value = 1;
    } else {
      _count.forward();
    }
  }

  @override
  void dispose() {
    _count.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final facts = gemFacts(widget.store);
    final fact = facts[widget.factIndex.clamp(0, facts.length - 1)];
    return AnimatedBuilder(
      animation: _count,
      builder: (context, _) => FactTicket(
        fact: fact,
        store: widget.store,
        compact: true,
        count: _count.value,
      ),
    );
  }
}
