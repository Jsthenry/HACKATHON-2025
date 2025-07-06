import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../models/report_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/report_card.dart';
import '../widgets/loading_widget.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/reports_overview_map.dart';
import '../widgets/common_widgets.dart';
import 'citizen_report_page.dart';
import 'user_management_page.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final DatabaseService _databaseService = DatabaseService();
  
  List<Report> _allReports = [];
  bool _isLoading = true;
  String _error = '';
  
  int _currentIndex = 0;
  String _selectedReportType = 'all';
  String _selectedStatus = 'all';

  @override
  void initState() {
    super.initState();
    _loadAllReports();
  }

  Future<void> _loadAllReports() async {
    try {
      setState(() {
        _isLoading = true;
        _error = '';
      });

      // Admin can see all reports
      final reports = await _databaseService.getAllReports();
      
      setState(() {
        _allReports = reports;
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
        title: Row(
          children: [
            Icon(Icons.admin_panel_settings, color: Colors.white),
            const SizedBox(width: 8),
            Text('System Administrator'),
          ],
        ),
        backgroundColor: AppColors.errorRed,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'settings':
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('System Settings - Coming Soon')),
                  );
                  break;
                case 'users':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const UserManagementPage(),
                    ),
                  );
                  break;
                case 'reports':
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Report Management - Coming Soon')),
                  );
                  break;
                case 'signout':
                  _signOut();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  leading: Icon(Icons.settings),
                  title: Text('System Settings'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'users',
                child: ListTile(
                  leading: Icon(Icons.people),
                  title: Text('User Management'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'reports',
                child: ListTile(
                  leading: Icon(Icons.assignment),
                  title: Text('Report Management'),
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
          _buildOverviewTab(),
          _buildReportsTab(),
          _buildAnalyticsTab(),
          _buildEmergencyTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: AppColors.errorRed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Overview',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment),
            label: 'All Reports',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.emergency),
            label: 'Emergency',
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return RefreshIndicator(
      onRefresh: _loadAllReports,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppTheme.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: 'System Administrator',
              subtitle: 'System-wide monitoring and management\nAll reports • All companies • Real-time data',
              icon: Icons.admin_panel_settings,
              iconColor: AppColors.errorRed,
            ),
            
            SizedBox(height: AppTheme.sectionPadding.top),
            
            SectionHeader(
              title: 'System Overview',
              subtitle: 'Real-time statistics across all companies',
            ),
            _buildSystemStatsGrid(),
            
            SizedBox(height: AppTheme.sectionPadding.top),
            
            SectionHeader(
              title: 'Reports Location Overview',
              action: TextButton.icon(
                onPressed: () => setState(() => _currentIndex = 1),
                icon: const Icon(Icons.map, size: 16),
                label: const Text('View All'),
              ),
            ),
            _buildReportsMapSection(),
            
            SizedBox(height: AppTheme.sectionPadding.top),
            
            SectionHeader(
              title: 'Recent Activity',
              action: TextButton(
                onPressed: () => setState(() => _currentIndex = 1),
                child: const Text('View All'),
              ),
            ),
            _buildRecentActivitySection(),
            
            SizedBox(height: AppTheme.sectionPadding.top),
            
            SectionHeader(title: 'Quick Actions'),
            _buildQuickActionsGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemStatsGrid() {
    final totalReports = _allReports.length;
    final citizenReports = _allReports.where((r) => r.reportType == 'standard').length;
    final employeeReports = _allReports.where((r) => r.reportType == 'employee').length;
    final emergencyReports = _allReports.where((r) => r.reportType == 'emergency_audio').length;
    final highPriorityReports = _allReports.where((r) => r.severityLevel == 'high').length;
    final pendingReports = _allReports.where((r) => r.status == 'submitted' || r.status == 'under_review').length;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: AppTheme.mediumSpacing,
      crossAxisSpacing: AppTheme.mediumSpacing,
      childAspectRatio: 1.5,
      children: [
        StatCard(
          label: 'Total Reports',
          value: totalReports.toString(),
          icon: Icons.assignment,
          color: AppColors.infoBlue,
        ),
        StatCard(
          label: 'Citizen Reports',
          value: citizenReports.toString(),
          icon: Icons.person,
          color: AppColors.successGreen,
        ),
        StatCard(
          label: 'Employee Reports',
          value: employeeReports.toString(),
          icon: Icons.business,
          color: AppColors.primaryBlue,
        ),
        StatCard(
          label: 'Emergency Reports',
          value: emergencyReports.toString(),
          icon: Icons.emergency,
          color: AppColors.errorRed,
          subtitle: 'Requires immediate attention',
        ),
        StatCard(
          label: 'High Priority',
          value: highPriorityReports.toString(),
          icon: Icons.priority_high,
          color: AppColors.warningOrange,
        ),
        StatCard(
          label: 'Pending Review',
          value: pendingReports.toString(),
          icon: Icons.pending,
          color: AppColors.warningOrange,
        ),
      ],
    );
  }

  Widget _buildReportsMapSection() {
    if (_isLoading) {
      return const LoadingWidget();
    } else if (_allReports.isEmpty) {
      return const EmptyState(
        icon: Icons.map,
        title: 'No Reports to Display',
        subtitle: 'Location data will appear here when reports are submitted',
      );
    } else {
      return ReportsOverviewMap(
        reports: _allReports,
        height: 250,
        onReportTapped: (report) => _showReportDetails(report),
      );
    }
  }

  Widget _buildRecentActivitySection() {
    final recentReports = _allReports.take(5).toList();

    if (_isLoading) {
      return const LoadingWidget();
    } else if (_error.isNotEmpty) {
      return Container(
        padding: AppTheme.cardPadding,
        decoration: BoxDecoration(
          color: AppColors.errorRed.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
        ),
        child: Column(
          children: [
            Icon(Icons.error, color: AppColors.errorRed),
            SizedBox(height: AppTheme.smallSpacing),
            Text('Error loading reports: $_error'),
            SizedBox(height: AppTheme.smallSpacing),
            ElevatedButton(
              onPressed: _loadAllReports,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    } else if (recentReports.isEmpty) {
      return const EmptyState(
        icon: Icons.assignment,
        title: 'No Reports Yet',
        subtitle: 'Reports will appear here as they are submitted',
      );
    } else {
      return Column(
        children: recentReports
            .map((report) => Padding(
              padding: EdgeInsets.only(bottom: AppTheme.mediumSpacing),
              child: ReportCard(
                report: report,
                onTap: () => _showReportDetails(report),
                showCompanyInfo: true,
              ),
            ))
            .toList(),
      );
    }
  }

  Widget _buildQuickActionsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: AppTheme.mediumSpacing,
      crossAxisSpacing: AppTheme.mediumSpacing,
      childAspectRatio: 1.2,
      children: [
        InfoCard(
          title: 'System Analytics',
          subtitle: 'View comprehensive reports',
          icon: Icons.analytics,
          color: AppColors.infoBlue,
          onTap: () => setState(() => _currentIndex = 2),
        ),
        InfoCard(
          title: 'Emergency Reports',
          subtitle: 'Monitor urgent incidents',
          icon: Icons.emergency,
          color: AppColors.errorRed,
          onTap: () => setState(() => _currentIndex = 3),
        ),
        InfoCard(
          title: 'User Management',
          subtitle: 'Manage system users',
          icon: Icons.people,
          color: AppColors.primaryBlue,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const UserManagementPage(),
            ),
          ),
        ),
        InfoCard(
          title: 'System Settings',
          subtitle: 'Configure system',
          icon: Icons.settings,
          color: AppColors.successGreen,
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('System Settings - Coming Soon')),
          ),
        ),
      ],
    );
  }

  Widget _buildReportsTab() {
    final filteredReports = _getFilteredReports();

    return Column(
      children: [
        // Filters
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: AppColors.lightGrey)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedReportType,
                      decoration: const InputDecoration(
                        labelText: 'Report Type',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All Types')),
                        DropdownMenuItem(value: 'standard', child: Text('Citizen Reports')),
                        DropdownMenuItem(value: 'employee', child: Text('Employee Reports')),
                        DropdownMenuItem(value: 'emergency_audio', child: Text('Emergency Reports')),
                      ],
                      onChanged: (value) => setState(() => _selectedReportType = value!),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedStatus,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All Status')),
                        DropdownMenuItem(value: 'submitted', child: Text('Submitted')),
                        DropdownMenuItem(value: 'under_review', child: Text('Under Review')),
                        DropdownMenuItem(value: 'investigating', child: Text('Investigating')),
                        DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
                        DropdownMenuItem(value: 'closed', child: Text('Closed')),
                      ],
                      onChanged: (value) => setState(() => _selectedStatus = value!),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // Reports list
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadAllReports,
            child: _isLoading
                ? const LoadingWidget()
                : filteredReports.isEmpty
                    ? const EmptyStateWidget(
                        icon: Icons.assignment,
                        title: 'No Reports Found',
                        subtitle: 'No reports match the selected filters',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredReports.length,
                        itemBuilder: (context, index) {
                          final report = filteredReports[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: ReportCard(
                              report: report,
                              onTap: () => _showReportDetails(report),
                              showCompanyInfo: true,
                            ),
                          );
                        },
                      ),
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
          Text(
            'System Analytics',
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
                  'Advanced Analytics - Coming Soon',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.infoBlue,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Comprehensive system-wide analytics, trend analysis, and predictive insights will be available soon.',
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

  Widget _buildEmergencyTab() {
    final emergencyReports = _allReports.where((r) => r.reportType == 'emergency_audio').toList();

    return RefreshIndicator(
      onRefresh: _loadAllReports,
      child: emergencyReports.isEmpty
          ? const EmptyStateWidget(
              icon: Icons.emergency,
              title: 'No Emergency Reports',
              subtitle: 'Emergency audio reports will appear here',
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: emergencyReports.length,
              itemBuilder: (context, index) {
                final report = emergencyReports[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    color: AppColors.errorRed.withOpacity(0.05),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.errorRed.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ReportCard(
                        report: report,
                        onTap: () => _showReportDetails(report),
                        showCompanyInfo: true,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  List<Report> _getFilteredReports() {
    var reports = _allReports;

    if (_selectedReportType != 'all') {
      reports = reports.where((r) => r.reportType == _selectedReportType).toList();
    }

    if (_selectedStatus != 'all') {
      reports = reports.where((r) => r.status == _selectedStatus).toList();
    }

    return reports;
  }

  void _showReportDetails(Report report) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
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
                    // Admin-specific header with more actions
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
                                '${report.incidentType} • ${report.reportType.toUpperCase()}',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (value) async {
                            switch (value) {
                              case 'under_review':
                              case 'investigating':
                              case 'resolved':
                              case 'closed':
                                try {
                                  await _databaseService.updateReportStatus(report.id, value);
                                  await _loadAllReports();
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Report status updated to ${value.replaceAll('_', ' ')}'),
                                      backgroundColor: AppColors.successGreen,
                                    ),
                                  );
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Failed to update status: $e'),
                                      backgroundColor: AppColors.errorRed,
                                    ),
                                  );
                                }
                                break;
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'under_review',
                              child: Text('Mark Under Review'),
                            ),
                            const PopupMenuItem(
                              value: 'investigating',
                              child: Text('Mark Investigating'),
                            ),
                            const PopupMenuItem(
                              value: 'resolved',
                              child: Text('Mark Resolved'),
                            ),
                            const PopupMenuItem(
                              value: 'closed',
                              child: Text('Mark Closed'),
                            ),
                          ],
                          icon: Icon(Icons.more_vert),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getStatusColor(report.status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _getStatusColor(report.status)),
                      ),
                      child: Text(
                        report.status.replaceAll('_', ' ').toUpperCase(),
                        style: TextStyle(
                          color: _getStatusColor(report.status),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Report details (same as employee dashboard)
                    // ...existing report details code...
                  ],
                ),
              ),
            ),
          ],
        ),
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
