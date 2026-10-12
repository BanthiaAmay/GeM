/// Builds the in-memory search index from the app's static content.
///
/// Index is rebuilt lazily once per session — no cross-session cache because
/// it is fast (< 5 ms) and the source data is constant at runtime.
library;

import '../../features/tools_hub/tool_registry.dart';
import 'bid_source.dart';
import 'search_models.dart';

class SearchIndex {
  SearchIndex._();

  static SearchIndex? _instance;
  static SearchIndex get instance => _instance ??= SearchIndex._()..build();

  final List<SearchItem> _items = [];

  List<SearchItem> get items => List.unmodifiable(_items);

  void build() {
    _items.clear();
    _addBids();
    _addTools();
  }

  void _addBids() {
    for (final bid in sampleBidSource.bids) {
      _items.add(sampleBidSource.bidToItem(bid));
    }
  }

  void _addTools() {
    for (final tool in kTools) {
      _items.add(
        SearchItem(
          id: tool.route,
          type: SearchType.tool,
          titleEn: tool.titleEn,
          titleHi: tool.titleHi,
          subtitleEn: tool.descriptionEn,
          subtitleHi: tool.descriptionHi,
          keywords: [
            tool.titleEn.toLowerCase(),
            tool.titleHi,
            tool.docCategory.labelEn.toLowerCase(),
            tool.docCategory.labelHi,
            ...tool.descriptionEn.toLowerCase().split(' '),
          ],
          route: tool.route,
          actionEn: 'Open',
          actionHi: 'खोलें',
        ),
      );
    }
  }
}
