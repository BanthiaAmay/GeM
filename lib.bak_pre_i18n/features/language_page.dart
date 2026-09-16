import 'dart:async';
import 'package:flutter/material.dart';
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
    unawaited(widget.store.completeOnboarding());
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/home',
      (route) => false,
    );
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
                  'नमस्ते.',
                  style: TextStyle(
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
                  style: const TextStyle(fontSize: 24, color: Colors.black),
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
                const SizedBox(height: 92),
                Row(
                  children: [
                    Expanded(
                      child: _LanguageOption(
                        label: 'English',
                        selected: selected == 'en',
                        onTap: () => select('en'),
                      ),
                    ),
                    Expanded(
                      child: _LanguageOption(
                        label: 'हिन्दी',
                        selected: selected == 'hi',
                        onTap: () => select('hi'),
                      ),
                    ),
                    Expanded(
                      child: _LanguageOption(
                        label: 'বাংলা',
                        selected: selected == 'bn',
                        onTap: () => select('bn'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 116),
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
                const SizedBox(height: 28),
                TextButton(
                  onPressed: () {},
                  child: Text(
                    widget.store.t('More languages', 'और भाषाएं'),
                    style: const TextStyle(
                      fontSize: 17,
                      color: Colors.black,
                      decoration: TextDecoration.underline,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 22,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 15),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: selected ? 140 : 0,
            height: 4,
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