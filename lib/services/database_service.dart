import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import '../models/report_model.dart';
import '../models/company_model.dart';
import '../config/supabase_config.dart';
import 'auth_service.dart';
import 'storage_service.dart';

class DatabaseService {
  static final _supabase = Supabase.instance.client;
  static const _uuid = Uuid();

  // Generate unique ID
  String generateId() => _uuid.v4();

  // Calculate priority score
  int calculatePriorityScore(String severityLevel, String reportType) {
    int baseScore = 0;

    // Severity weight
    switch (severityLevel) {
      case 'high':
        baseScore += 70;
        break;
      case 'medium':
        baseScore += 40;
        break;
      case 'low':
        baseScore += 10;
        break;
    }

    // Report type weight
    switch (reportType) {
      case 'emergency_audio':
        baseScore += 30;
        break;
      case 'employee':
        baseScore += 20;
        break;
      case 'standard':
        baseScore += 10;
        break;
    }

    return baseScore;
  }

  // Save report with file uploads
  Future<Report> saveReportWithFiles({
    required Report report,
    List<PlatformFile>? documentFiles,
    List<XFile>? imageFiles,
  }) async {
    try {
      // First save the report
      final savedReport = await saveReport(report);

      // Upload and save document files
      if (documentFiles != null && documentFiles.isNotEmpty) {
        for (final file in documentFiles) {
          try {
            final storagePath = await StorageService.uploadPlatformFile(
              file: file,
              reportId: savedReport.id,
            );

            final evidence = SupportingEvidence(
              id: generateId(),
              reportId: savedReport.id,
              filePath: storagePath,
              fileName: file.name,
              fileType: _getFileTypeFromExtension(file.extension ?? ''),
              fileSize: file.size,
              mimeType: _getMimeType(file.extension ?? ''),
              storageBucket: SupabaseConfig.evidenceFilesBucket,
              uploadedAt: DateTime.now(),
            );

            await saveSupportingEvidence(evidence);
          } catch (e) {
            print('Failed to upload file ${file.name}: $e');
            // Continue with other files
          }
        }
      }

      // Upload and save image files
      if (imageFiles != null && imageFiles.isNotEmpty) {
        for (final image in imageFiles) {
          try {
            final storagePath = await StorageService.uploadXFile(
              file: image,
              reportId: savedReport.id,
            );

            final evidence = SupportingEvidence(
              id: generateId(),
              reportId: savedReport.id,
              filePath: storagePath,
              fileName: image.name,
              fileType: 'image',
              fileSize: null, // XFile doesn't provide size
              mimeType: _getMimeType(image.path.split('.').last),
              storageBucket: SupabaseConfig.evidenceFilesBucket,
              uploadedAt: DateTime.now(),
            );

            await saveSupportingEvidence(evidence);
          } catch (e) {
            print('Failed to upload image ${image.name}: $e');
            // Continue with other images
          }
        }
      }

      return savedReport;
    } catch (e) {
      throw Exception('Failed to save report with files: $e');
    }
  }

  // Save emergency report with audio (ENHANCED with anonymous access)
  Future<Report> saveEmergencyReportWithAudio({
    required Report report,
    required String audioFilePath,
    required String fileName,
  }) async {
    try {
      print('🚨 Starting emergency report submission...');

      // For testing: Ensure we have some kind of Supabase session
      await _ensureAnonymousSession();

      // Step 1: Save the report first (this generates the incident number and ensures it exists)
      final savedReport = await _saveEmergencyReport(report);
      print('✅ Emergency report saved: ${savedReport.incidentNumber}');

      // Step 2: Save reporter info IMMEDIATELY after report is saved
      try {
        final reporterInfo = ReporterInfo(
          id: generateId(),
          reportId: savedReport.id,
          name: null,
          email: null,
          phone: null,
          organization: null,
          isAnonymous: true,
          ipAddress: null,
          createdAt: DateTime.now(),
        );

        await saveReporterInfo(reporterInfo);
        print('👤 Anonymous reporter info saved');
      } catch (reporterError) {
        print('⚠️ Failed to save reporter info: $reporterError');
        // Continue - emergency report is still valid
      }

      // Step 3: Upload audio file with multiple fallback strategies
      if (audioFilePath.isNotEmpty) {
        try {
          final audioFile = File(audioFilePath);
          if (await audioFile.exists()) {
            final audioBytes = await audioFile.readAsBytes();
            print('📁 Audio file read: ${audioBytes.length} bytes');

            // Strategy 1: Try StorageService upload
            try {
              final storagePath = await StorageService.uploadEmergencyAudio(
                fileName: fileName,
                audioBytes: audioBytes,
                reportId: savedReport.id,
              );
              print('☁️ Audio uploaded to: $storagePath');

              // Save emergency audio record
              final emergencyAudio = EmergencyAudio(
                id: generateId(),
                reportId: savedReport.id,
                audioFilePath: storagePath,
                fileName: fileName,
                fileSize: audioBytes.length,
                mimeType: 'audio/aac',
                durationSeconds: 10,
                recordingQuality: 'standard',
                createdAt: DateTime.now(),
              );

              await _saveEmergencyAudioRecord(emergencyAudio);
              print('🎵 Audio record saved to database');
            } catch (storageError) {
              print('❌ StorageService upload failed: $storageError');
              print('💡 Emergency report submitted successfully without audio attachment');
            }
          } else {
            print('⚠️ Audio file not found at: $audioFilePath');
          }
        } catch (audioError) {
          print('❌ Audio processing failed: $audioError');
        }
      }

      return savedReport;
    } catch (e) {
      print('❌ Emergency report submission failed: $e');
      throw Exception('Failed to save emergency report: $e');
    }
  }

  // Ensure we have an anonymous session for RLS compliance (testing)
  Future<void> _ensureAnonymousSession() async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        print('🔓 Creating anonymous session for database access...');
        await _supabase.auth.signInAnonymously();
        print('✅ Anonymous session created');
      }
    } catch (e) {
      print('⚠️ Could not create anonymous session: $e');
      // Continue anyway - our RLS policies allow anon access
    }
  }

  // Direct storage upload bypassing StorageService
  Future<String> _directStorageUpload(Uint8List audioBytes, String fileName, String reportId) async {
    final supabase = Supabase.instance.client;
    final uniqueFileName = '${reportId}_${generateId()}_emergency.aac';

    // Try multiple bucket strategies
    final bucketOptions = [
      'emergency-audio',
      'evidence-files',
      'public', // Last resort
    ];

    for (final bucketName in bucketOptions) {
      try {
        print('🪣 Trying bucket: $bucketName');

        final filePath = 'emergency/$reportId/$uniqueFileName';
        await supabase.storage.from(bucketName).uploadBinary(filePath, audioBytes);

        print('✅ Upload successful to bucket: $bucketName');
        return filePath;
      } catch (e) {
        print('❌ Bucket $bucketName failed: $e');
        continue;
      }
    }

    throw Exception('All storage buckets failed');
  }

  // Save audio as base64 in database (fallback strategy)
  Future<void> _saveAudioAsBase64(Uint8List audioBytes, String fileName, String reportId) async {
    try {
      final base64Audio = base64Encode(audioBytes);

      // Save in emergency audio table with base64 data
      final emergencyAudio = EmergencyAudio(
        id: generateId(),
        reportId: reportId,
        audioFilePath: 'base64:$base64Audio', // Prefix to indicate base64 storage
        fileName: fileName,
        fileSize: audioBytes.length,
        mimeType: 'audio/aac',
        durationSeconds: 10,
        recordingQuality: 'standard',
        createdAt: DateTime.now(),
      );

      await _saveEmergencyAudioRecord(emergencyAudio);
      print('💾 Audio saved as base64 in database');
    } catch (e) {
      throw Exception('Failed to save audio as base64: $e');
    }
  }

  // Private method to save emergency report (simplified for anonymous access)
  Future<Report> _saveEmergencyReport(Report report) async {
    try {
      final reportData = {
        'report_type': report.reportType,
        'incident_type': report.incidentType,
        'severity_level': report.severityLevel,
        'status': report.status,
        'incident_date': report.incidentDate.toIso8601String().split('T')[0],
        'incident_time': report.incidentTime,
        'location_text': report.locationText,
        'latitude': report.latitude,
        'longitude': report.longitude,
        'detailed_description': report.detailedDescription,
        'submitted_anonymously': report.submittedAnonymously,
        'priority_score': report.priorityScore,
        'company_id': report.companyId,
      };

      print('📝 Inserting emergency report data: $reportData');

      final response = await _supabase
          .from(SupabaseConfig.reportsTable)
          .insert(reportData)
          .select()
          .single();

      print('✅ Emergency report inserted successfully');
      return Report.fromMap(response);
    } catch (e) {
      print('❌ Failed to insert emergency report: $e');
      throw Exception('Failed to save emergency report: $e');
    }
  }

  // Private method to save emergency audio record
  Future<void> _saveEmergencyAudioRecord(EmergencyAudio audio) async {
    try {
      final data = {
        'report_id': audio.reportId,
        'audio_file_path': audio.audioFilePath,
        'file_name': audio.fileName,
        'file_size': audio.fileSize,
        'mime_type': audio.mimeType,
        'duration_seconds': audio.durationSeconds,
        'recording_quality': audio.recordingQuality,
      };

      await _supabase.from(SupabaseConfig.emergencyAudioTable).insert(data);

      print('✅ Emergency audio record saved');
    } catch (e) {
      print('❌ Failed to save emergency audio record: $e');
      // Don't throw - emergency report is still valid without audio record
    }
  }

  // Helper methods
  String _getFileTypeFromExtension(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return 'image';
      case 'mp4':
      case 'mov':
      case 'avi':
        return 'video';
      case 'pdf':
      case 'doc':
      case 'docx':
      case 'txt':
        return 'document';
      default:
        return 'other';
    }
  }

  String _getMimeType(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'txt':
        return 'text/plain';
      case 'mp4':
        return 'video/mp4';
      case 'aac':
        return 'audio/aac';
      default:
        return 'application/octet-stream';
    }
  }

  // Save regular report (with session check)
  Future<Report> saveReport(Report report) async {
    try {
      // Ensure anonymous session for testing
      await _ensureAnonymousSession();

      final reportData = report.toMap();

      // Remove fields that are auto-generated by database
      reportData.remove('id');
      reportData.remove('created_at');
      reportData.remove('updated_at');
      reportData.remove('incident_number');

      final response = await _supabase
          .from(SupabaseConfig.reportsTable)
          .insert(reportData)
          .select()
          .single();

      return Report.fromMap(response);
    } catch (e) {
      throw Exception('Failed to save report: $e');
    }
  }

  // Get all reports (with proper error handling)
  Future<List<Report>> getAllReports() async {
    try {
      final response = await _supabase
          .from(SupabaseConfig.reportsTable)
          .select()
          .order('created_at', ascending: false);

      return response.map<Report>((data) => Report.fromMap(data)).toList();
    } catch (e) {
      print('Error fetching all reports: $e');
      throw Exception('Failed to fetch reports: $e');
    }
  }

  // Get reports by company domain
  Future<List<Report>> getReportsByCompany(String companyDomain) async {
    try {
      // First get company ID
      final companyResponse = await _supabase
          .from(SupabaseConfig.companiesTable)
          .select('id')
          .eq('domain', companyDomain)
          .maybeSingle();

      if (companyResponse == null) {
        print('Company not found for domain: $companyDomain');
        return [];
      }

      final companyId = companyResponse['id'];

      // Then get reports for that company
      final response = await _supabase
          .from(SupabaseConfig.reportsTable)
          .select()
          .eq('company_id', companyId)
          .order('created_at', ascending: false);

      return response.map<Report>((data) => Report.fromMap(data)).toList();
    } catch (e) {
      print('Error fetching company reports: $e');
      throw Exception('Failed to fetch company reports: $e');
    }
  }

  // Get report by ID
  Future<Report?> getReportById(String id) async {
    try {
      final response = await _supabase
          .from(SupabaseConfig.reportsTable)
          .select()
          .eq('id', id)
          .maybeSingle();

      return response != null ? Report.fromMap(response) : null;
    } catch (e) {
      print('Error fetching report: $e');
      return null;
    }
  }

  // Update report status
  Future<void> updateReportStatus(String reportId, String newStatus) async {
    try {
      await _supabase
          .from(SupabaseConfig.reportsTable)
          .update({
            'status': newStatus,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', reportId);
    } catch (e) {
      throw Exception('Failed to update report status: $e');
    }
  }

  // Save reporter info with better error handling
  Future<void> saveReporterInfo(ReporterInfo reporterInfo) async {
    try {
      final data = reporterInfo.toMap();
      data.remove('id'); // Let database generate ID
      data.remove('created_at');

      await _supabase.from(SupabaseConfig.reporterInfoTable).insert(data);

      print('✅ Reporter info saved successfully');
    } catch (e) {
      throw Exception('Failed to save reporter info: $e');
    }
  }

  // Save supporting evidence
  Future<void> saveSupportingEvidence(SupportingEvidence evidence) async {
    try {
      final data = evidence.toMap();
      data.remove('id');
      data.remove('uploaded_at');

      await _supabase.from(SupabaseConfig.supportingEvidenceTable).insert(data);
    } catch (e) {
      throw Exception('Failed to save supporting evidence: $e');
    }
  }

  // Save emergency audio
  Future<void> saveEmergencyAudio(EmergencyAudio audio) async {
    try {
      final data = audio.toMap();
      data.remove('id');
      data.remove('created_at');

      await _supabase.from(SupabaseConfig.emergencyAudioTable).insert(data);
    } catch (e) {
      throw Exception('Failed to save emergency audio: $e');
    }
  }

  // Get reports with real-time updates
  Stream<List<Report>> getReportsStream() {
    return _supabase
        .from(SupabaseConfig.reportsTable)
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((data) => data.map<Report>((item) => Report.fromMap(item)).toList());
  }

  // Get company reports stream
  Stream<List<Report>> getCompanyReportsStream(String companyDomain) async* {
    try {
      // First get company ID
      final companyResponse = await _supabase
          .from(SupabaseConfig.companiesTable)
          .select('id')
          .eq('domain', companyDomain)
          .maybeSingle();

      if (companyResponse == null) {
        yield [];
        return;
      }

      final companyId = companyResponse['id'];

      // Stream reports for that company
      yield* _supabase
          .from(SupabaseConfig.reportsTable)
          .stream(primaryKey: ['id'])
          .eq('company_id', companyId)
          .order('created_at', ascending: false)
          .map((data) => data.map<Report>((item) => Report.fromMap(item)).toList());
    } catch (e) {
      print('Error streaming company reports: $e');
      yield [];
    }
  }

  // User Management Methods
  Future<List<UserProfile>> getAllUsers() async {
    try {
      final response = await _supabase
          .from(SupabaseConfig.profilesTable)
          .select()
          .order('created_at', ascending: false);

      return response.map<UserProfile>((data) => UserProfile.fromMap(data)).toList();
    } catch (e) {
      throw Exception('Failed to fetch users: $e');
    }
  }

  Future<List<Company>> getAllCompanies() async {
    try {
      final response = await _supabase
          .from(SupabaseConfig.companiesTable)
          .select()
          .order('name', ascending: true);

      return response.map<Company>((data) => Company.fromMap(data)).toList();
    } catch (e) {
      throw Exception('Failed to fetch companies: $e');
    }
  }

  Future<UserProfile> createUser({
    required String email,
    required String password,
    required String fullName,
    required String role,
    String? companyDomain,
    String? phone,
  }) async {
    try {
      final userData = {
        'email': email,
        'password': password, // Plain text for testing
        'full_name': fullName,
        'role': role,
        'company_domain': companyDomain,
        'phone': phone,
        'is_active': true,
      };

      final response = await _supabase
          .from(SupabaseConfig.profilesTable)
          .insert(userData)
          .select()
          .single();

      return UserProfile.fromMap(response);
    } catch (e) {
      throw Exception('Failed to create user: $e');
    }
  }

  Future<void> updateUser({
    required String userId,
    String? fullName,
    String? role,
    String? companyDomain,
    String? phone,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (fullName != null) updateData['full_name'] = fullName;
      if (role != null) updateData['role'] = role;
      if (companyDomain != null) updateData['company_domain'] = companyDomain;
      if (phone != null) updateData['phone'] = phone;

      await _supabase
          .from(SupabaseConfig.profilesTable)
          .update(updateData)
          .eq('id', userId);
    } catch (e) {
      throw Exception('Failed to update user: $e');
    }
  }

  Future<void> updateUserStatus(String userId, bool isActive) async {
    try {
      await _supabase
          .from(SupabaseConfig.profilesTable)
          .update({
            'is_active': isActive,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);
    } catch (e) {
      throw Exception('Failed to update user status: $e');
    }
  }

  Future<void> resetUserPassword(String userId, String newPassword) async {
    try {
      await _supabase
          .from(SupabaseConfig.profilesTable)
          .update({
            'password': newPassword,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);
    } catch (e) {
      throw Exception('Failed to reset password: $e');
    }
  }

  Future<void> deleteUser(String userId) async {
    try {
      await _supabase
          .from(SupabaseConfig.profilesTable)
          .delete()
          .eq('id', userId);
    } catch (e) {
      throw Exception('Failed to delete user: $e');
    }
  }
}