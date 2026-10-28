/// Core data types for universal search — pure Dart, no Flutter imports.
library;

import '../../data/sample_bids.dart';

enum SearchType {
  bid,
  tool,
  lesson,
  finance,
  calculator,
  document,
  faq,
  myData,
  category,
}

/// One result returned by the search engine.
class SearchItem {
  final String id;
  final SearchType type;
  final String titleEn;
  final String titleHi;
  final String subtitleEn;
  final String subtitleHi;

  /// Keywords used by the engine (not shown in UI).
  final List<String> keywords;

  /// Named route to navigate to when tapped.
  final String route;

  /// Optional argument for the route (e.g. bid id, tool id).
  final String? routeArg;

  /// Primary action label for this result.
  final String actionEn;
  final String actionHi;

  /// Relevance score set by the engine (higher = better). 0–100.
  final double score;

  const SearchItem({
    required this.id,
    required this.type,
    required this.titleEn,
    required this.titleHi,
    required this.subtitleEn,
    required this.subtitleHi,
    required this.keywords,
    required this.route,
    this.routeArg,
    required this.actionEn,
    required this.actionHi,
    this.score = 0,
  });
}

/// Sort options for the results list.
enum SortOption {
  bestMatch,
  closingSoon,
  highestValue,
  newest;

  String get labelEn => switch (this) {
    SortOption.bestMatch => 'Best match',
    SortOption.closingSoon => 'Closing soon',
    SortOption.highestValue => 'Highest value',
    SortOption.newest => 'Newest',
  };

  String get labelHi => switch (this) {
    SortOption.bestMatch => 'सर्वोत्तम मिलान',
    SortOption.closingSoon => 'जल्द बंद होने वाले',
    SortOption.highestValue => 'सर्वाधिक मूल्य',
    SortOption.newest => 'नए',
  };
}

/// Scope tabs on the search page.
enum SearchScope { all, bids, tools, learn, finance, myData }

extension SearchScopeLabel on SearchScope {
  String get labelEn => switch (this) {
    SearchScope.all => 'All',
    SearchScope.bids => 'Bids',
    SearchScope.tools => 'Tools',
    SearchScope.learn => 'Learn',
    SearchScope.finance => 'Finance',
    SearchScope.myData => 'My data',
  };

  String get labelHi => switch (this) {
    SearchScope.all => 'सभी',
    SearchScope.bids => 'बोलियाँ',
    SearchScope.tools => 'टूल',
    SearchScope.learn => 'सीखें',
    SearchScope.finance => 'वित्त',
    SearchScope.myData => 'मेरा डेटा',
  };

  SearchType? get typeFilter => switch (this) {
    SearchScope.all => null,
    SearchScope.bids => SearchType.bid,
    SearchScope.tools => SearchType.tool,
    SearchScope.learn => SearchType.lesson,
    SearchScope.finance => SearchType.finance,
    SearchScope.myData => SearchType.myData,
  };
}

/// Active bid-list filter state.
class BidFilter {
  final String? state;
  final String? district;
  final int? maxValueRs;
  final int? closingInDays;
  final bool? mseRelaxation;
  final bool? emdExemption;
  final bool? startupRelaxation;
  final String? category;
  final String? department;

  const BidFilter({
    this.state,
    this.district,
    this.maxValueRs,
    this.closingInDays,
    this.mseRelaxation,
    this.emdExemption,
    this.startupRelaxation,
    this.category,
    this.department,
  });

  bool get hasAny =>
      state != null ||
      district != null ||
      maxValueRs != null ||
      closingInDays != null ||
      mseRelaxation != null ||
      emdExemption != null ||
      startupRelaxation != null ||
      category != null ||
      department != null;

  const BidFilter.empty()
    : state = null,
      district = null,
      maxValueRs = null,
      closingInDays = null,
      mseRelaxation = null,
      emdExemption = null,
      startupRelaxation = null,
      category = null,
      department = null;

  // Sentinel value — allows copyWith to distinguish "keep current" from "set null".
  static const Object _keep = Object();

  BidFilter copyWith({
    Object? state = _keep,
    Object? district = _keep,
    Object? maxValueRs = _keep,
    Object? closingInDays = _keep,
    Object? mseRelaxation = _keep,
    Object? emdExemption = _keep,
    Object? startupRelaxation = _keep,
    Object? category = _keep,
    Object? department = _keep,
  }) {
    T? resolve<T>(Object? arg, T? current) =>
        identical(arg, _keep) ? current : arg as T?;
    return BidFilter(
      state: resolve(state, this.state),
      district: resolve(district, this.district),
      maxValueRs: resolve(maxValueRs, this.maxValueRs),
      closingInDays: resolve(closingInDays, this.closingInDays),
      mseRelaxation: resolve(mseRelaxation, this.mseRelaxation),
      emdExemption: resolve(emdExemption, this.emdExemption),
      startupRelaxation: resolve(startupRelaxation, this.startupRelaxation),
      category: resolve(category, this.category),
      department: resolve(department, this.department),
    );
  }

  /// Returns true when [bid] satisfies every active filter criterion.
  bool matches(SampleBid bid) {
    if (state != null && bid.state?.toLowerCase() != state!.toLowerCase()) {
      return false;
    }
    if (district != null &&
        bid.district?.toLowerCase() != district!.toLowerCase()) {
      return false;
    }
    if (maxValueRs != null && bid.valueRs > maxValueRs!) {
      return false;
    }
    if (closingInDays != null &&
        (bid.closesInDays < 0 || bid.closesInDays > closingInDays!)) {
      return false;
    }
    if (mseRelaxation == true && !bid.mseRelaxation) {
      return false;
    }
    if (emdExemption == true && !bid.emdExemption) {
      return false;
    }
    if (startupRelaxation == true && !bid.startupRelaxation) {
      return false;
    }
    if (category != null && bid.category != category) {
      return false;
    }
    if (department != null &&
        !(bid.department?.toLowerCase().contains(department!.toLowerCase()) ??
            false)) {
      return false;
    }
    return true;
  }
}
