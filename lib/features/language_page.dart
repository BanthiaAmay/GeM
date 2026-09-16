import 'package:flutter/material.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../data/app_store.dart';

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
    Navigator.of(context).pushNamed('/gem-check');
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: size.height - 44),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: back,
                    icon: const Icon(Icons.arrow_back_ios_new, size: 26),
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 18),
                Image.asset(
                  'assets/brand_logo.png',
                  width: 160,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 80),
                Text(
                  widget.store.t('Hello.', 'नमस्ते.'),
                  style: TextStyle(
                    fontFamily: sfProDisplay,
                    fontSize: size.width < 430 ? 64 : 72,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 54),
                Text(
                  widget.store.t(
                    'Choose your language',
                    'अपनी भाषा चुनें',
                  ),
                  style: const TextStyle(
                    fontFamily: sfProDisplay,
                    fontSize: 24,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.store.t(
                    'You can change this later.',
                    'आप इसे बाद में बदल सकते हैं।',
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF737B84),
                  ),
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
                const SizedBox(height: 56),
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
                      widget.store.t('Continue', 'जारी रखें'),
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
            style: TextStyle(
              fontSize: 18,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 10),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: selected ? 56 : 0,
            height: 3,
            decoration: const ShapeDecoration(
              color: Colors.black,
              shape: StadiumBorder(),
            ),
          ),
        ],
      ),
    ),
  );
}