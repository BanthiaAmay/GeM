import 'package:flutter/material.dart';
import '../../core/tokens.dart';
import '../components.dart';
import 'search_models.dart';

/// Bottom sheet that lets the user pick a [SortOption].
class SortSheet extends StatelessWidget {
  final SortOption current;
  final ValueChanged<SortOption> onSelected;
  final bool isHindi;

  const SortSheet({
    super.key,
    required this.current,
    required this.onSelected,
    this.isHindi = false,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.xxl,
              AppSpace.sm,
              AppSpace.xxl,
              AppSpace.xxl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isHindi ? 'क्रम से लगाएँ' : 'Sort by',
                  style: AppText.h3,
                ),
                const SizedBox(height: AppSpace.lg),
                for (final option in SortOption.values)
                  InkWell(
                    borderRadius: AppRadius.card,
                    onTap: () {
                      Navigator.pop(context);
                      onSelected(option);
                    },
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: AppSize.tap),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              isHindi ? option.labelHi : option.labelEn,
                              style: AppText.body,
                            ),
                          ),
                          if (option == current)
                            const Icon(
                              Icons.check,
                              size: AppIconSize.md,
                              color: AppColors.brand,
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
