/// Bid-feed abstraction: swap [SampleBidSource] for a live GeM feed and the
/// search UI stays unchanged. Every caller must display "Illustrative data"
/// until a live source is in place.
library;

import '../../data/sample_bids.dart';
import 'search_models.dart';

abstract class BidSource {
  /// All bids available for local search. Must be purely in-memory — no HTTP.
  List<SampleBid> get bids;
}

/// Serves [kNamedBids] — the curated illustrative set. All results from this
/// source must be labelled "Illustrative data" in the UI.
class SampleBidSource implements BidSource {
  const SampleBidSource();

  @override
  List<SampleBid> get bids => kNamedBids;

  SearchItem bidToItem(SampleBid bid) => SearchItem(
    id: bid.id,
    type: SearchType.bid,
    titleEn: bid.displayTitle,
    titleHi: bid.titleHi ?? bid.displayTitle,
    subtitleEn: [
      if (bid.department != null) bid.department!,
      if (bid.state != null && bid.state!.isNotEmpty) bid.state!,
    ].join(' · '),
    subtitleHi: [
      if (bid.department != null) bid.department!,
      if (bid.state != null && bid.state!.isNotEmpty) bid.state!,
    ].join(' · '),
    keywords: _bidKeywords(bid),
    route: 'bid-detail',
    routeArg: bid.id,
    actionEn: 'View bid',
    actionHi: 'बोली देखें',
    score: bid.effectiveScore.toDouble(),
  );

  static List<String> _bidKeywords(SampleBid bid) => [
    bid.category,
    if (bid.titleEn != null) bid.titleEn!.toLowerCase(),
    if (bid.titleHi != null) bid.titleHi!,
    if (bid.department != null) bid.department!.toLowerCase(),
    if (bid.state != null) bid.state!.toLowerCase(),
    if (bid.district != null) bid.district!.toLowerCase(),
    if (bid.items != null) bid.items!.toLowerCase(),
    // HSN codes enable "9405 → LED lighting" style queries
    ...bid.hsnCodes,
    // Bank-guarantee bids surface on "bank guarantee / BG" queries
    if (bid.needsBG) ...['bank', 'guarantee', 'bg', 'security', 'deposit'],
    // EMD-exempt bids surface on EMD queries
    if (bid.emdExemption) ...['emd', 'earnest', 'money', 'exemption'],
    // MSE / startup relaxation bids surface on those queries
    if (bid.mseRelaxation) ...['mse', 'msme', 'relaxation'],
    if (bid.startupRelaxation) ...['startup', 'relaxation'],
    // Certification keywords
    ...bid.requiredCertifications.map((c) => c.toLowerCase()),
  ];
}

const sampleBidSource = SampleBidSource();
