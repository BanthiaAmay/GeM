/// The single list of tools shown as boxes on the Tools tab.
///
/// To add a tool: (1) build its page, (2) add a named route in main.dart's
/// `onGenerateRoute`, (3) append ONE [ToolEntry] below. Nothing else changes —
/// the Tools tab, grouping, card look and analytics all come from here.
library;

import 'package:flutter/material.dart';

/// Sections on the Tools tab, in display order.
enum ToolGroup {
  bidDocuments(
    'Bid documents',
    'बोली दस्तावेज़',
    'Declarations and certificates your bid asks for.',
    'आपकी बोली में माँगी जाने वाली घोषणाएँ और प्रमाणपत्र।',
  );

  // Future groups, e.g. `calculators`, `financing`, once those tools are
  // moved onto this registry.

  final String titleEn;
  final String titleHi;
  final String subtitleEn;
  final String subtitleHi;
  const ToolGroup(this.titleEn, this.titleHi, this.subtitleEn, this.subtitleHi);
}

/// Document category used for filter chips on the Tools tab.
/// Each [ToolEntry] carries one category so the hub can filter by it.
enum DocCategory {
  certificates('Certificates', 'प्रमाणपत्र'),
  declarations('Declarations', 'घोषणाएँ'),
  undertakings('Undertakings', 'उपक्रम'),
  templates('Templates', 'टेम्पलेट');

  final String labelEn;
  final String labelHi;
  const DocCategory(this.labelEn, this.labelHi);
}

class ToolEntry {
  /// Stable id, also used in analytics (`tool_opened`, `document_generated`).
  final String id;

  /// Named route registered in main.dart (pushNamed).
  final String route;
  final IconData icon;
  final ToolGroup group;
  final DocCategory docCategory;
  final String titleEn;
  final String titleHi;
  final String descriptionEn;
  final String descriptionHi;

  /// Optional small tag on the card (e.g. "PDF"). English + Hindi.
  final (String en, String hi)? badge;

  const ToolEntry({
    required this.id,
    required this.route,
    required this.icon,
    required this.group,
    required this.docCategory,
    required this.titleEn,
    required this.titleHi,
    required this.descriptionEn,
    required this.descriptionHi,
    this.badge,
  });
}

const List<ToolEntry> kTools = [
  ToolEntry(
    id: 'mii-certificate',
    route: '/tool-mii',
    icon: Icons.verified_outlined,
    group: ToolGroup.bidDocuments,
    docCategory: DocCategory.certificates,
    titleEn: 'Make in India certificate',
    titleHi: 'मेक इन इंडिया प्रमाणपत्र',
    descriptionEn: 'Local-supplier self-declaration, ready to sign.',
    descriptionHi: 'स्थानीय आपूर्तिकर्ता की स्व-घोषणा, हस्ताक्षर के लिए तैयार।',
    badge: ('PDF', 'PDF'),
  ),
  ToolEntry(
    id: 'escalation-matrix',
    route: '/tool-escalation',
    icon: Icons.people_outlined,
    group: ToolGroup.bidDocuments,
    docCategory: DocCategory.templates,
    titleEn: 'Escalation Matrix',
    titleHi: 'एस्केलेशन मैट्रिक्स',
    descriptionEn: 'Contact hierarchy letter for your tender submission',
    descriptionHi: 'निविदा जमा के लिए संपर्क क्रम पत्र',
    badge: ('PDF', 'PDF'),
  ),
  ToolEntry(
    id: 'bid-security',
    route: '/tool-bid-security',
    icon: Icons.security_outlined,
    group: ToolGroup.bidDocuments,
    docCategory: DocCategory.declarations,
    titleEn: 'Bid Security Declaration',
    titleHi: 'बिड सुरक्षा घोषणा',
    descriptionEn:
        'Declare compliance with bid security conditions in lieu of a physical deposit',
    descriptionHi: 'भौतिक जमा के बदले बिड सुरक्षा शर्तों का अनुपालन घोषित करें',
    badge: ('PDF', 'PDF'),
  ),
  ToolEntry(
    id: 'financial-standing',
    route: '/tool-financial-standing',
    icon: Icons.account_balance_outlined,
    group: ToolGroup.bidDocuments,
    docCategory: DocCategory.undertakings,
    titleEn: 'Financial Standing Undertaking',
    titleHi: 'वित्तीय स्थिति उपक्रम',
    descriptionEn:
        'Declare your company is solvent and not under legal proceedings',
    descriptionHi:
        'प्रमाणित करें कि कंपनी दिवालिया या कानूनी कार्यवाही में नहीं है',
    badge: ('PDF', 'PDF'),
  ),
  ToolEntry(
    id: 'non-conviction',
    route: '/tool-non-conviction',
    icon: Icons.gavel_outlined,
    group: ToolGroup.bidDocuments,
    docCategory: DocCategory.certificates,
    titleEn: 'Non-Conviction Certificate',
    titleHi: 'गैर-दोषसिद्धि प्रमाणपत्र',
    descriptionEn: 'Certify your company has no criminal convictions',
    descriptionHi: 'प्रमाणित करें कि कंपनी पर कोई आपराधिक दोष नहीं है',
    badge: ('PDF', 'PDF'),
  ),
  ToolEntry(
    id: 'non-relation',
    route: '/tool-non-relation',
    icon: Icons.handshake_outlined,
    group: ToolGroup.bidDocuments,
    docCategory: DocCategory.undertakings,
    titleEn: 'Non-Relation Undertaking',
    titleHi: 'असंबद्धता उपक्रम',
    descriptionEn: 'Certify no conflict of interest with the tender committee',
    descriptionHi: 'निविदा समिति से हितों के टकराव की अनुपस्थिति का प्रमाण',
    badge: ('PDF', 'PDF'),
  ),
  ToolEntry(
    id: 'atc-certificate',
    route: '/tool-atc-certificate',
    icon: Icons.task_alt_outlined,
    group: ToolGroup.bidDocuments,
    docCategory: DocCategory.certificates,
    titleEn: 'ATC Certificate',
    titleHi: 'नियम एवं शर्त स्वीकृति प्रमाण',
    descriptionEn:
        'Accept all additional terms and conditions associated with a GeM bid',
    descriptionHi: 'GeM बिड की सभी अतिरिक्त नियम व शर्तें स्वीकार करें',
    badge: ('PDF', 'PDF'),
  ),
  ToolEntry(
    id: 'msme-turnover-exemption',
    route: '/tool-msme-turnover',
    icon: Icons.trending_up_outlined,
    group: ToolGroup.bidDocuments,
    docCategory: DocCategory.undertakings,
    titleEn: 'MSME Turnover/Experience Exemption',
    titleHi: 'MSME टर्नओवर/अनुभव छूट अनुरोध',
    descriptionEn:
        'Request exemption from turnover or experience requirements as a registered MSME',
    descriptionHi:
        'MSME के रूप में टर्नओवर या अनुभव आवश्यकताओं से छूट का अनुरोध करें',
    badge: ('PDF', 'PDF'),
  ),
  ToolEntry(
    id: 'msme-emd-exemption',
    route: '/tool-msme-emd',
    icon: Icons.money_off_outlined,
    group: ToolGroup.bidDocuments,
    docCategory: DocCategory.undertakings,
    titleEn: 'MSME EMD Exemption',
    titleHi: 'MSME EMD छूट अनुरोध',
    descriptionEn:
        'Request exemption from Earnest Money Deposit as a registered MSME',
    descriptionHi: 'पंजीकृत MSME के रूप में EMD से छूट का अनुरोध करें',
    badge: ('PDF', 'PDF'),
  ),
  ToolEntry(
    id: 'warranty-declaration',
    route: '/tool-warranty-declaration',
    icon: Icons.verified_outlined,
    group: ToolGroup.bidDocuments,
    docCategory: DocCategory.declarations,
    titleEn: 'Warranty Declaration',
    titleHi: 'वारंटी घोषणा',
    descriptionEn:
        'Certify your warranty terms for products or services being tendered',
    descriptionHi: 'निविदित उत्पादों या सेवाओं की वारंटी शर्तें प्रमाणित करें',
    badge: ('PDF', 'PDF'),
  ),
  ToolEntry(
    id: 'non-blacklist-certificate',
    route: '/tool-nbc',
    icon: Icons.gavel_outlined,
    group: ToolGroup.bidDocuments,
    docCategory: DocCategory.certificates,
    titleEn: 'Non Blacklist Certificate',
    titleHi: 'गैर-ब्लैकलिस्ट प्रमाणपत्र',
    descriptionEn:
        'Generate a professional non-blacklisting undertaking for government tenders.',
    descriptionHi:
        'सरकारी निविदाओं के लिए पेशेवर गैर-ब्लैकलिस्टिंग उपक्रम बनाएँ।',
    badge: ('PDF', 'PDF'),
  ),
  ToolEntry(
    id: 'lowest-price-declaration',
    route: '/tool-lowest-price-declaration',
    icon: Icons.price_check_outlined,
    group: ToolGroup.bidDocuments,
    docCategory: DocCategory.declarations,
    titleEn: 'Lowest Price Declaration',
    titleHi: 'न्यूनतम मूल्य घोषणा',
    descriptionEn:
        'Declare that your quoted price is the lowest offered to any buyer',
    descriptionHi:
        'घोषित करें कि आपका उद्धृत मूल्य किसी भी खरीदार को दिया गया सबसे कम मूल्य है',
    badge: ('PDF', 'PDF'),
  ),
  ToolEntry(
    id: 'oem-authorization',
    route: '/tool-oem-authorization',
    icon: Icons.verified_user_outlined,
    group: ToolGroup.bidDocuments,
    docCategory: DocCategory.templates,
    titleEn: 'OEM Authorization Certificate',
    titleHi: 'OEM प्राधिकरण प्रमाण पत्र',
    descriptionEn:
        'Authorize a reseller or distributor to participate in a GeM bid on your behalf',
    descriptionHi:
        'किसी रिसेलर को GeM बिड में आपकी ओर से भाग लेने के लिए अधिकृत करें',
    badge: ('PDF', 'PDF'),
  ),
  ToolEntry(
    id: 'land-border-declaration',
    route: '/tool-land-border-declaration',
    icon: Icons.public_off_outlined,
    group: ToolGroup.bidDocuments,
    docCategory: DocCategory.declarations,
    titleEn: 'Land Border Declaration',
    titleHi: 'भूमि सीमा घोषणा',
    descriptionEn:
        'Certify compliance with land border restrictions under Rule 144 (xi) of GFR 2017',
    descriptionHi:
        'GFR 2017 के नियम 144 (xi) के तहत भूमि सीमा प्रतिबंधों का अनुपालन प्रमाणित करें',
    badge: ('PDF', 'PDF'),
  ),
  ToolEntry(
    id: 'mrp-declaration',
    route: '/tool-mrp-declaration',
    icon: Icons.label_outline,
    group: ToolGroup.bidDocuments,
    docCategory: DocCategory.declarations,
    titleEn: 'MRP Declaration Letter',
    titleHi: 'MRP घोषणा पत्र',
    descriptionEn:
        'Declare the Maximum Retail Price of your products for a GeM bid submission',
    descriptionHi:
        'GeM बिड जमा करने के लिए अपने उत्पादों की अधिकतम खुदरा कीमत (MRP) घोषित करें',
    badge: ('PDF', 'PDF'),
  ),
];
