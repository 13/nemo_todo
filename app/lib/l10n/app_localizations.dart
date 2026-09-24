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
  /// **'nemo todo'**
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

  /// No description provided for @navNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get navNotes;

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

  /// No description provided for @upcomingNoDate.
  ///
  /// In en, this message translates to:
  /// **'No date'**
  String get upcomingNoDate;

  /// No description provided for @upcomingEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing planned. Tasks with a date or without one show here.'**
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

  /// No description provided for @tasksPhotos.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get tasksPhotos;

  /// No description provided for @tasksWork.
  ///
  /// In en, this message translates to:
  /// **'What it took'**
  String get tasksWork;

  /// No description provided for @tasksSolutionHint.
  ///
  /// In en, this message translates to:
  /// **'How it was solved'**
  String get tasksSolutionHint;

  /// No description provided for @tasksTimeSpentHint.
  ///
  /// In en, this message translates to:
  /// **'Time spent'**
  String get tasksTimeSpentHint;

  /// No description provided for @tasksCostHint.
  ///
  /// In en, this message translates to:
  /// **'Cost'**
  String get tasksCostHint;

  /// No description provided for @tasksHours.
  ///
  /// In en, this message translates to:
  /// **'h'**
  String get tasksHours;

  /// No description provided for @tasksMinutes.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get tasksMinutes;

  /// No description provided for @photosTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get photosTakePhoto;

  /// No description provided for @photosChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get photosChoose;

  /// No description provided for @photosAdd.
  ///
  /// In en, this message translates to:
  /// **'Add photo'**
  String get photosAdd;

  /// No description provided for @photosNotAnImage.
  ///
  /// In en, this message translates to:
  /// **'That file is not a picture.'**
  String get photosNotAnImage;

  /// No description provided for @photosTooLarge.
  ///
  /// In en, this message translates to:
  /// **'That picture is too large for this server.'**
  String get photosTooLarge;

  /// No description provided for @photosServerFull.
  ///
  /// In en, this message translates to:
  /// **'The server has no room for more pictures.'**
  String get photosServerFull;

  /// No description provided for @photosPhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo {index} of {count}'**
  String photosPhoto(int index, int count);

  /// No description provided for @photosNotUploaded.
  ///
  /// In en, this message translates to:
  /// **'Not uploaded yet'**
  String get photosNotUploaded;

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

  /// No description provided for @searchTasksHeader.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get searchTasksHeader;

  /// No description provided for @searchNotesHeader.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get searchNotesHeader;

  /// No description provided for @searchEmpty.
  ///
  /// In en, this message translates to:
  /// **'Type to search across all lists.'**
  String get searchEmpty;

  /// No description provided for @searchNoResults.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches \"{query}\".'**
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

  /// No description provided for @settingsSignOutConfirmWeb.
  ///
  /// In en, this message translates to:
  /// **'Sign out? This browser forgets your tasks; they stay on your server.'**
  String get settingsSignOutConfirmWeb;

  /// No description provided for @settingsChangePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get settingsChangePassword;

  /// No description provided for @settingsCurrentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get settingsCurrentPassword;

  /// No description provided for @settingsNewPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get settingsNewPassword;

  /// No description provided for @settingsPasswordChanged.
  ///
  /// In en, this message translates to:
  /// **'Password changed. Your other devices have been signed out.'**
  String get settingsPasswordChanged;

  /// No description provided for @settingsDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get settingsDeleteAccount;

  /// No description provided for @settingsDeleteAccountConfirm.
  ///
  /// In en, this message translates to:
  /// **'This deletes your account on {server}. Lists only you use are deleted with it, and each shared list you own goes to another member. This cannot be undone.'**
  String settingsDeleteAccountConfirm(String server);

  /// No description provided for @settingsDeleteAccountKeeps.
  ///
  /// In en, this message translates to:
  /// **'Your tasks stay on this device.'**
  String get settingsDeleteAccountKeeps;

  /// No description provided for @settingsDeleteAccountWipes.
  ///
  /// In en, this message translates to:
  /// **'This browser forgets your tasks too.'**
  String get settingsDeleteAccountWipes;

  /// No description provided for @settingsAccountDeleted.
  ///
  /// In en, this message translates to:
  /// **'Account deleted.'**
  String get settingsAccountDeleted;

  /// No description provided for @accountErrorWrongPassword.
  ///
  /// In en, this message translates to:
  /// **'That is not your password.'**
  String get accountErrorWrongPassword;

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

  /// No description provided for @settingsCertificateUntrusted.
  ///
  /// In en, this message translates to:
  /// **'This device does not trust the certificate this server offered.'**
  String get settingsCertificateUntrusted;

  /// No description provided for @settingsCertificateReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get settingsCertificateReview;

  /// No description provided for @settingsVersions.
  ///
  /// In en, this message translates to:
  /// **'App {app} · Server {server}'**
  String settingsVersions(String app, String server);

  /// No description provided for @settingsServerNewer.
  ///
  /// In en, this message translates to:
  /// **'This page is older than the server. Reload to get the current build.'**
  String get settingsServerNewer;

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

  /// No description provided for @settingsTasks.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get settingsTasks;

  /// No description provided for @settingsCurrency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get settingsCurrency;

  /// No description provided for @settingsCelebrations.
  ///
  /// In en, this message translates to:
  /// **'Celebrations & achievements'**
  String get settingsCelebrations;

  /// No description provided for @settingsCelebrationsEnabled.
  ///
  /// In en, this message translates to:
  /// **'Celebrations'**
  String get settingsCelebrationsEnabled;

  /// No description provided for @settingsCelebrationsEnabledHint.
  ///
  /// In en, this message translates to:
  /// **'Confetti, animations and haptics when you complete tasks'**
  String get settingsCelebrationsEnabledHint;

  /// No description provided for @settingsCelebrationSound.
  ///
  /// In en, this message translates to:
  /// **'Sound'**
  String get settingsCelebrationSound;

  /// No description provided for @settingsCelebrationSoundHint.
  ///
  /// In en, this message translates to:
  /// **'Play a sound for big moments'**
  String get settingsCelebrationSoundHint;

  /// No description provided for @settingsAchievements.
  ///
  /// In en, this message translates to:
  /// **'Achievements'**
  String get settingsAchievements;

  /// No description provided for @settingsAchievementsHint.
  ///
  /// In en, this message translates to:
  /// **'Show achievements and unlock banners'**
  String get settingsAchievementsHint;

  /// No description provided for @achievementsView.
  ///
  /// In en, this message translates to:
  /// **'View achievements'**
  String get achievementsView;

  /// No description provided for @accountSignInAction.
  ///
  /// In en, this message translates to:
  /// **'Sign in to your server'**
  String get accountSignInAction;

  /// No description provided for @accountWebNotice.
  ///
  /// In en, this message translates to:
  /// **'nemo keeps your tasks on this server. Sign in to see them.'**
  String get accountWebNotice;

  /// No description provided for @accountCertificateTitle.
  ///
  /// In en, this message translates to:
  /// **'Trust this server\'s certificate?'**
  String get accountCertificateTitle;

  /// No description provided for @accountCertificateBody.
  ///
  /// In en, this message translates to:
  /// **'{host} identifies itself with a certificate this device cannot check. Compare the fingerprint with your server before you accept it.'**
  String accountCertificateBody(String host);

  /// No description provided for @accountCertificateIssuer.
  ///
  /// In en, this message translates to:
  /// **'Issued by'**
  String get accountCertificateIssuer;

  /// No description provided for @accountCertificateExpires.
  ///
  /// In en, this message translates to:
  /// **'Valid until'**
  String get accountCertificateExpires;

  /// No description provided for @accountCertificateFingerprint.
  ///
  /// In en, this message translates to:
  /// **'SHA-256 fingerprint'**
  String get accountCertificateFingerprint;

  /// No description provided for @accountCertificateTrust.
  ///
  /// In en, this message translates to:
  /// **'Trust and connect'**
  String get accountCertificateTrust;

  /// No description provided for @accountErrorCertificate.
  ///
  /// In en, this message translates to:
  /// **'This device does not trust that server\'s certificate.'**
  String get accountErrorCertificate;

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

  /// No description provided for @repeatWeekdays.
  ///
  /// In en, this message translates to:
  /// **'Weekdays'**
  String get repeatWeekdays;

  /// No description provided for @repeatFortnightly.
  ///
  /// In en, this message translates to:
  /// **'Every 2 weeks'**
  String get repeatFortnightly;

  /// No description provided for @repeatLastWeekday.
  ///
  /// In en, this message translates to:
  /// **'Last {weekday} of the month'**
  String repeatLastWeekday(String weekday);

  /// No description provided for @repeatCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom…'**
  String get repeatCustom;

  /// No description provided for @repeatCustomTitle.
  ///
  /// In en, this message translates to:
  /// **'Custom repeat'**
  String get repeatCustomTitle;

  /// No description provided for @repeatModeInterval.
  ///
  /// In en, this message translates to:
  /// **'Interval'**
  String get repeatModeInterval;

  /// No description provided for @repeatModeWeekday.
  ///
  /// In en, this message translates to:
  /// **'Weekday of the month'**
  String get repeatModeWeekday;

  /// No description provided for @repeatEvery.
  ///
  /// In en, this message translates to:
  /// **'Every'**
  String get repeatEvery;

  /// No description provided for @repeatUnitDays.
  ///
  /// In en, this message translates to:
  /// **'days'**
  String get repeatUnitDays;

  /// No description provided for @repeatUnitWeeks.
  ///
  /// In en, this message translates to:
  /// **'weeks'**
  String get repeatUnitWeeks;

  /// No description provided for @repeatUnitMonths.
  ///
  /// In en, this message translates to:
  /// **'months'**
  String get repeatUnitMonths;

  /// No description provided for @repeatUnitYears.
  ///
  /// In en, this message translates to:
  /// **'years'**
  String get repeatUnitYears;

  /// No description provided for @repeatEveryDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Daily} other{Every {count} days}}'**
  String repeatEveryDays(int count);

  /// No description provided for @repeatEveryWeeks.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Weekly} other{Every {count} weeks}}'**
  String repeatEveryWeeks(int count);

  /// No description provided for @repeatEveryMonths.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Monthly} other{Every {count} months}}'**
  String repeatEveryMonths(int count);

  /// No description provided for @repeatEveryYears.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Yearly} other{Every {count} years}}'**
  String repeatEveryYears(int count);

  /// No description provided for @repeatNthWeekday.
  ///
  /// In en, this message translates to:
  /// **'{ordinal, select, first{First} second{Second} third{Third} fourth{Fourth} other{Last}} {weekday} of the month'**
  String repeatNthWeekday(String ordinal, String weekday);

  /// No description provided for @repeatOrdinal.
  ///
  /// In en, this message translates to:
  /// **'{ordinal, select, first{first} second{second} third{third} fourth{fourth} other{last}}'**
  String repeatOrdinal(String ordinal);

  /// No description provided for @settingsData.
  ///
  /// In en, this message translates to:
  /// **'Your data'**
  String get settingsData;

  /// No description provided for @settingsExport.
  ///
  /// In en, this message translates to:
  /// **'Export tasks'**
  String get settingsExport;

  /// No description provided for @settingsExportHint.
  ///
  /// In en, this message translates to:
  /// **'Lists, tasks, subtasks and photos as a zip file.'**
  String get settingsExportHint;

  /// No description provided for @settingsImport.
  ///
  /// In en, this message translates to:
  /// **'Import tasks'**
  String get settingsImport;

  /// No description provided for @settingsImportHint.
  ///
  /// In en, this message translates to:
  /// **'Adds what a nemo export holds and this device does not.'**
  String get settingsImportHint;

  /// No description provided for @settingsExported.
  ///
  /// In en, this message translates to:
  /// **'Tasks exported.'**
  String get settingsExported;

  /// No description provided for @settingsImported.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nothing new to import.} =1{1 item imported.} other{{count} items imported.}}'**
  String settingsImported(int count);

  /// No description provided for @settingsImportInvalid.
  ///
  /// In en, this message translates to:
  /// **'That file is not a nemo export.'**
  String get settingsImportInvalid;

  /// No description provided for @aboutBuild.
  ///
  /// In en, this message translates to:
  /// **'{channel, select, release{Release build} main{Development build} other{Local build}}'**
  String aboutBuild(String channel);

  /// No description provided for @aboutBuildNumbered.
  ///
  /// In en, this message translates to:
  /// **'{channel, select, release{Release build {number}} main{Development build {number}} other{Local build {number}}}'**
  String aboutBuildNumbered(String channel, String number);

  /// No description provided for @aboutServerBuild.
  ///
  /// In en, this message translates to:
  /// **'Server {details}'**
  String aboutServerBuild(String details);

  /// No description provided for @aboutCopyDetails.
  ///
  /// In en, this message translates to:
  /// **'Copy details'**
  String get aboutCopyDetails;

  /// No description provided for @aboutCopied.
  ///
  /// In en, this message translates to:
  /// **'Details copied.'**
  String get aboutCopied;

  /// No description provided for @aboutSourceCode.
  ///
  /// In en, this message translates to:
  /// **'Source code'**
  String get aboutSourceCode;

  /// No description provided for @aboutLegalese.
  ///
  /// In en, this message translates to:
  /// **'Local-first tasks, synced with a server you host yourself.'**
  String get aboutLegalese;

  /// No description provided for @tagEmpty.
  ///
  /// In en, this message translates to:
  /// **'No tasks tagged #{tag}.'**
  String tagEmpty(String tag);

  /// No description provided for @rescheduleTitle.
  ///
  /// In en, this message translates to:
  /// **'Move to'**
  String get rescheduleTitle;

  /// No description provided for @rescheduleNextWeek.
  ///
  /// In en, this message translates to:
  /// **'Next week'**
  String get rescheduleNextWeek;

  /// No description provided for @reschedulePick.
  ///
  /// In en, this message translates to:
  /// **'Pick a date…'**
  String get reschedulePick;

  /// No description provided for @rescheduleMoved.
  ///
  /// In en, this message translates to:
  /// **'Moved to {when}.'**
  String rescheduleMoved(String when);

  /// No description provided for @rescheduleCleared.
  ///
  /// In en, this message translates to:
  /// **'Date cleared.'**
  String get rescheduleCleared;

  /// No description provided for @tasksAddHintSmart.
  ///
  /// In en, this message translates to:
  /// **'Add a task — try “tomorrow #shop !high”'**
  String get tasksAddHintSmart;

  /// No description provided for @achievementFirstDoneTitle.
  ///
  /// In en, this message translates to:
  /// **'First step'**
  String get achievementFirstDoneTitle;

  /// No description provided for @achievementFirstDoneDescription.
  ///
  /// In en, this message translates to:
  /// **'Complete your first task'**
  String get achievementFirstDoneDescription;

  /// No description provided for @achievementDone10Title.
  ///
  /// In en, this message translates to:
  /// **'Getting going'**
  String get achievementDone10Title;

  /// No description provided for @achievementDone10Description.
  ///
  /// In en, this message translates to:
  /// **'Complete 10 tasks'**
  String get achievementDone10Description;

  /// No description provided for @achievementDone100Title.
  ///
  /// In en, this message translates to:
  /// **'Centurion'**
  String get achievementDone100Title;

  /// No description provided for @achievementDone100Description.
  ///
  /// In en, this message translates to:
  /// **'Complete 100 tasks'**
  String get achievementDone100Description;

  /// No description provided for @achievementDone500Title.
  ///
  /// In en, this message translates to:
  /// **'Unstoppable'**
  String get achievementDone500Title;

  /// No description provided for @achievementDone500Description.
  ///
  /// In en, this message translates to:
  /// **'Complete 500 tasks'**
  String get achievementDone500Description;

  /// No description provided for @achievementStreak3Title.
  ///
  /// In en, this message translates to:
  /// **'On a roll'**
  String get achievementStreak3Title;

  /// No description provided for @achievementStreak3Description.
  ///
  /// In en, this message translates to:
  /// **'Complete a task 3 days in a row'**
  String get achievementStreak3Description;

  /// No description provided for @achievementStreak7Title.
  ///
  /// In en, this message translates to:
  /// **'Week warrior'**
  String get achievementStreak7Title;

  /// No description provided for @achievementStreak7Description.
  ///
  /// In en, this message translates to:
  /// **'Complete a task 7 days in a row'**
  String get achievementStreak7Description;

  /// No description provided for @achievementStreak30Title.
  ///
  /// In en, this message translates to:
  /// **'Habit formed'**
  String get achievementStreak30Title;

  /// No description provided for @achievementStreak30Description.
  ///
  /// In en, this message translates to:
  /// **'Complete a task 30 days in a row'**
  String get achievementStreak30Description;

  /// No description provided for @achievementClearedTodayTitle.
  ///
  /// In en, this message translates to:
  /// **'Clean slate'**
  String get achievementClearedTodayTitle;

  /// No description provided for @achievementClearedTodayDescription.
  ///
  /// In en, this message translates to:
  /// **'Finish everything due today'**
  String get achievementClearedTodayDescription;

  /// No description provided for @achievementOnTime25Title.
  ///
  /// In en, this message translates to:
  /// **'Punctual'**
  String get achievementOnTime25Title;

  /// No description provided for @achievementOnTime25Description.
  ///
  /// In en, this message translates to:
  /// **'Complete 25 tasks before they are due'**
  String get achievementOnTime25Description;

  /// No description provided for @achievementChecklist5Title.
  ///
  /// In en, this message translates to:
  /// **'Checklist master'**
  String get achievementChecklist5Title;

  /// No description provided for @achievementChecklist5Description.
  ///
  /// In en, this message translates to:
  /// **'Complete a task with 5 or more subtasks'**
  String get achievementChecklist5Description;

  /// No description provided for @achievementsTitle.
  ///
  /// In en, this message translates to:
  /// **'Achievements'**
  String get achievementsTitle;

  /// No description provided for @achievementsUnlockedCount.
  ///
  /// In en, this message translates to:
  /// **'{unlocked} of {total} unlocked'**
  String achievementsUnlockedCount(int unlocked, int total);

  /// No description provided for @achievementsProgress.
  ///
  /// In en, this message translates to:
  /// **'{value} / {target}'**
  String achievementsProgress(int value, int target);

  /// No description provided for @achievementsUnlocked.
  ///
  /// In en, this message translates to:
  /// **'Unlocked'**
  String get achievementsUnlocked;

  /// No description provided for @achievementsStreak.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1-day streak} other{{count}-day streak}}'**
  String achievementsStreak(int count);

  /// No description provided for @achievementsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Achievements could not be loaded.'**
  String get achievementsLoadError;

  /// No description provided for @achievementUnlockedBanner.
  ///
  /// In en, this message translates to:
  /// **'Achievement unlocked'**
  String get achievementUnlockedBanner;

  /// No description provided for @achievementsUnlockedMany.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{count} achievements unlocked}}'**
  String achievementsUnlockedMany(int count);

  /// No description provided for @settingsExportedWithoutPhotos.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Tasks exported. 1 photo is not on this device and was left out.} other{Tasks exported. {count} photos are not on this device and were left out.}}'**
  String settingsExportedWithoutPhotos(int count);

  /// No description provided for @notesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No notes yet. A note keeps what a task cannot: the recipe, the address, the paragraph.'**
  String get notesEmpty;

  /// No description provided for @notesPinned.
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get notesPinned;

  /// No description provided for @notesOthers.
  ///
  /// In en, this message translates to:
  /// **'Others'**
  String get notesOthers;

  /// No description provided for @noteNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New note'**
  String get noteNewTitle;

  /// No description provided for @noteTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get noteTitleHint;

  /// No description provided for @noteBodyHint.
  ///
  /// In en, this message translates to:
  /// **'Write something'**
  String get noteBodyHint;

  /// No description provided for @notePreviewEmpty.
  ///
  /// In en, this message translates to:
  /// **'Empty note'**
  String get notePreviewEmpty;

  /// No description provided for @noteNotFound.
  ///
  /// In en, this message translates to:
  /// **'This note is no longer here.'**
  String get noteNotFound;

  /// No description provided for @notePin.
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get notePin;

  /// No description provided for @noteUnpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get noteUnpin;

  /// No description provided for @noteDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get noteDelete;

  /// No description provided for @noteMoveToList.
  ///
  /// In en, this message translates to:
  /// **'Move to list'**
  String get noteMoveToList;

  /// Snackbar when writing a note's title or body to the local store fails; the typed text stays in the field.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the note'**
  String get noteSaveFailed;

  /// No description provided for @notesDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this note?'**
  String get notesDeleteConfirm;

  /// No description provided for @notesDeleted.
  ///
  /// In en, this message translates to:
  /// **'Note deleted'**
  String get notesDeleted;

  /// No description provided for @mdBold.
  ///
  /// In en, this message translates to:
  /// **'Bold'**
  String get mdBold;

  /// No description provided for @mdItalic.
  ///
  /// In en, this message translates to:
  /// **'Italic'**
  String get mdItalic;

  /// No description provided for @mdStrike.
  ///
  /// In en, this message translates to:
  /// **'Strikethrough'**
  String get mdStrike;

  /// No description provided for @mdHeading.
  ///
  /// In en, this message translates to:
  /// **'Heading'**
  String get mdHeading;

  /// No description provided for @mdBulletList.
  ///
  /// In en, this message translates to:
  /// **'Bulleted list'**
  String get mdBulletList;

  /// No description provided for @mdNumberedList.
  ///
  /// In en, this message translates to:
  /// **'Numbered list'**
  String get mdNumberedList;

  /// No description provided for @mdChecklist.
  ///
  /// In en, this message translates to:
  /// **'Checkbox'**
  String get mdChecklist;

  /// No description provided for @mdQuote.
  ///
  /// In en, this message translates to:
  /// **'Quote'**
  String get mdQuote;

  /// No description provided for @mdCode.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get mdCode;

  /// No description provided for @mdCodeBlock.
  ///
  /// In en, this message translates to:
  /// **'Code block'**
  String get mdCodeBlock;

  /// No description provided for @mdLink.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get mdLink;

  /// No description provided for @mdLinkUrlHint.
  ///
  /// In en, this message translates to:
  /// **'URL'**
  String get mdLinkUrlHint;

  /// No description provided for @mdOpenLink.
  ///
  /// In en, this message translates to:
  /// **'Open link'**
  String get mdOpenLink;

  /// No description provided for @mdUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get mdUndo;

  /// No description provided for @mdRedo.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get mdRedo;

  /// Label of a task link chip in a note when the linked task no longer exists.
  ///
  /// In en, this message translates to:
  /// **'Task deleted'**
  String get noteTaskDeleted;

  /// Tooltip of the note app bar button that switches the body to the formatted read view.
  ///
  /// In en, this message translates to:
  /// **'Formatted'**
  String get noteReadToggle;

  /// Tooltip of the note app bar button that switches the body back to editing its markdown.
  ///
  /// In en, this message translates to:
  /// **'Markdown'**
  String get noteEditToggle;

  /// Action that turns the selected note text or line into a task.
  ///
  /// In en, this message translates to:
  /// **'Make todo'**
  String get noteMakeTodo;

  /// Row on the note page that turns the whole note into a task.
  ///
  /// In en, this message translates to:
  /// **'Make todo from note'**
  String get noteMakeTodoFromNote;

  /// Action on a note line that already links to a task; opens that task.
  ///
  /// In en, this message translates to:
  /// **'Open task'**
  String get noteOpenTask;

  /// Make-todo sheet choice: each selected line becomes its own task.
  ///
  /// In en, this message translates to:
  /// **'One task per line'**
  String get noteTodoPerLine;

  /// Make-todo sheet choice: the first selected line is the task, the rest its subtasks.
  ///
  /// In en, this message translates to:
  /// **'One task with subtasks'**
  String get noteTodoWithSubtasks;

  /// Make-todo sheet switch for a whole note: its open checkboxes become subtasks of the new task.
  ///
  /// In en, this message translates to:
  /// **'Checklist becomes subtasks'**
  String get noteTodoChecklistSubtasks;

  /// Make-todo sheet button that creates the task(s).
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get noteTodoCreate;

  /// Snackbar after make-todo created tasks.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Task created} other{{count} tasks created}}'**
  String noteTodoCreated(int count);

  /// Snackbar after make-todo created tasks while the note was changed elsewhere, so the links were left out.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Task created. The note changed meanwhile, so no link was added.} other{{count} tasks created. The note changed meanwhile, so no links were added.}}'**
  String noteTodoCreatedNoLink(int count);

  /// Snackbar when creating tasks from a note fails; nothing was changed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t create the task'**
  String get noteTodoFailed;

  /// Generic action that opens the thing a message is about.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get commonOpen;

  /// Message after ticking off a task: today's list is now empty.
  ///
  /// In en, this message translates to:
  /// **'All clear for today. Enjoy it.'**
  String get motivationDayCleared0;

  /// Message after ticking off a task: today's list is now empty.
  ///
  /// In en, this message translates to:
  /// **'That\'s everything for today. Well done.'**
  String get motivationDayCleared1;

  /// Message after ticking off a task: today's list is now empty.
  ///
  /// In en, this message translates to:
  /// **'Today\'s list is empty. Nice work.'**
  String get motivationDayCleared2;

  /// Message after ticking off a task: today's list is now empty.
  ///
  /// In en, this message translates to:
  /// **'All done. Time for something you enjoy.'**
  String get motivationDayCleared3;

  /// Message after ticking off a task: exactly one Today task is left open.
  ///
  /// In en, this message translates to:
  /// **'One to go.'**
  String get motivationLastOne0;

  /// Message after ticking off a task: exactly one Today task is left open.
  ///
  /// In en, this message translates to:
  /// **'Just one left.'**
  String get motivationLastOne1;

  /// Message after ticking off a task: exactly one Today task is left open.
  ///
  /// In en, this message translates to:
  /// **'Nearly there. One more.'**
  String get motivationLastOne2;

  /// Message after ticking off a task: this tick crossed half of today's tasks.
  ///
  /// In en, this message translates to:
  /// **'Halfway there.'**
  String get motivationHalfway0;

  /// Message after ticking off a task: this tick crossed half of today's tasks.
  ///
  /// In en, this message translates to:
  /// **'Half of today, done.'**
  String get motivationHalfway1;

  /// Message after ticking off a task: this tick crossed half of today's tasks.
  ///
  /// In en, this message translates to:
  /// **'Good pace. Halfway through.'**
  String get motivationHalfway2;

  /// Message after ticking off a task: first completion today, continuing a streak of two days or more.
  ///
  /// In en, this message translates to:
  /// **'Day {days} in a row.'**
  String motivationStreakDay0(int days);

  /// Message after ticking off a task: first completion today, continuing a streak of two days or more.
  ///
  /// In en, this message translates to:
  /// **'{days} days running. Keep it gentle.'**
  String motivationStreakDay1(int days);

  /// Message after ticking off a task: first completion today, continuing a streak of two days or more.
  ///
  /// In en, this message translates to:
  /// **'Another day, another step. {days} in a row.'**
  String motivationStreakDay2(int days);

  /// Message after ticking off a task: first completion today, no streak.
  ///
  /// In en, this message translates to:
  /// **'Good start.'**
  String get motivationFirstOfDay0;

  /// Message after ticking off a task: first completion today, no streak.
  ///
  /// In en, this message translates to:
  /// **'First one done. The rest is easier.'**
  String get motivationFirstOfDay1;

  /// Message after ticking off a task: first completion today, no streak.
  ///
  /// In en, this message translates to:
  /// **'And the day is moving.'**
  String get motivationFirstOfDay2;

  /// Message after ticking off a task: first completion today, no streak.
  ///
  /// In en, this message translates to:
  /// **'Off to a good start.'**
  String get motivationFirstOfDay3;

  /// Message after ticking off a task: the task was due before today.
  ///
  /// In en, this message translates to:
  /// **'That one\'s been waiting. Good to have it gone.'**
  String get motivationOverdue0;

  /// Message after ticking off a task: the task was due before today.
  ///
  /// In en, this message translates to:
  /// **'Off your mind at last.'**
  String get motivationOverdue1;

  /// Message after ticking off a task: the task was due before today.
  ///
  /// In en, this message translates to:
  /// **'Finally done. That feels better.'**
  String get motivationOverdue2;

  /// Message after ticking off a task: a count of today's progress.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} done today.'**
  String motivationProgress0(int done, int total);

  /// Message after ticking off a task: a count of today's progress.
  ///
  /// In en, this message translates to:
  /// **'{done} down, {left} to go.'**
  String motivationProgress1(int done, int left);

  /// Message after ticking off a task: no more specific situation applies.
  ///
  /// In en, this message translates to:
  /// **'Nice, one less thing.'**
  String get motivationGeneric0;

  /// Message after ticking off a task: no more specific situation applies.
  ///
  /// In en, this message translates to:
  /// **'Done and dusted.'**
  String get motivationGeneric1;

  /// Message after ticking off a task: no more specific situation applies.
  ///
  /// In en, this message translates to:
  /// **'Progress feels good.'**
  String get motivationGeneric2;

  /// Message after ticking off a task: no more specific situation applies.
  ///
  /// In en, this message translates to:
  /// **'Another one done.'**
  String get motivationGeneric3;

  /// Message after ticking off a task: no more specific situation applies.
  ///
  /// In en, this message translates to:
  /// **'Ticked off.'**
  String get motivationGeneric4;

  /// Message after ticking off a task: no more specific situation applies.
  ///
  /// In en, this message translates to:
  /// **'That\'s handled.'**
  String get motivationGeneric5;

  /// Message after ticking off a task: no more specific situation applies.
  ///
  /// In en, this message translates to:
  /// **'Good work.'**
  String get motivationGeneric6;

  /// Message after ticking off a task: no more specific situation applies.
  ///
  /// In en, this message translates to:
  /// **'One step further.'**
  String get motivationGeneric7;

  /// Message after ticking off a task: no more specific situation applies.
  ///
  /// In en, this message translates to:
  /// **'Nicely done.'**
  String get motivationGeneric8;

  /// Message after ticking off a task: no more specific situation applies.
  ///
  /// In en, this message translates to:
  /// **'Crossed off.'**
  String get motivationGeneric9;

  /// Message after ticking off a task: no more specific situation applies.
  ///
  /// In en, this message translates to:
  /// **'Keep going, gently.'**
  String get motivationGeneric10;

  /// Message after ticking off a task: no more specific situation applies.
  ///
  /// In en, this message translates to:
  /// **'Small steps count.'**
  String get motivationGeneric11;

  /// Today header's count of tasks completed out of total.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} done'**
  String todayProgressCount(int done, int total);

  /// Today header's line: nothing has been completed today yet, after 3 or more days without a completion.
  ///
  /// In en, this message translates to:
  /// **'Welcome back. One small thing is a good start.'**
  String get todayWelcomeBack0;

  /// Today header's line: nothing has been completed today yet, after 3 or more days without a completion.
  ///
  /// In en, this message translates to:
  /// **'Good to see you. Start with something easy.'**
  String get todayWelcomeBack1;

  /// Today header's line: nothing has been completed today yet.
  ///
  /// In en, this message translates to:
  /// **'A fresh start.'**
  String get todayFreshStart0;

  /// Today header's line: nothing has been completed today yet.
  ///
  /// In en, this message translates to:
  /// **'Pick one to begin.'**
  String get todayFreshStart1;

  /// Today header's line: nothing has been completed today yet.
  ///
  /// In en, this message translates to:
  /// **'One thing at a time.'**
  String get todayFreshStart2;

  /// Today header's line: nothing Today shows is open any more.
  ///
  /// In en, this message translates to:
  /// **'All clear. Enjoy the rest of your day.'**
  String get todayAllClear;

  /// Snackbar after pulling down to sync when it failed.
  ///
  /// In en, this message translates to:
  /// **'Sync didn\'t work. It will try again shortly.'**
  String get syncPullFailed;

  /// Snackbar after pulling down to sync when the session ended.
  ///
  /// In en, this message translates to:
  /// **'Your session has ended. Sign in again in Settings.'**
  String get syncPullSignedOut;
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
