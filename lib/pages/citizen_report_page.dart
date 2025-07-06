import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform, File;
import 'dart:async';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vibration/vibration.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import '../models/incident_report.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';
import '../models/report_model.dart';

import '../widgets/responsive_wrapper.dart';
import '../widgets/news_monitor_widget.dart';
import 'login_selection_page.dart';

class CitizenReportPage extends StatefulWidget {
  const CitizenReportPage({super.key});

  @override
  State<CitizenReportPage> createState() => _CitizenReportPageState();
}

class _CitizenReportPageState extends State<CitizenReportPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  
  // Form controllers
  final _locationController = TextEditingController();
  final _detailedDescriptionController = TextEditingController();
  final _causeOfDeathController = TextEditingController();
  final _employeeNameController = TextEditingController();
  final _employerNameController = TextEditingController();
  
  // Reporter information controllers
  final _reporterNameController = TextEditingController();
  final _reporterEmailController = TextEditingController();
  final _reporterPhoneController = TextEditingController();
  final _reporterOrganizationController = TextEditingController();
  
  // Form values
  String? _incidentType;
  DateTime? _incidentDate;
  TimeOfDay? _incidentTime;
  SeverityLevel _severityLevel = SeverityLevel.medium;
  String? _regulationCategory;
  String? _accidentType;
  bool _submitAnonymously = true;
  bool _showAdditionalInfo = false;
  
  // Location data
  LatLng? _currentLocation;
  bool _isLoadingLocation = false;
  
  final DatabaseService _databaseService = DatabaseService();

  // Emergency recording variables
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isEmergencyActive = false;
  bool _isRecording = false;
  bool _isCountingDown = false;
  int _countdownSeconds = 4;
  int _recordingSeconds = 0;
  Timer? _countdownTimer;
  Timer? _recordingTimer;
  String? _recordingPath;
  LatLng? _emergencyLocation;
  
  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _countdownController;
  late AnimationController _holdController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _countdownAnimation;
  late Animation<double> _holdAnimation;

  // Hold-to-activate variables
  bool _isHolding = false;
  int _holdSeconds = 0;
  Timer? _holdTimer;
  Timer? _vibrationTimer;

  // Platform detection
  bool get _isMobilePlatform {
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (e) {
      return false;
    }
  }

  // Bottom navigation
  int _currentIndex = 0;

  // File upload variables
  List<PlatformFile> _selectedFiles = [];
  List<XFile> _selectedImages = [];
  final ImagePicker _imagePicker = ImagePicker();
  bool _isUploadingFiles = false;

  @override
  void initState() {
    super.initState();
    _setCurrentDateTime();
    _initializeAnimations();
    
    // Request permissions after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      _requestInitialPermissions();
    });
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _countdownController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );
    
    _holdController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _countdownAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _countdownController,
      curve: Curves.linear,
     ));

    _holdAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _holdController,
      curve: Curves.linear,
    ));
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _recordingTimer?.cancel();
    _holdTimer?.cancel();
    _vibrationTimer?.cancel();
    _pulseController.dispose();
    _countdownController.dispose();
    _holdController.dispose();
    _audioRecorder.dispose();
    _locationController.dispose();
    _detailedDescriptionController.dispose();
    _causeOfDeathController.dispose();
    _employeeNameController.dispose();
    _employerNameController.dispose();
    _reporterNameController.dispose();
    _reporterEmailController.dispose();
    _reporterPhoneController.dispose();
    _reporterOrganizationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _setCurrentDateTime() {
    final now = DateTime.now();
    setState(() {
      _incidentDate = now;
      _incidentTime = TimeOfDay.fromDateTime(now);
    });
  }

  Future<void> _requestInitialPermissions() async {
    try {
      // Request microphone permission for emergency recording
      var microphoneStatus = await Permission.microphone.status;
      if (!microphoneStatus.isGranted) {
        await Permission.microphone.request();
      }

      // Request location permission using Geolocator (works on all platforms)
      LocationPermission locationPermission = await Geolocator.checkPermission();
      if (locationPermission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }

      // Only request mobile-specific permissions on mobile platforms
      if (_isMobilePlatform) {
        // Request camera permission for photo evidence (mobile only)
        var cameraStatus = await Permission.camera.status;
        if (!cameraStatus.isGranted) {
          await Permission.camera.request();
        }

        // Request storage permission for file uploads (mobile only)
        var storageStatus = await Permission.storage.status;
        if (!storageStatus.isGranted) {
          await Permission.storage.request();
        }
      }
    } catch (e) {
      print('Error requesting permissions: $e');
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location services are disabled. Please enable them in settings.'),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() {
          _isLoadingLocation = false;
        });
        return;
      }

      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permissions are denied'),
              backgroundColor: Colors.orange,
            ),
          );
          setState(() {
            _isLoadingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permissions are permanently denied, we cannot request permissions.'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoadingLocation = false;
        });
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _currentLocation = LatLng(position.latitude, position.longitude);

      // Get address from coordinates
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          String address = '';
          
          if (place.street != null && place.street!.isNotEmpty) {
            address += place.street!;
          }
          if (place.subLocality != null && place.subLocality!.isNotEmpty) {
            if (address.isNotEmpty) address += ', ';
            address += place.subLocality!;
          }
          if (place.locality != null && place.locality!.isNotEmpty) {
            if (address.isNotEmpty) address += ', ';
            address += place.locality!;
          }
          if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
            if (address.isNotEmpty) address += ', ';
            address += place.administrativeArea!;
          }
          if (place.country != null && place.country!.isNotEmpty) {
            if (address.isNotEmpty) address += ', ';
            address += place.country!;
          }

          // Add coordinates for precision
          address += '\n(${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)})';

          _locationController.text = address;
        } else {
          _locationController.text = 'Lat: ${position.latitude.toStringAsFixed(6)}, Lng: ${position.longitude.toStringAsFixed(6)}';
        }
      } catch (e) {
        // If geocoding fails, just use coordinates
        _locationController.text = 'Lat: ${position.latitude.toStringAsFixed(6)}, Lng: ${position.longitude.toStringAsFixed(6)}';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Current location added successfully!'),
          backgroundColor: AppColors.successGreen,
        ),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error getting location: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  Future<void> _submitReport() async {
    if (_formKey.currentState?.validate() ?? false) {
      if (_incidentType == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select an incident type')),
        );
        return;
      }
      
      try {
        // Show loading indicator
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                CircularProgressIndicator(strokeWidth: 2),
                SizedBox(width: 16),
                Text('Submitting report...'),
              ],
            ),
            duration: Duration(seconds: 30),
          ),
        );

        // Create report object
        final report = Report(
          id: _databaseService.generateId(),
          incidentNumber: '', // Will be auto-generated by database
          reportType: 'standard', // Citizen report
          incidentType: _incidentType!,
          severityLevel: _severityLevel.name,
          status: 'submitted',
          incidentDate: _incidentDate ?? DateTime.now(),
          incidentTime: _incidentTime?.format(context) ?? TimeOfDay.now().format(context),
          locationText: _locationController.text.isNotEmpty ? _locationController.text : null,
          latitude: _currentLocation?.latitude,
          longitude: _currentLocation?.longitude,
          detailedDescription: _detailedDescriptionController.text,
          regulationCategory: _regulationCategory,
          accidentType: _accidentType,
          causeOfDeath: _causeOfDeathController.text.isNotEmpty ? _causeOfDeathController.text : null,
          employeeName: _employeeNameController.text.isNotEmpty ? _employeeNameController.text : null,
          employerName: _employerNameController.text.isNotEmpty ? _employerNameController.text : null,
          submittedAnonymously: _submitAnonymously,
          priorityScore: _databaseService.calculatePriorityScore(_severityLevel.name, 'standard'),
          companyId: null, // Citizen reports don't have company ID
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Save report with files to database
        final savedReport = await _databaseService.saveReportWithFiles(
          report: report,
          documentFiles: _selectedFiles.isNotEmpty ? _selectedFiles : null,
          imageFiles: _selectedImages.isNotEmpty ? _selectedImages : null,
        );

        // Save reporter info
        if (!_submitAnonymously) {
          final reporterInfo = ReporterInfo(
            id: _databaseService.generateId(),
            reportId: savedReport.id,
            name: _reporterNameController.text.isNotEmpty ? _reporterNameController.text : null,
            email: _reporterEmailController.text.isNotEmpty ? _reporterEmailController.text : null,
            phone: _reporterPhoneController.text.isNotEmpty ? _reporterPhoneController.text : null,
            organization: _reporterOrganizationController.text.isNotEmpty ? _reporterOrganizationController.text : null,
            isAnonymous: false,
            ipAddress: null,
            createdAt: DateTime.now(),
          );

          await _databaseService.saveReporterInfo(reporterInfo);
        } else {
          // Save anonymous reporter info
          final reporterInfo = ReporterInfo(
            id: _databaseService.generateId(),
            reportId: savedReport.id,
            name: null,
            email: null,
            phone: null,
            organization: null,
            isAnonymous: true,
            ipAddress: null,
            createdAt: DateTime.now(),
          );

          await _databaseService.saveReporterInfo(reporterInfo);
        }

        // Hide loading indicator
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        // Show success message with incident number
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Report submitted successfully!',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('Incident #${savedReport.incidentNumber}'),
                if (_selectedFiles.length + _selectedImages.length > 0)
                  Text('${_selectedFiles.length + _selectedImages.length} file(s) uploaded'),
                Text('Thank you for helping make Guyana safer.'),
              ],
            ),
            backgroundColor: AppColors.successGreen,
            duration: const Duration(seconds: 8),
            action: SnackBarAction(
              label: 'Copy ID',
              textColor: Colors.white,
              onPressed: () {
                // Copy incident number to clipboard
                // Clipboard.setData(ClipboardData(text: savedReport.incidentNumber));
              },
            ),
          ),
        );

        // Clear form after successful submission
        _clearForm();

      } catch (e) {
        // Hide loading indicator
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        
        print('Error submitting report: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Failed to submit report',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('Error: ${e.toString()}'),
                Text('Please try again or contact support.'),
              ],
            ),
            backgroundColor: AppColors.errorRed,
            duration: const Duration(seconds: 10),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _submitReport(),
            ),
          ),
        );
      }
    }
  }

  Future<void> _submitEmergencyReport() async {
    try {
      // Show emergency submission indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              CircularProgressIndicator(strokeWidth: 2),
              SizedBox(width: 16),
              Text('Submitting emergency report...'),
            ],
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 30),
        ),
      );

      final reportId = _databaseService.generateId();
      
      final emergencyReport = Report(
        id: reportId,
        incidentNumber: '', // Will be auto-generated
        reportType: 'emergency_audio',
        incidentType: 'Emergency',
        severityLevel: 'high',
        status: 'submitted',
        incidentDate: DateTime.now(),
        incidentTime: '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
        locationText: _emergencyLocation != null 
            ? 'Emergency Location'
            : 'Location Unavailable',
        latitude: _emergencyLocation?.latitude,
        longitude: _emergencyLocation?.longitude,
        detailedDescription: 'Emergency audio report - 10 second recording submitted via emergency button',
        submittedAnonymously: true,
        priorityScore: _databaseService.calculatePriorityScore('high', 'emergency_audio'),
        companyId: null, // Emergency reports from citizens go to admin
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      Report savedReport;
      
      // Save emergency report with audio (if recording exists)
      if (_recordingPath != null && _recordingPath!.isNotEmpty) {
        final fileName = _recordingPath!.split('/').last;
        try {
          savedReport = await _databaseService.saveEmergencyReportWithAudio(
            report: emergencyReport,
            audioFilePath: _recordingPath!,
            fileName: fileName,
          );
        } catch (e) {
          print('⚠️ Emergency report with audio failed, saving without audio: $e');
          // Fallback: save report without audio
          savedReport = await _databaseService.saveReport(emergencyReport);
          
          // Save reporter info separately for fallback
          final reporterInfo = ReporterInfo(
            id: _databaseService.generateId(),
            reportId: savedReport.id,
            name: null,
            email: null,
            phone: null,
            organization: null,
            isAnonymous: true,
            ipAddress: null,
            createdAt: DateTime.now(),
          );
          await _databaseService.saveReporterInfo(reporterInfo);
        }
      } else {
        // No recording - save report without audio
        savedReport = await _databaseService.saveReport(emergencyReport);
        
        // Save anonymous reporter info
        final reporterInfo = ReporterInfo(
          id: _databaseService.generateId(),
          reportId: savedReport.id,
          name: null,
          email: null,
          phone: null,
          organization: null,
          isAnonymous: true,
          ipAddress: null,
          createdAt: DateTime.now(),
        );
        await _databaseService.saveReporterInfo(reporterInfo);
      }

      // Hide loading indicator
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Emergency report submitted!',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('Incident #${savedReport.incidentNumber}'),
              Text('Emergency services have been notified.'),
            ],
          ),
          backgroundColor: AppColors.errorRed,
          duration: const Duration(seconds: 5),
        ),
      );

      _showEmergencyConfirmationDialog();

    } catch (e) {
      // Hide loading indicator
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      
      print('❌ Error submitting emergency report: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Emergency submission failed',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('Error: ${e.toString()}'),
              Text('Please try again or call emergency services directly.'),
            ],
          ),
          backgroundColor: AppColors.errorRed,
          duration: const Duration(seconds: 10),
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () => _submitEmergencyReport(),
          ),
        ),
      );
    }
  }

  void _clearForm() {
    // Clear form validation
    _formKey.currentState?.reset();
    
    // Clear all text controllers
    _locationController.clear();
    _detailedDescriptionController.clear();
    _causeOfDeathController.clear();
    _employeeNameController.clear();
    _employerNameController.clear();
    _reporterNameController.clear();
    _reporterEmailController.clear();
    _reporterPhoneController.clear();
    _reporterOrganizationController.clear();
    
    // Reset form values
    setState(() {
      _incidentType = null;
      _incidentDate = null;
      _incidentTime = null;
      _severityLevel = SeverityLevel.medium;
      _regulationCategory = null;
      _accidentType = null;
      _submitAnonymously = true;
      _showAdditionalInfo = false;
      _currentLocation = null;
      _selectedFiles.clear();
      _selectedImages.clear();
    });
    
    // Reset to current date/time
    _setCurrentDateTime();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_currentIndex == 0 ? 'HSSE Platform' : 'HSSE Analytics'),
            Text(
              _currentIndex == 0
                  ? 'Public safety portal'
                  : 'View real-time HSSE analytics',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        //shift the title to the left
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const LoginSelectionPage(),
                ),
              );
            },
            icon: const Icon(Icons.login, size: 18),
            label: const Text('Login'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryBlue,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: [
              _buildReportsTab(),
              _buildAnalyticsTab(),
            ],
          ),
          if (_isEmergencyActive || _isHolding) _buildEmergencyOverlay(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.report),
            label: 'Submit Report',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
        ],
      ),
      floatingActionButton: _buildEmergencyButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildReportsTab() {
    return Form(
      key: _formKey,
      child: Scrollbar(
        controller: _scrollController,
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildAnonymousToggle(),
              const SizedBox(height: 24),
              if (!_submitAnonymously) _buildReporterInfoSection(),
              if (!_submitAnonymously) const SizedBox(height: 24),
              _buildWhatHappenedSection(),
              const SizedBox(height: 24),
              _buildIncidentDetailsSection(),
              const SizedBox(height: 24),
              _buildSupportingEvidenceSection(),
              const SizedBox(height: 24),
              _buildAdditionalInfoToggle(),
              if (_showAdditionalInfo) const SizedBox(height: 24),
              if (_showAdditionalInfo) _buildAdditionalInfoSection(),
              const SizedBox(height: 32),
              _buildSubmitSection(),
              const SizedBox(height: 100), // Space for floating button
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitSection() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: _clearForm,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.lightGrey,
              foregroundColor: AppColors.textPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Clear Form'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: _submitReport,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Submit Report'),
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyticsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primaryBlue,
                  AppColors.primaryBlueDark,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'HSSE Analytics',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Real-time analysis of HSSE incidents across Guyana',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.analytics,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // News Monitor Widget
          const NewsMonitorWidget(),
          
          const SizedBox(height: 24),
                    
          const SizedBox(height: 24),
          
          // Quick Insights Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.lightGrey),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: AppColors.warningOrange),
                    const SizedBox(width: 8),
                    Text(
                      'Quick Insights',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                _buildInsightItem(
                  'Most Common Incident Type',
                  'Safety Incidents (52%)',
                  Icons.warning,
                  AppColors.errorRed,
                ),
                const SizedBox(height: 12),
                
                _buildInsightItem(
                  'Peak Incident Time',
                  'Between 2-4 PM',
                  Icons.schedule,
                  AppColors.infoBlue,
                ),
                const SizedBox(height: 12),
                
                _buildInsightItem(
                  'Most Affected Sector',
                  'Construction & Mining',
                  Icons.construction,
                  AppColors.warningOrange,
                ),
                const SizedBox(height: 12),
                
                _buildInsightItem(
                  'Response Time',
                  'Average 2.3 hours',
                  Icons.timer,
                  AppColors.successGreen,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 100), // Space for floating button
        ],
      ),
    );
  }

  Widget _buildInsightItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(

                color: AppColors.safetyGreen.withOpacity(0.1),
                shape: BoxShape.circle, border: Border.all(color: AppColors.infoBlue.withOpacity(0.3))

              ),
              child: Icon(
                Icons.shield,
                size: 32,
                color: AppColors.primaryBlueDark,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Welcome to HSSE',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Help us build a safer Guyana by reporting health, safety, security, and environmental incidents',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.mediumGrey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnonymousToggle() {
    return Card(
      child: SwitchListTile(
        title: const Text('Submit anonymously'),
        subtitle: const Text('Your identity will be kept private'),
        value: _submitAnonymously,
        onChanged: (value) {
          setState(() {
            _submitAnonymously = value;
          });
        },
        secondary: const Icon(Icons.visibility_off),
      ),
    );
  }

  Widget _buildReporterInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person, color: AppColors.safetyGreen),
                const SizedBox(width: 8),
                Text(
                  'Reporter Information',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            _buildSimpleTextField(
              controller: _reporterNameController,
              label: 'Full Name *',
              hint: 'Enter your full name',
              icon: Icons.person_outline,
              validator: (value) => value?.isEmpty == true ? 'Name is required' : null,
            ),
            
            const SizedBox(height: 16),
            
            _buildSimpleTextField(
              controller: _reporterEmailController,
              label: 'Email Address *',
              hint: 'your.email@example.com',
              icon: Icons.email_outlined,
              validator: (value) {
                if (value?.isEmpty == true) return 'Email is required';
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value!)) {
                  return 'Enter a valid email';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: _buildSimpleTextField(
                    controller: _reporterPhoneController,
                    label: 'Phone Number',
                    hint: '+592-XXX-XXXX',
                    icon: Icons.phone_outlined,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSimpleTextField(
                    controller: _reporterOrganizationController,
                    label: 'Organization',
                    hint: 'Company name',
                    icon: Icons.business_outlined,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWhatHappenedSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.warningOrange.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.warning_amber,
                    color: AppColors.warningOrange,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'What happened?',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Tell us briefly what unsafe behavior you observed',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.mediumGrey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            _buildDropdownCard(
              'Type of Incident *',
              'Select the type of incident',
              _incidentType,
              [
                'Safety Incident',
                'Health Incident', 
                'Environmental Incident',
                'Security Incident',
                'Near Miss',
                'Regulatory Violation'
              ],
              (value) => setState(() => _incidentType = value),
            ),
            
            const SizedBox(height: 16),
            
            _buildSeveritySelection(),
          ],
        ),
      ),
    );
  }

  Widget _buildIncidentDetailsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.description, color: AppColors.safetyGreen),
                const SizedBox(width: 8),
                Text(
                  'Incident Details',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Date and Time row
            Row(
              children: [
                Expanded(child: _buildDateCard()),
                const SizedBox(width: 16),
                Expanded(child: _buildTimeCard()),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Location with GPS button
            Row(
              children: [
                Expanded(
                  child: _buildSimpleTextField(
                    controller: _locationController,
                    label: 'Location *',
                    hint: 'Where did this happen?',
                    icon: Icons.location_on_outlined,
                    maxLines: 3,
                    validator: (value) => value?.isEmpty == true ? 'Location is required' : null,
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  children: [
                    const SizedBox(height: 8), // Align with text field
                    IconButton(
                      onPressed: _isLoadingLocation ? null : _getCurrentLocation,
                      icon: _isLoadingLocation 
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.safetyGreen),
                            ),
                          )
                        : Icon(
                            Icons.my_location,
                            color: AppColors.safetyGreen,
                          ),
                      tooltip: 'Get current location',
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.safetyGreen.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            _buildSimpleTextField(
              controller: _detailedDescriptionController,
              label: 'Brief description *',
              hint: 'What unsafe behavior did you see? What safety rule wasn\'t being followed?',
              icon: Icons.description_outlined,
              maxLines: 4,
              helperText: 'Keep it simple - provide key details about what happened',
              validator: (value) => value?.isEmpty == true ? 'Description is required' : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportingEvidenceSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.attach_file, color: AppColors.infoBlue),
                const SizedBox(width: 8),
                Text(
                  'Supporting Evidence',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Upload photos, videos, or documents to support your report',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.mediumGrey,
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Upload area
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppColors.mediumGrey.withOpacity(0.3),
                  style: BorderStyle.solid,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(8),
                color: AppColors.lightGrey.withOpacity(0.1),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.cloud_upload_outlined,
                    size: 48,
                    color: AppColors.infoBlue,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Upload evidence files',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Supported formats: JPG, PNG, PDF, MP4, MOV\nMax file size: 10MB each',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.mediumGrey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  
                  // Upload buttons
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _isUploadingFiles ? null : _pickImages,
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Photos'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.successGreen,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _isUploadingFiles ? null : _pickFiles,
                        icon: const Icon(Icons.folder_open),
                        label: const Text('Documents'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.infoBlue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      if (_isMobilePlatform)
                        ElevatedButton.icon(
                          onPressed: _isUploadingFiles ? null : _takePhoto,
                          icon: const Icon(Icons.camera),
                          label: const Text('Camera'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.warningOrange,
                            foregroundColor: Colors.white,
                          ),
                        ),
                    ],
                  ),
                  
                  if (_isUploadingFiles)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.infoBlue),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('Processing files...'),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // File list
            if (_selectedFiles.isNotEmpty || _selectedImages.isNotEmpty)
              _buildFileList()
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: AppColors.lightGrey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppColors.mediumGrey,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No files uploaded yet. Evidence helps us better understand the incident.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.mediumGrey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileList() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.lightGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.attachment, color: AppColors.successGreen, size: 20),
              const SizedBox(width: 8),
              Text(
                'Uploaded Files (${_selectedFiles.length + _selectedImages.length})',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _clearAllFiles,
                child: Text(
                  'Clear All',
                  style: TextStyle(color: AppColors.errorRed),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Document files
          ..._selectedFiles.map((file) => _buildFileItem(
            file.name,
            _formatFileSize(file.size),
            _getFileIcon(file.extension ?? ''),
            () => _removeFile(file),
          )),
          
          // Image files
          ..._selectedImages.map((image) => _buildFileItem(
            image.name,
            'Image file',
            Icons.image,
            () => _removeImage(image),
          )),
        ],
      ),
    );
  }

  Widget _buildFileItem(String name, String size, IconData icon, VoidCallback onRemove) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.lightGrey.withOpacity(0.3),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.infoBlue, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  size,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: Icon(Icons.close, color: AppColors.errorRed, size: 20),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImages() async {
    try {
      setState(() => _isUploadingFiles = true);
      
      final List<XFile> images = await _imagePicker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      // Filter out large files
      final validImages = <XFile>[];
      for (final image in images) {
        final file = File(image.path);
        final size = await file.length();
        if (size <= 10 * 1024 * 1024) { // 10MB limit
          validImages.add(image);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${image.name} is too large (max 10MB)'),
                backgroundColor: AppColors.warningOrange,
              ),
            );
          }
        }
      }
      
      setState(() {
        _selectedImages.addAll(validImages);
      });
      
      if (validImages.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${validImages.length} image(s) added successfully'),
            backgroundColor: AppColors.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking images: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    } finally {
      setState(() => _isUploadingFiles = false);
    }
  }

  Future<void> _pickFiles() async {
    try {
      setState(() => _isUploadingFiles = true);
      
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'jpg', 'jpeg', 'png', 'mp4', 'mov', 'avi'],
        allowMultiple: true,
        withData: kIsWeb, // Load data for web
      );

      if (result != null) {
        // Filter out large files
        final validFiles = <PlatformFile>[];
        for (final file in result.files) {
          if (file.size <= 10 * 1024 * 1024) { // 10MB limit
            validFiles.add(file);
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${file.name} is too large (max 10MB)'),
                  backgroundColor: AppColors.warningOrange,
                ),
              );
            }
          }
        }
        
        setState(() {
          _selectedFiles.addAll(validFiles);
        });
        
        if (validFiles.isNotEmpty && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${validFiles.length} file(s) added successfully'),
              backgroundColor: AppColors.successGreen,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking files: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    } finally {
      setState(() => _isUploadingFiles = false);
    }
  }

  Future<void> _takePhoto() async {
    try {
      setState(() => _isUploadingFiles = true);
      
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (photo != null) {
        final file = File(photo.path);
        final size = await file.length();
        
        if (size <= 10 * 1024 * 1024) { // 10MB limit
          setState(() {
            _selectedImages.add(photo);
          });
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Photo captured successfully'),
                backgroundColor: AppColors.successGreen,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Photo is too large (max 10MB)'),
                backgroundColor: AppColors.warningOrange,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error taking photo: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    } finally {
      setState(() => _isUploadingFiles = false);
    }
  }

  void _removeFile(PlatformFile file) {
    setState(() {
      _selectedFiles.remove(file);
    });
  }

  void _removeImage(XFile image) {
    setState(() {
      _selectedImages.remove(image);
    });
  }

  void _clearAllFiles() {
    setState(() {
      _selectedFiles.clear();
      _selectedImages.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('All files cleared'),
        backgroundColor: AppColors.infoBlue,
      ),
    );
  }

  IconData _getFileIcon(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'txt':
        return Icons.text_snippet;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image;
      case 'mp4':
      case 'mov':
      case 'avi':
        return Icons.video_file;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Widget _buildAdditionalInfoToggle() {
    return SwitchListTile(
      title: const Text('Include additional information'),
      subtitle: const Text('Optional details about the incident'),
      value: _showAdditionalInfo,
      onChanged: (value) {
        setState(() {
          _showAdditionalInfo = value;
        });
      },
      secondary: const Icon(Icons.info_outline),
    );
  }

  Widget _buildAdditionalInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.infoBlue),
                const SizedBox(width: 8),
                Text(
                  'Additional Information',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            _buildDropdownCard(
              'Class of Regulation Broken',
              'Select if applicable',
              _regulationCategory,
              ['Safety Regulation', 'Health Regulation', 'Environmental Regulation', 'Security Regulation', 'Other'],
              (value) => setState(() => _regulationCategory = value),
            ),
            
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: _buildSimpleTextField(
                    controller: _employerNameController,
                    label: 'Company/Employer',
                    hint: 'Name of company involved',
                    icon: Icons.business_outlined,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSimpleTextField(
                    controller: _employeeNameController,
                    label: 'Employee Name',
                    hint: 'If applicable',
                    icon: Icons.person_outline,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            _buildDropdownCard(
              'Type of Accident',
              'Select if applicable',
              _accidentType,
              ['Fall from Height', 'Struck by Object', 'Chemical Exposure', 'Fire/Explosion', 'Vehicle Accident', 'Machinery Accident', 'Other'],
              (value) => setState(() => _accidentType = value),
            ),
            
            const SizedBox(height: 16),
            
            _buildSimpleTextField(
              controller: _causeOfDeathController,
              label: 'Cause of Death',
              hint: 'Only if applicable',
              icon: Icons.medical_information_outlined,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? icon,
    int maxLines = 1,
    String? helperText,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helperText,
        prefixIcon: icon != null ? Icon(icon) : null,
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
      ),
      maxLines: maxLines,
      validator: validator,
    );
  }

  Widget _buildDropdownCard(
    String label,
    String hint,
    String? value,
    List<String> items,
    ValueChanged<String?> onChanged,
  ) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
      ),
      items: items.map((item) => DropdownMenuItem(
        value: item,
        child: Text(item),
      )).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildSeveritySelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.warning_amber, color: AppColors.warningOrange, size: 20),
            const SizedBox(width: 8),
            Text(
              'Severity Level *',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildSeverityButton(
                'Low',
                AppColors.successGreen,
                _severityLevel == SeverityLevel.low,
                () => setState(() => _severityLevel = SeverityLevel.low),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSeverityButton(
                'Medium',
                AppColors.warningOrange,
                _severityLevel == SeverityLevel.medium,
                () => setState(() => _severityLevel = SeverityLevel.medium),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSeverityButton(
                'High',
                AppColors.errorRed,
                _severityLevel == SeverityLevel.high,
                () => setState(() => _severityLevel = SeverityLevel.high),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSeverityButton(String label, Color color, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color,
            width: 2.5, // Slightly thicker border for better visibility
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.4), // Slightly stronger shadow
                    blurRadius: 8,
                    spreadRadius: 1,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1), // Slightly stronger default shadow
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Column(
          children: [
            Icon(
              _getSeverityIcon(label),
              color: isSelected ? Colors.white : color,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getSeverityIcon(String severity) {
    switch (severity.toLowerCase()) {
      case 'low':
        return Icons.check_circle;
      case 'medium':
        return Icons.warning;
      case 'high':
        return Icons.dangerous;
      default:
        return Icons.help;
    }
  }

  Widget _buildDateCard() {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: _incidentDate ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        if (date != null) {
          setState(() => _incidentDate = date);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(4),
          color: Theme.of(context).colorScheme.surface,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today, color: AppColors.mediumGrey, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Date *',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const Spacer(),
                if (_incidentDate != null)
                  Icon(
                    Icons.check_circle,
                    color: AppColors.successGreen,
                    size: 16,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _incidentDate != null 
                ? '${_incidentDate!.day}/${_incidentDate!.month}/${_incidentDate!.year}'
                : 'Select date',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (_incidentDate != null)
              Text(
                'Current date auto-filled',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.successGreen,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeCard() {
    return InkWell(
      onTap: () async {
        final time = await showTimePicker(
          context: context,
          initialTime: _incidentTime ?? TimeOfDay.now(),
        );
        if (time != null) {
          setState(() => _incidentTime = time);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(4),
          color: Theme.of(context).colorScheme.surface,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.access_time, color: AppColors.mediumGrey, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Time',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const Spacer(),
                if (_incidentTime != null)
                  Icon(
                    Icons.check_circle,
                    color: AppColors.successGreen,
                    size: 16,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _incidentTime != null 
                ? _incidentTime!.format(context)
                : 'Select time',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (_incidentTime != null)
              Text(
                'Current time auto-filled',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.successGreen,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyButton() {
    if (_isEmergencyActive) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _isEmergencyActive ? _pulseAnimation.value : 1.0,
          child: GestureDetector(
            onLongPressStart: _isMobilePlatform ? (details) => _startHoldSequence() : null,
            onLongPressEnd: _isMobilePlatform ? (details) {
              if (_isHolding) {
                _cancelHoldSequence();
              }
            } : null,
            onLongPressCancel: _isMobilePlatform ? () {
              if (_isHolding) {
                _cancelHoldSequence();
              }
            } : null,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_isHolding && _isMobilePlatform)
                  AnimatedBuilder(
                    animation: _holdAnimation,
                    builder: (context, child) {
                      return Container(
                        width: 90,
                        height: 90,
                        child: CircularProgressIndicator(
                          value: _holdAnimation.value,
                          strokeWidth: 6,
                          backgroundColor: Colors.white.withOpacity(0.3),
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      );
                    },
                  ),
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isHolding 
                        ? AppColors.errorRed.withOpacity(1.0)
                        : AppColors.errorRed.withOpacity(0.8),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.errorRed.withOpacity(0.3),
                        blurRadius: _isHolding ? 15 : 10,
                        spreadRadius: _isHolding ? 4 : 2,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(40),
                      onTap: _handleEmergencyButtonPress,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.emergency,
                              size: _isHolding ? 32 : 36,
                              color: Colors.white,
                            ),
                            if (_isHolding && _isMobilePlatform)
                              Text(
                                '${3 - _holdSeconds}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            else if (!_isMobilePlatform)
                              const Text(
                                'CLICK',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmergencyOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: Card(
          margin: const EdgeInsets.all(32),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isHolding) ...[
                  AnimatedBuilder(
                    animation: _holdAnimation,
                    builder: (context, child) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 120,
                            height: 120,
                            child: CircularProgressIndicator(
                              value: _holdAnimation.value,
                              strokeWidth: 8,
                              backgroundColor: Colors.grey.shade300,
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.errorRed),
                            ),
                          ),
                          Text(
                            '${3 - _holdSeconds}',
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Hold to Activate Emergency...',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Release to cancel',
                    style: TextStyle(color: Colors.grey),
                  ),
                ] else if (_isCountingDown) ...[
                  AnimatedBuilder(
                    animation: _countdownAnimation,
                    builder: (context, child) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 120,
                            height: 120,
                            child: CircularProgressIndicator(
                              value: _countdownAnimation.value,
                              strokeWidth: 8,
                              backgroundColor: Colors.grey.shade300,
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.errorRed),
                            ),
                          ),
                          Text(
                            '$_countdownSeconds',
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Emergency Recording Starting...',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Location captured automatically',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        _cancelEmergency();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Emergency recording cancelled'),
                            backgroundColor: AppColors.warningOrange,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.warningOrange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'CANCEL',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ] else if (_isRecording) ...[
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.errorRed,
                    ),
                    child: const Icon(
                      Icons.mic,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'RECORDING...',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${10 - _recordingSeconds} seconds remaining',
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: _recordingSeconds / 10,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.errorRed),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Speak clearly about the emergency',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        _stopRecording();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Emergency recording stopped manually'),
                            backgroundColor: AppColors.warningOrange,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.warningOrange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'STOP RECORDING',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _cancelEmergency() {
    // Cancel all timers immediately
    _countdownTimer?.cancel();
    _recordingTimer?.cancel();
    _holdTimer?.cancel();
    _vibrationTimer?.cancel();
    
    // Stop all animations
    _pulseController.stop();
    _countdownController.reset();
    _holdController.reset();
    
    // Stop recording if active
    if (_isRecording) {
      try {
        _audioRecorder.stop();
      } catch (e) {
        print('Error stopping recording: $e');
      }
    }
    
    // Reset all state variables
    setState(() {
      _isEmergencyActive = false;
      _isCountingDown = false;
      _isRecording = false;
      _isHolding = false;
      _countdownSeconds = 4;
      _recordingSeconds = 0;
      _holdSeconds = 0;
    });
    
    print('Emergency cancelled - all states reset');
  }

  Future<void> _startHoldSequence() async {
    if (_isEmergencyActive || _isHolding) return;
    
    setState(() {
      _isHolding = true;
      _holdSeconds = 0;
    });

    _holdController.forward();
    _startHoldVibration();

    _holdTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _holdSeconds++;
      });

      if (_holdSeconds >= 3) {
        timer.cancel();
        _completeHoldSequence();
      }
    });
  }

  Future<void> _startHoldVibration() async {
    try {
      if (await Vibration.hasVibrator() ?? false) {
        _vibrationTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
          if (_isHolding) {
            Vibration.vibrate(duration: 100);
          } else {
            timer.cancel();
          }
        });
      }
    } catch (e) {
      print('Vibration not supported: $e');
    }
  }

  void _completeHoldSequence() {
    _holdTimer?.cancel();
    _vibrationTimer?.cancel();
    _holdController.reset();
    
    setState(() {
      _isHolding = false;
    });

    _startEmergencySequence();
  }

  void _cancelHoldSequence() {
    _holdTimer?.cancel();
    _vibrationTimer?.cancel();
    _holdController.reset();
    
    setState(() {
      _isHolding = false;
      _holdSeconds = 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Emergency activation cancelled'),
        backgroundColor: AppColors.warningOrange,
      ),
    );
  }

  Future<void> _startEmergencySequence() async {
    if (_isEmergencyActive) return;
    
    setState(() {
      _isEmergencyActive = true;
      _isCountingDown = true;
      _countdownSeconds = 4;
    });

    _pulseController.repeat(reverse: true);
    _countdownController.forward();
    await _captureEmergencyLocation();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      try {
        if (await Vibration.hasVibrator() ?? false) {
          Vibration.vibrate(duration: 200);
        }
      } catch (e) {
        // Ignore vibration errors
      }

      setState(() {
        _countdownSeconds--;
      });

      if (_countdownSeconds <= 0) {
        timer.cancel();
        _startRecording();
      }
    });
  }

  Future<void> _captureEmergencyLocation() async {
    try {
      if (kIsWeb || Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        _emergencyLocation = const LatLng(6.8013, -58.1551);
      } else {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (serviceEnabled) {
          LocationPermission permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.whileInUse || 
              permission == LocationPermission.always) {
            Position position = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high,
              timeLimit: const Duration(seconds: 5),
            );
            _emergencyLocation = LatLng(position.latitude, position.longitude);
          }
        }
      }
    } catch (e) {
      print('Emergency location capture failed: $e');
      _emergencyLocation = const LatLng(6.8013, -58.1551);
    }
  }

  Future<void> _startRecording() async {
    setState(() {
      _isCountingDown = false;
      _isRecording = true;
      _recordingSeconds = 0;
    });

    try {
      var status = await Permission.microphone.status;
      if (!status.isGranted) {
        status = await Permission.microphone.request();
        if (!status.isGranted) {
          _handleRecordingError('Microphone permission denied');
          return;
        }
      }

      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _recordingPath = '${directory.path}/emergency_$timestamp.aac';

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _recordingPath!,
      );

      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _recordingSeconds++;
        });

        if (_recordingSeconds >= 10) {
          timer.cancel();
          _stopRecording();
        }
      });

    } catch (e) {
      _handleRecordingError('Failed to start recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      await _audioRecorder.stop();
      _recordingTimer?.cancel();
      _pulseController.stop();
      _countdownController.reset();

      setState(() {
        _isRecording = false;
        _isEmergencyActive = false;
      });

      await _submitEmergencyReport();

    } catch (e) {
      _handleRecordingError('Failed to stop recording: $e');
    }
  }

  void _handleRecordingError(String message) {
    _cancelEmergency();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.errorRed,
      ),
    );
  }

  void _showDesktopEmergencyConfirmationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          icon: Icon(
            Icons.warning_amber,
            color: AppColors.errorRed,
            size: 48,
          ),
          title: const Text('Emergency Alert'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Are you sure you want to activate emergency recording?'),
              SizedBox(height: 16),
              Text(
                'This will:\n• Start a 4-second countdown\n• Record 10 seconds of audio\n• Capture your location\n• Send an emergency report',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _startEmergencySequence();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.errorRed,
                foregroundColor: Colors.white,
              ),
              child: const Text('Start Emergency'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showEmergencyConfirmationDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          icon: Icon(
            Icons.check_circle,
            color: AppColors.successGreen,
            size: 48,
          ),
          title: const Text('Emergency Report Sent'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Your emergency audio report has been submitted.'),
              const SizedBox(height: 16),
              if (_emergencyLocation != null)
                Text(
                  'Location: ${_emergencyLocation!.latitude.toStringAsFixed(6)}, ${_emergencyLocation!.longitude.toStringAsFixed(6)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              const SizedBox(height: 8),
              const Text(
                'Recording Duration: 10 seconds',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleEmergencyButtonPress() async {
    if (_isMobilePlatform) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Hold button for 3 seconds to activate emergency'),
          backgroundColor: AppColors.infoBlue,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      _showDesktopEmergencyConfirmationDialog();
    }
  }
}