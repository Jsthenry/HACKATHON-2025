import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../services/database_service.dart';
import '../models/report_model.dart';

class HSSEOfficerReportsPage extends StatefulWidget {
  final String companyDomain;
  final String officerEmail;

  const HSSEOfficerReportsPage({
    super.key,
    required this.companyDomain,
    required this.officerEmail,
  });

  @override
  State<HSSEOfficerReportsPage> createState() => _HSSEOfficerReportsPageState();
}

class _HSSEOfficerReportsPageState extends State<HSSEOfficerReportsPage> {
  final DatabaseService _databaseService = DatabaseService();
  List<Report> _reports = [];
  bool _isLoading = false;
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);
    try {
      final reports = await _databaseService.getAllReports();
      final filteredReports = reports.where((report) => 
        report.employerName?.toLowerCase().contains(widget.companyDomain.toLowerCase()) ?? false
      ).toList();
      
      setState(() {
        _reports = filteredReports;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: Column(
        children: [
          _buildHeader(),
          _buildFilters(),
          Expanded(child: _buildReportsList()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _exportReports(),
        backgroundColor: AppColors.successGreen,
        foregroundColor: Colors.white,
        icon: Icon(Icons.download),
        label: Text('Export'),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Text(
            'Investigation Center',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: _loadReports,
            icon: Icon(Icons.refresh),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildFilterChip('All', 'all'),
          _buildFilterChip('Need Review', 'submitted'),
          _buildFilterChip('Investigating', 'investigating'),
          _buildFilterChip('High Priority', 'high'),
          _buildFilterChip('My Cases', 'my_cases'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedFilter = value;
          });
        },
        backgroundColor: Colors.white,
        selectedColor: AppColors.primaryBlue.withOpacity(0.2),
      ),
    );
  }

  Widget _buildReportsList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_reports.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_outlined, size: 64, color: AppColors.mediumGrey),
            const SizedBox(height: 16),
            Text(
              'No reports found',
              style: TextStyle(
                fontSize: 18,
                color: AppColors.mediumGrey,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _reports.length,
      itemBuilder: (context, index) {
        final report = _reports[index];
        return _buildReportCard(report);
      },
    );
  }

  Widget _buildReportCard(Report report) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightGrey),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _getSeverityIcon(report.severityLevel),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            report.incidentType,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'ID: ${report.id.substring(0, 8)}...',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getStatusColor(report.status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        report.status.toUpperCase(),
                        style: TextStyle(
                          color: _getStatusColor(report.status),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                Text(
                  report.detailedDescription,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                
                const SizedBox(height: 12),
                
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: AppColors.mediumGrey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        report.locationText ?? 'No location',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.access_time, size: 16, color: AppColors.mediumGrey),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(report.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.lightGrey.withOpacity(0.3),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: () => _editReport(report),
                  icon: Icon(Icons.edit, size: 16),
                  label: Text('Edit Report'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.infoBlue,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _addUpdateLog(report),
                  icon: Icon(Icons.note_add, size: 16),
                  label: Text('Add Update'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.successGreen,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _viewReportDetails(report),
                  icon: Icon(Icons.visibility, size: 16),
                  label: Text('View'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.warningOrange,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _getSeverityIcon(String severity) {
    switch (severity) {
      case 'high':
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.errorRed.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.warning, color: AppColors.errorRed, size: 20),
        );
      case 'medium':
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.warningOrange.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.warning_amber, color: AppColors.warningOrange, size: 20),
        );
      case 'low':
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.successGreen.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.info, color: AppColors.successGreen, size: 20),
        );
      default:
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.mediumGrey.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.help, color: AppColors.mediumGrey, size: 20),
        );
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'submitted':
        return AppColors.infoBlue;
      case 'under_review':
        return AppColors.warningOrange;
      case 'investigating':
        return AppColors.errorRed;
      case 'resolved':
        return AppColors.successGreen;
      default:
        return AppColors.mediumGrey;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inMinutes}m ago';
    }
  }

  void _editReport(Report report) {
    showDialog(
      context: context,
      builder: (context) => _EditReportDialog(
        report: report,
        officerEmail: widget.officerEmail,
        onReportUpdated: () => _loadReports(),
      ),
    );
  }

  void _addUpdateLog(Report report) {
    showDialog(
      context: context,
      builder: (context) => _AddUpdateLogDialog(
        report: report,
        officerEmail: widget.officerEmail,
        onUpdateAdded: () => _loadReports(),
      ),
    );
  }

  void _viewReportDetails(Report report) {
    showDialog(
      context: context,
      builder: (context) => _ReportDetailsDialog(report: report),
    );
  }

  void _exportReports() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Exporting ${_reports.length} reports...'),
        backgroundColor: AppColors.successGreen,
      ),
    );
  }
}

class _EditReportDialog extends StatefulWidget {
  final Report report;
  final String officerEmail;
  final VoidCallback onReportUpdated;

  const _EditReportDialog({
    required this.report,
    required this.officerEmail,
    required this.onReportUpdated,
  });

  @override
  State<_EditReportDialog> createState() => _EditReportDialogState();
}

class _EditReportDialogState extends State<_EditReportDialog> {
  late String _selectedSeverity;
  late String _selectedStatus;
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedSeverity = widget.report.severityLevel;
    _selectedStatus = widget.report.status;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.edit, color: AppColors.primaryBlue),
                const SizedBox(width: 8),
                Text(
                  'Edit Report',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            Text(
              'Report: ${widget.report.incidentType}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            
            const SizedBox(height: 16),
            
            Text('Severity Level'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedSeverity,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              items: [
                DropdownMenuItem(value: 'low', child: Text('Low')),
                DropdownMenuItem(value: 'medium', child: Text('Medium')),
                DropdownMenuItem(value: 'high', child: Text('High')),
              ],
              onChanged: (value) => setState(() => _selectedSeverity = value!),
            ),
            
            const SizedBox(height: 16),
            
            Text('Status'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedStatus,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              items: [
                DropdownMenuItem(value: 'submitted', child: Text('Submitted')),
                DropdownMenuItem(value: 'under_review', child: Text('Under Review')),
                DropdownMenuItem(value: 'investigating', child: Text('Investigating')),
                DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
                DropdownMenuItem(value: 'closed', child: Text('Closed')),
              ],
              onChanged: (value) => setState(() => _selectedStatus = value!),
            ),
            
            const SizedBox(height: 16),
            
            Text('Officer Notes'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesController,
              decoration: InputDecoration(
                hintText: 'Add investigation notes or comments...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              maxLines: 3,
            ),
            
            const SizedBox(height: 24),
            
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onReportUpdated();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Report updated successfully by ${widget.officerEmail}'),
                          backgroundColor: AppColors.successGreen,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                    ),
                    child: Text('Update Report'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }
}

class _AddUpdateLogDialog extends StatefulWidget {
  final Report report;
  final String officerEmail;
  final VoidCallback onUpdateAdded;

  const _AddUpdateLogDialog({
    required this.report,
    required this.officerEmail,
    required this.onUpdateAdded,
  });

  @override
  State<_AddUpdateLogDialog> createState() => _AddUpdateLogDialogState();
}

class _AddUpdateLogDialogState extends State<_AddUpdateLogDialog> {
  final _updateController = TextEditingController();
  String _selectedUpdateType = 'investigation';

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.note_add, color: AppColors.successGreen),
                const SizedBox(width: 8),
                Text(
                  'Add Update Log',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            Text(
              'Report: ${widget.report.incidentType}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            
            const SizedBox(height: 16),
            
            Text('Update Type'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedUpdateType,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              items: [
                DropdownMenuItem(value: 'investigation', child: Text('Investigation Update')),
                DropdownMenuItem(value: 'action_taken', child: Text('Action Taken')),
                DropdownMenuItem(value: 'follow_up', child: Text('Follow-up Required')),
                DropdownMenuItem(value: 'evidence', child: Text('Evidence Collected')),
                DropdownMenuItem(value: 'resolution', child: Text('Resolution Update')),
              ],
              onChanged: (value) => setState(() => _selectedUpdateType = value!),
            ),
            
            const SizedBox(height: 16),
            
            Text('Update Details'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _updateController,
              decoration: InputDecoration(
                hintText: 'Enter detailed update information...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              maxLines: 4,
              validator: (value) => value?.isEmpty == true ? 'Update details are required' : null,
            ),
            
            const SizedBox(height: 16),
            
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.infoBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.infoBlue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: AppColors.infoBlue, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This update will be logged with timestamp and your officer ID for audit trail.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      if (_updateController.text.isNotEmpty) {
                        Navigator.pop(context);
                        widget.onUpdateAdded();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Update log added by ${widget.officerEmail}'),
                            backgroundColor: AppColors.successGreen,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.successGreen,
                      foregroundColor: Colors.white,
                    ),
                    child: Text('Add Update'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _updateController.dispose();
    super.dispose();
  }
}

class _ReportDetailsDialog extends StatelessWidget {
  final Report report;

  const _ReportDetailsDialog({required this.report});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Report Details',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // ...existing code from company_reports_page.dart _ReportDetailsDialog...
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                ),
                child: Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
