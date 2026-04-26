import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

/// Shared brand colour used in the Flutter UI (`AppColors.darkBlue500`).
const PdfColor _brand = PdfColor.fromInt(0xFF1B4080);
const PdfColor _ink = PdfColor.fromInt(0xFF0F172A);
const PdfColor _muted = PdfColor.fromInt(0xFF64748B);
const PdfColor _hairline = PdfColor.fromInt(0xFFE2E8F0);
const PdfColor _bg = PdfColor.fromInt(0xFFF8FAFC);

/// Builds a clinic-style PDF for either a medical record or a prescription
/// and pipes it to the system share sheet so the patient can save to disk
/// (Files / Drive / WhatsApp / etc).
class ClinicalPdf {
  static Future<void> shareMedicalRecord(Map<String, dynamic> record) async {
    final title = (record['title']?.toString().trim().isNotEmpty == true)
        ? record['title'].toString()
        : (record['diagnosis']?.toString() ?? 'Medical Record');
    final author = record['authored_by_name']?.toString() ?? 'Doctor';
    final authorSpecialty = record['authored_by_specialty']?.toString() ?? '';
    final created = record['created_at']?.toString();
    final dateLine = _formatDate(created);
    final symptoms = (record['symptoms'] as List?)?.join(', ') ?? '';

    final sections = <_Section>[
      _Section('Chief complaint', record['chief_complaint']),
      _Section('Symptoms', symptoms),
      _Section('Symptom duration', record['symptom_duration']),
      _Section('Examination findings', record['examination_findings']),
      _Section('Diagnosis', record['diagnosis']),
      _Section('Treatment plan', record['treatment_plan']),
      _Section('Medications', record['medications_summary']),
      _Section('Follow-up', record['follow_up_date']),
    ];

    final pdf = await _buildDocument(
      headline: 'Medical Record',
      subhead: title,
      meta: [
        if (author.isNotEmpty) 'Authored by $author',
        if (authorSpecialty.isNotEmpty) authorSpecialty,
        if (dateLine.isNotEmpty) dateLine,
      ].join(' · '),
      builder: (ctx) => sections
          .where((s) => (s.value ?? '').toString().trim().isNotEmpty)
          .map((s) => _buildSection(s.label, s.value!.toString()))
          .toList(),
    );

    await _shareBytes(
      filename: 'clinix_record_${_safeName(title)}.pdf',
      bytes: pdf,
      subject: 'Medical Record — $title',
    );
  }

  static Future<void> sharePrescription(Map<String, dynamic> prescription) async {
    final providerName = prescription['provider_name']?.toString() ?? 'Doctor';
    final issuedAt = prescription['issued_at']?.toString();
    final dateLine = _formatDate(issuedAt);
    final medications = (prescription['medications'] as List?) ?? const [];
    final instructions = prescription['instructions']?.toString() ?? '';
    final validUntil = prescription['valid_until']?.toString();
    final isValid = validUntil != null &&
        DateTime.tryParse(validUntil)?.isAfter(DateTime.now()) == true;

    final pdf = await _buildDocument(
      headline: 'Prescription',
      subhead: 'Issued by $providerName',
      meta: [
        if (dateLine.isNotEmpty) dateLine,
        isValid ? 'Active' : 'Expired',
      ].join(' · '),
      builder: (ctx) => [
        if (medications.isNotEmpty) _buildMedicationsTable(medications),
        if (instructions.trim().isNotEmpty)
          _buildSection('Doctor\'s instructions', instructions.trim()),
        _buildDisclaimer(
          'Confirm with a doctor or pharmacist before starting any medication. '
          'Take medications exactly as prescribed.',
        ),
      ],
    );

    final fileTitle =
        medications.isNotEmpty && medications.first is Map && medications.first['name'] != null
            ? medications.first['name'].toString()
            : 'prescription';
    await _shareBytes(
      filename: 'clinix_prescription_${_safeName(fileTitle)}.pdf',
      bytes: pdf,
      subject: 'Prescription — $providerName',
    );
  }

  // ─── Internals ──────────────────────────────────────────────────────────

  static Future<List<int>> _buildDocument({
    required String headline,
    required String subhead,
    required String meta,
    required List<pw.Widget> Function(pw.Context) builder,
  }) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 40, 40, 48),
        header: (ctx) => _buildHeader(headline, subhead, meta),
        footer: (ctx) => _buildFooter(ctx),
        build: builder,
      ),
    );
    return doc.save();
  }

  static pw.Widget _buildHeader(String headline, String subhead, String meta) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 22),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Container(
                width: 36, height: 36,
                decoration: const pw.BoxDecoration(
                  color: _brand,
                  shape: pw.BoxShape.circle,
                ),
                alignment: pw.Alignment.center,
                child: pw.Text(
                  'C',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Clinix Health',
                    style: pw.TextStyle(
                      color: _ink,
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'Cameroon · Digital Healthcare',
                    style: pw.TextStyle(color: _muted, fontSize: 9),
                  ),
                ],
              ),
              pw.Spacer(),
              pw.Text(
                headline.toUpperCase(),
                style: pw.TextStyle(
                  color: _brand,
                  fontSize: 11,
                  letterSpacing: 1.2,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Container(height: 1, color: _hairline),
          pw.SizedBox(height: 14),
          pw.Text(
            subhead,
            style: pw.TextStyle(
              color: _ink,
              fontSize: 22,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          if (meta.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Text(meta, style: pw.TextStyle(color: _muted, fontSize: 11)),
          ],
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(pw.Context ctx) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 14),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _hairline)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Generated by Clinix · ${DateFormat('d MMM yyyy, HH:mm').format(DateTime.now())}',
            style: pw.TextStyle(color: _muted, fontSize: 9),
          ),
          pw.Text(
            'Page ${ctx.pageNumber} / ${ctx.pagesCount}',
            style: pw.TextStyle(color: _muted, fontSize: 9),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSection(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 14),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label.toUpperCase(),
            style: pw.TextStyle(
              color: _muted,
              fontSize: 9,
              letterSpacing: 1,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(color: _ink, fontSize: 11.5, lineSpacing: 2),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildMedicationsTable(List meds) {
    pw.Widget cell(String text, {bool header = false, double? width}) {
      return pw.Container(
        width: width,
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            color: header ? _muted : _ink,
            fontSize: header ? 9 : 11,
            fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
            letterSpacing: header ? 0.8 : 0,
          ),
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'MEDICATIONS',
          style: pw.TextStyle(
            color: _muted,
            fontSize: 9,
            letterSpacing: 1,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Container(
          decoration: pw.BoxDecoration(
            color: _bg,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Table(
            columnWidths: const {
              0: pw.FlexColumnWidth(2.5),
              1: pw.FlexColumnWidth(1.4),
              2: pw.FlexColumnWidth(1.6),
              3: pw.FlexColumnWidth(1.4),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(color: _hairline)),
                ),
                children: [
                  cell('DRUG', header: true),
                  cell('DOSAGE', header: true),
                  cell('FREQUENCY', header: true),
                  cell('DURATION', header: true),
                ],
              ),
              ...meds.map((raw) {
                final m = raw is Map ? raw : const {};
                return pw.TableRow(
                  children: [
                    cell((m['name'] ?? '—').toString()),
                    cell((m['dosage'] ?? '—').toString()),
                    cell((m['frequency'] ?? '—').toString()),
                    cell((m['duration'] ?? '—').toString()),
                  ],
                );
              }),
            ],
          ),
        ),
        pw.SizedBox(height: 18),
      ],
    );
  }

  static pw.Widget _buildDisclaimer(String text) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 10),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _bg,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _hairline),
      ),
      child: pw.Text(
        text,
        style: pw.TextStyle(color: _muted, fontSize: 10, lineSpacing: 1.5),
      ),
    );
  }

  static Future<void> _shareBytes({
    required String filename,
    required List<int> bytes,
    required String subject,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject: subject,
    );
  }

  static String _safeName(String input) {
    final cleaned = input
        .replaceAll(RegExp(r'[^a-zA-Z0-9_\- ]'), '')
        .replaceAll(' ', '_');
    return cleaned.isEmpty ? 'document' : cleaned;
  }

  static String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      return DateFormat('d MMM yyyy').format(dt);
    } catch (_) {
      return '';
    }
  }
}

class _Section {
  final String label;
  final dynamic value;
  _Section(this.label, this.value);
}
