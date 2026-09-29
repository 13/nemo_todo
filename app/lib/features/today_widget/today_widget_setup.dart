/// `openTodayWidget`: the Android widget where `dart:io` exists, nothing on
/// the web, which then never imports `home_widget`.
library;

export 'package:nemo/features/today_widget/today_widget_setup_stub.dart'
    if (dart.library.io) 'package:nemo/features/today_widget/today_widget_setup_io.dart';
