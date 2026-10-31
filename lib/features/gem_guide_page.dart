import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../data/app_store.dart';
import 'components.dart';
import 'onboarding_flow_4.dart' show gemRegistrationUrl;
import 'widgets.dart' show openLink;

/// A resumable checklist. Opening GeM never counts as completing registration.
class GemGuidePage extends StatelessWidget {
  final AppStore store;
  const GemGuidePage({super.key, required this.store});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final s = store;
      final done = List<bool>.from(
        s.profile['gemGuide'] ?? List.filled(5, false),
      );
      final steps = [
        (
          s.t('Get your details ready', 'अपने विवरण तैयार रखें'),
          s.t(
            'Keep your authorised person’s contact details, business PAN and bank details handy. Check the current prerequisites on GeM for your business type.',
            'अधिकृत व्यक्ति का संपर्क, व्यवसाय PAN और बैंक विवरण तैयार रखें। अपने व्यवसाय प्रकार की वर्तमान शर्तें GeM पर देखें।',
          ),
        ),
        (
          s.t(
            'Choose Seller / Service Provider',
            'विक्रेता / सेवा प्रदाता चुनें',
          ),
          s.t(
            'Open the official GeM portal and choose Sign up → Seller / Service Provider. Complete the identity and contact checks requested there.',
            'आधिकारिक GeM पोर्टल पर साइन अप → विक्रेता / सेवा प्रदाता चुनें। पहचान और संपर्क जाँच वहीं पूरी करें।',
          ),
        ),
        (
          s.t('Create your GeM login', 'अपना GeM लॉगिन बनाएँ'),
          s.t(
            'Use your own email and mobile number. Enter OTPs and create your GeM credentials only on the official portal.',
            'अपना ईमेल और मोबाइल इस्तेमाल करें। OTP और GeM लॉगिन विवरण केवल आधिकारिक पोर्टल पर दें।',
          ),
        ),
        (
          s.t('Complete your seller profile', 'विक्रेता प्रोफ़ाइल पूरी करें'),
          s.t(
            'Add business, bank, tax and other details that GeM requests. GST, Udyam and assessment requirements depend on your business and what you sell.',
            'GeM द्वारा माँगे गए व्यवसाय, बैंक, कर और अन्य विवरण भरें। GST, उद्यम और आकलन की शर्तें आपके व्यवसाय और पेशकश पर निर्भर हैं।',
          ),
        ),
        (
          s.t('Prepare to respond to bids', 'बोलियों के लिए तैयार हों'),
          s.t(
            'Complete the relevant product or service listing, then read each bid’s eligibility, specifications, delivery location and closing time before participating.',
            'संबंधित उत्पाद या सेवा सूची पूरी करें। भाग लेने से पहले हर बोली की पात्रता, विनिर्देश, वितरण स्थान और अंतिम समय पढ़ें।',
          ),
        ),
      ];
      return Scaffold(
        appBar: AppBar(
          title: Text(s.t('GeM registration guide', 'GeM पंजीकरण गाइड')),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpace.gutter),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.t(
                        'From your business\nto the GeM marketplace.',
                        'आपके व्यवसाय से\nGeM बाज़ार तक।',
                      ),
                      style: AppText.h1,
                    ),
                    const SizedBox(height: AppSpace.lg),
                    Text(
                      s.t(
                        'Your Bid2Scale account and official GeM seller account are separate. Complete seller registration on gem.gov.in.',
                        'आपका Bid2Scale खाता और आधिकारिक GeM विक्रेता खाता अलग हैं। विक्रेता पंजीकरण gem.gov.in पर पूरा करें।',
                      ),
                      style: AppText.body,
                    ),
                    const SizedBox(height: AppSpace.xxl),
                    Text(
                      s.t(
                        '${done.where((v) => v).length} of 5 steps checked by you',
                        'आपने 5 में से ${done.where((v) => v).length} चरण पूरे बताए',
                      ),
                      style: AppText.title,
                    ),
                    const SizedBox(height: AppSpace.md),
                    LinearProgressIndicator(
                      value: done.where((v) => v).length / 5,
                      semanticsLabel: s.t(
                        'Registration preparation',
                        'पंजीकरण तैयारी',
                      ),
                    ),
                    const SizedBox(height: AppSpace.xxl),
                    for (var i = 0; i < steps.length; i++) ...[
                      AppCard(
                        child: CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: done[i],
                          title: Text(steps[i].$1, style: AppText.title),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: AppSpace.sm),
                            child: Text(steps[i].$2, style: AppText.bodySmall),
                          ),
                          onChanged: (v) {
                            done[i] = v ?? false;
                            s.setProfile('gemGuide', done);
                          },
                        ),
                      ),
                      const SizedBox(height: AppSpace.md),
                    ],
                    const SizedBox(height: AppSpace.md),
                    AppButton(
                      label: s.t(
                        'Open official GeM registration',
                        'आधिकारिक GeM पंजीकरण खोलें',
                      ),
                      trailingIcon: Icons.open_in_new,
                      onPressed: () => openLink(context, s, gemRegistrationUrl),
                    ),
                    const SizedBox(height: AppSpace.md),
                    Text(
                      s.t(
                        'Opens mkp.gem.gov.in. Return here to keep your checklist updated. Your checks are self-reported, not confirmation from GeM.',
                        'mkp.gem.gov.in खुलेगा। लौटकर चेकलिस्ट अपडेट करें। आपके चेक स्वयं बताए गए हैं, GeM की पुष्टि नहीं।',
                      ),
                      style: AppText.caption,
                    ),
                    const SizedBox(height: AppSpace.xl),
                    AppButton(
                      label: s.t(
                        'Choose my bid alerts',
                        'मेरे बोली अलर्ट चुनें',
                      ),
                      variant: AppButtonVariant.secondary,
                      onPressed: () => Navigator.pushNamed(context, '/alerts'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
