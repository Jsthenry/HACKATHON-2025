import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class CompanySettingsPage extends StatefulWidget {
  final String companyDomain;

  const CompanySettingsPage({super.key, required this.companyDomain});

  @override
  State<CompanySettingsPage> createState() => _CompanySettingsPageState();
}

class _CompanySettingsPageState extends State<CompanySettingsPage> {
  final _companyNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  
  bool _emailNotifications = true;
  bool _smsNotifications = false;
  bool _autoAssignReports = true;
  String _defaultPriority = 'medium';

  @override
  void initState() {
    super.initState();
    _loadCompanySettings();
  }

  void _loadCompanySettings() {
    // Mock data loading
    _companyNameController.text = widget.companyDomain.split('.')[0].toUpperCase();
    _emailController.text = 'hsse@${widget.companyDomain}';
    _phoneController.text = '+592-123-4567';
    _addressController.text = '123 Main Street, Georgetown, Guyana';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Company Settings'),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCompanyInfoSection(),
            const SizedBox(height: 24),
            _buildNotificationSettings(),
            const SizedBox(height: 24),
            _buildReportSettings(),
            const SizedBox(height: 24),
            _buildSecuritySettings(),
            const SizedBox(height: 32),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanyInfoSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Company Information',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          
          _buildTextField(
            controller: _companyNameController,
            label: 'Company Name',
            icon: Icons.business,
          ),
          const SizedBox(height: 16),
          
          _buildTextField(
            controller: _emailController,
            label: 'HSSE Email',
            icon: Icons.email,
          ),
          const SizedBox(height: 16),
          
          _buildTextField(
            controller: _phoneController,
            label: 'Phone Number',
            icon: Icons.phone,
          ),
          const SizedBox(height: 16),
          
          _buildTextField(
            controller: _addressController,
            label: 'Address',
            icon: Icons.location_on,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationSettings() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Notification Preferences',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          
          SwitchListTile(
            title: const Text('Email Notifications'),
            subtitle: const Text('Receive incident reports via email'),
            value: _emailNotifications,
            onChanged: (value) => setState(() => _emailNotifications = value),
            contentPadding: EdgeInsets.zero,
          ),
          
          SwitchListTile(
            title: const Text('SMS Notifications'),
            subtitle: const Text('Receive urgent alerts via SMS'),
            value: _smsNotifications,
            onChanged: (value) => setState(() => _smsNotifications = value),
            contentPadding: EdgeInsets.zero,
          ),
          
          SwitchListTile(
            title: const Text('Auto-assign Reports'),
            subtitle: const Text('Automatically assign reports to available officers'),
            value: _autoAssignReports,
            onChanged: (value) => setState(() => _autoAssignReports = value),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildReportSettings() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Report Settings',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          
          Text(
            'Default Priority Level',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          
          DropdownButtonFormField<String>(
            value: _defaultPriority,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: [
              DropdownMenuItem(value: 'low', child: Text('Low Priority')),
              DropdownMenuItem(value: 'medium', child: Text('Medium Priority')),
              DropdownMenuItem(value: 'high', child: Text('High Priority')),
            ],
            onChanged: (value) => setState(() => _defaultPriority = value!),
          ),
          
          const SizedBox(height: 16),
          
          _buildFeatureCard(
            'Report Templates',
            'Customize report forms for your industry',
            Icons.description,
            AppColors.infoBlue,
            'Coming Soon',
          ),
          
          const SizedBox(height: 12),
          
          _buildFeatureCard(
            'Custom Fields',
            'Add company-specific fields to reports',
            Icons.add_box,
            AppColors.successGreen,
            'Configure',
          ),
        ],
      ),
    );
  }

  Widget _buildSecuritySettings() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Security & Privacy',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          
          _buildSecurityItem(
            'Two-Factor Authentication',
            'Enhance account security',
            Icons.security,
            'Enable',
          ),
          
          const SizedBox(height: 12),
          
          _buildSecurityItem(
            'Data Retention Policy',
            'Manage how long data is stored',
            Icons.storage,
            'Configure',
          ),
          
          const SizedBox(height: 12),
          
          _buildSecurityItem(
            'Access Logs',
            'View system access history',
            Icons.history,
            'View Logs',
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: AppColors.lightGrey.withOpacity(0.3),
      ),
      maxLines: maxLines,
    );
  }

  Widget _buildFeatureCard(String title, String subtitle, IconData icon, Color color, String action) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
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
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$action feature coming soon!')),
              );
            },
            child: Text(action),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityItem(String title, String subtitle, IconData icon, String action) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.lightGrey.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary),
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
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$action feature coming soon!')),
              );
            },
            child: Text(action),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _saveSettings,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          'Save Settings',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _saveSettings() {
    // TODO: Save settings to database
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Settings saved successfully!'),
        backgroundColor: AppColors.successGreen,
      ),
    );
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }
}
