import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/singer_terms.dart';
import 'supabase_service.dart';

class SingerKycService {
  static const bucket = 'singer-kyc-docs';

  SupabaseClient get _supabase => SupabaseService().client;

  static String newSubmissionId() {
    final r = Random.secure();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  static String consentHash({
    required String name,
    required String mobileNumber,
    required String termsVersion,
    required DateTime termsAcceptedAt,
  }) {
    final raw = name +
        mobileNumber +
        termsVersion +
        termsAcceptedAt.toUtc().toIso8601String();
    return sha256.convert(utf8.encode(raw)).toString();
  }

  Future<String?> fetchPublicIp() async {
    try {
      final res = await http
          .get(Uri.parse('https://api.ipify.org'))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final ip = res.body.trim();
        if (ip.isNotEmpty) return ip;
      }
    } catch (_) {}
    return null;
  }

  String deviceInfo() {
    try {
      return '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
    } catch (_) {
      return 'unknown';
    }
  }

  Future<void> submit({
    required String name,
    required String mobileNumber,
    required Uint8List idJpeg,
    required Uint8List selfieJpeg,
  }) async {
    final id = newSubmissionId();
    final idPath = '$id/id_document.jpg';
    final livePath = '$id/liveness_selfie.jpg';
    final acceptedAt = DateTime.now().toUtc();
    final hash = consentHash(
      name: name,
      mobileNumber: mobileNumber,
      termsVersion: SingerTerms.version,
      termsAcceptedAt: acceptedAt,
    );
    final idSha = sha256.convert(idJpeg).toString();
    final liveSha = sha256.convert(selfieJpeg).toString();
    final termsSha = sha256.convert(utf8.encode(SingerTerms.text)).toString();
    final acceptedCanon = acceptedAt.toIso8601String();
    final manifest = jsonEncode({
      'submission_id': id,
      'name': name,
      'mobile_number': mobileNumber,
      'terms_version': SingerTerms.version,
      'terms_accepted_at': acceptedCanon,
      'terms_text_sha256': termsSha,
      'id_document_path': idPath,
      'id_document_sha256': idSha,
      'liveness_image_path': livePath,
      'liveness_image_sha256': liveSha,
      'consent_hash': hash,
    });
    final packSha = sha256.convert(utf8.encode(manifest)).toString();

    var uploadedId = false;
    var uploadedLive = false;
    try {
      await _supabase.storage.from(bucket).uploadBinary(
            idPath,
            idJpeg,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: false,
            ),
          );
      uploadedId = true;
      await _supabase.storage.from(bucket).uploadBinary(
            livePath,
            selfieJpeg,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: false,
            ),
          );
      uploadedLive = true;
      await _supabase.storage.from(bucket).uploadBinary(
            '$id/consent_manifest.json',
            Uint8List.fromList(utf8.encode(manifest)),
            fileOptions: const FileOptions(
              contentType: 'application/json',
              upsert: false,
            ),
          );

      final ip = await fetchPublicIp();

      await _supabase.rpc(
        'submit_singer_application',
        params: {
          'p_id': id,
          'p_name': name,
          'p_mobile_number': mobileNumber,
          'p_id_document_path': idPath,
          'p_liveness_image_path': livePath,
          'p_terms_version': SingerTerms.version,
          'p_terms_text_snapshot': SingerTerms.text,
          'p_terms_accepted_at': acceptedAt.toIso8601String(),
          'p_consent_ip_address': ip,
          'p_consent_device_info': deviceInfo(),
          'p_consent_hash': hash,
          'p_id_document_sha256': idSha,
          'p_liveness_image_sha256': liveSha,
          'p_terms_text_sha256': termsSha,
          'p_consent_manifest': manifest,
          'p_evidence_pack_sha256': packSha,
        },
      );
    } catch (e) {
      if (uploadedId || uploadedLive) {
        try {
          await _supabase.storage.from(bucket).remove([
            if (uploadedId) idPath,
            if (uploadedLive) livePath,
          ]);
        } catch (_) {}
      }
      throw Exception('Failed to submit singer permission: ${e.toString()}');
    }
  }
}