class SingerApplication {
  final String id;
  final String name;
  final String mobileNumber;
  final String idDocumentPath;
  final String livenessImagePath;
  final String livenessCheckMethod;
  final String termsVersion;
  final String termsTextSnapshot;
  final bool termsAccepted;
  final DateTime termsAcceptedAt;
  final String? consentIpAddress;
  final String? consentDeviceInfo;
  final String consentHash;
  final String status;
  final String? rejectionReason;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final DateTime createdAt;
  final String? submittedBy;
  final String? idDocumentSha256;
  final String? livenessImageSha256;
  final String? termsTextSha256;
  final String? consentManifest;
  final String? evidencePackSha256;

  SingerApplication({
    required this.id,
    required this.name,
    required this.mobileNumber,
    required this.idDocumentPath,
    required this.livenessImagePath,
    this.livenessCheckMethod = 'head_turn_left_right',
    required this.termsVersion,
    required this.termsTextSnapshot,
    required this.termsAccepted,
    required this.termsAcceptedAt,
    this.consentIpAddress,
    this.consentDeviceInfo,
    required this.consentHash,
    this.status = 'pending',
    this.rejectionReason,
    this.reviewedAt,
    this.reviewedBy,
    required this.createdAt,
    this.submittedBy,
    this.idDocumentSha256,
    this.livenessImageSha256,
    this.termsTextSha256,
    this.consentManifest,
    this.evidencePackSha256,
  });

  factory SingerApplication.fromJson(Map<String, dynamic> json) {
    DateTime? parseDt(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      return DateTime.tryParse(v.toString());
    }

    return SingerApplication(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      mobileNumber: json['mobile_number'] as String? ?? '',
      idDocumentPath: json['id_document_path'] as String? ?? '',
      livenessImagePath: json['liveness_image_path'] as String? ?? '',
      livenessCheckMethod:
          json['liveness_check_method'] as String? ?? 'head_turn_left_right',
      termsVersion: json['terms_version'] as String? ?? '',
      termsTextSnapshot: json['terms_text_snapshot'] as String? ?? '',
      termsAccepted: json['terms_accepted'] as bool? ?? false,
      termsAcceptedAt: parseDt(json['terms_accepted_at']) ?? DateTime.now(),
      consentIpAddress: json['consent_ip_address'] as String?,
      consentDeviceInfo: json['consent_device_info'] as String?,
      consentHash: json['consent_hash'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      rejectionReason: json['rejection_reason'] as String?,
      reviewedAt: parseDt(json['reviewed_at']),
      reviewedBy: json['reviewed_by'] as String?,
      createdAt: parseDt(json['created_at']) ?? DateTime.now(),
      submittedBy: json['submitted_by'] as String?,
      idDocumentSha256: json['id_document_sha256'] as String?,
      livenessImageSha256: json['liveness_image_sha256'] as String?,
      termsTextSha256: json['terms_text_sha256'] as String?,
      consentManifest: json['consent_manifest'] as String?,
      evidencePackSha256: json['evidence_pack_sha256'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'mobile_number': mobileNumber,
      'id_document_path': idDocumentPath,
      'liveness_image_path': livenessImagePath,
      'liveness_check_method': livenessCheckMethod,
      'terms_version': termsVersion,
      'terms_text_snapshot': termsTextSnapshot,
      'terms_accepted': termsAccepted,
      'terms_accepted_at': termsAcceptedAt.toUtc().toIso8601String(),
      'consent_ip_address': consentIpAddress,
      'consent_device_info': consentDeviceInfo,
      'consent_hash': consentHash,
      'status': status,
      'rejection_reason': rejectionReason,
      'reviewed_at': reviewedAt?.toUtc().toIso8601String(),
      'reviewed_by': reviewedBy,
      'created_at': createdAt.toUtc().toIso8601String(),
      'submitted_by': submittedBy,
      'id_document_sha256': idDocumentSha256,
      'liveness_image_sha256': livenessImageSha256,
      'terms_text_sha256': termsTextSha256,
      'consent_manifest': consentManifest,
      'evidence_pack_sha256': evidencePackSha256,
    };
  }
}