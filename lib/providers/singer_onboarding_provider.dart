import 'package:flutter/foundation.dart';

import '../core/utils/error_handler.dart';
import '../services/singer_kyc_service.dart';

class SingerOnboardingProvider extends ChangeNotifier {
  final SingerKycService _service;

  SingerOnboardingProvider({SingerKycService? service})
      : _service = service ?? SingerKycService();

  int step = 0;
  String name = '';
  String mobile = '';
  Uint8List? idJpeg;
  Uint8List? selfieJpeg;
  bool termsReadToEnd = false;
  bool termsAccepted = false;
  bool submitting = false;
  String? errorMessage;
  bool submitted = false;

  bool get canGoStep2 {
    final n = name.trim();
    final m = mobile.trim();
    return n.isNotEmpty && RegExp(r'^\d{10}$').hasMatch(m);
  }

  bool get canGoStep3 => selfieJpeg != null && selfieJpeg!.isNotEmpty;
  bool get canGoStep4 => idJpeg != null && idJpeg!.isNotEmpty;
  bool get canSubmit =>
      canGoStep2 &&
      canGoStep3 &&
      canGoStep4 &&
      termsAccepted &&
      !submitting;

  void setName(String v) {
    name = v;
    notifyListeners();
  }

  void setMobile(String v) {
    mobile = v.replaceAll(RegExp(r'\D'), '');
    if (mobile.length > 10) mobile = mobile.substring(0, 10);
    notifyListeners();
  }

  void setIdJpeg(Uint8List bytes) {
    idJpeg = bytes;
    notifyListeners();
  }

  void clearIdJpeg() {
    idJpeg = null;
    notifyListeners();
  }

  void setSelfieJpeg(Uint8List bytes) {
    selfieJpeg = bytes;
    notifyListeners();
  }

  void clearSelfieJpeg() {
    selfieJpeg = null;
    notifyListeners();
  }

  void markTermsReadToEnd() {
    if (termsReadToEnd) return;
    termsReadToEnd = true;
    notifyListeners();
  }

  void setTermsAccepted(bool v) {
    termsAccepted = v;
    if (v) termsReadToEnd = true;
    notifyListeners();
  }

  void next() {
    if (step == 0 && !canGoStep2) return;
    if (step == 1 && !canGoStep3) return;
    if (step == 2 && !canGoStep4) return;
    if (step >= 3) return;
    step += 1;
    errorMessage = null;
    notifyListeners();
  }

  void back() {
    if (step <= 0) return;
    step -= 1;
    errorMessage = null;
    notifyListeners();
  }

  Future<bool> submit() async {
    if (!canSubmit) return false;
    submitting = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _service.submit(
        name: name.trim(),
        mobileNumber: mobile.trim(),
        idJpeg: idJpeg!,
        selfieJpeg: selfieJpeg!,
      );
      submitted = true;
      submitting = false;
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = ErrorHandler.getMessage(e);
      submitting = false;
      notifyListeners();
      return false;
    }
  }
}