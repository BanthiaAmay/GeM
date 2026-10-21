# Bid2Scale: animation prompts

Paste the **context prompt** once at the start of a session, then run the prompts one at a time in order. Test on a device after each prompt before moving on.

## 0. Context prompt (paste first)

```
You are working in a Flutter app (Bid2Scale) at the repo root. Key files:
- lib/main.dart: SplashGate, route table (flowPages), onGenerateRoute using MaterialPageRoute
- lib/core/theme.dart: colours and ThemeData
- lib/features/onboarding_widgets.dart: OnboardingStepScaffold (GlassBar header with back button, logo, progress bar, section/step labels; scrolling body; GlassBar bottom Continue button), OnboardingTextField, OnboardingPickerField, OnboardingRadioOption, OnboardingCheckOption
- lib/features/onboarding_flow_1..4.dart: the 15 onboarding screens
- lib/features/home_page.dart, tools.dart, language_page.dart, welcome_page.dart, scroll_hint.dart, glass.dart

Goal: a restrained, premium motion language. It should feel calm and precise, like Apple's apps: soft ease-out, no bounce, no confetti, nothing over 600 ms on a frequently used path. It must run smoothly on low-end Android phones and on the web.

Rules:
- Don't change copy, colours, layout or business logic unless the task says so.
- Keep the English/Hindi s.t(...) pattern for any new text.
- Repeating animations break pumpAndSettle in tests. Follow the ScrollMoreHint.debugDisableBounce pattern or disable them under reduced motion.
- Finish with `flutter analyze` (zero issues) and `flutter test` (all pass), and list every file you changed.
```

## 1. Shared motion tokens

```
Create lib/core/motion.dart as the single source of animation timing.

- class Motion with static const durations: fast = 160ms, normal = 280ms, slow = 450ms, emphasis = 600ms.
- Curves: enter = Cubic(0.22, 1, 0.36, 1) (soft ease-out), exit = Cubic(0.4, 0, 1, 1), standard = Curves.easeInOutCubic.
- A stagger step: const staggerStep = Duration(milliseconds: 60).
- static bool reduced(BuildContext c) => MediaQuery.maybeDisableAnimationsOf(c) ?? false.
- static Duration of(BuildContext c, Duration d): returns Duration.zero when reduced, otherwise d.

Then replace every hard-coded animation duration and curve in lib/ with these tokens:
language_page.dart (~line 175), home_page.dart (~121 and ~1175) and scroll_hint.dart (~74, ~97).
Pick the closest token and keep behaviour otherwise identical.
```

## 2. Custom screen transition

```
Replace the default MaterialPageRoute in lib/main.dart onGenerateRoute with a custom route that feels quiet and editorial.

- Create lib/core/transitions.dart with class SoftRoute<T> extends PageRouteBuilder<T>.
- Incoming page: fades 0 to 1 and slides from Offset(0.06, 0) to zero, using Motion.enter over Motion.normal + 40ms (320ms).
- Outgoing page (secondaryAnimation): fades to 0.85 opacity and drifts to Offset(-0.03, 0).
- Reverse (back) runs at 260ms with Motion.exit, mirrored.
- Opaque route, white barrier, maintainState true, and pass settings through so web hash routes (/#/revenue etc.) keep working.
- SplashGate's pushReplacementNamed must use a pure fade (no slide) over Motion.slow.
- pushNamedAndRemoveUntil('/home') at the end of onboarding should also use a fade, not a slide.
- Under Motion.reduced, use a 150ms cross-fade only.
Keep the Android system back gesture working. Add a widget test that pushes a route and pumps through the transition without errors.
```

## 3. Smooth progress bar and fixed header

```
In OnboardingStepScaffold (lib/features/onboarding_widgets.dart) the progress bar is rebuilt on every screen, so it jumps. Make it fill smoothly, and fix the progress values first.

Step A: fix the data. The progress and sectionLabel values across onboarding_flow_1..4 are inconsistent: the name page is "Your business 1/6", privacy is "Getting started" at 1.0, and PAN is 4/5 after records at 5/5, so the bar goes backwards. Build one ordered list in onboarding_widgets.dart describing all 15 routes (flow-name ... flow-redirect) with their section and step, and compute progress as overall step / 15 from the current route name.
Use these sections:
- Getting started: name, phone, otp, location
- Your business: bizname, bizform, sector, role, authorised
- Get ready: privacy, records, pan, checklist
- Next step: video, redirect
Derive the step label ("GETTING STARTED · 2 OF 4", Hindi equivalent) from that list and remove the hard-coded progress/stepLabel arguments from each page. Keep the existing section-label text and translations.

Step B: animate.
- Keep a static double lastProgress in the scaffold's state class. Draw the bar with TweenAnimationBuilder<double>(begin: lastProgress, end: current, duration: Motion.slow, curve: Motion.enter), rendered with FractionallySizedBox instead of the current flex Row.
- Wrap the whole GlassBar.top header in Hero(tag: 'onboarding-header') so it stays put while only the body transitions between screens. Use a flightShuttleBuilder that shows the destination header, so nothing flickers.
- Cross-fade the section and step labels with AnimatedSwitcher (Motion.fast, fade plus a 6px upward shift).
- Going back animates the bar backwards.
- Under reduced motion, jump straight to the value.
```

## 4. Staggered content entrance

```
Make each onboarding screen appear in sequence instead of all at once.

- Create a StaggeredEntrance widget in lib/features/onboarding_widgets.dart that takes an index. It fades 0 to 1 and translates from 12px below to 0 over 400ms with Motion.enter, delayed by index * Motion.staggerStep.
- Use a StatefulWidget with one AnimationController started once in initState. The screens rebuild on every store notification through ListenableBuilder, and a rebuild must NOT replay the animation.
- In OnboardingStepScaffold, wrap headline (index 0), subtitle (index 1) and each child in the body (index 2+, capped at index 7 so long lists don't wait).
- Don't stagger when returning to a screen via back (only on first push). A simple way: skip when ModalRoute.of(context)!.animation is already completed at initState.
- Reduced motion: render immediately.
- Don't stagger the Continue button; it stays put.
```

## 5. Option cards with tactile feedback

```
Upgrade OnboardingRadioOption, OnboardingCheckOption and OnboardingPickerField in lib/features/onboarding_widgets.dart.

- Convert to StatefulWidget. On pointer down, scale to 0.98 (AnimatedScale, Motion.fast, Motion.standard); on release or cancel, scale back to 1.
- Replace Container with AnimatedContainer (Motion.fast) so the border colour, width and background fade when selected changes.
- Radio indicator: the inner dot scales from 0 to 1 with Motion.enter.
- Checkbox: draw the tick with a CustomPainter that animates path length 0 to 1 over 220ms (PathMetric.extractPath), so the tick draws itself.
- Call HapticFeedback.selectionClick() on each selection change.
- Keep GestureDetector hit areas the same, and add Semantics(button: true, selected: ...) so screen readers read the state.
- Reduced motion: no scale, instant tick.
```

## 6. Continue button

```
Improve the Continue button at the bottom of OnboardingStepScaffold (lib/features/onboarding_widgets.dart, the FilledButton inside GlassBar.bottom).

- When onContinue changes from null to non-null, animate the background from #CCCCCC to #151515 and the label from 60% to 100% opacity over Motion.normal. Use TweenAnimationBuilder<Color?> or an AnimatedContainer around a transparent button; don't rely on the FilledButton's instant disabled swap.
- Press: scale 0.98 with Motion.fast, back to 1 on release.
- On a successful tap, call HapticFeedback.lightImpact().
- Keep it semantically disabled (onPressed null) when not ready.
- Keep the height of 66, the StadiumBorder and the text style exactly as they are.
```

## 7. Splash sequence

```
Replace the static SplashGate in lib/main.dart with a short brand sequence.

- Use BrandLogo (lib/features/brand_logo.dart). Show the mark variant first: fade 0 to 1 and scale 0.96 to 1 over 600ms with Motion.enter.
- From 250ms to 750ms, fade in the wordmark below or beside it (use the full or lockup variant, whichever matches the UI/Logo SVGs best) and rise it 8px.
- Hold until about 1200ms total, then navigate with a pure fade (see prompt 2).
- Also wait until store.initialize() has finished, but never longer than 2.5s total.
- Wrap the logo in Hero(tag: 'brand-logo'), and put the same tag on the logo in welcome_page.dart (~line 34), so the logo glides into place on the welcome screen.
- Reduced motion: show the final logo immediately and go after 600ms.
```

## 8. Section-complete moments

```
Add a small, elegant checkpoint when the user finishes a section of onboarding (Getting started, Your business, Get ready), using the section list from prompt 3.

- Create showSectionComplete(BuildContext context, String sectionName) in lib/features/onboarding_widgets.dart that returns a Future completing after the animation.
- It shows a full-screen white overlay (a fade route or OverlayEntry). A 56px circle outline draws itself (300ms), then a checkmark draws inside it (300ms), then "<Section> complete" / Hindi equivalent fades in below. Hold 400ms, then fade out.
- Total about 1.2s. Tapping anywhere skips it.
- Trigger it from the Continue handler of the last screen in each section, before pushing the next route. Don't trigger it for the final "Next step" section, or on the already-on-GeM early exit in FlowRecordsPage.
- HapticFeedback.mediumImpact() when the check completes.
- Reduced motion: show the static check for 500ms.
- No confetti, particles or bounce.
```

## 9. Input usability: OTP, validation, sheets

```
Usability fixes in the onboarding inputs.

A. OTP (FlowOtpPage, lib/features/onboarding_flow_1.dart):
- Replace the 6 separate TextFields with ONE hidden TextField (maxLength 6, digits only, autofillHints: [AutofillHints.oneTimeCode]) drawn as 6 boxes. Tapping the boxes focuses it.
- Backspace naturally moves back, and pasting "123456" fills all boxes.
- The active box border animates (Motion.fast). Each digit fades and scales in from 0.8 when typed.
- When 6 digits are entered, pause 300ms and continue automatically (same destination as the button).
- Keep the "Use demo code" button and the prototype copy.

B. Validation shake: create a ShakeOnError widget (horizontal offset ±6px, 3 cycles, 360ms, decaying) plus HapticFeedback.mediumImpact(). Use it when Continue is tapped with an invalid phone number or empty required field, if those pages have validation. Otherwise add it as a reusable widget and apply it to the phone page for fewer than 10 digits.

C. Bottom sheets: in onboarding_widgets.dart (~line 255) and home_page.dart (~line 875), pass sheetAnimationStyle: AnimationStyle(duration: Motion.slow, reverseDuration: Motion.normal, curve: Motion.enter) and use rounded 20px top corners with a drag handle, if they're not already there.
```

## 10. Home and calculator results

```
Polish motion on the home screen and in the calculators (lib/features/home_page.dart, lib/features/tools.dart).

- Create an AnimatedMoney widget: TweenAnimationBuilder<double> that animates from the PREVIOUS value (not from 0 on every rebuild) to the new value over Motion.emphasis with Motion.enter, formatted with money() from core/models.dart. Use it for every ₹ result figure (revenue range, target price, ROI, payback). Percentages get the same treatment with one decimal.
- When a result card first appears after Calculate, fade and rise it 12px (Motion.normal).
- Home screen: stagger the entrance of the main cards on first load only (reuse StaggeredEntrance from prompt 4), not on every return to home.
- scroll_hint.dart: make the chevron calmer. Change the bob from 1100ms to 1600ms with Curves.easeInOutSine and cap the travel at 4px.
- Reduced motion: numbers jump straight to their value, and there is no stagger or bob.
```

## 11. Reduced-motion and performance audit

```
Final motion audit across lib/.

1. Every AnimationController, implicit animation, Hero and custom route must respect Motion.reduced(context): zero duration, or a fade of 150ms or less. Repeating animations must stop.
2. Add a widget test that wraps the app in MediaQuery(data: MediaQueryData(disableAnimations: true)), walks through the 15 onboarding routes via the Continue button (use the demo OTP), and uses pumpAndSettle, so it proves nothing loops forever.
3. Performance: wrap animated regions that sit over complex content in RepaintBoundary. Don't animate BackdropFilter blur values; the GlassBar blur stays static. Avoid Opacity widgets over large subtrees (use FadeTransition). Run in profile mode on Android and report any frame over 16ms during an onboarding transition.
4. Remove any leftover hard-coded Duration or Curves values that bypass Motion.
Report what you changed and anything you couldn't make smooth.
```
