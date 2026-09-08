// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class LIt extends L {
  LIt([String locale = 'it']) : super(locale);

  @override
  String get appName => 'nemo';

  @override
  String get commonSave => 'Salva';

  @override
  String get commonCancel => 'Annulla';

  @override
  String get commonDelete => 'Elimina';

  @override
  String get commonUndo => 'Annulla';

  @override
  String get commonRetry => 'Riprova';

  @override
  String get commonEdit => 'Modifica';

  @override
  String get commonClose => 'Chiudi';

  @override
  String get commonAdd => 'Aggiungi';

  @override
  String get commonOk => 'OK';

  @override
  String get navToday => 'Oggi';

  @override
  String get navUpcoming => 'Prossime';

  @override
  String get navLists => 'Liste';

  @override
  String get navSearch => 'Cerca';

  @override
  String get navSettings => 'Impostazioni';

  @override
  String get todayOverdue => 'In ritardo';

  @override
  String get todayDoneToday => 'Completate oggi';

  @override
  String get todayEmpty => 'Niente in scadenza oggi. Goditi la calma.';

  @override
  String get upcomingLater => 'Più avanti';

  @override
  String get upcomingEmpty =>
      'Nessuna attività in programma. Aggiungi una scadenza per vederle qui.';

  @override
  String get listsTitle => 'Liste';

  @override
  String get listsInbox => 'In arrivo';

  @override
  String get listsNewList => 'Nuova lista';

  @override
  String get listsEditList => 'Modifica lista';

  @override
  String get listsName => 'Nome';

  @override
  String get listsNameHint => 'es. Spesa';

  @override
  String get listsColor => 'Colore';

  @override
  String get listsIcon => 'Icona';

  @override
  String listsDeleteConfirm(String name) {
    return 'Eliminare \"$name\" e tutte le sue attività?';
  }

  @override
  String get listsDeleted => 'Lista eliminata';

  @override
  String get listsShared => 'Condivisa';

  @override
  String get listsMembers => 'Membri';

  @override
  String listsOpenCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count attività aperte',
      one: '1 attività aperta',
      zero: 'Nessuna attività aperta',
    );
    return '$_temp0';
  }

  @override
  String get listsEmpty => 'Crea una lista per raggruppare le attività.';

  @override
  String get tasksAddHint => 'Aggiungi un\'attività';

  @override
  String get tasksOpen => 'Aperte';

  @override
  String tasksCompleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count completate',
      one: '1 completata',
    );
    return '$_temp0';
  }

  @override
  String get tasksEmptyList => 'Nessuna attività. Aggiungine una qui sotto.';

  @override
  String get tasksTitleHint => 'Titolo';

  @override
  String get tasksNotesHint => 'Note';

  @override
  String get tasksDue => 'Scadenza';

  @override
  String get tasksNoDue => 'Nessuna data';

  @override
  String get tasksTime => 'Ora';

  @override
  String get tasksNoTime => 'Tutto il giorno';

  @override
  String get tasksRemind => 'Ricordamelo';

  @override
  String get tasksRemindUnavailable =>
      'I promemoria sono disponibili solo nell\'app Android.';

  @override
  String get tasksPriority => 'Priorità';

  @override
  String get priorityNone => 'Nessuna';

  @override
  String get priorityLow => 'Bassa';

  @override
  String get priorityMedium => 'Media';

  @override
  String get priorityHigh => 'Alta';

  @override
  String get tasksTags => 'Tag';

  @override
  String get tasksTagsHint => 'Aggiungi tag';

  @override
  String get tasksSubtasks => 'Sottoattività';

  @override
  String get tasksSubtaskHint => 'Aggiungi sottoattività';

  @override
  String get tasksList => 'Lista';

  @override
  String get tasksDeleteConfirm => 'Eliminare questa attività?';

  @override
  String get tasksDeleted => 'Attività eliminata';

  @override
  String get tasksCompletedSnack => 'Attività completata';

  @override
  String get tasksNotFound => 'Questa attività non esiste più.';

  @override
  String get tasksClearDue => 'Rimuovi data';

  @override
  String get dateToday => 'Oggi';

  @override
  String get dateTomorrow => 'Domani';

  @override
  String get dateYesterday => 'Ieri';

  @override
  String dateInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tra $count giorni',
      one: 'Tra 1 giorno',
    );
    return '$_temp0';
  }

  @override
  String dateDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count giorni fa',
      one: '1 giorno fa',
    );
    return '$_temp0';
  }

  @override
  String get searchHint => 'Cerca attività, note e tag';

  @override
  String get searchEmpty => 'Scrivi per cercare in tutte le liste.';

  @override
  String searchNoResults(String query) {
    return 'Nessuna attività corrisponde a \"$query\".';
  }

  @override
  String get settingsTitle => 'Impostazioni';

  @override
  String get settingsAppearance => 'Aspetto';

  @override
  String get settingsTheme => 'Tema';

  @override
  String get themeSystem => 'Sistema';

  @override
  String get themeLight => 'Chiaro';

  @override
  String get themeDark => 'Scuro';

  @override
  String get settingsAccount => 'Account';

  @override
  String get settingsNotConnected =>
      'Non connesso. I tuoi dati restano su questo dispositivo.';

  @override
  String get settingsConnect => 'Connetti a un server';

  @override
  String settingsConnectedAs(String username, String server) {
    return 'Accesso come $username su $server';
  }

  @override
  String get settingsSignOut => 'Esci';

  @override
  String get settingsSignOutConfirm =>
      'Uscire? Le attività restano su questo dispositivo e non vengono più sincronizzate.';

  @override
  String get settingsSync => 'Sincronizzazione';

  @override
  String get settingsSyncNow => 'Sincronizza ora';

  @override
  String settingsLastSync(String time) {
    return 'Ultima sincronizzazione $time';
  }

  @override
  String get settingsNeverSynced => 'Non ancora sincronizzato';

  @override
  String settingsPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modifiche in attesa',
      one: '1 modifica in attesa',
      zero: 'Tutto è sincronizzato',
    );
    return '$_temp0';
  }

  @override
  String get settingsSyncing => 'Sincronizzazione…';

  @override
  String settingsSyncError(String error) {
    return 'Sincronizzazione non riuscita: $error';
  }

  @override
  String get settingsOffline =>
      'Offline. Le modifiche verranno sincronizzate quando tornerai online.';

  @override
  String get settingsSignedOutRemotely =>
      'La sessione è scaduta. Accedi di nuovo per continuare a sincronizzare.';

  @override
  String settingsDiscarded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modifiche sono state rifiutate dal server e annullate.',
      one: '1 modifica è stata rifiutata dal server e annullata.',
    );
    return '$_temp0';
  }

  @override
  String get settingsAbout => 'Informazioni';

  @override
  String settingsVersion(String version) {
    return 'Versione $version';
  }

  @override
  String get accountTitle => 'Connetti';

  @override
  String get accountServer => 'Indirizzo del server';

  @override
  String get accountServerHint => 'https://nemo.example.com';

  @override
  String get accountUsername => 'Nome utente';

  @override
  String get accountPassword => 'Password';

  @override
  String get accountSignIn => 'Accedi';

  @override
  String get accountSignUp => 'Crea account';

  @override
  String get accountLocalNotice =>
      'Le attività esistenti verranno caricate in questo account.';

  @override
  String get accountErrorInvalidCredentials => 'Nome utente o password errati.';

  @override
  String get accountErrorSignupDisabled =>
      'Questo server non consente nuovi account.';

  @override
  String get accountErrorUsernameTaken => 'Questo nome utente è già in uso.';

  @override
  String get accountErrorInvalidUsername =>
      'Usa 3–32 lettere minuscole, cifre, punti, trattini o underscore.';

  @override
  String get accountErrorWeakPassword => 'Usa almeno 8 caratteri.';

  @override
  String get accountErrorNetwork => 'Impossibile raggiungere il server.';

  @override
  String get accountErrorTooMany => 'Troppi tentativi. Riprova tra un minuto.';

  @override
  String accountErrorGeneric(String code) {
    return 'Qualcosa è andato storto ($code).';
  }

  @override
  String get accountInvalidUrl => 'Inserisci un indirizzo http(s) valido.';

  @override
  String get membersTitle => 'Membri';

  @override
  String get membersAddHint => 'Nome utente';

  @override
  String get membersOwner => 'Proprietario';

  @override
  String get membersEditor => 'Editor';

  @override
  String membersRemoveConfirm(String name) {
    return 'Rimuovere $name da questa lista?';
  }

  @override
  String get membersOfflineNotice =>
      'Per condividere serve una connessione al tuo server.';

  @override
  String get membersNotConnected =>
      'Connettiti a un server per condividere le liste.';

  @override
  String get membersOnlyOwner =>
      'Solo il proprietario può modificare i membri.';

  @override
  String get membersYou => 'tu';

  @override
  String get membersErrorUnknownUser => 'Nessun utente con questo nome.';

  @override
  String get remindersChannelName => 'Promemoria';

  @override
  String get remindersChannelDescription =>
      'Notifiche quando un\'attività è in scadenza';

  @override
  String get remindersDueNow => 'In scadenza ora';

  @override
  String get startupErrorTitle => 'nemo non riesce ad aprire il suo database';

  @override
  String get startupErrorBody =>
      'Le tue attività sono salvate su questo dispositivo. Se usi una finestra privata o hai bloccato i dati del sito per questa pagina, consentili e ricarica.';

  @override
  String get updatesTitle => 'Aggiornamenti';

  @override
  String updatesCurrentVersion(String version) {
    return 'Hai la versione $version';
  }

  @override
  String get updatesCheckNow => 'Cerca aggiornamenti';

  @override
  String get updatesChecking => 'Controllo…';

  @override
  String get updatesUpToDate => 'nemo è aggiornato';

  @override
  String updatesAvailable(String version) {
    return 'La versione $version è disponibile';
  }

  @override
  String get updatesWhatsNew => 'Novità';

  @override
  String get updatesDownload => 'Scarica';

  @override
  String updatesDownloading(int percent) {
    return 'Download… $percent%';
  }

  @override
  String get updatesInstall => 'Installa';

  @override
  String get updatesInstallHint =>
      'Android ti chiederà di confermare l\'installazione.';

  @override
  String get updatesLater => 'Più tardi';

  @override
  String get updatesErrorNetwork => 'Impossibile raggiungere GitHub.';

  @override
  String get updatesErrorRateLimited =>
      'GitHub sta limitando le richieste; riprova più tardi.';

  @override
  String get updatesErrorNotFound =>
      'Nessun download per questo dispositivo in quella versione.';

  @override
  String get updatesErrorMalformed =>
      'Il download non corrisponde alla sua checksum.';
}
