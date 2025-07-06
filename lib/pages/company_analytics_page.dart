import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_colors.dart';
import '../services/database_service.dart';
import '../models/report_model.dart';
import '../widgets/responsive_wrapper.dart';

class CompanyAnalyticsPage extends StatefulWidget {
  final String companyDomain;

  const CompanyAnalyticsPage({super.key, required this.companyDomain});

  @override
  State<CompanyAnalyticsPage> createState() => _CompanyAnalyticsPageState();
}

class _CompanyAnalyticsPageState extends State<CompanyAnalyticsPage> {
  final DatabaseService _databaseService = DatabaseService();
  List<Report> _companyReports = [];
  bool _isLoading = false;
  String _selectedPeriod = '30_days';

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);
    try {
      final reports = await _databaseService.getAllReports();
      final filteredReports = reports.where((report) => 
        report.employerName?.toLowerCase().contains(widget.companyDomain.toLowerCase()) ?? false
      ).toList();
      
      setState(() {
        _companyReports = filteredReports;
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildMetricsOverview(),
            const SizedBox(height: 24),
            _buildChartsSection(),
            const SizedBox(height: 24),
            _buildTrendsSection(),
            const SizedBox(height: 24),
            _buildRecommendations(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
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
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                'Safety insights for ${widget.companyDomain}',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.lightGrey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButton<String>(
            value: _selectedPeriod,
            underline: const SizedBox.shrink(),
            items: [
              DropdownMenuItem(value: '7_days', child: Text('Last 7 days')),
              DropdownMenuItem(value: '30_days', child: Text('Last 30 days')),
              DropdownMenuItem(value: '90_days', child: Text('Last 90 days')),
              DropdownMenuItem(value: '1_year', child: Text('Last year')),
            ],
            onChanged: (value) {
              setState(() {
                _selectedPeriod = value!;
              });
              _loadAnalytics();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMetricsOverview() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final totalReports = _companyReports.length;
    final highSeverity = _companyReports.where((r) => r.severityLevel == 'high').length;
    final resolved = _companyReports.where((r) => r.status == 'resolved').length;
    final avgResponseTime = '2.4'; // Mock data

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Key Metrics',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Total Reports',
                '$totalReports',
                Icons.assignment,
                AppColors.primaryBlue,
                '+12%',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                'High Severity',
                '$highSeverity',
                Icons.warning,
                AppColors.errorRed,
                '+3',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Resolved',
                '$resolved',
                Icons.check_circle,
                AppColors.successGreen,
                '85%',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                'Avg Response',
                '${avgResponseTime}h',
                Icons.timer,
                AppColors.infoBlue,
                '-0.2h',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color, String change) {
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
                change,
                style: TextStyle(
                  color: change.startsWith('+') || change.startsWith('-') 
                      ? (change.startsWith('+') ? AppColors.successGreen : AppColors.errorRed)
                      : AppColors.mediumGrey,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
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

  Widget _buildChartsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Visual Analytics',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildSeverityChart()),
            const SizedBox(width: 16),
            Expanded(child: _buildStatusChart()),
          ],
        ),
        const SizedBox(height: 16),
        _buildTrendChart(),
      ],
    );
  }

  Widget _buildSeverityChart() {
    final high = _companyReports.where((r) => r.severityLevel == 'high').length;
    final medium = _companyReports.where((r) => r.severityLevel == 'medium').length;
    final low = _companyReports.where((r) => r.severityLevel == 'low').length;
    final total = high + medium + low;

    if (total == 0) {
      return _buildEmptyChart('Severity Distribution');
    }

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
          Text(
            'Severity Distribution',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: PieChart(
              PieChartData(
                sections: [
                  PieChartSectionData(
                    value: high.toDouble(),
                    title: '${((high / total) * 100).round()}%',
                    color: AppColors.errorRed,
                    radius: 50,
                  ),
                  PieChartSectionData(
                    value: medium.toDouble(),
                    title: '${((medium / total) * 100).round()}%',
                    color: AppColors.warningOrange,
                    radius: 50,
                  ),
                  PieChartSectionData(
                    value: low.toDouble(),
                    title: '${((low / total) * 100).round()}%',
                    color: AppColors.successGreen,
                    radius: 50,
                  ),
                ],
                centerSpaceRadius: 30,
                sectionsSpace: 2,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildLegend([
            ('High', high, AppColors.errorRed),
            ('Medium', medium, AppColors.warningOrange),
            ('Low', low, AppColors.successGreen),
          ]),
        ],
      ),
    );
  }

  Widget _buildStatusChart() {
    final submitted = _companyReports.where((r) => r.status == 'submitted').length;
    final underReview = _companyReports.where((r) => r.status == 'under_review').length;
    final investigating = _companyReports.where((r) => r.status == 'investigating').length;
    final resolved = _companyReports.where((r) => r.status == 'resolved').length;
    final total = submitted + underReview + investigating + resolved;

    if (total == 0) {
      return _buildEmptyChart('Status Overview');
    }

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
          Text(
            'Status Overview',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: [submitted, underReview, investigating, resolved].reduce((a, b) => a > b ? a : b).toDouble() + 1,
                barGroups: [
                  BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: submitted.toDouble(), color: AppColors.infoBlue, width: 16)]),
                  BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: underReview.toDouble(), color: AppColors.warningOrange, width: 16)]),
                  BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: investigating.toDouble(), color: AppColors.errorRed, width: 16)]),
                  BarChartGroupData(x: 3, barRods: [BarChartRodData(toY: resolved.toDouble(), color: AppColors.successGreen, width: 16)]),
                ],
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        switch (value.toInt()) {
                          case 0: return Text('Sub', style: TextStyle(fontSize: 10));
                          case 1: return Text('Rev', style: TextStyle(fontSize: 10));
                          case 2: return Text('Inv', style: TextStyle(fontSize: 10));
                          case 3: return Text('Res', style: TextStyle(fontSize: 10));
                          default: return Text('');
                        }
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(show: false),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendChart() {
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
          Text(
            'Reports Trend (Last 30 Days)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: true),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text('Day ${value.toInt()}', style: TextStyle(fontSize: 10));
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: _generateMockTrendData(),
                    isCurved: true,
                    color: AppColors.primaryBlue,
                    barWidth: 3,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.primaryBlue.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendsSection() {
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
          Text(
            'Trending Insights',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _buildTrendItem(
            'Most Common Incident',
            'Safety violations (45%)',
            Icons.trending_up,
            AppColors.errorRed,
            'Up 12% from last month',
          ),
          const SizedBox(height: 12),
          _buildTrendItem(
            'Peak Incident Time',
            '2:00 PM - 4:00 PM',
            Icons.schedule,
            AppColors.warningOrange,
            'Afternoon shift focus needed',
          ),
          const SizedBox(height: 12),
          _buildTrendItem(
            'Best Performing Area',
            'Office Environment',
            Icons.check_circle,
            AppColors.successGreen,
            'Zero incidents this month',
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendations() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.infoBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.infoBlue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb, color: AppColors.infoBlue),
              const SizedBox(width: 8),
              Text(
                'AI Recommendations',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildRecommendationItem(
            'Increase safety training frequency',
            'Consider weekly safety briefings for high-risk areas',
          ),
          _buildRecommendationItem(
            'Improve afternoon shift supervision',
            'Most incidents occur between 2-4 PM',
          ),
          _buildRecommendationItem(
            'Implement equipment inspection schedule',
            'Equipment-related incidents have increased by 23%',
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChart(String title) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightGrey),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 32),
          Icon(Icons.bar_chart, size: 48, color: AppColors.mediumGrey),
          const SizedBox(height: 8),
          Text(
            'No data available',
            style: TextStyle(color: AppColors.mediumGrey),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(List<(String, int, Color)> items) {
    return Column(
      children: items.map((item) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: item.$3,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${item.$1}: ${item.$2}',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildTrendItem(String title, String value, IconData icon, Color color, String subtitle) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendationItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: AppColors.infoBlue,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
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

  List<FlSpot> _generateMockTrendData() {
    // Generate mock trend data for the last 30 days
    return List.generate(30, (index) {
      return FlSpot(index.toDouble(), (index % 7 + 1).toDouble());
    });
  }
}
