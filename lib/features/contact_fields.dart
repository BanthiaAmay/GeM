import 'package:flutter/material.dart';
import '../core/phone.dart';
import '../data/app_store.dart';

/// Signup contact number. Bid alerts are in-app only, so this field asks for
/// no messaging consent.
class ContactFields extends StatelessWidget {
  final AppStore store;
  final TextEditingController phone;
  final bool enabled;
  const ContactFields({
    super.key,
    required this.store,
    required this.phone,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
    key: const ValueKey('mobile-number'),
    controller: phone,
    enabled: enabled,
    keyboardType: TextInputType.phone,
    textInputAction: TextInputAction.next,
    autofillHints: const [AutofillHints.telephoneNumber],
    autovalidateMode: AutovalidateMode.onUserInteraction,
    decoration: InputDecoration(
      labelText: store.t('Mobile number', 'मोबाइल नंबर'),
      hintText: '+91 98765 43210',
      helperText: store.t(
        'Your Indian mobile number, with +91.',
        'आपका भारतीय मोबाइल नंबर, +91 के साथ।',
      ),
    ),
    validator: (value) => normalizeWhatsapp(value ?? '') == null
        ? store.t(
            'Enter a valid 10-digit Indian mobile number.',
            'सही 10 अंकों का भारतीय मोबाइल नंबर डालें।',
          )
        : null,
  );
}
