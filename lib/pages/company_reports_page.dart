import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../services/database_service.dart';
import '../models/report_model.dart';

class CompanyReportsPage extends StatefulWidget {
  final String companyDomain;

  const CompanyReportsPage({super.key, required this.companyDomain});

  @override
  State<CompanyReportsPage> createState() => _CompanyReportsPageState();
}

class _CompanyReportsPageState extends State<CompanyReportsPage> {
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
            'Reports Management',
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
          _buildFilterChip('Submitted', 'submitted'),
          _buildFilterChip('Under Review', 'under_review'),
          _buildFilterChip('High Priority', 'high'),
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
                  onPressed: () => _viewReportDetails(report),
                  icon: Icon(Icons.visibility, size: 16),
                  label: Text('View Details'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.infoBlue,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _updateReportStatus(report),
                  icon: Icon(Icons.edit, size: 16),
                  label: Text('Update Status'),
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

  void _viewReportDetails(Report report) {
    showDialog(
      context: context,
      builder: (context) => _ReportDetailsDialog(report: report),
    );
  }

  void _updateReportStatus(Report report) {
    showDialog(
      context: context,
      builder: (context) => _UpdateStatusDialog(
        report: report,
        onStatusUpdated: () => _loadReports(),
      ),
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
            
            _DetailRow('Report ID', report.id.substring(0, 8) + '...'),
            _DetailRow('Type', report.incidentType),
            _DetailRow('Severity', report.severityLevel.toUpperCase()),
            _DetailRow('Status', report.status.toUpperCase()),
            _DetailRow('Date', report.incidentDate.toString().split(' ')[0]),
            _DetailRow('Time', report.incidentTime),
            _DetailRow('Location', report.locationText ?? 'Not specified'),
            
            const SizedBox(height: 16),
            
            Text(
              'Description',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              report.detailedDescription,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            
            const SizedBox(height: 24),
            
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

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _UpdateStatusDialog extends StatefulWidget {
  final Report report;
  final VoidCallback onStatusUpdated;

  const _UpdateStatusDialog({
    required this.report,
    required this.onStatusUpdated,
  });

  @override
  State<_UpdateStatusDialog> createState() => _UpdateStatusDialogState();
}

class _UpdateStatusDialogState extends State<_UpdateStatusDialog> {
  late String _selectedStatus;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.report.status;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Update Report Status'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Report: ${widget.report.incidentType}'),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedStatus,
            decoration: InputDecoration(
              labelText: 'Status',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            items: [
              'submitted',
              'under_review',
              'investigating',
              'resolved',
              'closed',
            ].map((status) => DropdownMenuItem(
              value: status,
              child: Text(status.toUpperCase()),
            )).toList(),
            onChanged: (value) => setState(() => _selectedStatus = value!),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            widget.onStatusUpdated();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Status updated to $_selectedStatus'),
                backgroundColor: AppColors.successGreen,
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryBlue,
            foregroundColor: Colors.white,
          ),
          child: Text('Update'),
        ),
      ],
    );
  }
}
