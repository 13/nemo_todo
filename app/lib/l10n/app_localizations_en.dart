// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class LEn extends L {
  LEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'nemo';

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
  String get settingsAbout => 'About';

  @override
  String settingsVersion(String version) {
    return 'Version $version';
  }

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
}
