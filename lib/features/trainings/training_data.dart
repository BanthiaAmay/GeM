import 'package:flutter/material.dart';

/// The 34 official GeM seller-training videos ("GeM Seller Training Videos —
/// English", playlist PLsV56B8jjgAJNxNj2bjngfL9H6sghRhGX on the Government
/// e-Marketplace YouTube channel), grouped into 6 themed modules.
///
/// Ordering within each module runs overview → specifics (lesson from the
/// Oct 2026 registration-guide rollout where video order had to be reversed
/// post-ship). Append-only: when a new video is published, add it to the
/// bottom of the right module — ids referenced by analytics/quiz state will
/// still be stable.

/// One YouTube video inside a [TrainingModule].
class TrainingVideo {
  /// 11-character YouTube video id used by [YouTubeVideoCard].
  final String videoId;

  /// Short, action-first title (English).
  final String titleEn;

  /// Hindi title. YouTube itself serves English titles; this one-liner lets
  /// Hindi users understand the topic before tapping play.
  final String titleHi;

  /// Rough duration in minutes, from scanning the playlist. Hint only.
  final int minutes;

  const TrainingVideo({
    required this.videoId,
    required this.titleEn,
    required this.titleHi,
    required this.minutes,
  });
}

/// One quiz question. Exactly one of [options] is correct ([correctIndex]).
class TrainingQuizQuestion {
  final String promptEn;
  final String promptHi;
  final List<String> optionsEn;
  final List<String> optionsHi;
  final int correctIndex;

  const TrainingQuizQuestion({
    required this.promptEn,
    required this.promptHi,
    required this.optionsEn,
    required this.optionsHi,
    required this.correctIndex,
  });
}

/// A learning module: a group of related training videos plus a short
/// post-module quiz.
class TrainingModule {
  /// Stable id used in analytics, deep links and state. Lowercase,
  /// hyphen-free — matches the shape of existing `tool`/`page` keys.
  final String id;

  final String titleEn;
  final String titleHi;
  final String subtitleEn;
  final String subtitleHi;

  /// Icon from the Material outlined set.
  final IconData icon;

  final List<TrainingVideo> videos;
  final List<TrainingQuizQuestion> quiz;

  const TrainingModule({
    required this.id,
    required this.titleEn,
    required this.titleHi,
    required this.subtitleEn,
    required this.subtitleHi,
    required this.icon,
    required this.videos,
    required this.quiz,
  });

  /// Rough total runtime in minutes (sum of video hints).
  int get totalMinutes => videos.fold(0, (sum, v) => sum + v.minutes);
}

/// The six modules. Keep as `const` so the list is cheap to pass around and
/// safe to use anywhere (search index, deep links, tests).
const kTrainingModules = <TrainingModule>[
  // ────────────────────────── Module 1 ──────────────────────────
  TrainingModule(
    id: 'trn-m1',
    titleEn: 'Get Started on GeM',
    titleHi: 'GeM पर शुरू करें',
    subtitleEn:
        'Register, sign in and verify your business — the first five videos.',
    subtitleHi:
        'पंजीकरण, साइन-इन और सत्यापन — पहले पाँच वीडियो।',
    icon: Icons.rocket_launch_outlined,
    videos: [
      TrainingVideo(
        videoId: 'XCRwD-sqELE',
        titleEn: 'Introduction to Seller / Service Provider on GeM',
        titleHi: 'GeM पर विक्रेता / सेवा प्रदाता परिचय',
        minutes: 6,
      ),
      TrainingVideo(
        videoId: '567GuVY6vRc',
        titleEn: 'Register as a Seller using PAN',
        titleHi: 'PAN से विक्रेता पंजीकरण',
        minutes: 5,
      ),
      TrainingVideo(
        videoId: 'FiQPVJpAICM',
        titleEn: 'Register as a Seller using Aadhaar',
        titleHi: 'आधार से विक्रेता पंजीकरण',
        minutes: 5,
      ),
      TrainingVideo(
        videoId: 'V_84PXf_jd4',
        titleEn: 'Complete the e-Sign process',
        titleHi: 'e-Sign प्रक्रिया पूरी करें',
        minutes: 4,
      ),
      TrainingVideo(
        videoId: 'vVfeoRvK97c',
        titleEn: 'India Post registration process for users',
        titleHi: 'उपयोगकर्ताओं के लिए इंडिया पोस्ट पंजीकरण',
        minutes: 5,
      ),
    ],
    quiz: [
      TrainingQuizQuestion(
        promptEn: 'What does GeM stand for?',
        promptHi: 'GeM का पूरा रूप क्या है?',
        optionsEn: [
          'Government e-Marketplace',
          'General e-Mart',
          'Goods e-Mandi',
        ],
        optionsHi: [
          'Government e-Marketplace',
          'General e-Mart',
          'Goods e-Mandi',
        ],
        correctIndex: 0,
      ),
      TrainingQuizQuestion(
        promptEn: 'Which document can be used by itself to register as a seller?',
        promptHi: 'अकेले किस दस्तावेज़ से विक्रेता पंजीकरण हो सकता है?',
        optionsEn: ['PAN or Aadhaar', 'Driving licence', 'Voter ID'],
        optionsHi: ['PAN या आधार', 'ड्राइविंग लाइसेंस', 'वोटर आईडी'],
        correctIndex: 0,
      ),
      TrainingQuizQuestion(
        promptEn: 'Where should you create your GeM login?',
        promptHi: 'GeM लॉगिन कहाँ बनाएँ?',
        optionsEn: [
          'Any registration agent',
          'The official GeM portal only',
          'A WhatsApp group',
        ],
        optionsHi: [
          'कोई भी पंजीकरण एजेंट',
          'केवल आधिकारिक GeM पोर्टल',
          'WhatsApp समूह',
        ],
        correctIndex: 1,
      ),
    ],
  ),

  // ────────────────────────── Module 2 ──────────────────────────
  TrainingModule(
    id: 'trn-m2',
    titleEn: 'Set Up Your Seller Profile',
    titleHi: 'विक्रेता प्रोफ़ाइल सेट करें',
    subtitleEn:
        'Fill in business details, invite teammates and understand vendor assessment.',
    subtitleHi:
        'व्यवसाय विवरण, टीम और विक्रेता मूल्यांकन समझें।',
    icon: Icons.badge_outlined,
    videos: [
      TrainingVideo(
        videoId: '37XWI3lBD8M',
        titleEn: 'Update your seller profile',
        titleHi: 'विक्रेता प्रोफ़ाइल अपडेट करें',
        minutes: 5,
      ),
      TrainingVideo(
        videoId: '3KbjYD0HF5w',
        titleEn: 'Add a Secondary User to your account',
        titleHi: 'खाते में सहायक उपयोगकर्ता जोड़ें',
        minutes: 4,
      ),
      TrainingVideo(
        videoId: 'XmnaLsKR_3M',
        titleEn: 'Vendor Assessment: what to expect',
        titleHi: 'विक्रेता मूल्यांकन: क्या अपेक्षा रखें',
        minutes: 7,
      ),
    ],
    quiz: [
      TrainingQuizQuestion(
        promptEn: 'What is a Secondary User?',
        promptHi: 'सहायक उपयोगकर्ता क्या है?',
        optionsEn: [
          'A teammate who logs in under your seller account',
          'A customer buying from you',
          'A GeM admin',
        ],
        optionsHi: [
          'आपके विक्रेता खाते में लॉगिन करने वाला सहकर्मी',
          'आपसे खरीदने वाला ग्राहक',
          'GeM प्रशासक',
        ],
        correctIndex: 0,
      ),
      TrainingQuizQuestion(
        promptEn: 'Vendor Assessment is usually done because the buyer wants to know …',
        promptHi: 'विक्रेता मूल्यांकन इसलिए होता है क्योंकि खरीदार जानना चाहता है …',
        optionsEn: [
          'Your bank balance',
          'Your capability to deliver reliably',
          'Your family details',
        ],
        optionsHi: [
          'आपका बैंक बैलेंस',
          'आपकी भरोसेमंद आपूर्ति क्षमता',
          'आपकी पारिवारिक जानकारी',
        ],
        correctIndex: 1,
      ),
      TrainingQuizQuestion(
        promptEn: 'Where do you update profile information?',
        promptHi: 'प्रोफ़ाइल जानकारी कहाँ अपडेट करें?',
        optionsEn: [
          'By calling GeM support',
          'On a third-party form',
          'Inside your seller dashboard on GeM',
        ],
        optionsHi: [
          'GeM सहायता को कॉल करके',
          'किसी तीसरे-पक्ष फॉर्म पर',
          'GeM पर अपने विक्रेता डैशबोर्ड में',
        ],
        correctIndex: 2,
      ),
    ],
  ),

  // ────────────────────────── Module 3 ──────────────────────────
  TrainingModule(
    id: 'trn-m3',
    titleEn: 'Master Your Catalogue',
    titleHi: 'कैटलॉग में महारत',
    subtitleEn:
        'List products the right way: images, pairing, clones and MRP documents.',
    subtitleHi:
        'उत्पाद सही तरीके से सूचीबद्ध करें: फ़ोटो, जोड़ी, क्लोन और MRP।',
    icon: Icons.inventory_2_outlined,
    videos: [
      TrainingVideo(
        videoId: 'MC-JonjNZqU',
        titleEn: 'Catalogue management for products',
        titleHi: 'उत्पादों के लिए कैटलॉग प्रबंधन',
        minutes: 8,
      ),
      TrainingVideo(
        videoId: 'wVMXoqx8tM8',
        titleEn: 'Image upload process',
        titleHi: 'चित्र अपलोड प्रक्रिया',
        minutes: 4,
      ),
      TrainingVideo(
        videoId: 'rZjec0Yrx2Q',
        titleEn: 'Pair Catalogue: group related listings',
        titleHi: 'Pair Catalogue: सम्बंधित सूची समूहित करें',
        minutes: 5,
      ),
      TrainingVideo(
        videoId: 'w7Om2ijuCig',
        titleEn: 'Clone Catalogue functionality',
        titleHi: 'Clone Catalogue कार्यक्षमता',
        minutes: 5,
      ),
      TrainingVideo(
        videoId: 'prrxj8YhZRI',
        titleEn: 'Supporting documents for MRP',
        titleHi: 'MRP के लिए सहायक दस्तावेज़',
        minutes: 4,
      ),
      TrainingVideo(
        videoId: 'VwimbhwP2j0',
        titleEn: 'Mark a product as discontinued',
        titleHi: 'उत्पाद को बन्द (Discontinued) चिह्नित करें',
        minutes: 3,
      ),
      TrainingVideo(
        videoId: 'Ztf1RjdNCdQ',
        titleEn: 'Resubmit a rejected or notified brand',
        titleHi: 'अस्वीकृत या सूचित ब्रांड पुनः जमा करें',
        minutes: 6,
      ),
    ],
    quiz: [
      TrainingQuizQuestion(
        promptEn: 'What does Clone Catalogue help you do?',
        promptHi: 'Clone Catalogue से क्या होता है?',
        optionsEn: [
          'Reuse an existing listing as the base for a new one',
          'Copy another seller\'s listing',
          'Delete all listings',
        ],
        optionsHi: [
          'मौजूदा सूची को नई सूची का आधार बनाना',
          'अन्य विक्रेता की सूची कॉपी करना',
          'सभी सूचियाँ हटाना',
        ],
        correctIndex: 0,
      ),
      TrainingQuizQuestion(
        promptEn: 'Product images should be …',
        promptHi: 'उत्पाद चित्र कैसे होने चाहिए?',
        optionsEn: [
          'Any photo from the internet',
          'Clear, your own, matching the actual product',
          'Blurred to protect the design',
        ],
        optionsHi: [
          'इंटरनेट से कोई भी फ़ोटो',
          'स्पष्ट, आपके अपने, उत्पाद से मेल खाते हुए',
          'डिज़ाइन छुपाने के लिए धुंधली',
        ],
        correctIndex: 1,
      ),
      TrainingQuizQuestion(
        promptEn: 'A notified brand rejection usually means …',
        promptHi: 'सूचित ब्रांड की अस्वीकृति अक्सर दर्शाती है …',
        optionsEn: [
          'The seller is banned forever',
          'The product cannot be sold anywhere',
          'The documents needed updating or clarification',
        ],
        optionsHi: [
          'विक्रेता पर स्थायी प्रतिबंध',
          'उत्पाद कहीं भी नहीं बिक सकता',
          'दस्तावेज़ों को अद्यतन या स्पष्टीकरण की आवश्यकता',
        ],
        correctIndex: 2,
      ),
    ],
  ),

  // ────────────────────────── Module 4 ──────────────────────────
  TrainingModule(
    id: 'trn-m4',
    titleEn: 'Win Your First Bid',
    titleHi: 'पहली बोली जीतें',
    subtitleEn:
        'From a bid feed to EMD to reverse auction — the full participation workflow.',
    subtitleHi:
        'बोली सूची से EMD और रिवर्स नीलामी तक — पूरी प्रक्रिया।',
    icon: Icons.gavel_outlined,
    videos: [
      TrainingVideo(
        videoId: '4iUHXRB9n48',
        titleEn: 'Bid participation (services)',
        titleHi: 'बोली भागीदारी (सेवाएँ)',
        minutes: 7,
      ),
      TrainingVideo(
        videoId: 'PbABxpkHwpI',
        titleEn: 'BOQ — Seller view',
        titleHi: 'BOQ — विक्रेता दृश्य',
        minutes: 5,
      ),
      TrainingVideo(
        videoId: '4ajT3ciuZoM',
        titleEn: 'Item-wise BOQ for sellers',
        titleHi: 'विक्रेताओं के लिए Item-wise BOQ',
        minutes: 5,
      ),
      TrainingVideo(
        videoId: 'lQUQY_phTpw',
        titleEn: 'Custom Catalogue Based Bid: seller participation',
        titleHi: 'Custom Catalogue आधारित बोली: भागीदारी',
        minutes: 6,
      ),
      TrainingVideo(
        videoId: 'KQTTxKJKK4Q',
        titleEn: 'Reverse Auction participation (seller)',
        titleHi: 'रिवर्स नीलामी भागीदारी (विक्रेता)',
        minutes: 6,
      ),
      TrainingVideo(
        videoId: 'W5JDD64fQiE',
        titleEn: 'Forward Auction: bidder registration and participation',
        titleHi: 'फॉरवर्ड नीलामी: बोलीदाता पंजीकरण और भागीदारी',
        minutes: 6,
      ),
      TrainingVideo(
        videoId: 'qc3kW0kJurc',
        titleEn: 'EMD requirements for sellers',
        titleHi: 'विक्रेताओं के लिए EMD आवश्यकताएँ',
        minutes: 5,
      ),
    ],
    quiz: [
      TrainingQuizQuestion(
        promptEn: 'EMD stands for …',
        promptHi: 'EMD का अर्थ है …',
        optionsEn: [
          'Earnest Money Deposit',
          'Electronic Money Draft',
          'Emergency Monetary Deposit',
        ],
        optionsHi: [
          'Earnest Money Deposit',
          'Electronic Money Draft',
          'Emergency Monetary Deposit',
        ],
        correctIndex: 0,
      ),
      TrainingQuizQuestion(
        promptEn: 'A Reverse Auction is one where …',
        promptHi: 'रिवर्स नीलामी वह है जहाँ …',
        optionsEn: [
          'Buyers raise their offer each round',
          'Sellers compete by progressively lowering their price',
          'The seller sets the final price',
        ],
        optionsHi: [
          'खरीदार हर दौर में मूल्य बढ़ाते हैं',
          'विक्रेता मूल्य घटाकर प्रतिस्पर्धा करते हैं',
          'विक्रेता अंतिम मूल्य तय करता है',
        ],
        correctIndex: 1,
      ),
      TrainingQuizQuestion(
        promptEn: 'Before bidding, which is the single most important thing to read?',
        promptHi: 'बोली से पहले सबसे ज़रूरी क्या पढ़ना चाहिए?',
        optionsEn: [
          'Only the price field',
          'Other sellers\' profiles',
          'The bid document (specs, delivery, buyer terms)',
        ],
        optionsHi: [
          'केवल मूल्य फ़ील्ड',
          'अन्य विक्रेताओं की प्रोफ़ाइल',
          'बोली दस्तावेज़ (विनिर्देश, डिलीवरी, खरीदार शर्तें)',
        ],
        correctIndex: 2,
      ),
    ],
  ),

  // ────────────────────────── Module 5 ──────────────────────────
  TrainingModule(
    id: 'trn-m5',
    titleEn: 'Fulfil Orders and Get Paid',
    titleHi: 'ऑर्डर पूरा करें और भुगतान पाएँ',
    subtitleEn:
        'Invoicing, TDS, consignee review and price-variation clauses.',
    subtitleHi:
        'चालान, TDS, consignee समीक्षा और मूल्य-परिवर्तन।',
    icon: Icons.receipt_long_outlined,
    videos: [
      TrainingVideo(
        videoId: 'QB231j7qeEM',
        titleEn: 'Order processing and invoice generation (seller)',
        titleHi: 'ऑर्डर प्रक्रिया और चालान (विक्रेता)',
        minutes: 7,
      ),
      TrainingVideo(
        videoId: 'CUHd59HcVg4',
        titleEn: 'Service invoicing, consignee review and order billing',
        titleHi: 'सेवा चालान, consignee समीक्षा और बिलिंग',
        minutes: 8,
      ),
      TrainingVideo(
        videoId: 'YLED6mtia30',
        titleEn: 'Raise a Supplementary Invoice',
        titleHi: 'पूरक चालान बनाएँ',
        minutes: 4,
      ),
      TrainingVideo(
        videoId: '3XHbez5MpbE',
        titleEn: 'TDS Certificate workflow',
        titleHi: 'TDS प्रमाणपत्र प्रक्रिया',
        minutes: 5,
      ),
      TrainingVideo(
        videoId: 'xq8h0dgcFlQ',
        titleEn: 'Price Variation Clause — seller',
        titleHi: 'मूल्य-परिवर्तन खंड — विक्रेता',
        minutes: 5,
      ),
    ],
    quiz: [
      TrainingQuizQuestion(
        promptEn: 'A supplementary invoice is raised to …',
        promptHi: 'पूरक चालान किस लिए बनाया जाता है?',
        optionsEn: [
          'Add charges missed in the original invoice',
          'Cancel the original invoice',
          'Replace an order',
        ],
        optionsHi: [
          'मूल चालान में छूटे शुल्क जोड़ने के लिए',
          'मूल चालान रद्द करने के लिए',
          'ऑर्डर बदलने के लिए',
        ],
        correctIndex: 0,
      ),
      TrainingQuizQuestion(
        promptEn: 'The consignee is …',
        promptHi: 'Consignee कौन होता है?',
        optionsEn: [
          'The seller\'s warehouse',
          'The buyer\'s representative who receives and reviews the goods',
          'The transporter',
        ],
        optionsHi: [
          'विक्रेता का गोदाम',
          'खरीदार का प्रतिनिधि जो सामान प्राप्त और समीक्षा करता है',
          'ट्रांसपोर्टर',
        ],
        correctIndex: 1,
      ),
      TrainingQuizQuestion(
        promptEn: 'A Price Variation Clause mainly protects against …',
        promptHi: 'मूल्य-परिवर्तन खंड मुख्यतः किससे रक्षा करता है?',
        optionsEn: [
          'Tax audits',
          'Buyer cancellations',
          'Material-cost swings during a long contract',
        ],
        optionsHi: [
          'कर ऑडिट से',
          'खरीदार द्वारा रद्द करने से',
          'लंबे अनुबंध में सामग्री-लागत के उतार-चढ़ाव से',
        ],
        correctIndex: 2,
      ),
    ],
  ),

  // ────────────────────────── Module 6 ──────────────────────────
  TrainingModule(
    id: 'trn-m6',
    titleEn: 'Grow — Advanced, OEM and Finance',
    titleHi: 'आगे बढ़ें — उन्नत, OEM और वित्त',
    subtitleEn:
        'Dashboard, request-management, finance (Sahay) and OEM/reseller workflows.',
    subtitleHi:
        'डैशबोर्ड, अनुरोध प्रबंधन, वित्त (Sahay) और OEM/रिसेलर।',
    icon: Icons.trending_up_outlined,
    videos: [
      TrainingVideo(
        videoId: '9ztafq9OagQ',
        titleEn: 'Overview of the seller dashboard',
        titleHi: 'विक्रेता डैशबोर्ड का परिचय',
        minutes: 6,
      ),
      TrainingVideo(
        videoId: 'BHLyw68cvxU',
        titleEn: 'Request Management System for sellers',
        titleHi: 'विक्रेताओं के लिए अनुरोध प्रबंधन',
        minutes: 5,
      ),
      TrainingVideo(
        videoId: 'FdZo1z2YFss',
        titleEn: 'Learning Management System for users',
        titleHi: 'उपयोगकर्ताओं के लिए लर्निंग प्रबंधन',
        minutes: 5,
      ),
      TrainingVideo(
        videoId: '1gkbvAUqrrs',
        titleEn: 'Sahay Loan Scheme on GeM',
        titleHi: 'GeM पर Sahay ऋण योजना',
        minutes: 5,
      ),
      TrainingVideo(
        videoId: 'G65sooDSy24',
        titleEn: 'OEM panel: approvals for sellers, catalogues and authorisations',
        titleHi: 'OEM पैनल: विक्रेता, कैटलॉग और अधिकार अनुमोदन',
        minutes: 7,
      ),
      TrainingVideo(
        videoId: 'M20MbRzTOGU',
        titleEn: 'Reseller panel workflow',
        titleHi: 'रिसेलर पैनल प्रक्रिया',
        minutes: 6,
      ),
      TrainingVideo(
        videoId: 'KMsYD36TUIU',
        titleEn: 'Secondary user creation — Ministry of Panchayati Raj',
        titleHi: 'सहायक उपयोगकर्ता — पंचायती राज मंत्रालय',
        minutes: 5,
      ),
    ],
    quiz: [
      TrainingQuizQuestion(
        promptEn: 'Sahay on GeM is primarily a …',
        promptHi: 'GeM पर Sahay मुख्यतः क्या है?',
        optionsEn: [
          'Short-term working-capital loan scheme',
          'Shipping subsidy',
          'Government grant',
        ],
        optionsHi: [
          'अल्पकालिक कार्यशील-पूंजी ऋण योजना',
          'शिपिंग सब्सिडी',
          'सरकारी अनुदान',
        ],
        correctIndex: 0,
      ),
      TrainingQuizQuestion(
        promptEn: 'What does an OEM panel approve?',
        promptHi: 'OEM पैनल क्या अनुमोदित करता है?',
        optionsEn: [
          'Buyer purchases',
          'Reseller authorisations and reseller catalogues',
          'GeM policy changes',
        ],
        optionsHi: [
          'खरीदार खरीद',
          'रिसेलर अधिकार और रिसेलर कैटलॉग',
          'GeM नीति परिवर्तन',
        ],
        correctIndex: 1,
      ),
      TrainingQuizQuestion(
        promptEn: 'The Request Management System is where you …',
        promptHi: 'अनुरोध प्रबंधन प्रणाली में आप …',
        optionsEn: [
          'Message other sellers',
          'Chat with buyers directly',
          'Raise and track requests to GeM (support, change, exemption)',
        ],
        optionsHi: [
          'अन्य विक्रेताओं को संदेश भेजते हैं',
          'खरीदारों से सीधे चैट करते हैं',
          'GeM को अनुरोध (सहायता, परिवर्तन, छूट) करते और ट्रैक करते हैं',
        ],
        correctIndex: 2,
      ),
    ],
  ),
];

/// Total number of videos across every module. Computed once at startup.
final int kTotalTrainingVideos =
    kTrainingModules.fold(0, (n, m) => n + m.videos.length);

/// Find a module by id. Returns null if the id is unknown (e.g. a stale
/// deep link after a module was renamed).
TrainingModule? findTrainingModule(String id) {
  for (final m in kTrainingModules) {
    if (m.id == id) return m;
  }
  return null;
}

/// Find which module a given [videoId] belongs to, or null if it isn't in
/// any module (defensive — used for the "resume" nudge, where lastVideoId
/// might refer to a since-removed video).
TrainingModule? moduleForVideo(String videoId) {
  for (final m in kTrainingModules) {
    for (final v in m.videos) {
      if (v.videoId == videoId) return m;
    }
  }
  return null;
}

/// Find a video record anywhere in the catalogue, or null.
TrainingVideo? findTrainingVideo(String videoId) {
  for (final m in kTrainingModules) {
    for (final v in m.videos) {
      if (v.videoId == videoId) return v;
    }
  }
  return null;
}
