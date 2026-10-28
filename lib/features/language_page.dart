import 'dart:async';

import 'package:flutter/material.dart';
import '../core/models.dart';
import '../core/motion.dart';
import '../core/theme.dart';
import '../data/app_store.dart';
import 'brand_logo.dart';
import 'components.dart';
import 'glass.dart';
import 'scroll_hint.dart';

class LanguagePage extends StatefulWidget {
  final AppStore store;
  const LanguagePage({super.key, required this.store});

  @override
  State<LanguagePage> createState() => _LanguagePageState();
}

class _LanguagePageState extends State<LanguagePage> {
  late String selected = widget.store.language;

  void select(String language) {
    setState(() => selected = language);
    // Applies immediately and app-wide, not just once "Continue" is
    // tapped — every screen listens to AppStore and re-renders in the
    // chosen language right away.
    widget.store.setLanguage(language);
  }

  void back() => Navigator.of(context).canPop()
      ? Navigator.of(context).pop()
      : Navigator.of(context).pushReplacementNamed('/home');

  void continueToApp() {
    widget.store.setLanguage(selected);
    Navigator.of(
      context,
    ).pushNamed(widget.store.signedIn ? '/gem-check' : '/onboarding-auth');
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            GlassBar.top(
              child: Align(
                alignment: Alignment.centerLeft,
                child: AppIconButton(
                  onPressed: back,
                  icon: Icons.arrow_back_ios_new,
                  tooltip: widget.store.t('Back', 'वापस'),
                ),
              ),
            ),
            Expanded(
              child: ScrollMoreHint(
                builder: (context, scrollController) => SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.gutter,
                    AppSpace.xl,
                    AppSpace.gutter,
                    60,
                  ),
                  child: Column(
                    children: [
                      const BrandLogo(
                        variant: BrandLogoVariant.lockup,
                        width: 160,
                      ),
                      const SizedBox(height: 80),
                      _GreetingIntro(
                        store: widget.store,
                        language: selected,
                        style: AppText.display.copyWith(
                          fontSize: size.width < 430 ? 64 : 72,
                          fontWeight: FontWeight.w500,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 54),
                      Text(
                        widget.store.t(
                          'Choose your language',
                          'अपनी भाषा चुनें',
                        ),
                        style: AppText.h2.copyWith(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.store.t(
                          'You can change this later.',
                          'आप इसे बाद में बदल सकते हैं।',
                        ),
                        style: AppText.secondary(AppText.body),
                      ),
                      const SizedBox(height: 60),
                      GridView.count(
                        crossAxisCount: 3,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: 1.1,
                        children: [
                          for (final lang in supportedLanguages)
                            _LanguageOption(
                              label: lang[1],
                              selected: selected == lang[0],
                              onTap: () => select(lang[0]),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            GlassBar.bottom(
              child: AppButton(
                label: widget.store.t('Continue', 'जारी रखें'),
                onPressed: continueToApp,
                size: AppButtonSize.lg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The big "Hello." headline — plus, the very first time a device reaches
/// this screen, a brief tour through every other supported language's own
/// greeting before settling on [language].
///
/// **Reusable by construction, not by a maintained list:** every frame of
/// the tour is `tr(code, 'Hello.', 'नमस्ते.')` for a `code` drawn straight
/// from [supportedLanguages] (core/models.dart) — the same "Hello." key
/// [LanguagePage] already showed before this widget existed, just looked
/// up for languages other than the current one. Adding a new supported
/// language only means adding it to `supportedLanguages` and giving
/// `'Hello.'` a translation for it in `kTranslations`
/// (core/translations.dart), exactly as every other translated string in
/// this app already requires — nothing here needs to change or know the
/// language list grew.
///
/// Plays once per device (see [AppStore.hasSeenGreetingIntro]): later
/// visits — including simply navigating back to this screen — show
/// [language]'s greeting immediately. Selecting a different language card
/// (or a "Start onboarding again" reset) still crossfades/replays via the
/// same mechanism, just without the multi-language tour.
class _GreetingIntro extends StatefulWidget {
  final AppStore store;
  final String language;
  final TextStyle style;
  const _GreetingIntro({
    required this.store,
    required this.language,
    required this.style,
  });

  @override
  State<_GreetingIntro> createState() => _GreetingIntroState();
}

class _GreetingIntroState extends State<_GreetingIntro> {
  // Brisk, Apple-"Hello"-ad pacing rather than a lingering slideshow: each
  // language gets a beat, crossfades are quick, the whole tour is over in
  // a couple of seconds even in the worst case (last-listed language).
  static const _frameHold = Duration(milliseconds: 360);

  late String _shown = widget.language;
  bool _playingIntro = false;
  List<String> _sequence = const [];
  int _step = 0;
  Timer? _timer;
  bool _decided = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Motion.reduced reads MediaQuery, unavailable in initState — decided
    // once, right after mount, like every other screen-entry choice in
    // this app (see e.g. StaggeredEntrance).
    if (_decided) return;
    _decided = true;
    if (Motion.reduced(context) || widget.store.hasSeenGreetingIntro) {
      // Nothing to replay: land straight on the real greeting and — under
      // reduced motion specifically — still record the intro as "seen",
      // so turning reduced motion back off later doesn't retroactively
      // trigger a tour on an otherwise-ordinary return visit.
      unawaited(widget.store.markGreetingIntroSeen());
      return;
    }
    _startIntro();
  }

  void _startIntro() {
    final others = [
      for (final lang in supportedLanguages)
        if (lang[0] != widget.language) lang[0],
    ];
    // Tour every other language, then land on the selected one last — so
    // the sequence always finishes exactly where it must settle, with no
    // separate "now show the real one" step bolted on afterwards.
    _sequence = [...others, widget.language];
    _playingIntro = true;
    _step = 0;
    _shown = _sequence[0];
    _scheduleNext();
  }

  void _scheduleNext() {
    _timer = Timer(_frameHold, () {
      if (!mounted) return;
      _step++;
      if (_step >= _sequence.length) {
        _finishIntro();
        return;
      }
      setState(() => _shown = _sequence[_step]);
      _scheduleNext();
    });
  }

  void _finishIntro() {
    _timer?.cancel();
    _timer = null;
    if (mounted) {
      setState(() {
        _playingIntro = false;
        _shown = widget.language;
      });
    }
    unawaited(widget.store.markGreetingIntroSeen());
  }

  void _skip() {
    if (!_playingIntro) return;
    _finishIntro();
  }

  @override
  void didUpdateWidget(covariant _GreetingIntro old) {
    super.didUpdateWidget(old);
    if (old.language == widget.language) return;
    if (_playingIntro) {
      // A language tap or Continue must never wait on the tour — jump
      // straight to what the user just chose.
      _finishIntro();
    } else {
      setState(() => _shown = widget.language);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    final settled = tr(widget.language, 'Hello.', 'नमस्ते.');
    return Column(
      children: [
        // The headline itself stays out of the semantics tree and always
        // reports the *settled* greeting as its one accessible label —
        // a screen reader hears "Hello." once, never the eight quick
        // language changes that led up to it.
        Semantics(
          container: true,
          label: settled,
          child: ExcludeSemantics(
            child: SizedBox(
              width: double.infinity,
              height: widget.style.fontSize! * widget.style.height! * 1.08,
              child: Center(
                child: AnimatedSwitcher(
                  duration: Motion.of(context, Motion.normal),
                  switchInCurve: Motion.enter,
                  switchOutCurve: Motion.exit,
                  transitionBuilder: (child, animation) =>
                      FadeTransition(opacity: animation, child: child),
                  child: FittedBox(
                    key: ValueKey(_shown),
                    fit: BoxFit.scaleDown,
                    child: Text(
                      tr(_shown, 'Hello.', 'नमस्ते.'),
                      maxLines: 1,
                      style: widget.style,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: Motion.of(context, Motion.fast),
          curve: Motion.standard,
          alignment: Alignment.topCenter,
          child: _playingIntro
              ? Padding(
                  padding: const EdgeInsets.only(top: AppSpace.sm),
                  child: AppButton(
                    label: s.t('Skip', 'छोड़ें'),
                    onPressed: _skip,
                    variant: AppButtonVariant.tertiary,
                    size: AppButtonSize.sm,
                    expand: false,
                    haptic: false,
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

class _LanguageOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _LanguageOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppText.title.copyWith(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
          const SizedBox(height: 10),
          AnimatedContainer(
            duration: Motion.of(context, Motion.fast),
            curve: Motion.enter,
            width: selected ? 56 : 0,
            height: 3,
            decoration: const ShapeDecoration(
              color: AppColors.ink,
              shape: StadiumBorder(),
            ),
          ),
        ],
      ),
    ),
  );
}
