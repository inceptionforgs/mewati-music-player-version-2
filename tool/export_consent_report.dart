// Admin-only. Run on a machine that has the service role key.
// dart run tool/export_consent_report.dart --id=<uuid>
// dart run tool/export_consent_report.dart --mobile=98XXXXXXXX
//
// Env:
//   SUPABASE_URL
//   SUPABASE_SERVICE_ROLE_KEY

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

Future<void> main(List<String> args) async {
  String? id;
  String? mobile;
  for (final a in args) {
    if (a.startsWith('--id=')) id = a.substring(5);
    if (a.startsWith('--mobile=')) mobile = a.substring(9);
  }
  final url = Platform.environment['SUPABASE_URL'];
  final key = Platform.environment['SUPABASE_SERVICE_ROLE_KEY'];
  if (url == null || key == null) {
    stderr.writeln('Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY');
    exit(1);
  }
  if ((id == null || id.isEmpty) && (mobile == null || mobile.isEmpty)) {
    stderr.writeln('Pass --id= or --mobile=');
    exit(1);
  }

  final headers = {
    'apikey': key,
    'Authorization': 'Bearer $key',
    'Content-Type': 'application/json',
  };

  final listRes = await http.post(
    Uri.parse('$url/rest/v1/rpc/export_singer_consent_proof'),
    headers: headers,
    body: jsonEncode({
      'p_id': id,
      'p_mobile': mobile,
    }),
  );
  if (listRes.statusCode != 200) {
    stderr.writeln('Fetch failed: ${listRes.statusCode} ${listRes.body}');
    exit(1);
  }
  final rows = jsonDecode(listRes.body) as List<dynamic>;
  if (rows.isEmpty) {
    stderr.writeln('No application found');
    exit(1);
  }
  final row = rows.first as Map<String, dynamic>;

  Future<Uint8List?> loadObj(String path) async {
    final r = await http.get(
      Uri.parse('$url/storage/v1/object/singer-kyc-docs/$path'),
      headers: headers,
    );
    if (r.statusCode == 200) return r.bodyBytes;
    return null;
  }

  final idBytes = await loadObj(row['id_document_path'] as String);
  final liveBytes = await loadObj(row['liveness_image_path'] as String);

  final name = row['name'] as String? ?? '';
  final mob = row['mobile_number'] as String? ?? '';
  final ver = row['terms_version'] as String? ?? '';
  final acceptedAt = row['terms_accepted_at'] as String? ?? '';
  final storedHash = row['consent_hash'] as String? ?? '';
  final acceptedCanon = DateTime.parse(acceptedAt).toUtc().toIso8601String();
  final recomputed = sha256
      .convert(utf8.encode(name + mob + ver + acceptedCanon))
      .toString();
  final match = storedHash == recomputed;

  final doc = pw.Document();
  pw.MemoryImage? idImg;
  pw.MemoryImage? liveImg;
  if (idBytes != null) idImg = pw.MemoryImage(idBytes);
  if (liveBytes != null) liveImg = pw.MemoryImage(liveBytes);

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) => [
        pw.Header(level: 0, child: pw.Text('Consent Proof Report')),
        pw.Text('Mewati Music Player — Singer permission'),
        pw.SizedBox(height: 12),
        pw.Text('Submission ID: ${row['id']}'),
        pw.Text('Name: $name'),
        pw.Text('Mobile: $mob'),
        pw.Text('Submitted: ${row['created_at']}'),
        pw.Text('Terms accepted at: $acceptedAt'),
        pw.Text('Status: ${row['status']}'),
        pw.SizedBox(height: 12),
        pw.Text('Consent hash (stored): $storedHash'),
        pw.Text('Consent hash (recomputed): $recomputed'),
        pw.Text('Verify: ${match ? "MATCH" : "MISMATCH"}'),
        pw.Text('IP: ${row['consent_ip_address'] ?? "-"}'),
        pw.Text('Device: ${row['consent_device_info'] ?? "-"}'),
        pw.SizedBox(height: 16),
        pw.Header(level: 1, child: pw.Text('Terms snapshot')),
        pw.Text(row['terms_text_snapshot'] as String? ?? '', fontSize: 9),
        pw.SizedBox(height: 16),
        pw.Header(level: 1, child: pw.Text('ID document')),
        if (idImg != null) pw.Image(idImg, height: 280) else pw.Text('Image missing'),
        pw.SizedBox(height: 16),
        pw.Header(level: 1, child: pw.Text('Liveness selfie')),
        if (liveImg != null) pw.Image(liveImg, height: 280) else pw.Text('Image missing'),
      ],
    ),
  );

  final out = File('consent_proof_${row['id']}.pdf');
  await out.writeAsBytes(await doc.save());
  stdout.writeln('Wrote ${out.path}');
}