import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_it.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of L
/// returned by `L.of(context)`.
///
/// Applications need to include `L.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: L.localizationsDelegates,
///   supportedLocales: L.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the L.supportedLocales
/// property.
abstract class L {
  L(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static L of(BuildContext context) {
    return Localizations.of<L>(context, L)!;
  }

  static const LocalizationsDelegate<L> delegate = _LDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('it'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'nemo'**
  String get appName;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get commonUndo;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get commonAdd;

  /// No description provided for @commonOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @navToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get navToday;

  /// No description provided for @navUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get navUpcoming;

  /// No description provided for @navLists.
  ///
  /// In en, this message translates to:
  /// **'Lists'**
  String get navLists;

  /// No description provided for @navSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get navSearch;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @todayOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get todayOverdue;

  /// No description provided for @todayDoneToday.
  ///
  /// In en, this message translates to:
  /// **'Done today'**
  String get todayDoneToday;

  /// No description provided for @todayEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing due today. Enjoy the calm.'**
  String get todayEmpty;

  /// No description provided for @upcomingLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get upcomingLater;

  /// No description provided for @upcomingEmpty.
  ///
  /// In en, this message translates to:
  /// **'No upcoming tasks. Add a due date to see tasks here.'**
  String get upcomingEmpty;

  /// No description provided for @listsTitle.
  ///
  /// In en, this message translates to:
  /// **'Lists'**
  String get listsTitle;

  /// No description provided for @listsInbox.
  ///
  /// In en, this message translates to:
  /// **'Inbox'**
  String get listsInbox;

  /// No description provided for @listsNewList.
  ///
  /// In en, this message translates to:
  /// **'New list'**
  String get listsNewList;

  /// No description provided for @listsEditList.
  ///
  /// In en, this message translates to:
  /// **'Edit list'**
  String get listsEditList;

  /// No description provided for @listsName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get listsName;

  /// No description provided for @listsNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Groceries'**
  String get listsNameHint;

  /// No description provided for @listsColor.
  ///
  /// In en, this message translates to:
  /// **'Colour'**
  String get listsColor;

  /// No description provided for @listsIcon.
  ///
  /// In en, this message translates to:
  /// **'Icon'**
  String get listsIcon;

  /// No description provided for @listsDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\" and all its tasks?'**
  String listsDeleteConfirm(String name);

  /// No description provided for @listsDeleted.
  ///
  /// In en, this message translates to:
  /// **'List deleted'**
  String get listsDeleted;

  /// No description provided for @listsShared.
  ///
  /// In en, this message translates to:
  /// **'Shared'**
  String get listsShared;

  /// No description provided for @listsMembers.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get listsMembers;

  /// No description provided for @listsOpenCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No open tasks} =1{1 open task} other{{count} open tasks}}'**
  String listsOpenCount(int count);

  /// No description provided for @listsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Create a list to group your tasks.'**
  String get listsEmpty;

  /// No description provided for @tasksAddHint.
  ///
  /// In en, this message translates to:
  /// **'Add a task'**
  String get tasksAddHint;

  /// No description provided for @tasksOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get tasksOpen;

  /// No description provided for @tasksCompleted.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 completed} other{{count} completed}}'**
  String tasksCompleted(int count);

  /// No description provided for @tasksEmptyList.
  ///
  /// In en, this message translates to:
  /// **'No tasks yet. Add one below.'**
  String get tasksEmptyList;

  /// No description provided for @tasksTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get tasksTitleHint;

  /// No description provided for @tasksNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get tasksNotesHint;

  /// No description provided for @tasksDue.
  ///
  /// In en, this message translates to:
  /// **'Due'**
  String get tasksDue;

  /// No description provided for @tasksNoDue.
  ///
  /// In en, this message translates to:
  /// **'No date'**
  String get tasksNoDue;

  /// No description provided for @tasksTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get tasksTime;

  /// No description provided for @tasksNoTime.
  ///
  /// In en, this message translates to:
  /// **'All day'**
  String get tasksNoTime;

  /// No description provided for @tasksRemind.
  ///
  /// In en, this message translates to:
  /// **'Remind me'**
  String get tasksRemind;

  /// No description provided for @tasksRemindUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Reminders are only available in the Android app.'**
  String get tasksRemindUnavailable;

  /// No description provided for @tasksPriority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get tasksPriority;

  /// No description provided for @priorityNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get priorityNone;

  /// No description provided for @priorityLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get priorityLow;

  /// No description provided for @priorityMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get priorityMedium;

  /// No description provided for @priorityHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get priorityHigh;

  /// No description provided for @tasksTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get tasksTags;

  /// No description provided for @tasksTagsHint.
  ///
  /// In en, this message translates to:
  /// **'Add tag'**
  String get tasksTagsHint;

  /// No description provided for @tasksSubtasks.
  ///
  /// In en, this message translates to:
  /// **'Subtasks'**
  String get tasksSubtasks;

  /// No description provided for @tasksSubtaskHint.
  ///
  /// In en, this message translates to:
  /// **'Add subtask'**
  String get tasksSubtaskHint;

  /// No description provided for @tasksList.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get tasksList;

  /// No description provided for @tasksDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this task?'**
  String get tasksDeleteConfirm;

  /// No description provided for @tasksDeleted.
  ///
  /// In en, this message translates to:
  /// **'Task deleted'**
  String get tasksDeleted;

  /// No description provided for @tasksCompletedSnack.
  ///
  /// In en, this message translates to:
  /// **'Task completed'**
  String get tasksCompletedSnack;

  /// No description provided for @tasksNotFound.
  ///
  /// In en, this message translates to:
  /// **'This task no longer exists.'**
  String get tasksNotFound;

  /// No description provided for @tasksClearDue.
  ///
  /// In en, this message translates to:
  /// **'Clear date'**
  String get tasksClearDue;

  /// No description provided for @dateToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get dateToday;

  /// No description provided for @dateTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get dateTomorrow;

  /// No description provided for @dateYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get dateYesterday;

  /// No description provided for @dateInDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{In 1 day} other{In {count} days}}'**
  String dateInDays(int count);

  /// No description provided for @dateDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day ago} other{{count} days ago}}'**
  String dateDaysAgo(int count);

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search tasks, notes and tags'**
  String get searchHint;

  /// No description provided for @searchEmpty.
  ///
  /// In en, this message translates to:
  /// **'Type to search across all lists.'**
  String get searchEmpty;

  /// No description provided for @searchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No tasks match \"{query}\".'**
  String searchNoResults(String query);

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @settingsAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsAccount;

  /// No description provided for @settingsNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected. Your data stays on this device.'**
  String get settingsNotConnected;

  /// No description provided for @settingsConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect to a server'**
  String get settingsConnect;

  /// No description provided for @settingsConnectedAs.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {username} on {server}'**
  String settingsConnectedAs(String username, String server);

  /// No description provided for @settingsSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get settingsSignOut;

  /// No description provided for @settingsSignOutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Sign out? Your tasks stay on this device and stop syncing.'**
  String get settingsSignOutConfirm;

  /// No description provided for @settingsSync.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get settingsSync;

  /// No description provided for @settingsSyncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get settingsSyncNow;

  /// No description provided for @settingsLastSync.
  ///
  /// In en, this message translates to:
  /// **'Last synced {time}'**
  String settingsLastSync(String time);

  /// No description provided for @settingsNeverSynced.
  ///
  /// In en, this message translates to:
  /// **'Not synced yet'**
  String get settingsNeverSynced;

  /// No description provided for @settingsPending.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Everything is synced} =1{1 change waiting} other{{count} changes waiting}}'**
  String settingsPending(int count);

  /// No description provided for @settingsSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get settingsSyncing;

  /// No description provided for @settingsSyncError.
  ///
  /// In en, this message translates to:
  /// **'Sync failed: {error}'**
  String settingsSyncError(String error);

  /// No description provided for @settingsOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline. Changes will sync when you are back online.'**
  String get settingsOffline;

  /// No description provided for @settingsSignedOutRemotely.
  ///
  /// In en, this message translates to:
  /// **'Your session expired. Sign in again to keep syncing.'**
  String get settingsSignedOutRemotely;

  /// No description provided for @settingsDiscarded.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 change was rejected by the server and reverted.} other{{count} changes were rejected by the server and reverted.}}'**
  String settingsDiscarded(int count);

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String settingsVersion(String version);

  /// No description provided for @accountTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get accountTitle;

  /// No description provided for @accountServer.
  ///
  /// In en, this message translates to:
  /// **'Server address'**
  String get accountServer;

  /// No description provided for @accountServerHint.
  ///
  /// In en, this message translates to:
  /// **'https://nemo.example.com'**
  String get accountServerHint;

  /// No description provided for @accountUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get accountUsername;

  /// No description provided for @accountPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get accountPassword;

  /// No description provided for @accountSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get accountSignIn;

  /// No description provided for @accountSignUp.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get accountSignUp;

  /// No description provided for @accountLocalNotice.
  ///
  /// In en, this message translates to:
  /// **'Your existing tasks will be uploaded to this account.'**
  String get accountLocalNotice;

  /// No description provided for @accountErrorInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Wrong username or password.'**
  String get accountErrorInvalidCredentials;

  /// No description provided for @accountErrorSignupDisabled.
  ///
  /// In en, this message translates to:
  /// **'This server does not allow new accounts.'**
  String get accountErrorSignupDisabled;

  /// No description provided for @accountErrorUsernameTaken.
  ///
  /// In en, this message translates to:
  /// **'That username is taken.'**
  String get accountErrorUsernameTaken;

  /// No description provided for @accountErrorInvalidUsername.
  ///
  /// In en, this message translates to:
  /// **'Use 3–32 lowercase letters, digits, dots, dashes or underscores.'**
  String get accountErrorInvalidUsername;

  /// No description provided for @accountErrorWeakPassword.
  ///
  /// In en, this message translates to:
  /// **'Use at least 8 characters.'**
  String get accountErrorWeakPassword;

  /// No description provided for @accountErrorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the server.'**
  String get accountErrorNetwork;

  /// No description provided for @accountErrorTooMany.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again in a minute.'**
  String get accountErrorTooMany;

  /// No description provided for @accountErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong ({code}).'**
  String accountErrorGeneric(String code);

  /// No description provided for @accountInvalidUrl.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid http(s) address.'**
  String get accountInvalidUrl;

  /// No description provided for @membersTitle.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get membersTitle;

  /// No description provided for @membersAddHint.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get membersAddHint;

  /// No description provided for @membersOwner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get membersOwner;

  /// No description provided for @membersEditor.
  ///
  /// In en, this message translates to:
  /// **'Editor'**
  String get membersEditor;

  /// No description provided for @membersRemoveConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove {name} from this list?'**
  String membersRemoveConfirm(String name);

  /// No description provided for @membersOfflineNotice.
  ///
  /// In en, this message translates to:
  /// **'Sharing needs a connection to your server.'**
  String get membersOfflineNotice;

  /// No description provided for @membersNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Connect to a server to share lists.'**
  String get membersNotConnected;

  /// No description provided for @membersOnlyOwner.
  ///
  /// In en, this message translates to:
  /// **'Only the owner can change members.'**
  String get membersOnlyOwner;

  /// No description provided for @membersYou.
  ///
  /// In en, this message translates to:
  /// **'you'**
  String get membersYou;

  /// No description provided for @membersErrorUnknownUser.
  ///
  /// In en, this message translates to:
  /// **'No user with that name.'**
  String get membersErrorUnknownUser;

  /// No description provided for @remindersChannelName.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get remindersChannelName;

  /// No description provided for @remindersChannelDescription.
  ///
  /// In en, this message translates to:
  /// **'Notifications when a task is due'**
  String get remindersChannelDescription;

  /// No description provided for @remindersDueNow.
  ///
  /// In en, this message translates to:
  /// **'Due now'**
  String get remindersDueNow;

  /// No description provided for @startupErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'nemo cannot open its database'**
  String get startupErrorTitle;

  /// No description provided for @startupErrorBody.
  ///
  /// In en, this message translates to:
  /// **'Your tasks are stored on this device. If you are using a private window or have blocked site data for this page, allow it and reload.'**
  String get startupErrorBody;

  /// No description provided for @updatesTitle.
  ///
  /// In en, this message translates to:
  /// **'Updates'**
  String get updatesTitle;

  /// No description provided for @updatesCurrentVersion.
  ///
  /// In en, this message translates to:
  /// **'You have version {version}'**
  String updatesCurrentVersion(String version);

  /// No description provided for @updatesCheckNow.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get updatesCheckNow;

  /// No description provided for @updatesChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get updatesChecking;

  /// No description provided for @updatesUpToDate.
  ///
  /// In en, this message translates to:
  /// **'nemo is up to date'**
  String get updatesUpToDate;

  /// No description provided for @updatesAvailable.
  ///
  /// In en, this message translates to:
  /// **'Version {version} is available'**
  String updatesAvailable(String version);

  /// No description provided for @updatesWhatsNew.
  ///
  /// In en, this message translates to:
  /// **'What\'s new'**
  String get updatesWhatsNew;

  /// No description provided for @updatesDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get updatesDownload;

  /// No description provided for @updatesDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading… {percent}%'**
  String updatesDownloading(int percent);

  /// No description provided for @updatesInstall.
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get updatesInstall;

  /// No description provided for @updatesInstallHint.
  ///
  /// In en, this message translates to:
  /// **'Android will ask you to confirm the install.'**
  String get updatesInstallHint;

  /// No description provided for @updatesLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get updatesLater;

  /// No description provided for @updatesErrorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Could not reach GitHub.'**
  String get updatesErrorNetwork;

  /// No description provided for @updatesErrorRateLimited.
  ///
  /// In en, this message translates to:
  /// **'GitHub is rate limiting; try again later.'**
  String get updatesErrorRateLimited;

  /// No description provided for @updatesErrorNotFound.
  ///
  /// In en, this message translates to:
  /// **'No download for this device in that release.'**
  String get updatesErrorNotFound;

  /// No description provided for @updatesErrorMalformed.
  ///
  /// In en, this message translates to:
  /// **'That download did not match its checksum.'**
  String get updatesErrorMalformed;

  /// No description provided for @tasksRepeat.
  ///
  /// In en, this message translates to:
  /// **'Repeats'**
  String get tasksRepeat;

  /// No description provided for @tasksRepeatNeedsDue.
  ///
  /// In en, this message translates to:
  /// **'A repeating task needs a due date to count from.'**
  String get tasksRepeatNeedsDue;

  /// No description provided for @repeatNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get repeatNever;

  /// No description provided for @repeatDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get repeatDaily;

  /// No description provided for @repeatWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get repeatWeekly;

  /// No description provided for @repeatMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get repeatMonthly;

  /// No description provided for @repeatYearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get repeatYearly;

  /// No description provided for @membersMakeOwner.
  ///
  /// In en, this message translates to:
  /// **'Make owner'**
  String get membersMakeOwner;

  /// No description provided for @membersMakeOwnerConfirm.
  ///
  /// In en, this message translates to:
  /// **'Hand this list to {name}? They can then rename it, delete it and change who it is shared with. You stay on as an editor.'**
  String membersMakeOwnerConfirm(String name);

  /// No description provided for @membersErrorNotMember.
  ///
  /// In en, this message translates to:
  /// **'Share the list with them first.'**
  String get membersErrorNotMember;

  /// No description provided for @tasksNoSelection.
  ///
  /// In en, this message translates to:
  /// **'Pick a task to see it here.'**
  String get tasksNoSelection;
}

class _LDelegate extends LocalizationsDelegate<L> {
  const _LDelegate();

  @override
  Future<L> load(Locale locale) {
    return SynchronousFuture<L>(lookupL(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en', 'it'].contains(locale.languageCode);

  @override
  bool shouldReload(_LDelegate old) => false;
}

L lookupL(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return LDe();
    case 'en':
      return LEn();
    case 'it':
      return LIt();
  }

  throw FlutterError(
    'L.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
