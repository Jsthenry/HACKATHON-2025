import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'dart:async';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vibration/vibration.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geocoding/geocoding.dart';
import 'employee_report_form_page.dart';
import '../theme/app_colors.dart';
import '../services/database_service.dart';
import '../models/report_model.dart';
import '../models/incident_report.dart'; // Add this import

class EmployeeReportPage extends StatefulWidget {
  const EmployeeReportPage({super.key});

  @override
  State<EmployeeReportPage> createState() => _EmployeeReportPageState();
}

class _EmployeeReportPageState extends State<EmployeeReportPage> with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _locationController = TextEditingController();
  String? _detectedCompany;
  int _currentStep = 1;
  DateTime? _incidentDate;
  TimeOfDay? _incidentTime;
  SeverityLevel? _severityLevel;
  LatLng? _currentLocation;
  bool _isLoadingLocation = false;
  final List<PlatformFile> _selectedFiles = [];
  final List<XFile> _selectedImages = [];

  // Emergency recording variables
  final DatabaseService _databaseService = DatabaseService();
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

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: const Text('Employee Report'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      body: Stack(
        children: [
          // Main content
          SafeArea(
            child: Column(
              children: [
                _buildStepIndicator(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _buildMainCard(),
                        const SizedBox(height: 20),
                        if (_detectedCompany != null) _buildCompanyDetectedCard(),
                        const SizedBox(height: 32),
                        _buildContinueButton(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Emergency overlay
          if (_isEmergencyActive || _isHolding) _buildEmergencyOverlay(),
        ],
      ),
      floatingActionButton: _buildEmergencyButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          _buildStepCircle(1, 'Details', _currentStep >= 1),
          Expanded(child: _buildStepLine(_currentStep > 1)),
          _buildStepCircle(2, 'Description', _currentStep >= 2),
          Expanded(child: _buildStepLine(_currentStep > 2)),
          _buildStepCircle(3, 'Reporter', _currentStep >= 3),
          Expanded(child: _buildStepLine(_currentStep > 3)),
          _buildStepCircle(4, 'Submit', _currentStep >= 4),
        ],
      ),
    );
  }

  Widget _buildStepCircle(int step, String label, bool isActive) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isActive ? AppColors.primaryBlue : AppColors.lightGrey,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$step',
              style: TextStyle(
                color: isActive ? Colors.white : AppColors.mediumGrey,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isActive ? AppColors.primaryBlue : AppColors.mediumGrey,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(bool isCompleted) {
    return Container(
      height: 2,
      margin: const EdgeInsets.only(bottom: 20),
      color: isCompleted ? AppColors.primaryBlue : AppColors.lightGrey,
    );
  }

  Widget _buildMainCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.lightGrey),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.business,
              size: 40,
              color: AppColors.primaryBlue,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Employee HSSE Report',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Submit a report through your company\'s HSSE system',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          _buildEmailField(),
        ],
      ),
    );
  }

  Widget _buildEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.email_outlined, color: AppColors.primaryBlue, size: 20),
            const SizedBox(width: 8),
            Text(
              'Company Email Address',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.lightGrey),
          ),
          child: TextField(
            controller: _emailController,
            decoration: InputDecoration(
              hintText: 'your.name@company.com',
              prefixIcon: Padding(
                padding: const EdgeInsets.all(12),
                child: Icon(Icons.email_outlined, color: AppColors.mediumGrey),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            keyboardType: TextInputType.emailAddress,
            onChanged: _onEmailChanged,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'We use your email domain to route the report to your company',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildCompanyDetectedCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.successGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.successGreen.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.successGreen.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check, color: AppColors.successGreen, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Company Detected',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.successGreen,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your report will be routed to: $_detectedCompany',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'The report will be anonymous to your colleagues but visible to your company\'s HSSE team',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContinueButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: _detectedCompany != null 
          ? LinearGradient(
              colors: [AppColors.primaryBlue, AppColors.primaryBlueDark],
            )
          : null,
        color: _detectedCompany == null ? AppColors.lightGrey : null,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _detectedCompany != null ? _continueToReport : null,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: Text(
              'Continue to Report Form',
              style: TextStyle(
                color: _detectedCompany != null ? Colors.white : AppColors.mediumGrey,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onEmailChanged(String email) {
    if (email.contains('@') && email.split('@').length == 2) {
      final domain = email.split('@')[1].toLowerCase();
      if (domain.isNotEmpty && domain.contains('.')) {
        setState(() {
          _detectedCompany = domain;
        });
      }
    } else {
      setState(() {
        _detectedCompany = null;
      });
    }
  }

  void _continueToReport() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EmployeeReportFormPage(
          employeeEmail: _emailController.text,
          companyDomain: _detectedCompany!,
        ),
      ),
    );
  }

  Future<void> _handleSOSButtonPress() async {
    if (_isMobilePlatform) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Use floating emergency button or hold for 3 seconds'),
          backgroundColor: AppColors.infoBlue,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      _showDesktopEmergencyConfirmationDialog();
    }
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
                      onTap: _handleSOSButtonPress,
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
                  // Countdown UI
                ] else if (_isRecording) ...[
                  // Recording UI
                ],
              ],
            ),
          ),
        ),
      ),
    );
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

  Future<void> _submitEmergencyReport() async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Emergency report submitted successfully!'),
        backgroundColor: AppColors.errorRed,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _cancelEmergency() {
    _countdownTimer?.cancel();
    _recordingTimer?.cancel();
    _holdTimer?.cancel();
    _vibrationTimer?.cancel();
    _pulseController.stop();
    _countdownController.reset();
    _holdController.reset();
    
    setState(() {
      _isEmergencyActive = false;
      _isCountingDown = false;
      _isRecording = false;
      _isHolding = false;
      _countdownSeconds = 4;
      _recordingSeconds = 0;
      _holdSeconds = 0;
    });
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

  Widget _buildDateField() {
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
                Icon(Icons.calendar_today, color: AppColors.primaryBlue, size: 20),
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
          ],
        ),
      ),
    );
  }

  Widget _buildTimeField() {
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
                Icon(Icons.access_time, color: AppColors.primaryBlue, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Time *',
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
          ],
        ),
      ),
    );
  }

  Widget _buildSeveritySelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Severity Level *',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: SeverityLevel.values.map((level) {
            return ChoiceChip(
              label: Text(level.displayName),
              selected: _severityLevel == level,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _severityLevel = level);
                }
              },
              backgroundColor: level.color.withOpacity(0.1),
              selectedColor: level.color.withOpacity(0.3),
              labelStyle: TextStyle(
                color: _severityLevel == level ? Colors.white : level.color,
                fontWeight: FontWeight.bold,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions denied');
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _currentLocation = LatLng(position.latitude, position.longitude);

      // Get address
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          String address = '';
          
          if (place.street != null) address += place.street!;
          if (place.subLocality != null) {
            if (address.isNotEmpty) address += ', ';
            address += place.subLocality!;
          }
          if (place.locality != null) {
            if (address.isNotEmpty) address += ', ';
            address += place.locality!;
          }

          _locationController.text = address;
        }
      } catch (e) {
        _locationController.text = 'Lat: ${position.latitude.toStringAsFixed(6)}, Lng: ${position.longitude.toStringAsFixed(6)}';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Location captured successfully!'),
          backgroundColor: AppColors.successGreen,
        ),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error getting location: $e'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    } finally {
      setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _pickFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'jpg', 'jpeg', 'png', 'mp4', 'mov'],
        allowMultiple: true,
        withData: true,
      );

      if (result != null) {
        final validFiles = result.files.where((file) => file.size <= 10 * 1024 * 1024).toList();
        
        setState(() {
          _selectedFiles.addAll(validFiles);
        });
        
        if (validFiles.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${validFiles.length} file(s) added'),
              backgroundColor: AppColors.successGreen,
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking files: $e'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await ImagePicker().pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      setState(() {
        _selectedImages.addAll(images);
      });
      
      if (images.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${images.length} image(s) added'),
            backgroundColor: AppColors.successGreen,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking images: $e'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }
}
