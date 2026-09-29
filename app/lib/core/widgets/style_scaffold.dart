import 'package:flutter/material.dart';
import 'package:nemo/core/theme/app_style.dart';

/// A main screen's frame, as its style draws one.
///
/// nemo and macOS: [appBar] over [body], as it always was. The Material
/// style: Android's large top app bar, [title] big above the content and
/// folding into the bar as it scrolls, or -- given a [searchBar], as on the
/// home screen -- the search bar on top, with the title below it as the
/// first thing on the page, the way Gmail and Keep lay out theirs.
///
/// [body] keeps its own scroll view; a [NestedScrollView] ties its scrolling
/// to the bar's, so no screen has to be rebuilt out of slivers.
class StyleScaffold extends StatelessWidget {
  const StyleScaffold({
    required this.appBar,
    required this.title,
    required this.body,
    this.actions = const [],
    this.leading,
    this.titleColor,
    this.belowTitle,
    this.searchBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    super.key,
  });

  /// The bar nemo and macOS draw.
  final PreferredSizeWidget appBar;

  final String title;
  final Widget body;

  /// The Material bar's actions and leading button.
  final List<Widget> actions;
  final Widget? leading;

  /// A colour for [title], as a list's page takes its list's.
  final Color? titleColor;

  /// A line under the title in the Material style, like Today's date.
  final Widget? belowTitle;

  /// Material's search bar, which then takes the top of the screen.
  final Widget? searchBar;

  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    if (context.appStyle != AppStyle.material) {
      return Scaffold(
        appBar: appBar,
        body: body,
        bottomNavigationBar: bottomNavigationBar,
        floatingActionButton: floatingActionButton,
      );
    }
    final text = Theme.of(context).textTheme;
    final search = searchBar;
    final header = search == null
        ? <Widget>[
            SliverAppBar.large(
              key: const Key('large-app-bar'),
              leading: leading,
              title: Text(title, style: TextStyle(color: titleColor)),
              actions: actions,
            ),
            if (belowTitle != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: belowTitle,
                ),
              ),
          ]
        : <Widget>[
            SliverAppBar(
              floating: true,
              snap: true,
              toolbarHeight: 72,
              titleSpacing: 16,
              automaticallyImplyLeading: false,
              title: search,
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      key: const Key('page-title'),
                      style: text.headlineMedium?.copyWith(color: titleColor),
                    ),
                    ?belowTitle,
                  ],
                ),
              ),
            ),
          ];
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => header,
        body: body,
      ),
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
    );
  }
}
