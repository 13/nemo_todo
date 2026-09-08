import 'dart:io';

import 'package:nemo/features/updates/data/github_release_client.dart';
import 'package:nemo/features/updates/domain/app_release.dart';

sealed class UpdateState {
  const UpdateState();
}

class UpdateIdle extends UpdateState {
  const UpdateIdle();
}

class UpdateChecking extends UpdateState {
  const UpdateChecking();
}

class UpToDate extends UpdateState {
  const UpToDate(this.checkedAt);

  final DateTime checkedAt;
}

class UpdateAvailable extends UpdateState {
  const UpdateAvailable(this.release, this.asset);

  final AppRelease release;
  final ReleaseAsset asset;
}

class UpdateDownloading extends UpdateState {
  const UpdateDownloading(this.progress);

  /// 0 to 1, or -1 when the server did not say how long the file is.
  final double progress;
}

class UpdateReady extends UpdateState {
  const UpdateReady(this.file, this.release);

  final File file;
  final AppRelease release;
}

class UpdateFailed extends UpdateState {
  const UpdateFailed(this.failure);

  final UpdateFailure failure;
}
