import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../data/app_store.dart';

/// Shared chrome for every screen in the "not yet on GeM" onboarding
/// walkthrough: back arrow, logo, progress bar, section/step labels,
/// headline, optional subtitle, the screen's own content, and a
/// Continue button (disabled when [onContinue] is null).
class OnboardingStepScaffold extends StatelessWidget {
  final VoidCallback onBack;
  final double progress;
  final String sectionLabel;
  final String stepLabel;
  final String headline;
  final String? subtitle;
  final List<Widget> children;
  final String continueLabel;
  final VoidCallback? onContinue;

  const OnboardingStepScaffold({
    super.key,
    required this.onBack,
    required this.progress,
    required this.sectionLabel,
    required this.stepLabel,
    required this.headline,
    this.subtitle,
    required this.children,
    required this.continueLabel,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final pct = progress.clamp(0.02, 0.98);
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
                      onPressed: onBack,
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
                        flex: (pct * 1000).round(),
                        child: Container(height: 5, color: Colors.black),
                      ),
                      Expanded(
                        flex: 1000 - (pct * 1000).round(),
                        child: Container(
                          height: 5,
                          color: const Color(0xFFE4E4E4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  sectionLabel,
                  style: const TextStyle(fontSize: 15, color: Color(0xFF737B84)),
                ),
                const SizedBox(height: 16),
                Text(
                  stepLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: Color(0xFF737B84),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  headline,
                  style: const TextStyle(
                    fontFamily: sfProDisplay,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                    color: Colors.black,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    subtitle!,
                    style: const TextStyle(fontSize: 16, color: Color(0xFF737B84)),
                  ),
                ],
                const SizedBox(height: 28),
                ...children,
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 66,
                  child: FilledButton(
                    onPressed: onContinue,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF151515),
                      disabledBackgroundColor: const Color(0xFFCCCCCC),
                      foregroundColor: Colors.white,
                      shape: const StadiumBorder(),
                    ),
                    child: Text(
                      continueLabel,
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

/// A labeled text input, styled to match the mockups.
class OnboardingTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final String? prefixText;
  final ValueChanged<String>? onChanged;

  const OnboardingTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.prefixText,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 15, color: Color(0xFF737B84))),
      const SizedBox(height: 8),
      TextField(
        controller: controller,
        keyboardType: keyboardType,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 18, color: Colors.black),
        decoration: InputDecoration(
          hintText: hint,
          prefixText: prefixText,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 18,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.black, width: 1.4),
          ),
        ),
      ),
    ],
  );
}

/// A tappable field that looks like the state/district pickers in the
/// mockups (leading icon, value text, trailing chevron) and opens a
/// simple bottom-sheet list to choose from.
class OnboardingPickerField extends StatelessWidget {
  final IconData icon;
  final String value;
  final String hint;
  final List<String> options;
  final ValueChanged<String> onSelected;
  final AppStore s;

  const OnboardingPickerField({
    super.key,
    required this.icon,
    required this.value,
    required this.hint,
    required this.options,
    required this.onSelected,
    required this.s,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () async {
      final picked = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        builder: (context) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.7,
            ),
            child: ListView(
              children: [
                for (final option in options)
                  ListTile(
                    title: Text(option),
                    trailing: option == value
                        ? const Icon(Icons.check, color: Colors.black)
                        : null,
                    onTap: () => Navigator.of(context).pop(option),
                  ),
              ],
            ),
          ),
        ),
      );
      if (picked != null) onSelected(picked);
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFDDDDDD)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: Colors.black),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value.isEmpty ? hint : value,
              style: TextStyle(
                fontSize: 18,
                color: value.isEmpty ? const Color(0xFF9A9A9A) : Colors.black,
              ),
            ),
          ),
          const Icon(Icons.keyboard_arrow_down, color: Colors.black),
        ],
      ),
    ),
  );
}

/// A single-select option row with a leading icon and trailing
/// radio-style indicator, used for business form / sector / role /
/// readiness questions throughout this flow.
class OnboardingRadioOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? trailingField;

  const OnboardingRadioOption({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.trailingField,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        border: Border.all(
          color: selected ? Colors.black : const Color(0xFFDDDDDD),
          width: selected ? 1.4 : 1,
        ),
        borderRadius: BorderRadius.circular(14),
        color: selected ? const Color(0xFFFAFAFA) : Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 24, color: Colors.black),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? Colors.black : const Color(0xFFBBBBBB),
              ),
            ],
          ),
          if (trailingField != null && selected) ...[
            const SizedBox(height: 12),
            trailingField!,
          ],
        ],
      ),
    ),
  );
}

/// A multi-select option row (checkbox), used for the business-records
/// checklist.
class OnboardingCheckOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? sublabel;
  final bool checked;
  final VoidCallback onTap;

  const OnboardingCheckOption({
    super.key,
    required this.icon,
    required this.label,
    this.sublabel,
    required this.checked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        border: Border.all(
          color: checked ? Colors.black : const Color(0xFFDDDDDD),
          width: checked ? 1.4 : 1,
        ),
        borderRadius: BorderRadius.circular(14),
        color: checked ? const Color(0xFFFAFAFA) : Colors.white,
      ),
      child: Row(
        children: [
          Icon(icon, size: 24, color: Colors.black),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 18, color: Colors.black),
                ),
                if (sublabel != null)
                  Text(
                    sublabel!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF9A9A9A),
                    ),
                  ),
              ],
            ),
          ),
          Icon(
            checked ? Icons.check_box : Icons.check_box_outline_blank,
            color: checked ? Colors.black : const Color(0xFFBBBBBB),
          ),
        ],
      ),
    ),
  );
}
