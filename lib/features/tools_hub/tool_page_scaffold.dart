/// The one screen frame for every tool page, matching the app concept:
/// frosted top bar with back chevron · centered title · optional action icon,
/// scrolling body (24 gutter, max 720), optional pinned bottom action bar.
///
/// `_DrawerPageScaffold` (drawer_pages.dart) and `_InsightsScaffold`
/// (insights_page.dart) are private copies of the same frame; they can be
/// migrated to this later (not part of this change).
library;

import 'package:flutter/material.dart';

import '../../core/tokens.dart';
import '../../data/app_store.dart';
import '../components.dart';
import '../glass.dart';
import '../scroll_hint.dart';

class ToolPageScaffold extends StatelessWidget {
  final AppStore store;
  final String title;

  /// Optional icon button at the top-right (e.g. reset, bookmark, share).
  final Widget? action;

  /// Pinned above the bottom edge in a frosted bar — put the screen's one
  /// primary [AppButton] (and at most one secondary) here.
  final Widget? bottomBar;
  final List<Widget> children;

  /// When provided, this controller is used for the scroll view instead of
  /// the one owned by [ScrollMoreHint], so callers can programmatically
  /// scroll (e.g. jump to top after a state transition).
  final ScrollController? scrollController;

  const ToolPageScaffold({
    super.key,
    required this.store,
    required this.title,
    required this.children,
    this.action,
    this.bottomBar,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.surface,
    body: SafeArea(
      child: Column(
        children: [
          GlassBar.top(
            padding: const EdgeInsets.all(AppSpace.sm),
            child: Row(
              children: [
                AppIconButton(
                  icon: Icons.arrow_back_ios_new,
                  tooltip: store.t('Back', 'वापस'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: AppText.title,
                    ),
                  ),
                ),
                SizedBox(width: AppSize.tap, child: action),
              ],
            ),
          ),
          Expanded(
            child: ScrollMoreHint(
              controller: scrollController,
              builder: (context, controller) => SingleChildScrollView(
                controller: controller,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  AppSpace.gutter,
                  AppSpace.lg,
                  AppSpace.gutter,
                  bottomBar == null ? 80 : AppSpace.xxl,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: children,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (bottomBar != null)
            GlassBar.bottom(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: bottomBar!,
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
