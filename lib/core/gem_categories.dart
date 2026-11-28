import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class GemIndustry {
  final String name;
  const GemIndustry(this.name);
}

class GemCategory {
  final String name;
  final String industry;
  final String quadrant;
  final String link;
  const GemCategory({
    required this.name,
    required this.industry,
    required this.quadrant,
    required this.link,
  });
}

const kOtherIndustry = 'Other';
const kOtherCategory = 'Other';

class GemCategoryData {
  final List<String> industries;
  final List<GemCategory> categories;

  const GemCategoryData({required this.industries, required this.categories});

  List<GemCategory> categoriesFor(String industry) =>
      categories.where((c) => c.industry == industry).toList();

  static Future<GemCategoryData> load() async {
    // Read uncached: it is needed once per onboarding, and a cached load can
    // never settle under widget tests' fake clock.
    final raw = await rootBundle.loadString(
      'assets/data/gem_categories.json',
      cache: false,
    );
    final map = json.decode(raw) as Map<String, dynamic>;
    final industries = List<String>.from(map['industries'] as List);
    final categories = (map['categories'] as List)
        .map((e) => GemCategory(
              name: (e['name'] as String?) ?? '',
              industry: (e['industry'] as String?) ?? '',
              quadrant: (e['quadrant'] as String?) ?? '',
              link: (e['link'] as String?) ?? '',
            ))
        .toList();
    return GemCategoryData(industries: industries, categories: categories);
  }
}

List<String> filterItems(List<String> items, String query) {
  if (query.isEmpty) return items;
  final q = query.toLowerCase();
  return items.where((s) => s.toLowerCase().contains(q)).toList();
}

List<GemCategory> filterCategories(List<GemCategory> cats, String query) {
  if (query.isEmpty) return cats;
  final q = query.toLowerCase();
  return cats.where((c) => c.name.toLowerCase().contains(q)).toList();
}
