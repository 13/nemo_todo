// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class LDe extends L {
  LDe([String locale = 'de']) : super(locale);

  @override
  String get appName => 'nemo';

  @override
  String get commonSave => 'Speichern';

  @override
  String get commonCancel => 'Abbrechen';

  @override
  String get commonDelete => 'Löschen';

  @override
  String get commonUndo => 'Rückgängig';

  @override
  String get commonRetry => 'Erneut versuchen';

  @override
  String get commonEdit => 'Bearbeiten';

  @override
  String get commonClose => 'Schließen';

  @override
  String get commonAdd => 'Hinzufügen';

  @override
  String get commonOk => 'OK';

  @override
  String get navToday => 'Heute';

  @override
  String get navUpcoming => 'Demnächst';

  @override
  String get navLists => 'Listen';

  @override
  String get navSearch => 'Suche';

  @override
  String get navSettings => 'Einstellungen';

  @override
  String get todayOverdue => 'Überfällig';

  @override
  String get todayDoneToday => 'Heute erledigt';

  @override
  String get todayEmpty => 'Heute ist nichts fällig. Genieß die Ruhe.';

  @override
  String get upcomingLater => 'Später';

  @override
  String get upcomingEmpty =>
      'Keine anstehenden Aufgaben. Setze ein Fälligkeitsdatum, um Aufgaben hier zu sehen.';

  @override
  String get listsTitle => 'Listen';

  @override
  String get listsInbox => 'Eingang';

  @override
  String get listsNewList => 'Neue Liste';

  @override
  String get listsEditList => 'Liste bearbeiten';

  @override
  String get listsName => 'Name';

  @override
  String get listsNameHint => 'z. B. Einkauf';

  @override
  String get listsColor => 'Farbe';

  @override
  String get listsIcon => 'Symbol';

  @override
  String listsDeleteConfirm(String name) {
    return '„$name“ mit allen Aufgaben löschen?';
  }

  @override
  String get listsDeleted => 'Liste gelöscht';

  @override
  String get listsShared => 'Geteilt';

  @override
  String get listsMembers => 'Mitglieder';

  @override
  String listsOpenCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count offene Aufgaben',
      one: '1 offene Aufgabe',
      zero: 'Keine offenen Aufgaben',
    );
    return '$_temp0';
  }

  @override
  String get listsEmpty => 'Erstelle eine Liste, um Aufgaben zu gruppieren.';

  @override
  String get tasksAddHint => 'Aufgabe hinzufügen';

  @override
  String get tasksOpen => 'Offen';

  @override
  String tasksCompleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count erledigt',
      one: '1 erledigt',
    );
    return '$_temp0';
  }

  @override
  String get tasksEmptyList => 'Noch keine Aufgaben. Füge unten eine hinzu.';

  @override
  String get tasksTitleHint => 'Titel';

  @override
  String get tasksNotesHint => 'Notizen';

  @override
  String get tasksDue => 'Fällig';

  @override
  String get tasksNoDue => 'Kein Datum';

  @override
  String get tasksTime => 'Uhrzeit';

  @override
  String get tasksNoTime => 'Ganztägig';

  @override
  String get tasksRemind => 'Erinnern';

  @override
  String get tasksRemindUnavailable =>
      'Erinnerungen gibt es nur in der Android-App.';

  @override
  String get tasksPriority => 'Priorität';

  @override
  String get priorityNone => 'Keine';

  @override
  String get priorityLow => 'Niedrig';

  @override
  String get priorityMedium => 'Mittel';

  @override
  String get priorityHigh => 'Hoch';

  @override
  String get tasksTags => 'Tags';

  @override
  String get tasksTagsHint => 'Tag hinzufügen';

  @override
  String get tasksSubtasks => 'Teilaufgaben';

  @override
  String get tasksSubtaskHint => 'Teilaufgabe hinzufügen';

  @override
  String get tasksPhotos => 'Fotos';

  @override
  String get photosTakePhoto => 'Foto aufnehmen';

  @override
  String get photosChoose => 'Aus Galerie wählen';

  @override
  String get photosAdd => 'Foto hinzufügen';

  @override
  String get photosNotAnImage => 'Diese Datei ist kein Bild.';

  @override
  String get photosTooLarge => 'Dieses Bild ist zu groß für diesen Server.';

  @override
  String get photosServerFull => 'Der Server hat keinen Platz mehr für Bilder.';

  @override
  String photosPhoto(int index, int count) {
    return 'Foto $index von $count';
  }

  @override
  String get photosNotUploaded => 'Noch nicht hochgeladen';

  @override
  String get tasksList => 'Liste';

  @override
  String get tasksDeleteConfirm => 'Diese Aufgabe löschen?';

  @override
  String get tasksDeleted => 'Aufgabe gelöscht';

  @override
  String get tasksCompletedSnack => 'Aufgabe erledigt';

  @override
  String get tasksNotFound => 'Diese Aufgabe gibt es nicht mehr.';

  @override
  String get tasksClearDue => 'Datum entfernen';

  @override
  String get dateToday => 'Heute';

  @override
  String get dateTomorrow => 'Morgen';

  @override
  String get dateYesterday => 'Gestern';

  @override
  String dateInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'In $count Tagen',
      one: 'In 1 Tag',
    );
    return '$_temp0';
  }

  @override
  String dateDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Vor $count Tagen',
      one: 'Vor 1 Tag',
    );
    return '$_temp0';
  }

  @override
  String get searchHint => 'Aufgaben, Notizen und Tags durchsuchen';

  @override
  String get searchEmpty => 'Tippe, um in allen Listen zu suchen.';

  @override
  String searchNoResults(String query) {
    return 'Keine Aufgaben passen zu „$query“.';
  }

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get settingsAppearance => 'Darstellung';

  @override
  String get settingsTheme => 'Design';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Hell';

  @override
  String get themeDark => 'Dunkel';

  @override
  String get settingsAccount => 'Konto';

  @override
  String get settingsNotConnected =>
      'Nicht verbunden. Deine Daten bleiben auf diesem Gerät.';

  @override
  String get settingsConnect => 'Mit einem Server verbinden';

  @override
  String settingsConnectedAs(String username, String server) {
    return 'Angemeldet als $username auf $server';
  }

  @override
  String get settingsSignOut => 'Abmelden';

  @override
  String get settingsSignOutConfirm =>
      'Abmelden? Deine Aufgaben bleiben auf diesem Gerät und werden nicht mehr synchronisiert.';

  @override
  String get settingsSignOutConfirmWeb =>
      'Abmelden? Dieser Browser vergisst deine Aufgaben; auf deinem Server bleiben sie.';

  @override
  String get settingsChangePassword => 'Passwort ändern';

  @override
  String get settingsCurrentPassword => 'Aktuelles Passwort';

  @override
  String get settingsNewPassword => 'Neues Passwort';

  @override
  String get settingsPasswordChanged =>
      'Passwort geändert. Deine anderen Geräte wurden abgemeldet.';

  @override
  String get settingsDeleteAccount => 'Konto löschen';

  @override
  String settingsDeleteAccountConfirm(String server) {
    return 'Damit wird dein Konto auf $server gelöscht. Listen, die nur du nutzt, werden mitgelöscht, und jede geteilte Liste, die dir gehört, geht an ein anderes Mitglied. Das lässt sich nicht rückgängig machen.';
  }

  @override
  String get settingsDeleteAccountKeeps =>
      'Deine Aufgaben bleiben auf diesem Gerät.';

  @override
  String get settingsDeleteAccountWipes =>
      'Dieser Browser vergisst deine Aufgaben ebenfalls.';

  @override
  String get settingsAccountDeleted => 'Konto gelöscht.';

  @override
  String get accountErrorWrongPassword => 'Das ist nicht dein Passwort.';

  @override
  String get settingsSync => 'Synchronisierung';

  @override
  String get settingsSyncNow => 'Jetzt synchronisieren';

  @override
  String settingsLastSync(String time) {
    return 'Zuletzt synchronisiert $time';
  }

  @override
  String get settingsNeverSynced => 'Noch nicht synchronisiert';

  @override
  String settingsPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Änderungen warten',
      one: '1 Änderung wartet',
      zero: 'Alles ist synchronisiert',
    );
    return '$_temp0';
  }

  @override
  String get settingsSyncing => 'Synchronisiere …';

  @override
  String settingsSyncError(String error) {
    return 'Synchronisierung fehlgeschlagen: $error';
  }

  @override
  String get settingsOffline =>
      'Offline. Änderungen werden synchronisiert, sobald du wieder online bist.';

  @override
  String get settingsSignedOutRemotely =>
      'Deine Sitzung ist abgelaufen. Melde dich erneut an, um weiter zu synchronisieren.';

  @override
  String settingsDiscarded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Änderungen wurden vom Server abgelehnt und zurückgesetzt.',
      one: '1 Änderung wurde vom Server abgelehnt und zurückgesetzt.',
    );
    return '$_temp0';
  }

  @override
  String get settingsCertificateUntrusted =>
      'Dieses Gerät vertraut dem Zertifikat nicht, das dieser Server vorgelegt hat.';

  @override
  String get settingsCertificateReview => 'Ansehen';

  @override
  String settingsVersions(String app, String server) {
    return 'App $app · Server $server';
  }

  @override
  String get settingsServerNewer =>
      'Diese Seite ist älter als der Server. Lade sie neu, um den aktuellen Stand zu bekommen.';

  @override
  String get settingsAbout => 'Über';

  @override
  String settingsVersion(String version) {
    return 'Version $version';
  }

  @override
  String get settingsCelebrations => 'Feiern & Erfolge';

  @override
  String get settingsCelebrationsEnabled => 'Feiern';

  @override
  String get settingsCelebrationsEnabledHint =>
      'Konfetti, Animationen und Vibration beim Erledigen von Aufgaben';

  @override
  String get settingsCelebrationSound => 'Ton';

  @override
  String get settingsCelebrationSoundHint =>
      'Bei großen Momenten einen Ton abspielen';

  @override
  String get settingsAchievements => 'Erfolge';

  @override
  String get settingsAchievementsHint =>
      'Erfolge und Freischalt-Hinweise anzeigen';

  @override
  String get achievementsView => 'Erfolge ansehen';

  @override
  String get accountSignInAction => 'Bei deinem Server anmelden';

  @override
  String get accountWebNotice =>
      'nemo bewahrt deine Aufgaben auf diesem Server auf. Melde dich an, um sie zu sehen.';

  @override
  String get accountCertificateTitle => 'Zertifikat dieses Servers vertrauen?';

  @override
  String accountCertificateBody(String host) {
    return '$host weist sich mit einem Zertifikat aus, das dieses Gerät nicht prüfen kann. Vergleiche den Fingerabdruck mit deinem Server, bevor du es annimmst.';
  }

  @override
  String get accountCertificateIssuer => 'Ausgestellt von';

  @override
  String get accountCertificateExpires => 'Gültig bis';

  @override
  String get accountCertificateFingerprint => 'SHA-256-Fingerabdruck';

  @override
  String get accountCertificateTrust => 'Vertrauen und verbinden';

  @override
  String get accountErrorCertificate =>
      'Dieses Gerät vertraut dem Zertifikat dieses Servers nicht.';

  @override
  String get accountTitle => 'Verbinden';

  @override
  String get accountServer => 'Serveradresse';

  @override
  String get accountServerHint => 'https://nemo.example.com';

  @override
  String get accountUsername => 'Benutzername';

  @override
  String get accountPassword => 'Passwort';

  @override
  String get accountSignIn => 'Anmelden';

  @override
  String get accountSignUp => 'Konto erstellen';

  @override
  String get accountLocalNotice =>
      'Deine vorhandenen Aufgaben werden in dieses Konto hochgeladen.';

  @override
  String get accountErrorInvalidCredentials =>
      'Falscher Benutzername oder falsches Passwort.';

  @override
  String get accountErrorSignupDisabled =>
      'Dieser Server erlaubt keine neuen Konten.';

  @override
  String get accountErrorUsernameTaken => 'Dieser Benutzername ist vergeben.';

  @override
  String get accountErrorInvalidUsername =>
      'Verwende 3–32 Kleinbuchstaben, Ziffern, Punkte, Binde- oder Unterstriche.';

  @override
  String get accountErrorWeakPassword => 'Verwende mindestens 8 Zeichen.';

  @override
  String get accountErrorNetwork => 'Der Server ist nicht erreichbar.';

  @override
  String get accountErrorTooMany =>
      'Zu viele Versuche. Probiere es in einer Minute erneut.';

  @override
  String accountErrorGeneric(String code) {
    return 'Etwas ist schiefgelaufen ($code).';
  }

  @override
  String get accountInvalidUrl => 'Gib eine gültige http(s)-Adresse ein.';

  @override
  String get membersTitle => 'Mitglieder';

  @override
  String get membersAddHint => 'Benutzername';

  @override
  String get membersOwner => 'Besitzer';

  @override
  String get membersEditor => 'Bearbeiter';

  @override
  String membersRemoveConfirm(String name) {
    return '$name aus dieser Liste entfernen?';
  }

  @override
  String get membersOfflineNotice =>
      'Zum Teilen braucht es eine Verbindung zu deinem Server.';

  @override
  String get membersNotConnected =>
      'Verbinde dich mit einem Server, um Listen zu teilen.';

  @override
  String get membersOnlyOwner => 'Nur der Besitzer kann Mitglieder ändern.';

  @override
  String get membersYou => 'du';

  @override
  String get membersErrorUnknownUser => 'Kein Benutzer mit diesem Namen.';

  @override
  String get remindersChannelName => 'Erinnerungen';

  @override
  String get remindersChannelDescription =>
      'Benachrichtigungen, wenn eine Aufgabe fällig ist';

  @override
  String get remindersDueNow => 'Jetzt fällig';

  @override
  String get startupErrorTitle => 'nemo kann seine Datenbank nicht öffnen';

  @override
  String get startupErrorBody =>
      'Deine Aufgaben liegen auf diesem Gerät. Wenn du ein privates Fenster nutzt oder Websitedaten für diese Seite blockierst, erlaube sie und lade neu.';

  @override
  String get updatesTitle => 'Aktualisierungen';

  @override
  String updatesCurrentVersion(String version) {
    return 'Du hast Version $version';
  }

  @override
  String get updatesCheckNow => 'Nach Updates suchen';

  @override
  String get updatesChecking => 'Suche …';

  @override
  String get updatesUpToDate => 'nemo ist aktuell';

  @override
  String updatesAvailable(String version) {
    return 'Version $version ist verfügbar';
  }

  @override
  String get updatesWhatsNew => 'Neu';

  @override
  String get updatesDownload => 'Herunterladen';

  @override
  String updatesDownloading(int percent) {
    return 'Lädt … $percent %';
  }

  @override
  String get updatesInstall => 'Installieren';

  @override
  String get updatesInstallHint =>
      'Android fragt dich, ob du die Installation erlaubst.';

  @override
  String get updatesLater => 'Später';

  @override
  String get updatesErrorNetwork => 'GitHub ist nicht erreichbar.';

  @override
  String get updatesErrorRateLimited =>
      'GitHub bremst die Anfragen; versuche es später erneut.';

  @override
  String get updatesErrorNotFound =>
      'In dieser Version gibt es keinen Download für dieses Gerät.';

  @override
  String get updatesErrorMalformed =>
      'Der Download passt nicht zu seiner Prüfsumme.';

  @override
  String get tasksRepeat => 'Wiederholung';

  @override
  String get tasksRepeatNeedsDue =>
      'Eine wiederkehrende Aufgabe braucht ein Fälligkeitsdatum.';

  @override
  String get repeatNever => 'Nie';

  @override
  String get repeatDaily => 'Täglich';

  @override
  String get repeatWeekly => 'Wöchentlich';

  @override
  String get repeatMonthly => 'Monatlich';

  @override
  String get repeatYearly => 'Jährlich';

  @override
  String get membersMakeOwner => 'Zur Besitzerin machen';

  @override
  String membersMakeOwnerConfirm(String name) {
    return 'Diese Liste an $name übergeben? Sie können sie dann umbenennen, löschen und die Freigabe ändern. Du bleibst als Bearbeiter dabei.';
  }

  @override
  String get membersErrorNotMember => 'Teile die Liste zuerst mit ihnen.';

  @override
  String get tasksNoSelection => 'Wähle eine Aufgabe, um sie hier zu sehen.';

  @override
  String get repeatWeekdays => 'Werktags';

  @override
  String get repeatFortnightly => 'Alle 2 Wochen';

  @override
  String repeatLastWeekday(String weekday) {
    return 'Letzter $weekday im Monat';
  }

  @override
  String get repeatCustom => 'Eigene…';

  @override
  String get repeatCustomTitle => 'Eigene Wiederholung';

  @override
  String get repeatModeInterval => 'Intervall';

  @override
  String get repeatModeWeekday => 'Wochentag im Monat';

  @override
  String get repeatEvery => 'Alle';

  @override
  String get repeatUnitDays => 'Tage';

  @override
  String get repeatUnitWeeks => 'Wochen';

  @override
  String get repeatUnitMonths => 'Monate';

  @override
  String get repeatUnitYears => 'Jahre';

  @override
  String repeatEveryDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Alle $count Tage',
      one: 'Täglich',
    );
    return '$_temp0';
  }

  @override
  String repeatEveryWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Alle $count Wochen',
      one: 'Wöchentlich',
    );
    return '$_temp0';
  }

  @override
  String repeatEveryMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Alle $count Monate',
      one: 'Monatlich',
    );
    return '$_temp0';
  }

  @override
  String repeatEveryYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Alle $count Jahre',
      one: 'Jährlich',
    );
    return '$_temp0';
  }

  @override
  String repeatNthWeekday(String ordinal, String weekday) {
    String _temp0 = intl.Intl.selectLogic(ordinal, {
      'first': 'Erster',
      'second': 'Zweiter',
      'third': 'Dritter',
      'fourth': 'Vierter',
      'other': 'Letzter',
    });
    return '$_temp0 $weekday im Monat';
  }

  @override
  String repeatOrdinal(String ordinal) {
    String _temp0 = intl.Intl.selectLogic(ordinal, {
      'first': 'erster',
      'second': 'zweiter',
      'third': 'dritter',
      'fourth': 'vierter',
      'other': 'letzter',
    });
    return '$_temp0';
  }

  @override
  String get settingsData => 'Deine Daten';

  @override
  String get settingsExport => 'Aufgaben exportieren';

  @override
  String get settingsExportHint =>
      'Listen, Aufgaben und Unteraufgaben als JSON-Datei. Fotos sind nicht enthalten.';

  @override
  String get settingsImport => 'Aufgaben importieren';

  @override
  String get settingsImportHint =>
      'Fügt hinzu, was ein nemo-Export enthält und dieses Gerät noch nicht hat.';

  @override
  String get settingsExported => 'Aufgaben exportiert.';

  @override
  String settingsImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Einträge importiert.',
      one: '1 Eintrag importiert.',
      zero: 'Nichts Neues zu importieren.',
    );
    return '$_temp0';
  }

  @override
  String get settingsImportInvalid => 'Diese Datei ist kein nemo-Export.';

  @override
  String aboutBuild(String channel) {
    String _temp0 = intl.Intl.selectLogic(channel, {
      'release': 'Release-Build',
      'main': 'Entwicklungs-Build',
      'other': 'Lokaler Build',
    });
    return '$_temp0';
  }

  @override
  String aboutBuildNumbered(String channel, String number) {
    String _temp0 = intl.Intl.selectLogic(channel, {
      'release': 'Release-Build $number',
      'main': 'Entwicklungs-Build $number',
      'other': 'Lokaler Build $number',
    });
    return '$_temp0';
  }

  @override
  String aboutServerBuild(String details) {
    return 'Server $details';
  }

  @override
  String get aboutCopyDetails => 'Details kopieren';

  @override
  String get aboutCopied => 'Details kopiert.';

  @override
  String get aboutSourceCode => 'Quellcode';

  @override
  String get aboutLegalese =>
      'Aufgaben zuerst auf dem Gerät, synchronisiert mit einem Server, den du selbst betreibst.';

  @override
  String tagEmpty(String tag) {
    return 'Keine Aufgaben mit #$tag.';
  }

  @override
  String get rescheduleTitle => 'Verschieben auf';

  @override
  String get rescheduleNextWeek => 'Nächste Woche';

  @override
  String get reschedulePick => 'Datum wählen…';

  @override
  String rescheduleMoved(String when) {
    return 'Verschoben auf $when.';
  }

  @override
  String get rescheduleCleared => 'Datum entfernt.';

  @override
  String get tasksAddHintSmart =>
      'Aufgabe hinzufügen – z. B. „morgen #einkauf !hoch“';

  @override
  String get achievementFirstDoneTitle => 'Erster Schritt';

  @override
  String get achievementFirstDoneDescription => 'Erledige deine erste Aufgabe';

  @override
  String get achievementDone10Title => 'In Fahrt';

  @override
  String get achievementDone10Description => 'Erledige 10 Aufgaben';

  @override
  String get achievementDone100Title => 'Hundert geschafft';

  @override
  String get achievementDone100Description => 'Erledige 100 Aufgaben';

  @override
  String get achievementDone500Title => 'Unaufhaltsam';

  @override
  String get achievementDone500Description => 'Erledige 500 Aufgaben';

  @override
  String get achievementStreak3Title => 'Am Laufen';

  @override
  String get achievementStreak3Description =>
      'Erledige 3 Tage in Folge eine Aufgabe';

  @override
  String get achievementStreak7Title => 'Wochenheld';

  @override
  String get achievementStreak7Description =>
      'Erledige 7 Tage in Folge eine Aufgabe';

  @override
  String get achievementStreak30Title => 'Gewohnheit';

  @override
  String get achievementStreak30Description =>
      'Erledige 30 Tage in Folge eine Aufgabe';

  @override
  String get achievementClearedTodayTitle => 'Reiner Tisch';

  @override
  String get achievementClearedTodayDescription =>
      'Erledige alles, was heute fällig ist';

  @override
  String get achievementOnTime25Title => 'Pünktlich';

  @override
  String get achievementOnTime25Description =>
      'Erledige 25 Aufgaben vor ihrer Fälligkeit';

  @override
  String get achievementChecklist5Title => 'Checklisten-Profi';

  @override
  String get achievementChecklist5Description =>
      'Erledige eine Aufgabe mit 5 oder mehr Unteraufgaben';

  @override
  String get achievementsTitle => 'Erfolge';

  @override
  String achievementsUnlockedCount(int unlocked, int total) {
    return '$unlocked von $total freigeschaltet';
  }

  @override
  String achievementsProgress(int value, int target) {
    return '$value / $target';
  }

  @override
  String get achievementsUnlocked => 'Freigeschaltet';

  @override
  String achievementsStreak(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tage in Folge',
      one: '1 Tag in Folge',
    );
    return '$_temp0';
  }
}
