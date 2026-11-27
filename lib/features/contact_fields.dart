import 'package:flutter/material.dart';
import '../core/phone.dart';
import '../data/app_store.dart';

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
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextFormField(
        key: const ValueKey('whatsapp-number'),
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
      ),
    ],
  );
}
