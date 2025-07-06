class SupabaseConfig {

  static const String url = 'https://sjlvgrskudqzybyfjdoh.supabase.co';
  static const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNqbHZncnNrdWRxenlieWZqZG9oIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTE3MjI2ODIsImV4cCI6MjA2NzI5ODY4Mn0.4vI0vMwkaUNnHfV0f78Yejx_ey2Bq-p-w0aB4NfqH9U';
  
  // Table names
  static const String companiesTable = 'companies';
  static const String profilesTable = 'profiles';
  static const String reportsTable = 'reports';
  static const String reporterInfoTable = 'reporter_info';
  static const String supportingEvidenceTable = 'supporting_evidence';
  static const String emergencyAudioTable = 'emergency_audio';
  static const String reportUpdatesTable = 'report_updates';
  
  // Storage buckets
  static const String evidenceFilesBucket = 'evidence-files';
  static const String emergencyAudioBucket = 'emergency-audio';
  
  // Functions
  static const String generateIncidentNumberFunction = 'generate_incident_number';
  static const String extractCompanyDomainFunction = 'extract_company_domain';
}
