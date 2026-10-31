import 'package:flutter/material.dart';
import '../core/phone.dart';
import '../data/app_store.dart';
import '../core/theme.dart';

class ContactFields extends StatelessWidget {
  final AppStore store;
  final TextEditingController phone;
  final bool optedIn;
  final bool enabled;
  final ValueChanged<bool> onOptIn;
  const ContactFields({
    super.key,
    required this.store,
    required this.phone,
    required this.optedIn,
    required this.onOptIn,
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
          labelText: store.t('WhatsApp number', 'WhatsApp नंबर'),
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
      const SizedBox(height: AppSpace.sm),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        value: optedIn,
        onChanged: enabled ? (v) => onOptIn(v ?? false) : null,
        title: Text(
          store.t(
            'Send me matching bid alerts on WhatsApp',
            'मिलती-जुलती बोलियों के अलर्ट WhatsApp पर भेजें',
          ),
          style: AppText.body,
        ),
        subtitle: Text(
          store.t(
            'Optional. Change this anytime in Updates. Delivery starts when the service is connected.',
            'वैकल्पिक। सूचनाओं में कभी भी बदलें। सेवा जुड़ने पर संदेश शुरू होंगे।',
          ),
          style: AppText.caption,
        ),
      ),
    ],
  );
}
