/// The escape character declared to drift's `like()` calls alongside
/// [likePattern] -- SQLite's `LIKE` has no default one, so without this a
/// backslash in the pattern is just a literal character and `%` or `_`
/// typed by the user still act as wildcards.
///
/// Shared by `NotesRepository` and `TasksRepository`'s `search()`, the only
/// two places in the app that build a `LIKE` pattern from user input.
const likeEscapeChar = r'\';

/// Wraps [q] as a substring match, escaping `%` and `_` -- SQLite's
/// multi-character and single-character `LIKE` wildcards -- and the escape
/// character itself, so a literal occurrence of any of the three in the
/// query matches only itself. Pass [likeEscapeChar] as the `escapeChar` to
/// drift's `like()`.
String likePattern(String q) => '%${_escapeLike(q)}%';

String _escapeLike(String q) => q
    .replaceAll(likeEscapeChar, likeEscapeChar * 2)
    .replaceAll('%', '$likeEscapeChar%')
    .replaceAll('_', '${likeEscapeChar}_');
