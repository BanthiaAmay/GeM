/// Builds the in-memory search index from the app's static content.
///
/// Index is rebuilt lazily once per session — no cross-session cache because
/// it is fast (< 5 ms) and the source data is constant at runtime.
library;

import '../../features/tools_hub/tool_registry.dart';
import 'bid_source.dart';
import 'search_content.dart';
import 'search_models.dart';

class SearchIndex {
  SearchIndex._();

  static SearchIndex? _instance;
  static SearchIndex get instance => _instance ??= SearchIndex._()..build();

  /// Test-only factory — inject a custom item list without the full pipeline.
  static SearchIndex withItems(List<SearchItem> items) {
    final idx = SearchIndex._();
    idx._items.addAll(items);
    return idx;
  }

  final List<SearchItem> _items = [];

  List<SearchItem> get items => List.unmodifiable(_items);

  void build() {
    _items.clear();
    _addBids();
    _addTools();
    _addLessons();
    _addFinanceItems();
    _addCalculators();
    _addCategories();
    _addFaqs();
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

  void _addLessons() => _items.addAll(kLessons);

  void _addFinanceItems() => _items.addAll(kFinanceItems);

  void _addCalculators() => _items.addAll(kCalculators);

  void _addCategories() => _items.addAll(kCategories);

  void _addFaqs() => _items.addAll(kFaqs);
}
