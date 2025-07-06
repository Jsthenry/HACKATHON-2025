import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../services/auth_service.dart';
import 'employee_dashboard_page.dart';
import 'company_hsse_page.dart';
import 'employee_signup_page.dart';

class EmployeeLoginPage extends StatefulWidget {
  final String? targetRole; // Add this to specify which role is logging in

  const EmployeeLoginPage({super.key, this.targetRole});

  @override
  State<EmployeeLoginPage> createState() => _EmployeeLoginPageState();
}

class _EmployeeLoginPageState extends State<EmployeeLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await AuthService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      // Get user profile to determine role and company
      final profile = await AuthService.getUserProfile();
      if (profile == null) {
        throw Exception('Failed to load user profile');
      }

      final role = profile['role'];
      final companyDomain = profile['company_domain'];

      // Validate role matches target role if specified
      if (widget.targetRole != null && role != widget.targetRole) {
        await AuthService.signOut();
        throw Exception('Invalid credentials for ${_getRoleDisplayName(widget.targetRole!)}');
      }

      // Navigate based on actual role
      if (role == 'employee') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => EmployeeDashboardPage(
              employeeEmail: _emailController.text.trim(),
              companyDomain: companyDomain ?? '',
            ),
          ),
        );
      } else if (role == 'hsse_officer') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => CompanyHSSEPage(
              companyDomain: companyDomain ?? '',
            ),
          ),
        );
      } else {
        throw Exception('Invalid role for employee login: $role');
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login failed: ${e.toString()}'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getRoleDisplayName(String role) {
    switch (role) {
      case 'employee':
        return 'Company Employee';
      case 'hsse_officer':
        return 'HSSE Officer/Manager';
      default:
        return role;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine title and description based on target role
    final title = widget.targetRole != null 
        ? _getRoleDisplayName(widget.targetRole!)
        : 'Employee Portal';
    
    final description = widget.targetRole == 'employee'
        ? 'Sign in with your company email to submit internal HSSE reports'
        : widget.targetRole == 'hsse_officer'
            ? 'Sign in to manage your company\'s HSSE program and investigate incidents'
            : 'Sign in with your company email to access internal HSSE reporting';

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text('$title Login'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              
              // Header - dynamic icon based on role
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _getRoleColor().withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getRoleIcon(),
                  size: 64,
                  color: _getRoleColor(),
                ),
              ),
              
              const SizedBox(height: 32),
              
              Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 16),
              
              Text(
                description,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 48),
              
              // Email field
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Company Email',
                  hintText: 'your.name@company.com',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                ),
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Email is required';
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value!)) {
                    return 'Enter a valid email address';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 24),
              
              // Password field
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  hintText: 'Enter your password',
                  prefixIcon: const Icon(Icons.lock_outlined),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                  ),
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                ),
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Password is required';
                  if (value!.length < 6) return 'Password must be at least 6 characters';
                  return null;
                },
              ),
              
              const SizedBox(height: 32),
              
              // Sign in button
              ElevatedButton(
                onPressed: _isLoading ? null : _signIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _getRoleColor(),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Sign In',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              
              const SizedBox(height: 24),
              
              // Divider
              Row(
                children: [
                  Expanded(child: Divider(color: AppColors.lightGrey)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Don\'t have an account?',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                  Expanded(child: Divider(color: AppColors.lightGrey)),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Sign up button
              OutlinedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EmployeeSignupPage(),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryBlue,
                  side: BorderSide(color: AppColors.primaryBlue),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Create Employee Account',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Info card
              Container(
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
                        Icon(Icons.info_outline, color: AppColors.infoBlue, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Employee Access Features',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.infoBlue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...[
                      'Submit internal company reports',
                      'View your submitted reports',
                      'Access company safety guidelines',
                      'Receive report status updates',
                    ].map((feature) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(Icons.check, color: AppColors.successGreen, size: 16),
                          const SizedBox(width: 8),
                          Expanded(child: Text(feature, style: TextStyle(fontSize: 14))),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getRoleColor() {
    switch (widget.targetRole) {
      case 'employee':
        return AppColors.successGreen;
      case 'hsse_officer':
        return AppColors.warningOrange;
      default:
        return AppColors.primaryBlue;
    }
  }

  IconData _getRoleIcon() {
    switch (widget.targetRole) {
      case 'employee':
        return Icons.person;
      case 'hsse_officer':
        return Icons.security;
      default:
        return Icons.business;
    }
  }
}
