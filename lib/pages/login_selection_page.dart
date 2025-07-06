import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/common_widgets.dart';
import '../theme/app_theme.dart';
import 'employee_login_page.dart';
import 'admin_login_page.dart';

class LoginSelectionPage extends StatelessWidget {
  const LoginSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Select Login Type'),
      ),
      body: SingleChildScrollView(
        padding: AppTheme.screenPadding,
        child: Column(
          children: [
            // Header
            PageHeader(
              title: 'HSSE Portal Login',
              subtitle: 'Choose your access level to continue',
              icon: Icons.admin_panel_settings,
              iconColor: AppColors.primaryBlue,
            ),
            
            SizedBox(height: AppTheme.extraLargeSpacing),
            
            // Login Options
            InfoCard(
              title: 'System Administrator',
              subtitle: 'Full system access\nView all reports from all companies',
              icon: Icons.admin_panel_settings,
              color: AppColors.errorRed,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminLoginPage(),
                ),
              ),
            ),
            
            SizedBox(height: AppTheme.mediumSpacing),
            
            InfoCard(
              title: 'Company HSSE Manager',
              subtitle: 'Manage your company\'s HSSE reports and safety metrics',
              icon: Icons.business,
              color: AppColors.primaryBlue,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const EmployeeLoginPage(targetRole: 'hsse_officer'),
                ),
              ),
            ),
            
            SizedBox(height: AppTheme.mediumSpacing),
            
            InfoCard(
              title: 'HSSE Officer',
              subtitle: 'Investigate incidents and manage safety compliance',
              icon: Icons.security,
              color: AppColors.warningOrange,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const EmployeeLoginPage(targetRole: 'hsse_officer'),
                ),
              ),
            ),
            
            SizedBox(height: AppTheme.mediumSpacing),
            
            InfoCard(
              title: 'Company Employee',
              subtitle: 'Submit HSSE reports through your company system',
              icon: Icons.person,
              color: AppColors.successGreen,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const EmployeeLoginPage(targetRole: 'employee'),
                ),
              ),
            ),
            
            SizedBox(height: AppTheme.extraLargeSpacing),
            
            // Back button
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to Citizen Portal'),
            ),
          ],
        ),
      ),
    );
  }
}
