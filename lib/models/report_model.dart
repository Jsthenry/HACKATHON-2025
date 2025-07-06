import 'package:uuid/uuid.dart';
import 'dart:typed_data';

class Report {
  final String id;
  final String incidentNumber; // INC-00000001 format
  final String reportType;
  final String incidentType;
  final String severityLevel;
  final String status;
  final DateTime incidentDate;
  final String incidentTime;
  final String? locationText;
  final double? latitude;
  final double? longitude;
  final String detailedDescription;
  final String? regulationCategory;
  final String? accidentType;
  final String? causeOfDeath;
  final String? employeeName;
  final String? employerName;
  final bool submittedAnonymously;
  final int priorityScore;
  final String? companyId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Report({
    required this.id,
    required this.incidentNumber,
    required this.reportType,
    required this.incidentType,
    required this.severityLevel,
    required this.status,
    required this.incidentDate,
    required this.incidentTime,
    this.locationText,
    this.latitude,
    this.longitude,
    required this.detailedDescription,
    this.regulationCategory,
    this.accidentType,
    this.causeOfDeath,
    this.employeeName,
    this.employerName,
    required this.submittedAnonymously,
    required this.priorityScore,
    this.companyId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Report.fromMap(Map<String, dynamic> map) {
    return Report(
      id: map['id'],
      incidentNumber: map['incident_number'] ?? '',
      reportType: map['report_type'],
      incidentType: map['incident_type'],
      severityLevel: map['severity_level'],
      status: map['status'],
      incidentDate: DateTime.parse(map['incident_date']),
      incidentTime: map['incident_time'],
      locationText: map['location_text'],
      latitude: map['latitude']?.toDouble(),
      longitude: map['longitude']?.toDouble(),
      detailedDescription: map['detailed_description'],
      regulationCategory: map['regulation_category'],
      accidentType: map['accident_type'],
      causeOfDeath: map['cause_of_death'],
      employeeName: map['employee_name'],
      employerName: map['employer_name'],
      submittedAnonymously: map['submitted_anonymously'] ?? true,
      priorityScore: map['priority_score'] ?? 0,
      companyId: map['company_id'],
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'incident_number': incidentNumber,
      'report_type': reportType,
      'incident_type': incidentType,
      'severity_level': severityLevel,
      'status': status,
      'incident_date': incidentDate.toIso8601String().split('T')[0],
      'incident_time': incidentTime,
      'location_text': locationText,
      'latitude': latitude,
      'longitude': longitude,
      'detailed_description': detailedDescription,
      'regulation_category': regulationCategory,
      'accident_type': accidentType,
      'cause_of_death': causeOfDeath,
      'employee_name': employeeName,
      'employer_name': employerName,
      'submitted_anonymously': submittedAnonymously,
      'priority_score': priorityScore,
      'company_id': companyId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Report copyWith({
    String? id,
    String? incidentNumber,
    String? reportType,
    String? incidentType,
    String? severityLevel,
    String? status,
    DateTime? incidentDate,
    String? incidentTime,
    String? locationText,
    double? latitude,
    double? longitude,
    String? detailedDescription,
    String? regulationCategory,
    String? accidentType,
    String? causeOfDeath,
    String? employeeName,
    String? employerName,
    bool? submittedAnonymously,
    int? priorityScore,
    String? companyId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Report(
      id: id ?? this.id,
      incidentNumber: incidentNumber ?? this.incidentNumber,
      reportType: reportType ?? this.reportType,
      incidentType: incidentType ?? this.incidentType,
      severityLevel: severityLevel ?? this.severityLevel,
      status: status ?? this.status,
      incidentDate: incidentDate ?? this.incidentDate,
      incidentTime: incidentTime ?? this.incidentTime,
      locationText: locationText ?? this.locationText,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      detailedDescription: detailedDescription ?? this.detailedDescription,
      regulationCategory: regulationCategory ?? this.regulationCategory,
      accidentType: accidentType ?? this.accidentType,
      causeOfDeath: causeOfDeath ?? this.causeOfDeath,
      employeeName: employeeName ?? this.employeeName,
      employerName: employerName ?? this.employerName,
      submittedAnonymously: submittedAnonymously ?? this.submittedAnonymously,
      priorityScore: priorityScore ?? this.priorityScore,
      companyId: companyId ?? this.companyId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class ReporterInfo {
  final String id;
  final String reportId;
  final String? name;
  final String? email;
  final String? phone;
  final String? organization;
  final bool isAnonymous;
  final String? ipAddress;
  final DateTime createdAt;

  const ReporterInfo({
    required this.id,
    required this.reportId,
    this.name,
    this.email,
    this.phone,
    this.organization,
    required this.isAnonymous,
    this.ipAddress,
    required this.createdAt,
  });

  factory ReporterInfo.fromMap(Map<String, dynamic> map) {
    return ReporterInfo(
      id: map['id'],
      reportId: map['report_id'],
      name: map['name'],
      email: map['email'],
      phone: map['phone'],
      organization: map['organization'],
      isAnonymous: map['is_anonymous'] ?? true,
      ipAddress: map['ip_address'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'report_id': reportId,
      'name': name,
      'email': email,
      'phone': phone,
      'organization': organization,
      'is_anonymous': isAnonymous,
      'ip_address': ipAddress,
    };
  }
}

class SupportingEvidence {
  final String id;
  final String reportId;
  final String filePath;
  final String fileName;
  final String fileType;
  final int? fileSize;
  final String? mimeType;
  final String storageBucket;
  final DateTime uploadedAt;

  const SupportingEvidence({
    required this.id,
    required this.reportId,
    required this.filePath,
    required this.fileName,
    required this.fileType,
    this.fileSize,
    this.mimeType,
    required this.storageBucket,
    required this.uploadedAt,
  });

  factory SupportingEvidence.fromMap(Map<String, dynamic> map) {
    return SupportingEvidence(
      id: map['id'],
      reportId: map['report_id'],
      filePath: map['file_path'],
      fileName: map['file_name'],
      fileType: map['file_type'],
      fileSize: map['file_size'],
      mimeType: map['mime_type'],
      storageBucket: map['storage_bucket'] ?? 'evidence-files',
      uploadedAt: DateTime.parse(map['uploaded_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'report_id': reportId,
      'file_path': filePath,
      'file_name': fileName,
      'file_type': fileType,
      'file_size': fileSize,
      'mime_type': mimeType,
      'storage_bucket': storageBucket,
      'uploaded_at': uploadedAt.toIso8601String(),
    };
  }
}

class EmergencyAudio {
  final String id;
  final String reportId;
  final String audioFilePath;
  final String fileName;
  final int? fileSize;
  final String? mimeType;
  final int? durationSeconds;
  final String? recordingQuality;
  final DateTime createdAt;

  const EmergencyAudio({
    required this.id,
    required this.reportId,
    required this.audioFilePath,
    required this.fileName,
    this.fileSize,
    this.mimeType,
    this.durationSeconds,
    this.recordingQuality,
    required this.createdAt,
  });

  factory EmergencyAudio.fromMap(Map<String, dynamic> map) {
    return EmergencyAudio(
      id: map['id'],
      reportId: map['report_id'],
      audioFilePath: map['audio_file_path'],
      fileName: map['file_name'],
      fileSize: map['file_size'],
      mimeType: map['mime_type'],
      durationSeconds: map['duration_seconds'],
      recordingQuality: map['recording_quality'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'report_id': reportId,
      'audio_file_path': audioFilePath,
      'file_name': fileName,
      'file_size': fileSize,
      'mime_type': mimeType,
      'duration_seconds': durationSeconds,
      'recording_quality': recordingQuality,
      'created_at': createdAt.toIso8601String(),
    };
  }
}