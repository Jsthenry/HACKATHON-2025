import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../models/report_model.dart';
import '../theme/app_colors.dart';
import '../widgets/report_card.dart';
import '../widgets/loading_widget.dart';
import '../widgets/empty_state_widget.dart';
import 'employee_report_page.dart';
import 'citizen_report_page.dart';
import 'employee_report_form_page.dart';

class EmployeeDashboardPage extends StatefulWidget {
  final String employeeEmail;
  final String companyDomain;

  const EmployeeDashboardPage({
    super.key,
    required this.employeeEmail,
    required this.companyDomain,
  });

  @override
  State<EmployeeDashboardPage> createState() => _EmployeeDashboardPageState();
}

class _EmployeeDashboardPageState extends State<EmployeeDashboardPage> {
  final DatabaseService _databaseService = DatabaseService();
  
  List<Report> _reports = [];
  bool _isLoading = true;
  String _error = '';
  
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    try {
      setState(() {
        _isLoading = true;
        _error = '';
      });

      // Get reports for this company
      final reports = await _databaseService.getReportsByCompany(widget.companyDomain);
      
      setState(() {
        _reports = reports;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _signOut() async {
    try {
      await AuthService.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const CitizenReportPage()),
          (route) => false,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sign out failed: $e'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text('Employee Dashboard'),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'profile':
                  // TODO: Implement profile settings
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profile Settings - Coming Soon')),
                  );
                  break;
                case 'guidelines':
                  // TODO: Implement safety guidelines
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Safety Guidelines - Coming Soon')),
                  );
                  break;
                case 'help':
                  // TODO: Implement help & support
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Help & Support - Coming Soon')),
                  );
                  break;
                case 'signout':
                  _signOut();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profile',
                child: ListTile(
                  leading: Icon(Icons.person),
                  title: Text('Profile Settings'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'guidelines',
                child: ListTile(
                  leading: Icon(Icons.policy),
                  title: Text('Safety Guidelines'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'help',
                child: ListTile(
                  leading: Icon(Icons.help),
                  title: Text('Help & Support'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'signout',
                child: ListTile(
                  leading: Icon(Icons.logout, color: Colors.red),
                  title: Text('Sign Out', style: TextStyle(color: Colors.red)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildDashboardTab(),
          _buildMyReportsTab(),
          _buildAnalyticsTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment),
            label: 'My Reports',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EmployeeReportFormPage(
              employeeEmail: widget.employeeEmail,
              companyDomain: widget.companyDomain,
            ),
          ),
        ).then((_) => _loadReports()), // Refresh reports after submission
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Report'),
      ),
    );
  }

  Widget _buildDashboardTab() {
    return RefreshIndicator(
      onRefresh: _loadReports,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeCard(),
            const SizedBox(height: 24),
            _buildQuickStats(),
            const SizedBox(height: 24),
            _buildRecentReports(),
            const SizedBox(height: 100), // Space for FAB
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.employeeEmail,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Company: ${widget.companyDomain}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.8),
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
                  Icons.business,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    final totalReports = _reports.length;
    final myReports = _reports.where((r) => r.reportType == 'employee').length;
    final highPriorityReports = _reports.where((r) => r.severityLevel == 'high').length;
    final pendingReports = _reports.where((r) => r.status == 'submitted' || r.status == 'under_review').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Overview',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Reports',
                totalReports.toString(),
                Icons.assignment,
                AppColors.infoBlue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'My Reports',
                myReports.toString(),
                Icons.person,
                AppColors.primaryBlue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'High Priority',
                highPriorityReports.toString(),
                Icons.priority_high,
                AppColors.errorRed,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Pending',
                pendingReports.toString(),
                Icons.pending,
                AppColors.warningOrange,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentReports() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Recent Reports',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => setState(() => _currentIndex = 1),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        if (_isLoading)
          const LoadingWidget()
        else if (_error.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.errorRed.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.errorRed.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Icon(Icons.error, color: AppColors.errorRed),
                const SizedBox(height: 8),
                Text('Error loading reports: $_error'),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _loadReports,
                  child: const Text('Retry'),
                ),
              ],
            ),
          )
        else if (_reports.isEmpty)
          const EmptyStateWidget(
            icon: Icons.assignment,
            title: 'No Reports Yet',
            subtitle: 'Submit your first report to get started',
          )
        else
          Column(
            children: _reports
                .take(3) // Show only recent 3 reports
                .map((report) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ReportCard(
                    report: report,
                    onTap: () => _showReportDetails(report),
                  ),
                ))
                .toList(),
          ),
      ],
    );
  }

  Widget _buildMyReportsTab() {
    // Filter reports by current user (employee reports only)
    final myReports = _reports.where((r) => r.reportType == 'employee').toList();

    return RefreshIndicator(
      onRefresh: _loadReports,
      child: _isLoading
          ? const LoadingWidget()
          : myReports.isEmpty
              ? const EmptyStateWidget(
                  icon: Icons.assignment,
                  title: 'No Reports Submitted',
                  subtitle: 'Start by submitting your first internal report',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: myReports.length,
                  itemBuilder: (context, index) {
                    final report = myReports[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ReportCard(
                        report: report,
                        onTap: () => _showReportDetails(report),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildAnalyticsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Company Analytics',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.infoBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.infoBlue.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Icon(Icons.analytics, color: AppColors.infoBlue, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Company Analytics - Coming Soon',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.infoBlue,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Detailed analytics for your company\'s HSSE performance will be available soon.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showReportDetails(Report report) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with incident number and status
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Incident #${report.incidentNumber}',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                report.incidentType,
                                style: TextStyle(
                                  fontSize: 16,
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
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _getStatusColor(report.status)),
                          ),
                          child: Text(
                            report.status.toUpperCase(),
                            style: TextStyle(
                              color: _getStatusColor(report.status),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Report details
                    _buildDetailRow('Date', '${report.incidentDate.day}/${report.incidentDate.month}/${report.incidentDate.year}'),
                    _buildDetailRow('Time', report.incidentTime),
                    _buildDetailRow('Severity', report.severityLevel.toUpperCase()),
                    if (report.locationText != null)
                      _buildDetailRow('Location', report.locationText!),
                    
                    const SizedBox(height: 20),
                    
                    Text(
                      'Description',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      report.detailedDescription,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    Text(
                      'Submission Info',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildDetailRow('Submitted', '${report.createdAt.day}/${report.createdAt.month}/${report.createdAt.year} at ${report.createdAt.hour.toString().padLeft(2, '0')}:${report.createdAt.minute.toString().padLeft(2, '0')}'),
                    _buildDetailRow('Priority Score', '${report.priorityScore}'),
                    _buildDetailRow('Anonymous', report.submittedAnonymously ? 'Yes' : 'No'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
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
              style: TextStyle(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'submitted':
        return AppColors.infoBlue;
      case 'under_review':
        return AppColors.warningOrange;
      case 'investigating':
        return AppColors.warningOrange;
      case 'resolved':
        return AppColors.successGreen;
      case 'closed':
        return AppColors.textSecondary;
      default:
        return AppColors.textSecondary;
    }
  }
}