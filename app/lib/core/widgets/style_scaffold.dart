import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/core/theme/app_style.dart';
import 'package:nemo/features/tasks/ui/selection_bar.dart';
import 'package:nemo/features/tasks/ui/selection_scaffold.dart';
import 'package:nemo/features/tasks/ui/task_selection.dart';

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
///
/// A screen listing tasks sets [taskSelection], and puts a
/// [SelectTasksButton] in its [appBar]'s actions; the Material bar gets
/// one from here. While picking, the [SelectionBar] takes the foot of
/// the screen on a phone -- in place of the bottom bar and the button --
/// or the top bar's place on a wide window, as [TaskSelectionScaffold]
/// lays out; leaving the screen ends the selection. The Material bar on a
/// wide window keeps its height and takes the selection bar's parts, so
/// the page under it does not jump.
class StyleScaffold extends ConsumerWidget {
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
    this.taskSelection = false,
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

  /// Whether this screen's tasks can be picked several at once.
  final bool taskSelection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selecting = taskSelection && ref.watch(taskSelectionProvider) != null;
    final onTop = selecting && SelectionBar.onTop(context);
    // Select comes first, as nemo's and macOS's bars put it.
    final actions = [
      if (taskSelection) const SelectTasksButton(),
      ...this.actions,
    ];

    if (context.appStyle != AppStyle.material) {
      return TaskSelectionScaffold(
        enabled: taskSelection,
        appBar: appBar,
        body: body,
        bottomNavigationBar: bottomNavigationBar,
        floatingActionButton: floatingActionButton,
      );
    }
    final text = Theme.of(context).textTheme;
    final search = searchBar;
    // On a wide window the selection bar stands in for the top bar: its
    // parts go into the same bar, the same height, so the page under it
    // stays where it was.
    final header = search == null
        ? <Widget>[
            if (onTop)
              SelectionBar(
                // The large title stays: the count joins the actions, as
                // the bar's own title would be drawn twice, large and small.
                topBar: (cancel, count, actions) => SliverAppBar.large(
                  key: const Key('large-app-bar'),
                  leading: cancel,
                  title: Text(title, style: TextStyle(color: titleColor)),
                  actions: [
                    Center(child: count),
                    const SizedBox(width: 8),
                    ...actions,
                  ],
                ),
              )
            else
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
            if (onTop)
              SelectionBar(
                // Floating like the search bar it stands in for, so the
                // page does not move however far it is scrolled; scrolling
                // back up brings it into view.
                topBar: (cancel, count, actions) => SliverAppBar(
                  floating: true,
                  snap: true,
                  toolbarHeight: 72,
                  automaticallyImplyLeading: false,
                  leading: cancel,
                  title: count,
                  actions: actions,
                ),
              )
            else
              SliverAppBar(
                floating: true,
                snap: true,
                toolbarHeight: 72,
                titleSpacing: 16,
                automaticallyImplyLeading: false,
                title: search,
                actions: actions,
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
    return TaskSelectionScaffold(
      enabled: taskSelection,
      bodyHasTopBar: true,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => header,
        body: body,
      ),
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
    );
  }
}
