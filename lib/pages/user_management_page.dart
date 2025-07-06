import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../models/company_model.dart';
import '../theme/app_colors.dart';
import '../widgets/loading_widget.dart';
import '../widgets/empty_state_widget.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final DatabaseService _databaseService = DatabaseService();
  
  List<UserProfile> _users = [];
  List<Company> _companies = [];
  bool _isLoading = true;
  String _error = '';
  String _selectedRoleFilter = 'all';
  String _selectedCompanyFilter = 'all';
  String _searchQuery = '';
  
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUsersAndCompanies();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsersAndCompanies() async {
    try {
      setState(() {
        _isLoading = true;
        _error = '';
      });

      // Load both users and companies
      final futures = await Future.wait([
        _databaseService.getAllUsers(),
        _databaseService.getAllCompanies(),
      ]);

      setState(() {
        _users = futures[0] as List<UserProfile>;
        _companies = futures[1] as List<Company>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<UserProfile> get _filteredUsers {
    var filtered = _users;

    // Filter by role
    if (_selectedRoleFilter != 'all') {
      filtered = filtered.where((user) => user.role == _selectedRoleFilter).toList();
    }

    // Filter by company
    if (_selectedCompanyFilter != 'all') {
      filtered = filtered.where((user) => user.companyDomain == _selectedCompanyFilter).toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((user) =>
        user.email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        (user.fullName?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false)
      ).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('User Management'),
        backgroundColor: AppColors.errorRed,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loadUsersAndCompanies,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFiltersSection(),
          Expanded(child: _buildUsersContent()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddUserDialog(),
        backgroundColor: AppColors.errorRed,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('Add User'),
      ),
    );
  }

  Widget _buildFiltersSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.lightGrey)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Search bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search users by name or email...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        });
                      },
                      icon: const Icon(Icons.clear),
                    )
                  : null,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
          
          const SizedBox(height: 16),
          
          // Filter dropdowns
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedRoleFilter,
                  decoration: const InputDecoration(
                    labelText: 'Filter by Role',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Roles')),
                    DropdownMenuItem(value: 'admin', child: Text('Administrators')),
                    DropdownMenuItem(value: 'hsse_officer', child: Text('HSSE Officers')),
                    DropdownMenuItem(value: 'employee', child: Text('Employees')),
                    DropdownMenuItem(value: 'citizen', child: Text('Citizens')),
                  ],
                  onChanged: (value) => setState(() => _selectedRoleFilter = value!),
                ),
              ),
              
              const SizedBox(width: 16),
              
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedCompanyFilter,
                  decoration: const InputDecoration(
                    labelText: 'Filter by Company',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem(value: 'all', child: Text('All Companies')),
                    ..._companies.map((company) => DropdownMenuItem(
                      value: company.domain,
                      child: Text(company.name),
                    )),
                  ],
                  onChanged: (value) => setState(() => _selectedCompanyFilter = value!),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUsersContent() {
    if (_isLoading) {
      return const LoadingWidget(message: 'Loading users...');
    }

    if (_error.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, color: AppColors.errorRed, size: 48),
            const SizedBox(height: 16),
            Text(
              'Error loading users',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error,
              style: TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadUsersAndCompanies,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final filteredUsers = _filteredUsers;

    if (filteredUsers.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.people,
        title: 'No Users Found',
        subtitle: 'No users match the current filters',
      );
    }

    return Column(
      children: [
        // Users count
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(
                '${filteredUsers.length} user(s) found',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              _buildBulkActionsButton(),
            ],
          ),
        ),
        
        // Users list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: filteredUsers.length,
            itemBuilder: (context, index) {
              final user = filteredUsers[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildUserCard(user),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUserCard(UserProfile user) {
    final company = _companies.firstWhere(
      (c) => c.domain == user.companyDomain,
      orElse: () => Company(
        id: '',
        domain: user.companyDomain ?? '',
        name: user.companyDomain ?? 'Unknown',
        settings: {},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 24,
                  backgroundColor: _getRoleColor(user.role).withOpacity(0.1),
                  child: Icon(
                    _getRoleIcon(user.role),
                    color: _getRoleColor(user.role),
                    size: 24,
                  ),
                       ),
                
                const SizedBox(width: 16),
                
                // User info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              user.fullName ?? user.email.split('@')[0],
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getRoleColor(user.role).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _getRoleColor(user.role)),
                            ),
                            child: Text(
                              _getRoleDisplayName(user.role),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _getRoleColor(user.role),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.email,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (user.companyDomain != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.business, size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              company.name,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Status indicator
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: user.isActive ? AppColors.successGreen : AppColors.errorRed,
                    shape: BoxShape.circle,
                  ),
                ),
                
                const SizedBox(width: 8),
                
                // Actions menu
                PopupMenuButton<String>(
                  onSelected: (value) => _handleUserAction(value, user),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(Icons.edit),
                        title: Text('Edit User'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: user.isActive ? 'deactivate' : 'activate',
                      child: ListTile(
                        leading: Icon(
                          user.isActive ? Icons.block : Icons.check_circle,
                          color: user.isActive ? AppColors.errorRed : AppColors.successGreen,
                        ),
                        title: Text(user.isActive ? 'Deactivate' : 'Activate'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'reset_password',
                      child: ListTile(
                        leading: Icon(Icons.lock_reset),
                        title: Text('Reset Password'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    if (user.role != 'admin') ...[
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete, color: Colors.red),
                          title: Text('Delete User', style: TextStyle(color: Colors.red)),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Additional info
            Row(
              children: [
                Text(
                  'Created: ${_formatDate(user.createdAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                if (user.phone != null) ...[
                  Icon(Icons.phone, size: 12, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    user.phone!,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBulkActionsButton() {
    return PopupMenuButton<String>(
      onSelected: _handleBulkAction,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.lightGrey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.more_horiz, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(
              'Bulk Actions',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'export',
          child: ListTile(
            leading: Icon(Icons.download),
            title: Text('Export Users'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: 'bulk_deactivate',
          child: ListTile(
            leading: Icon(Icons.block, color: Colors.orange),
            title: Text('Bulk Deactivate'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  void _showAddUserDialog() {
    showDialog(
      context: context,
      builder: (context) => AddUserDialog(
        companies: _companies,
        onUserAdded: _loadUsersAndCompanies,
      ),
    );
  }

  void _showEditUserDialog(UserProfile user) {
    showDialog(
      context: context,
      builder: (context) => EditUserDialog(
        user: user,
        companies: _companies,
        onUserUpdated: _loadUsersAndCompanies,
      ),
    );
  }

  void _handleUserAction(String action, UserProfile user) async {
    switch (action) {
      case 'edit':
        _showEditUserDialog(user);
        break;
      case 'activate':
      case 'deactivate':
        await _toggleUserStatus(user);
        break;
      case 'reset_password':
        await _resetUserPassword(user);
        break;
      case 'delete':
        await _deleteUser(user);
        break;
    }
  }

  void _handleBulkAction(String action) {
    switch (action) {
      case 'export':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export functionality - Coming Soon')),
        );
        break;
      case 'bulk_deactivate':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bulk operations - Coming Soon')),
        );
        break;
    }
  }

  Future<void> _toggleUserStatus(UserProfile user) async {
    try {
      await _databaseService.updateUserStatus(user.id, !user.isActive);
      await _loadUsersAndCompanies();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('User ${user.isActive ? 'deactivated' : 'activated'} successfully'),
          backgroundColor: AppColors.successGreen,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update user status: $e'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  Future<void> _resetUserPassword(UserProfile user) async {
    final newPassword = 'TempPass123!';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reset password for ${user.email}?'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.lightGrey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'New temporary password:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    newPassword,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'User will be required to change this password on next login.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _databaseService.resetUserPassword(user.id, newPassword);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Password reset for ${user.email}'),
                    backgroundColor: AppColors.successGreen,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to reset password: $e'),
                    backgroundColor: AppColors.errorRed,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warningOrange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reset Password'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteUser(UserProfile user) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning, color: AppColors.errorRed, size: 48),
            const SizedBox(height: 16),
            Text('Are you sure you want to delete ${user.email}?'),
            const SizedBox(height: 8),
            const Text(
              'This action cannot be undone. All user data will be permanently deleted.',
              style: TextStyle(fontSize: 14, color: Colors.red),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _databaseService.deleteUser(user.id);
                await _loadUsersAndCompanies();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('User ${user.email} deleted successfully'),
                    backgroundColor: AppColors.successGreen,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to delete user: $e'),
                    backgroundColor: AppColors.errorRed,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // Helper methods
  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin':
        return AppColors.errorRed;
      case 'hsse_officer':
        return AppColors.warningOrange;
      case 'employee':
        return AppColors.successGreen;
      case 'citizen':
        return AppColors.infoBlue;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'admin':
        return Icons.admin_panel_settings;
      case 'hsse_officer':
        return Icons.security;
      case 'employee':
        return Icons.person;
      case 'citizen':
        return Icons.public;
      default:
        return Icons.person_outline;
    }
  }

  String _getRoleDisplayName(String role) {
    switch (role) {
      case 'admin':
        return 'ADMIN';
      case 'hsse_officer':
        return 'HSSE';
      case 'employee':
        return 'EMPLOYEE';
      case 'citizen':
        return 'CITIZEN';
      default:
        return role.toUpperCase();
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

// Add User Dialog
class AddUserDialog extends StatefulWidget {
  final List<Company> companies;
  final VoidCallback onUserAdded;

  const AddUserDialog({
    super.key,
    required this.companies,
    required this.onUserAdded,
  });

  @override
  State<AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends State<AddUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  
  String _selectedRole = 'employee';
  String? _selectedCompany;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New User'),
      content: Container(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value?.isEmpty == true ? 'Name is required' : null,
                ),
                
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email Address *',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value?.isEmpty == true) return 'Email is required';
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value!)) {
                      return 'Enter a valid email';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Temporary Password *',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                    ),
                  ),
                  obscureText: _obscurePassword,
                  validator: (value) {
                    if (value?.isEmpty == true) return 'Password is required';
                    if (value!.length < 6) return 'Password must be at least 6 characters';
                    return null;
                  },
                ),
                
                const SizedBox(height: 16),
                
                DropdownButtonFormField<String>(
                  value: _selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Role *',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'employee', child: Text('Employee')),
                    DropdownMenuItem(value: 'hsse_officer', child: Text('HSSE Officer')),
                    DropdownMenuItem(value: 'admin', child: Text('Administrator')),
                    DropdownMenuItem(value: 'citizen', child: Text('Citizen')),
                  ],
                  onChanged: (value) => setState(() => _selectedRole = value!),
                ),
                
                if (_selectedRole != 'citizen' && _selectedRole != 'admin') ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedCompany,
                    decoration: const InputDecoration(
                      labelText: 'Company *',
                      border: OutlineInputBorder(),
                    ),
                    items: widget.companies.map((company) => DropdownMenuItem(
                      value: company.domain,
                      child: Text(company.name),
                    )).toList(),
                    onChanged: (value) => setState(() => _selectedCompany = value),
                    validator: (value) => value == null ? 'Company is required' : null,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _addUser,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.errorRed,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add User'),
        ),
      ],
    );
  }

  Future<void> _addUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await DatabaseService().createUser(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: _fullNameController.text.trim(),
        role: _selectedRole,
        companyDomain: _selectedCompany,
        phone: _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
      );

      widget.onUserAdded();
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('User ${_emailController.text} created successfully'),
          backgroundColor: AppColors.successGreen,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create user: $e'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}

// Edit User Dialog
class EditUserDialog extends StatefulWidget {
  final UserProfile user;
  final List<Company> companies;
  final VoidCallback onUserUpdated;

  const EditUserDialog({
    super.key,
    required this.user,
    required this.companies,
    required this.onUserUpdated,
  });

  @override
  State<EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<EditUserDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullNameController;
  late final TextEditingController _phoneController;
  
  late String _selectedRole;
  String? _selectedCompany;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.user.fullName);
    _phoneController = TextEditingController(text: widget.user.phone);
    _selectedRole = widget.user.role;
    _selectedCompany = widget.user.companyDomain;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit ${widget.user.email}'),
      content: Container(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value?.isEmpty == true ? 'Name is required' : null,
                ),
                
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                
                const SizedBox(height: 16),
                
                DropdownButtonFormField<String>(
                  value: _selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Role *',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'employee', child: Text('Employee')),
                    DropdownMenuItem(value: 'hsse_officer', child: Text('HSSE Officer')),
                    DropdownMenuItem(value: 'admin', child: Text('Administrator')),
                    DropdownMenuItem(value: 'citizen', child: Text('Citizen')),
                  ],
                  onChanged: (value) => setState(() => _selectedRole = value!),
                ),
                
                if (_selectedRole != 'citizen' && _selectedRole != 'admin') ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedCompany,
                    decoration: const InputDecoration(
                      labelText: 'Company *',
                      border: OutlineInputBorder(),
                    ),
                    items: widget.companies.map((company) => DropdownMenuItem(
                      value: company.domain,
                      child: Text(company.name),
                    )).toList(),
                    onChanged: (value) => setState(() => _selectedCompany = value),
                    validator: (value) => value == null ? 'Company is required' : null,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _updateUser,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryBlue,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Update'),
        ),
      ],
    );
  }

  Future<void> _updateUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await DatabaseService().updateUser(
        userId: widget.user.id,
        fullName: _fullNameController.text.trim(),
        role: _selectedRole,
        companyDomain: _selectedCompany,
        phone: _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
      );

      widget.onUserUpdated();
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('User ${widget.user.email} updated successfully'),
          backgroundColor: AppColors.successGreen,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update user: $e'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
