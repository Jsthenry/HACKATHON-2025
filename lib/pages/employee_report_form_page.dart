import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../models/incident_report.dart';
import '../models/report_model.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';

class EmployeeReportFormPage extends StatefulWidget {
  final String employeeEmail;
  final String companyDomain;

  const EmployeeReportFormPage({
    super.key,
    required this.employeeEmail,
    required this.companyDomain,
  });

  @override
  State<EmployeeReportFormPage> createState() => _EmployeeReportFormPageState();
}

class _EmployeeReportFormPageState extends State<EmployeeReportFormPage> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseService _databaseService = DatabaseService();
  
  // Controllers
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _immediateActionController = TextEditingController();
  final _witnessController = TextEditingController();
  final _equipmentController = TextEditingController();
  
  // Form data
  String? _incidentType;
  DateTime? _incidentDate;
  TimeOfDay? _incidentTime;
  SeverityLevel _severityLevel = SeverityLevel.medium;
  String? _departmentAffected;
  String? _rootCause;
  bool _requiresMedicalAttention = false;
  bool _resultedInPropertyDamage = false;
  bool _reportToAuthorities = false;
  
  // Location and files
  LatLng? _currentLocation;
  bool _isLoadingLocation = false;
  List<PlatformFile> _selectedFiles = [];
  List<XFile> _selectedImages = [];
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _setCurrentDateTime();
  }

  @override
  void dispose() {
    _locationController.dispose();
    _descriptionController.dispose();
    _immediateActionController.dispose();
    _witnessController.dispose();
    _equipmentController.dispose();
    super.dispose();
  }

  void _setCurrentDateTime() {
    final now = DateTime.now();
    setState(() {
      _incidentDate = now;
      _incidentTime = TimeOfDay.fromDateTime(now);
    });
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate() || _incidentType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    try {
      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              CircularProgressIndicator(strokeWidth: 2),
              SizedBox(width: 16),
              Text('Submitting internal report...'),
            ],
          ),
          duration: Duration(seconds: 30),
        ),
      );

      // Create employee report
      final report = Report(
        id: _databaseService.generateId(),
        incidentNumber: '', // Auto-generated
        reportType: 'employee', // Internal company report
        incidentType: _incidentType!,
        severityLevel: _severityLevel.name,
        status: 'submitted',
        incidentDate: _incidentDate ?? DateTime.now(),
        incidentTime: _incidentTime?.format(context) ?? TimeOfDay.now().format(context),
        locationText: _locationController.text.isNotEmpty ? _locationController.text : null,
        latitude: _currentLocation?.latitude,
        longitude: _currentLocation?.longitude,
        detailedDescription: _buildDetailedDescription(),
        submittedAnonymously: false, // Employee reports are not anonymous
        priorityScore: _databaseService.calculatePriorityScore(_severityLevel.name, 'employee'),
        // companyId will be auto-assigned by database trigger
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Submit with files
      final savedReport = await _databaseService.saveReportWithFiles(
        report: report,
        documentFiles: _selectedFiles.isNotEmpty ? _selectedFiles : null,
        imageFiles: _selectedImages.isNotEmpty ? _selectedImages : null,
      );

      // Save reporter info (not anonymous for employee reports)
      final reporterInfo = ReporterInfo(
        id: _databaseService.generateId(),
        reportId: savedReport.id,
        name: widget.employeeEmail.split('@')[0].replaceAll('.', ' ').toUpperCase(),
        email: widget.employeeEmail,
        phone: null,
        organization: widget.companyDomain,
        isAnonymous: false,
        ipAddress: null,
        createdAt: DateTime.now(),
      );

      await _databaseService.saveReporterInfo(reporterInfo);

      // Hide loading
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      // Show success
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Internal report submitted successfully!',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('Incident #${savedReport.incidentNumber}'),
              Text('Your HSSE team has been notified.'),
            ],
          ),
          backgroundColor: AppColors.successGreen,
          duration: const Duration(seconds: 5),
        ),
      );

      // Return to dashboard
      Navigator.pop(context);

    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit report: $e'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  String _buildDetailedDescription() {
    String description = _descriptionController.text;
    
    if (_departmentAffected != null) {
      description += '\n\nDepartment Affected: $_departmentAffected';
    }
    
    if (_rootCause != null) {
      description += '\nRoot Cause: $_rootCause';
    }
    
    if (_immediateActionController.text.isNotEmpty) {
      description += '\n\nImmediate Action Taken: ${_immediateActionController.text}';
    }
    
    if (_witnessController.text.isNotEmpty) {
      description += '\nWitnesses: ${_witnessController.text}';
    }
    
    if (_equipmentController.text.isNotEmpty) {
      description += '\nEquipment Involved: ${_equipmentController.text}';
    }
    
    if (_requiresMedicalAttention) {
      description += '\n\n⚠️ REQUIRES MEDICAL ATTENTION';
    }
    
    if (_resultedInPropertyDamage) {
      description += '\n💰 RESULTED IN PROPERTY DAMAGE';
    }
    
    if (_reportToAuthorities) {
      description += '\n🚨 RECOMMENDED FOR AUTHORITIES';
    }
    
    return description;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Submit Internal Report'),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildIncidentBasics(),
              const SizedBox(height: 24),
              _buildLocationSection(),
              const SizedBox(height: 24),
              _buildDescriptionSection(),
              const SizedBox(height: 24),
              _buildCompanySpecific(),
              const SizedBox(height: 24),
              _buildFilesSection(),
              const SizedBox(height: 24),
              _buildSubmitSection(),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryBlue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.business, color: AppColors.primaryBlue),
              const SizedBox(width: 8),
              Text(
                'Internal Company Report',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Employee: ${widget.employeeEmail}'),
          Text('Company: ${widget.companyDomain}'),
          const SizedBox(height: 8),
          Text(
            'This report will be sent to your company\'s HSSE team for internal review and action.',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildIncidentBasics() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Incident Information',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            DropdownButtonFormField<String>(
              value: _incidentType,
              decoration: const InputDecoration(
                labelText: 'Type of Incident *',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'Workplace Injury', child: Text('Workplace Injury')),
                DropdownMenuItem(value: 'Near Miss', child: Text('Near Miss')),
                DropdownMenuItem(value: 'Equipment Failure', child: Text('Equipment Failure')),
                DropdownMenuItem(value: 'Safety Violation', child: Text('Safety Violation')),
                DropdownMenuItem(value: 'Environmental Spill', child: Text('Environmental Spill')),
                DropdownMenuItem(value: 'Fire/Explosion', child: Text('Fire/Explosion')),
                DropdownMenuItem(value: 'Chemical Exposure', child: Text('Chemical Exposure')),
                DropdownMenuItem(value: 'Fall from Height', child: Text('Fall from Height')),
                DropdownMenuItem(value: 'Vehicle Incident', child: Text('Vehicle Incident')),
                DropdownMenuItem(value: 'Other', child: Text('Other')),
              ],
              onChanged: (value) => setState(() => _incidentType = value),
              validator: (value) => value == null ? 'Please select incident type' : null,
            ),
            
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(child: _buildDateField()),
                const SizedBox(width: 16),
                Expanded(child: _buildTimeField()),
              ],
            ),
            
            const SizedBox(height: 16),
            
            _buildSeveritySelection(),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Location Details',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _locationController,
                    decoration: const InputDecoration(
                      labelText: 'Specific Location *',
                      hintText: 'Building, floor, room, or outdoor area',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                    validator: (value) => value?.isEmpty == true ? 'Location is required' : null,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _isLoadingLocation ? null : _getCurrentLocation,
                  icon: _isLoadingLocation 
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.my_location, color: AppColors.primaryBlue),
                  tooltip: 'Get GPS coordinates',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Incident Description',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Detailed Description *',
                hintText: 'What happened? How did it happen? What were the circumstances?',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
              validator: (value) => value?.isEmpty == true ? 'Description is required' : null,
            ),
            
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _immediateActionController,
              decoration: const InputDecoration(
                labelText: 'Immediate Action Taken',
                hintText: 'What steps were taken immediately after the incident?',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _witnessController,
                    decoration: const InputDecoration(
                      labelText: 'Witnesses',
                      hintText: 'Names of people who saw the incident',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _equipmentController,
                    decoration: const InputDecoration(
                      labelText: 'Equipment Involved',
                      hintText: 'Machinery, tools, vehicles, etc.',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanySpecific() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Company-Specific Information',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _departmentAffected,
                    decoration: const InputDecoration(
                      labelText: 'Department/Area',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Operations', child: Text('Operations')),
                      DropdownMenuItem(value: 'Maintenance', child: Text('Maintenance')),
                      DropdownMenuItem(value: 'Administration', child: Text('Administration')),
                      DropdownMenuItem(value: 'Security', child: Text('Security')),
                      DropdownMenuItem(value: 'Logistics', child: Text('Logistics')),
                      DropdownMenuItem(value: 'Quality Control', child: Text('Quality Control')),
                      DropdownMenuItem(value: 'Other', child: Text('Other')),
                    ],
                    onChanged: (value) => setState(() => _departmentAffected = value),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _rootCause,
                    decoration: const InputDecoration(
                      labelText: 'Root Cause',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Human Error', child: Text('Human Error')),
                      DropdownMenuItem(value: 'Equipment Failure', child: Text('Equipment Failure')),
                      DropdownMenuItem(value: 'Process Issue', child: Text('Process Issue')),
                      DropdownMenuItem(value: 'Environmental Factor', child: Text('Environmental Factor')),
                      DropdownMenuItem(value: 'Training Gap', child: Text('Training Gap')),
                      DropdownMenuItem(value: 'System Failure', child: Text('System Failure')),
                      DropdownMenuItem(value: 'Unknown', child: Text('Unknown')),
                    ],
                    onChanged: (value) => setState(() => _rootCause = value),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            Column(
              children: [
                CheckboxListTile(
                  title: const Text('Requires Medical Attention'),
                  subtitle: const Text('Someone was injured and needs medical care'),
                  value: _requiresMedicalAttention,
                  onChanged: (value) => setState(() => _requiresMedicalAttention = value ?? false),
                  activeColor: AppColors.errorRed,
                ),
                CheckboxListTile(
                  title: const Text('Resulted in Property Damage'),
                  subtitle: const Text('Equipment, facilities, or materials were damaged'),
                  value: _resultedInPropertyDamage,
                  onChanged: (value) => setState(() => _resultedInPropertyDamage = value ?? false),
                  activeColor: AppColors.warningOrange,
                ),
                CheckboxListTile(
                  title: const Text('Should be Reported to Authorities'),
                  subtitle: const Text('Incident severity requires external reporting'),
                  value: _reportToAuthorities,
                  onChanged: (value) => setState(() => _reportToAuthorities = value ?? false),
                  activeColor: AppColors.errorRed,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Supporting Evidence',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Photos, documents, or videos that support this report',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            
            // Upload buttons
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ElevatedButton.icon(
                  onPressed: _pickImages,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Add Photos'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _pickFiles,
                  icon: const Icon(Icons.attach_file),
                  label: const Text('Add Files'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.successGreen,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            
            if (_selectedFiles.isNotEmpty || _selectedImages.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  '${_selectedFiles.length + _selectedImages.length} file(s) selected',
                  style: TextStyle(color: AppColors.successGreen),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitSection() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Cancel'),
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
            ),
            child: const Text('Submit Internal Report'),
          ),
        ),
      ],
    );
  }

  // Helper methods
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
      final List<XFile> images = await _imagePicker.pickMultiImage(
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
