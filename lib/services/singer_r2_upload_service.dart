import '../config/singer_upload_config.dart';

/// Empty hook. No screen uses this.
class SingerR2UploadService {
  bool get canUpload => SingerUploadConfig.enabled;
}