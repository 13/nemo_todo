// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class LEn extends L {
  LEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'nemo todo';

  @override
  String get commonSave => 'Save';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonUndo => 'Undo';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonClose => 'Close';

  @override
  String get commonAdd => 'Add';

  @override
  String get commonOk => 'OK';

  @override
  String get navToday => 'Today';

  @override
  String get navUpcoming => 'Upcoming';

  @override
  String get navLists => 'Lists';

  @override
  String get navSearch => 'Search';

  @override
  String get navNotes => 'Notes';

  @override
  String get navSettings => 'Settings';

  @override
  String get todayOverdue => 'Overdue';

  @override
  String get todayDoneToday => 'Done today';

  @override
  String get todayEmpty => 'Nothing due today. Enjoy the calm.';

  @override
  String get upcomingLater => 'Later';

  @override
  String get upcomingEmpty =>
      'No upcoming tasks. Add a due date to see tasks here.';

  @override
  String get listsTitle => 'Lists';

  @override
  String get listsInbox => 'Inbox';

  @override
  String get listsNewList => 'New list';

  @override
  String get listsEditList => 'Edit list';

  @override
  String get listsName => 'Name';

  @override
  String get listsNameHint => 'e.g. Groceries';

  @override
  String get listsColor => 'Colour';

  @override
  String get listsIcon => 'Icon';

  @override
  String listsDeleteConfirm(String name) {
    return 'Delete \"$name\" and all its tasks?';
  }

  @override
  String get listsDeleted => 'List deleted';

  @override
  String get listsShared => 'Shared';

  @override
  String get listsMembers => 'Members';

  @override
  String listsOpenCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count open tasks',
      one: '1 open task',
      zero: 'No open tasks',
    );
    return '$_temp0';
  }

  @override
  String get listsEmpty => 'Create a list to group your tasks.';

  @override
  String get tasksAddHint => 'Add a task';

  @override
  String get tasksOpen => 'Open';

  @override
  String tasksCompleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count completed',
      one: '1 completed',
    );
    return '$_temp0';
  }

  @override
  String get tasksEmptyList => 'No tasks yet. Add one below.';

  @override
  String get tasksTitleHint => 'Title';

  @override
  String get tasksNotesHint => 'Notes';

  @override
  String get tasksDue => 'Due';

  @override
  String get tasksNoDue => 'No date';

  @override
  String get tasksTime => 'Time';

  @override
  String get tasksNoTime => 'All day';

  @override
  String get tasksRemind => 'Remind me';

  @override
  String get tasksRemindUnavailable =>
      'Reminders are only available in the Android app.';

  @override
  String get tasksPriority => 'Priority';

  @override
  String get priorityNone => 'None';

  @override
  String get priorityLow => 'Low';

  @override
  String get priorityMedium => 'Medium';

  @override
  String get priorityHigh => 'High';

  @override
  String get tasksTags => 'Tags';

  @override
  String get tasksTagsHint => 'Add tag';

  @override
  String get tasksSubtasks => 'Subtasks';

  @override
  String get tasksSubtaskHint => 'Add subtask';

  @override
  String get tasksPhotos => 'Photos';

  @override
  String get photosTakePhoto => 'Take photo';

  @override
  String get photosChoose => 'Choose from gallery';

  @override
  String get photosAdd => 'Add photo';

  @override
  String get photosNotAnImage => 'That file is not a picture.';

  @override
  String get photosTooLarge => 'That picture is too large for this server.';

  @override
  String get photosServerFull => 'The server has no room for more pictures.';

  @override
  String photosPhoto(int index, int count) {
    return 'Photo $index of $count';
  }

  @override
  String get photosNotUploaded => 'Not uploaded yet';

  @override
  String get tasksList => 'List';

  @override
  String get tasksDeleteConfirm => 'Delete this task?';

  @override
  String get tasksDeleted => 'Task deleted';

  @override
  String get tasksCompletedSnack => 'Task completed';

  @override
  String get tasksNotFound => 'This task no longer exists.';

  @override
  String get tasksClearDue => 'Clear date';

  @override
  String get dateToday => 'Today';

  @override
  String get dateTomorrow => 'Tomorrow';

  @override
  String get dateYesterday => 'Yesterday';

  @override
  String dateInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'In $count days',
      one: 'In 1 day',
    );
    return '$_temp0';
  }

  @override
  String dateDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String get searchHint => 'Search tasks, notes and tags';

  @override
  String get searchTasksHeader => 'Tasks';

  @override
  String get searchNotesHeader => 'Notes';

  @override
  String get searchEmpty => 'Type to search across all lists.';

  @override
  String searchNoResults(String query) {
    return 'No tasks match \"$query\".';
  }

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get settingsAccount => 'Account';

  @override
  String get settingsNotConnected =>
      'Not connected. Your data stays on this device.';

  @override
  String get settingsConnect => 'Connect to a server';

  @override
  String settingsConnectedAs(String username, String server) {
    return 'Signed in as $username on $server';
  }

  @override
  String get settingsSignOut => 'Sign out';

  @override
  String get settingsSignOutConfirm =>
      'Sign out? Your tasks stay on this device and stop syncing.';

  @override
  String get settingsSignOutConfirmWeb =>
      'Sign out? This browser forgets your tasks; they stay on your server.';

  @override
  String get settingsChangePassword => 'Change password';

  @override
  String get settingsCurrentPassword => 'Current password';

  @override
  String get settingsNewPassword => 'New password';

  @override
  String get settingsPasswordChanged =>
      'Password changed. Your other devices have been signed out.';

  @override
  String get settingsDeleteAccount => 'Delete account';

  @override
  String settingsDeleteAccountConfirm(String server) {
    return 'This deletes your account on $server. Lists only you use are deleted with it, and each shared list you own goes to another member. This cannot be undone.';
  }

  @override
  String get settingsDeleteAccountKeeps => 'Your tasks stay on this device.';

  @override
  String get settingsDeleteAccountWipes =>
      'This browser forgets your tasks too.';

  @override
  String get settingsAccountDeleted => 'Account deleted.';

  @override
  String get accountErrorWrongPassword => 'That is not your password.';

  @override
  String get settingsSync => 'Sync';

  @override
  String get settingsSyncNow => 'Sync now';

  @override
  String settingsLastSync(String time) {
    return 'Last synced $time';
  }

  @override
  String get settingsNeverSynced => 'Not synced yet';

  @override
  String settingsPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes waiting',
      one: '1 change waiting',
      zero: 'Everything is synced',
    );
    return '$_temp0';
  }

  @override
  String get settingsSyncing => 'Syncing…';

  @override
  String settingsSyncError(String error) {
    return 'Sync failed: $error';
  }

  @override
  String get settingsOffline =>
      'Offline. Changes will sync when you are back online.';

  @override
  String get settingsSignedOutRemotely =>
      'Your session expired. Sign in again to keep syncing.';

  @override
  String settingsDiscarded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes were rejected by the server and reverted.',
      one: '1 change was rejected by the server and reverted.',
    );
    return '$_temp0';
  }

  @override
  String get settingsCertificateUntrusted =>
      'This device does not trust the certificate this server offered.';

  @override
  String get settingsCertificateReview => 'Review';

  @override
  String settingsVersions(String app, String server) {
    return 'App $app · Server $server';
  }

  @override
  String get settingsServerNewer =>
      'This page is older than the server. Reload to get the current build.';

  @override
  String get settingsAbout => 'About';

  @override
  String settingsVersion(String version) {
    return 'Version $version';
  }

  @override
  String get settingsCelebrations => 'Celebrations & achievements';

  @override
  String get settingsCelebrationsEnabled => 'Celebrations';

  @override
  String get settingsCelebrationsEnabledHint =>
      'Confetti, animations and haptics when you complete tasks';

  @override
  String get settingsCelebrationSound => 'Sound';

  @override
  String get settingsCelebrationSoundHint => 'Play a sound for big moments';

  @override
  String get settingsAchievements => 'Achievements';

  @override
  String get settingsAchievementsHint => 'Show achievements and unlock banners';

  @override
  String get achievementsView => 'View achievements';

  @override
  String get accountSignInAction => 'Sign in to your server';

  @override
  String get accountWebNotice =>
      'nemo keeps your tasks on this server. Sign in to see them.';

  @override
  String get accountCertificateTitle => 'Trust this server\'s certificate?';

  @override
  String accountCertificateBody(String host) {
    return '$host identifies itself with a certificate this device cannot check. Compare the fingerprint with your server before you accept it.';
  }

  @override
  String get accountCertificateIssuer => 'Issued by';

  @override
  String get accountCertificateExpires => 'Valid until';

  @override
  String get accountCertificateFingerprint => 'SHA-256 fingerprint';

  @override
  String get accountCertificateTrust => 'Trust and connect';

  @override
  String get accountErrorCertificate =>
      'This device does not trust that server\'s certificate.';

  @override
  String get accountTitle => 'Connect';

  @override
  String get accountServer => 'Server address';

  @override
  String get accountServerHint => 'https://nemo.example.com';

  @override
  String get accountUsername => 'Username';

  @override
  String get accountPassword => 'Password';

  @override
  String get accountSignIn => 'Sign in';

  @override
  String get accountSignUp => 'Create account';

  @override
  String get accountLocalNotice =>
      'Your existing tasks will be uploaded to this account.';

  @override
  String get accountErrorInvalidCredentials => 'Wrong username or password.';

  @override
  String get accountErrorSignupDisabled =>
      'This server does not allow new accounts.';

  @override
  String get accountErrorUsernameTaken => 'That username is taken.';

  @override
  String get accountErrorInvalidUsername =>
      'Use 3–32 lowercase letters, digits, dots, dashes or underscores.';

  @override
  String get accountErrorWeakPassword => 'Use at least 8 characters.';

  @override
  String get accountErrorNetwork => 'Could not reach the server.';

  @override
  String get accountErrorTooMany => 'Too many attempts. Try again in a minute.';

  @override
  String accountErrorGeneric(String code) {
    return 'Something went wrong ($code).';
  }

  @override
  String get accountInvalidUrl => 'Enter a valid http(s) address.';

  @override
  String get membersTitle => 'Members';

  @override
  String get membersAddHint => 'Username';

  @override
  String get membersOwner => 'Owner';

  @override
  String get membersEditor => 'Editor';

  @override
  String membersRemoveConfirm(String name) {
    return 'Remove $name from this list?';
  }

  @override
  String get membersOfflineNotice =>
      'Sharing needs a connection to your server.';

  @override
  String get membersNotConnected => 'Connect to a server to share lists.';

  @override
  String get membersOnlyOwner => 'Only the owner can change members.';

  @override
  String get membersYou => 'you';

  @override
  String get membersErrorUnknownUser => 'No user with that name.';

  @override
  String get remindersChannelName => 'Reminders';

  @override
  String get remindersChannelDescription => 'Notifications when a task is due';

  @override
  String get remindersDueNow => 'Due now';

  @override
  String get startupErrorTitle => 'nemo cannot open its database';

  @override
  String get startupErrorBody =>
      'Your tasks are stored on this device. If you are using a private window or have blocked site data for this page, allow it and reload.';

  @override
  String get updatesTitle => 'Updates';

  @override
  String updatesCurrentVersion(String version) {
    return 'You have version $version';
  }

  @override
  String get updatesCheckNow => 'Check for updates';

  @override
  String get updatesChecking => 'Checking…';

  @override
  String get updatesUpToDate => 'nemo is up to date';

  @override
  String updatesAvailable(String version) {
    return 'Version $version is available';
  }

  @override
  String get updatesWhatsNew => 'What\'s new';

  @override
  String get updatesDownload => 'Download';

  @override
  String updatesDownloading(int percent) {
    return 'Downloading… $percent%';
  }

  @override
  String get updatesInstall => 'Install';

  @override
  String get updatesInstallHint =>
      'Android will ask you to confirm the install.';

  @override
  String get updatesLater => 'Later';

  @override
  String get updatesErrorNetwork => 'Could not reach GitHub.';

  @override
  String get updatesErrorRateLimited =>
      'GitHub is rate limiting; try again later.';

  @override
  String get updatesErrorNotFound =>
      'No download for this device in that release.';

  @override
  String get updatesErrorMalformed =>
      'That download did not match its checksum.';

  @override
  String get tasksRepeat => 'Repeats';

  @override
  String get tasksRepeatNeedsDue =>
      'A repeating task needs a due date to count from.';

  @override
  String get repeatNever => 'Never';

  @override
  String get repeatDaily => 'Daily';

  @override
  String get repeatWeekly => 'Weekly';

  @override
  String get repeatMonthly => 'Monthly';

  @override
  String get repeatYearly => 'Yearly';

  @override
  String get membersMakeOwner => 'Make owner';

  @override
  String membersMakeOwnerConfirm(String name) {
    return 'Hand this list to $name? They can then rename it, delete it and change who it is shared with. You stay on as an editor.';
  }

  @override
  String get membersErrorNotMember => 'Share the list with them first.';

  @override
  String get tasksNoSelection => 'Pick a task to see it here.';

  @override
  String get repeatWeekdays => 'Weekdays';

  @override
  String get repeatFortnightly => 'Every 2 weeks';

  @override
  String repeatLastWeekday(String weekday) {
    return 'Last $weekday of the month';
  }

  @override
  String get repeatCustom => 'Custom…';

  @override
  String get repeatCustomTitle => 'Custom repeat';

  @override
  String get repeatModeInterval => 'Interval';

  @override
  String get repeatModeWeekday => 'Weekday of the month';

  @override
  String get repeatEvery => 'Every';

  @override
  String get repeatUnitDays => 'days';

  @override
  String get repeatUnitWeeks => 'weeks';

  @override
  String get repeatUnitMonths => 'months';

  @override
  String get repeatUnitYears => 'years';

  @override
  String repeatEveryDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $count days',
      one: 'Daily',
    );
    return '$_temp0';
  }

  @override
  String repeatEveryWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $count weeks',
      one: 'Weekly',
    );
    return '$_temp0';
  }

  @override
  String repeatEveryMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $count months',
      one: 'Monthly',
    );
    return '$_temp0';
  }

  @override
  String repeatEveryYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $count years',
      one: 'Yearly',
    );
    return '$_temp0';
  }

  @override
  String repeatNthWeekday(String ordinal, String weekday) {
    String _temp0 = intl.Intl.selectLogic(ordinal, {
      'first': 'First',
      'second': 'Second',
      'third': 'Third',
      'fourth': 'Fourth',
      'other': 'Last',
    });
    return '$_temp0 $weekday of the month';
  }

  @override
  String repeatOrdinal(String ordinal) {
    String _temp0 = intl.Intl.selectLogic(ordinal, {
      'first': 'first',
      'second': 'second',
      'third': 'third',
      'fourth': 'fourth',
      'other': 'last',
    });
    return '$_temp0';
  }

  @override
  String get settingsData => 'Your data';

  @override
  String get settingsExport => 'Export tasks';

  @override
  String get settingsExportHint =>
      'Lists, tasks, subtasks and photos as a zip file.';

  @override
  String get settingsImport => 'Import tasks';

  @override
  String get settingsImportHint =>
      'Adds what a nemo export holds and this device does not.';

  @override
  String get settingsExported => 'Tasks exported.';

  @override
  String settingsImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items imported.',
      one: '1 item imported.',
      zero: 'Nothing new to import.',
    );
    return '$_temp0';
  }

  @override
  String get settingsImportInvalid => 'That file is not a nemo export.';

  @override
  String aboutBuild(String channel) {
    String _temp0 = intl.Intl.selectLogic(channel, {
      'release': 'Release build',
      'main': 'Development build',
      'other': 'Local build',
    });
    return '$_temp0';
  }

  @override
  String aboutBuildNumbered(String channel, String number) {
    String _temp0 = intl.Intl.selectLogic(channel, {
      'release': 'Release build $number',
      'main': 'Development build $number',
      'other': 'Local build $number',
    });
    return '$_temp0';
  }

  @override
  String aboutServerBuild(String details) {
    return 'Server $details';
  }

  @override
  String get aboutCopyDetails => 'Copy details';

  @override
  String get aboutCopied => 'Details copied.';

  @override
  String get aboutSourceCode => 'Source code';

  @override
  String get aboutLegalese =>
      'Local-first tasks, synced with a server you host yourself.';

  @override
  String tagEmpty(String tag) {
    return 'No tasks tagged #$tag.';
  }

  @override
  String get rescheduleTitle => 'Move to';

  @override
  String get rescheduleNextWeek => 'Next week';

  @override
  String get reschedulePick => 'Pick a date…';

  @override
  String rescheduleMoved(String when) {
    return 'Moved to $when.';
  }

  @override
  String get rescheduleCleared => 'Date cleared.';

  @override
  String get tasksAddHintSmart => 'Add a task — try “tomorrow #shop !high”';

  @override
  String get achievementFirstDoneTitle => 'First step';

  @override
  String get achievementFirstDoneDescription => 'Complete your first task';

  @override
  String get achievementDone10Title => 'Getting going';

  @override
  String get achievementDone10Description => 'Complete 10 tasks';

  @override
  String get achievementDone100Title => 'Centurion';

  @override
  String get achievementDone100Description => 'Complete 100 tasks';

  @override
  String get achievementDone500Title => 'Unstoppable';

  @override
  String get achievementDone500Description => 'Complete 500 tasks';

  @override
  String get achievementStreak3Title => 'On a roll';

  @override
  String get achievementStreak3Description => 'Complete a task 3 days in a row';

  @override
  String get achievementStreak7Title => 'Week warrior';

  @override
  String get achievementStreak7Description => 'Complete a task 7 days in a row';

  @override
  String get achievementStreak30Title => 'Habit formed';

  @override
  String get achievementStreak30Description =>
      'Complete a task 30 days in a row';

  @override
  String get achievementClearedTodayTitle => 'Clean slate';

  @override
  String get achievementClearedTodayDescription =>
      'Finish everything due today';

  @override
  String get achievementOnTime25Title => 'Punctual';

  @override
  String get achievementOnTime25Description =>
      'Complete 25 tasks before they are due';

  @override
  String get achievementChecklist5Title => 'Checklist master';

  @override
  String get achievementChecklist5Description =>
      'Complete a task with 5 or more subtasks';

  @override
  String get achievementsTitle => 'Achievements';

  @override
  String achievementsUnlockedCount(int unlocked, int total) {
    return '$unlocked of $total unlocked';
  }

  @override
  String achievementsProgress(int value, int target) {
    return '$value / $target';
  }

  @override
  String get achievementsUnlocked => 'Unlocked';

  @override
  String achievementsStreak(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count-day streak',
      one: '1-day streak',
    );
    return '$_temp0';
  }

  @override
  String get achievementsLoadError => 'Achievements could not be loaded.';

  @override
  String get achievementUnlockedBanner => 'Achievement unlocked';

  @override
  String achievementsUnlockedMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count achievements unlocked',
    );
    return '$_temp0';
  }

  @override
  String settingsExportedWithoutPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Tasks exported. $count photos are not on this device and were left out.',
      one: 'Tasks exported. 1 photo is not on this device and was left out.',
    );
    return '$_temp0';
  }

  @override
  String get notesEmpty =>
      'No notes yet. A note keeps what a task cannot: the recipe, the address, the paragraph.';

  @override
  String get noteNewTitle => 'New note';

  @override
  String get noteTitleHint => 'Title';

  @override
  String get noteBodyHint => 'Write something';

  @override
  String get notePreviewEmpty => 'Empty note';

  @override
  String get noteNotFound => 'This note is no longer here.';

  @override
  String get noteEditToggle => 'Edit';

  @override
  String get noteReadToggle => 'Done';

  @override
  String get notePinned => 'Pin';

  @override
  String get noteUnpin => 'Unpin';

  @override
  String get noteDeleted => 'Delete';

  @override
  String get noteMoveToList => 'Move to list';
}
